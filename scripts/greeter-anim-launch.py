#!/usr/bin/env python3
"""greeter-anim-launch.py — jalankan overlay animasi di layar login.

Dipanggil otomatis oleh LightDM (greeter-setup-script) sebagai root, saat X
greeter sudah hidup tapi greeter belum/tengah digambar. Tugasnya:

  1. tunggu window greeter muncul,
  2. potret layarnya (yang berisi wallpaper + panel + kartu login yang sudah
     digambar greeter asli — autentikasi tetap milik greeter, bukan script ini),
  3. minta scripts/greeter-textures.py memotong tekstur dari potret itu:
     kartu login + strip panel (beserta tepi atas kartu untuk menaruh jam),
  4. jalankan overlay (greeter-anim.py) yang menyembunyikan kartu lebih dulu:
     layar menampilkan wallpaper TAJAM + jam besar di tengah (dengan tanggal),
     lalu saat ada tombol ditekan kartu naik dari bawah dan jam terbang ke atas
     form (tanggal hilang) lalu menetap di sana.

Kalau ada apa pun yang tidak wajar (window tak muncul, potret beda dari
wallpaper, PIL tidak ada, dsb) script hanya mencatat log dan keluar — layar
login tetap tampil normal, jadi tidak ada risiko gagal login.
"""
import argparse
import json
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
HERE = os.path.dirname(os.path.abspath(__file__))
OVERLAY = os.environ.get('ANIME_GLASS_OVERLAY',
                         '/usr/local/share/anime-glass/greeter-anim.py')
TEXTURES = os.environ.get('ANIME_GLASS_TEXTURES',
                          '/usr/local/share/anime-glass/greeter-textures.py')
OG_LOCAL = os.path.join(HERE, 'greeter-anim.py')
TX_LOCAL = os.path.join(HERE, 'greeter-textures.py')
LOG = os.environ.get('ANIME_GLASS_LOG', '/var/log/anime-glass-anim.log')
LOCK = '/run/anime-glass-anim.pid'
CONF = os.environ.get('ANIME_GLASS_ANIM_CONF', '/etc/lightdm/anime-glass-anim.conf')
WAIT_MAX = 12.0          # detik menunggu window greeter


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


def build_textures(shot, outdir):
    """Potong semua tekstur dari potret (logika ada di greeter-textures.py)."""
    tx = TEXTURES if os.path.isfile(TEXTURES) else TX_LOCAL
    if not os.path.isfile(tx):
        log('greeter-textures.py tidak ada -> animasi dilewati')
        return None
    try:
        r = subprocess.run([sys.executable or 'python3', tx,
                            '--shot', shot, '--wallpaper', WALLPAPER,
                            '--outdir', outdir],
                           capture_output=True, text=True, timeout=60)
    except Exception as e:
        log('gagal menjalankan greeter-textures.py: %s' % e)
        return None
    for line in (r.stdout or '').splitlines():
        if line.strip().startswith('{'):
            try:
                return json.loads(line)
            except ValueError:
                pass
    log('greeter-textures.py tidak mengeluarkan hasil (rc=%s)' % r.returncode)
    return None


