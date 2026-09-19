#!/usr/bin/env python3
"""greeter-anim-launch.py — jalankan overlay animasi di layar login.

Dipanggil otomatis oleh LightDM (greeter-setup-script) sebagai root, saat X
greeter sudah hidup tapi greeter belum/tengah digambar. Tugasnya:

  1. tunggu window greeter muncul,
  2. potret layarnya (yang berisi wallpaper + kartu login yang sudah digambar
     greeter asli — autentikasi tetap milik greeter, bukan script ini),
  3. cari kotak kartu & panel dengan MEMBANDINGKAN potret vs wallpaper resmi,
  4. jalankan overlay (greeter-anim.py) yang menyembunyikan kartu dulu, lalu
     memunculkannya dari bawah saat ada tombol ditekan.

Kalau ada apa pun yang tidak wajar (window tak muncul, potret beda dari
wallpaper, PIL tidak ada, dsb) script hanya mencatat log dan keluar — layar
login tetap tampil normal, jadi tidak ada risiko gagal login.
"""
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time

# Semua path bisa ditimpa lewat env (dipakai untuk uji coba lokal).
WALLPAPER = os.environ.get('ANIME_GLASS_WALLPAPER',
                           '/usr/share/backgrounds/anime-glass/login-bg.jpg')
OVERLAY = os.environ.get('ANIME_GLASS_OVERLAY',
                         '/usr/local/share/anime-glass/greeter-anim.py')
OVERLAY_LOCAL = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'greeter-anim.py')
LOG = os.environ.get('ANIME_GLASS_LOG', '/var/log/anime-glass-anim.log')
LOCK = '/run/anime-glass-anim.pid'
CONF = os.environ.get('ANIME_GLASS_ANIM_CONF', '/etc/lightdm/anime-glass-anim.conf')
WAIT_MAX = 12.0          # detik menunggu window greeter
PANEL_LIMIT = 130        # piksel: di atas ini dianggap area panel
CORE_T = 25              # ambang beda untuk kartu (kuat)
SOFT_T = 6               # ambang beda untuk bayangan/soft edge
SHADOW_PAD = 46          # perluasan area bayangan (px)


def log(msg):
    try:
        with open(LOG, 'a') as f:
            f.write('[anim %s] %s\n' % (time.strftime('%H:%M:%S'), msg))
    except OSError:
        pass
    print(msg)


def read_conf():
    """Baca /etc/lightdm/anime-glass-anim.conf (key=value) bila ada."""
    cfg = {}
    try:
        for line in open(CONF):
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            k, v = line.split('=', 1)
            cfg[k.strip()] = v.strip()
    except OSError:
        pass
    return cfg


def stop_previous():
    """Hentikan overlay lama (mis. saat greeter dijalankan ulang) agar tidak menumpuk."""
    try:
        with open(LOCK) as f:
            pid = int(f.read().strip())
        os.kill(pid, signal.SIGTERM)
        log('overlay lama (pid %d) dihentikan' % pid)
    except Exception:
        pass


def screen_size():
    try:
        out = subprocess.run(['xrandr'], capture_output=True, text=True, timeout=10).stdout
        for line in out.splitlines():
            if '*' in line:
                return tuple(int(v) for v in line.split()[0].split('x'))
    except Exception:
        pass
    return (1920, 1080)


def find_greeter_window(w, h, deadline):
    """Cari window greeter: berukuran layar penuh + punya nama/kelas.

    Window tanpa nama (frame/overlay milik WM) sengaja dilewati supaya tidak
    salah memotret. Utamakan yang berbau 'lightdm'.
    """
    needle = '%dx%d+0+0' % (w, h)
    while time.time() < deadline:
        try:
            out = subprocess.run(['xwininfo', '-root', '-tree'], capture_output=True,
                                 text=True, timeout=10).stdout
        except Exception:
            out = ''
        named, fallback = [], []
        for line in out.splitlines():
            if needle not in line or '"' not in line or 'has no name' in line:
                continue
            wid = next((p for p in line.split() if p.startswith('0x')), None)
            if not wid:
                continue
            (named if 'lightdm' in line.lower() else fallback).append(wid)
        if named:
            return named[0]
        if fallback:
            return fallback[0]
        time.sleep(0.25)
    return None