def main():
    ap = argparse.ArgumentParser(description='jalankan overlay animasi layar login')
    ap.add_argument('--shot', default='',
                    help='pakai potret ini (mode pratinjau; lewati pemotretan greeter)')
    ap.add_argument('--pass', dest='extra', action='append', default=[],
                    help='argumen tambahan untuk overlay (mis. --auto=5)')
    a = ap.parse_args()
    preview = bool(a.shot)

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
    overlay = OVERLAY if os.path.isfile(OVERLAY) else OG_LOCAL
    if not os.path.isfile(overlay):
        log('overlay %s tidak ada -> animasi dilewati' % overlay)
        return 0

    wid = ''
    tmp = tempfile.mkdtemp(prefix='anime-glass-anim-')
    if preview:
        # potret sudah disiapkan pemanggil (mis. dari preview-login.py --mock-shot)
        shot = os.path.abspath(a.shot)
        if not os.path.isfile(shot):
            log('potret %s tidak ada -> animasi dilewati' % shot)
            shutil.rmtree(tmp, ignore_errors=True)
            return 0
    else:
        w, h = screen_size()
        deadline = time.time() + WAIT_MAX
        wid = find_greeter_window(w, h, deadline)
        if not wid:
            log('window greeter tidak ditemukan dalam %gs -> animasi dilewati' % WAIT_MAX)
            return 0
        time.sleep(0.9)                              # beri waktu greeter menggambar kartu
        shot = os.path.join(tmp, 'shot.png')
        if not shot_window(wid, shot):
            log('gagal memotret window greeter (%s) -> animasi dilewati' % wid)
            shutil.rmtree(tmp, ignore_errors=True)
            return 0

    texdir = tmp
    geo = build_textures(shot, tmp)
    if geo and geo.get('card') and not geo.get('panel'):
        # Panel greeter kadang bukan bagian dari window yang dipotret. Kalau
        # panel tidak ketemu, coba potret seluruh layar (root) sebagai cadangan
        # — tanpa strip panel, panel akan "muncul mendadak" di akhir animasi.
        alt = os.path.join(tmp, 'root')
        os.makedirs(alt, exist_ok=True)
        shot_root = os.path.join(alt, 'shot.png')
        if shot_window('root', shot_root):
            geo2 = build_textures(shot_root, alt)
            if geo2 and geo2.get('card') and geo2.get('panel'):
                log('panel tidak ada di potret window -> pakai potret layar penuh')
                geo, texdir = geo2, alt
    if not geo or geo.get('error') or not geo.get('card'):
        log('tekstur gagal disiapkan (%s) -> animasi dilewati'
            % (geo.get('error') if geo else 'tanpa hasil'))
        shutil.rmtree(tmp, ignore_errors=True)
        return 0
    # pastikan potret memang layar login di atas wallpaper resmi; kalau tidak,
    # animasi dibatalkan supaya layar login tidak berubah jadi aneh.
    if geo.get('bg_match', 0) < 0.75:
        log('potret bukan di atas wallpaper resmi (kecocokan %.0f%%) -> animasi dilewati'
            % (geo.get('bg_match', 0) * 100))
        shutil.rmtree(tmp, ignore_errors=True)
        return 0

    card = geo['card']
    args = [sys.executable or 'python3', overlay,
            '--wallpaper', WALLPAPER,
            '--card', os.path.join(texdir, 'card.png'),
            '--card-x', str(card[0]), '--card-y', str(card[1]),
            '--card-top', str(geo.get('card_top', 0)),
            '--top-gap', str(geo.get('top_gap', 0)),
            '--timeout', cfg.get('timeout', '120'),
            '--duration', cfg.get('duration', '700'),
            '--hero', cfg.get('hero', '1'),
            '--hero-size', cfg.get('hero_size', '94'),
            '--hero-caption', cfg.get('hero_caption', 'SELAMAT DATANG'),
            '--clock-size', cfg.get('clock_size', '40'),
            '--clock-gap', cfg.get('clock_gap', '46'),
            '--stay', cfg.get('stay', '1'),
            '--hint', cfg.get('hint', ''),
            '--hint-sub', cfg.get('hint_sub', ''),
            '--hint-size', cfg.get('hint_size', '34'),
            '--auto', cfg.get('auto', '0'),
            '--log', LOG]
    panel_png = os.path.join(texdir, 'panel.png')
    if os.path.isfile(panel_png):
        args += ['--panel-strip', panel_png]
    if wid:
        args += ['--focus-window', wid]
    args += a.extra
    log('kartu %s (atas %s) panel=%s top_gap=%s window=%s'
        % (card, geo.get('card_top'), geo.get('panel'), geo.get('top_gap'),
           wid or '(pratinjau)'))

    if not preview:
        stop_previous()
    proc = subprocess.Popen(args)
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