def shot_window(wid, path):
    for _ in range(3):
        r = subprocess.run(['import', '-window', wid, path], capture_output=True)
        if r.returncode == 0 and os.path.isfile(path) and os.path.getsize(path) > 5000:
            return True
        time.sleep(0.4)
    return False


def bbox_of(diff_img, threshold, y_min=0):
    """Kotak terkecil area yang bedanya > threshold (mulai dari baris y_min)."""
    from PIL import Image
    gray = diff_img.convert('L')
    if y_min:
        gray = gray.crop((0, y_min, gray.width, gray.height))
    mask = gray.point(lambda v: 255 if v >= threshold else 0)
    box = mask.getbbox()
    if not box:
        return None
    if y_min:
        box = (box[0], box[1] + y_min, box[2], box[3] + y_min)
    return box


def build_card(shot_path, bg_path, out_path, core, soft):
    """Potong kartu dari potret + pisahkan bayangannya jadi lapisan semi-transparan."""
    from PIL import Image, ImageChops, ImageDraw, ImageFilter

    shot = Image.open(shot_path).convert('RGB')
    bg = Image.open(bg_path).convert('RGB')
    if shot.size != bg.size:
        shot = shot.resize(bg.size, Image.LANCZOS)

    x0, y0, x1, y1 = soft
    crop = shot.crop((x0, y0, x1, y1))
    shadow_src = ImageChops.difference(shot.crop((x0, y0, x1, y1)), bg.crop((x0, y0, x1, y1)))

    # alpha: kartu = penuh (dengan sudut membulat), bayangan = seberapa gelap dari wallpaper
    card = Image.new('RGBA', crop.size, (0, 0, 0, 0))
    shadow_alpha = shadow_src.convert('L').point(lambda v: min(255, v * 3))
    shadow_layer = Image.new('RGBA', crop.size, (0, 0, 0, 0))
    shadow_layer.putalpha(shadow_alpha)

    core_box = (core[0] - x0, core[1] - y0, core[2] - x0, core[3] - y0)
    core_layer = crop.convert('RGBA')
    mask = Image.new('L', crop.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(core_box, radius=26, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(0.6))       # haluskan tepi
    core_layer.putalpha(mask)

    card = Image.alpha_composite(shadow_layer, core_layer)
    card.save(out_path)
    return out_path


def main():
    cfg = read_conf()
    if cfg.get('enabled', '1') not in ('1', 'true', 'yes', 'on'):
        log('animasi dimatikan lewat %s' % CONF)
        return 0
    if not os.path.isfile(WALLPAPER):
        log('wallpaper %s tidak ada -> animasi dilewati' % WALLPAPER)
        return 0
    try:
        import PIL  # noqa: F401
    except ImportError:
        log('python3-pil tidak ada -> animasi dilewati')
        return 0
    overlay = OVERLAY if os.path.isfile(OVERLAY) else OVERLAY_LOCAL
    if not os.path.isfile(overlay):
        log('overlay %s tidak ada -> animasi dilewati' % overlay)
        return 0

    w, h = screen_size()
    deadline = time.time() + WAIT_MAX
    wid = find_greeter_window(w, h, deadline)
    if not wid:
        log('window greeter tidak ditemukan dalam %gs -> animasi dilewati' % WAIT_MAX)
        return 0
    time.sleep(0.9)                                  # beri waktu greeter menggambar kartu

    tmp = tempfile.mkdtemp(prefix='anime-glass-anim-')
    shot = os.path.join(tmp, 'shot.png')
    if not shot_window(wid, shot):
        log('gagal memotret window greeter (%s) -> animasi dilewati' % wid)
        shutil.rmtree(tmp, ignore_errors=True)
        return 0

    try:
        from PIL import Image, ImageChops
        sh = Image.open(shot).convert('RGB')
        bg = Image.open(WALLPAPER).convert('RGB')
        if sh.size != bg.size:
            sh = sh.resize(bg.size, Image.LANCZOS)
        diff = ImageChops.difference(sh, bg)

        soft = bbox_of(diff, SOFT_T, y_min=PANEL_LIMIT)
        core = bbox_of(diff, CORE_T, y_min=PANEL_LIMIT)
        # panel: hanya cari di strip atas (jangan sampai ikut menangkap kartu)
        panel = bbox_of(diff.crop((0, 0, diff.width, PANEL_LIMIT)), SOFT_T)
        if not core or not soft:
            log('kartu login tidak terdeteksi di potret -> animasi dilewati')
            shutil.rmtree(tmp, ignore_errors=True)
            return 0

        # pastikan latar potret benar-benar sama dengan wallpaper resmi (di luar kartu
        # & panel). Kalau tidak sama (mis. resolusi/skala beda), animasi dibatalkan.
        from PIL import ImageDraw, ImageStat
        keep = Image.new('L', diff.size, 255)
        pad = (max(0, soft[0] - SHADOW_PAD), max(0, soft[1] - SHADOW_PAD),
               min(diff.width, soft[2] + SHADOW_PAD), min(diff.height, soft[3] + SHADOW_PAD))
        ImageDraw.Draw(keep).rectangle(pad, fill=0)
        if panel:
            ImageDraw.Draw(keep).rectangle(
                (0, 0, diff.width, min(PANEL_LIMIT, panel[3] + 6)), fill=0)
        outside = Image.composite(diff.convert('L'), Image.new('L', diff.size, 0), keep)
        beda = ImageStat.Stat(outside.point(lambda v: 255 if v > SOFT_T else 0)).sum[0] / 255.0
        luas = ImageStat.Stat(keep).sum[0] / 255.0
        rasio = beda / max(1.0, luas)
        if rasio > 0.02:
            log('latar potret beda dari wallpaper (%.1f%% piksel) -> animasi dilewati'
                % (rasio * 100))
            shutil.rmtree(tmp, ignore_errors=True)
            return 0

        card_rect = (max(0, soft[0] - SHADOW_PAD), max(0, soft[1] - SHADOW_PAD),
                     min(bg.width, soft[2] + SHADOW_PAD), min(bg.height, soft[3] + SHADOW_PAD))
        card_png = os.path.join(tmp, 'card.png')
        build_card(shot, WALLPAPER, card_png, core, card_rect)
    except Exception as e:
        log('gagal menyiapkan overlay: %s -> animasi dilewati' % e)
        shutil.rmtree(tmp, ignore_errors=True)
        return 0

    top_gap = min(PANEL_LIMIT, panel[3] + 10) if panel else 0
    card_x, card_y = card_rect[0], card_rect[1]
    log('kartu %s panel=%s top_gap=%d window=%s' % (card_rect, panel, top_gap, wid))
    stop_previous()
    proc = subprocess.Popen([sys.executable or 'python3', overlay,
                             '--wallpaper', WALLPAPER,
                             '--card', card_png,
                             '--card-x', str(card_x), '--card-y', str(card_y),
                             '--top-gap', str(top_gap),
                             '--focus-window', wid,
                             '--timeout', cfg.get('timeout', '120'),
                             '--duration', cfg.get('duration', '520'),
                             '--hint', cfg.get('hint', 'Tekan tombol apa saja untuk masuk'),
                             '--log', LOG])
    try:
        with open(LOCK, 'w') as f:
            f.write(str(proc.pid))
    except OSError:
        pass
    proc.wait()
    try:
        os.remove(LOCK)
    except OSError:
        pass
    shutil.rmtree(tmp, ignore_errors=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
