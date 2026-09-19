#!/usr/bin/env python3
"""greeter-textures.py — dari SATU potret layar greeter, siapkan tekstur yang
dibutuhkan overlay animasi login.

Dipakai DUA tempat supaya pratinjau = kenyataan:
  • scripts/greeter-anim-launch.py (potret asli greeter saat layar login hidup)
  • scripts/preview-login.sh --anim (potret mock yang dirender sendiri)

Masukan : --shot (potret layar login) + --wallpaper (wallpaper resmi greeter)
Keluaran: card.png    potongan kartu login + bayangannya (RGBA)
          panel.png   strip panel atas (panel + bayangannya) — digambar apa
                      adanya oleh overlay supaya panel tidak "muncul mendadak"
          (stdout) JSON  {"card":[x,y,w,h], "card_top":n, "panel":[x,y,w,h]|null,
                          "top_gap":n, "bg_match":0..1, "bg_ratio":0..1}
                          card_top = tepi ATAS kartu tanpa bayangan → acuan
                          menaruh jam "di atas form".

Panel sengaja TIDAK punya jam (lihat lightdm-gtk-greeter.conf): jam digambar
overlay (besar di tengah, lalu naik ke atas kartu), jadi tidak ada yang perlu
ditambal di strip panel.
"""
import argparse
import json
import os
import sys

PANEL_LIMIT = 130        # px: di atas ini dianggap area panel (bukan kartu)
CORE_T = 25              # ambang beda untuk kartu (kuat)
SOFT_T = 6               # ambang beda untuk bayangan/soft edge
SHADOW_PAD = 80          # perluasan area bayangan (px) — harus lebih besar dari
                         # blur shadow greeter, kalau tidak tepinya terpotong
STRIP_EXTRA = 30         # strip panel dilebihkan ke bawah: ikut bayangan panel,
                         # jadi serah-terima ke greeter asli tidak "pop"


def log(msg):
    print('[tekstur] %s' % msg, file=sys.stderr)


# ------------------------------------------------------------------ deteksi
def bbox_of(diff_img, threshold, y_min=0):
    """Kotak terkecil area yang bedanya > threshold (mulai dari baris y_min)."""
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


def bg_match(diff):
    """Bagian layar yang SAMA dengan wallpaper (0..1).

    Ini jaring aman utama: pada potret greeter yang wajar, sebagian besar layar
    memang wallpaper (yang beda cuma kartu + panel), jadi angkanya besar
    (>0.8). Kalau potretnya bukan wallpaper resmi (beda skala/warna), angkanya
    nyaris 0 dan animasi dibatalkan.
    """
    hist = diff.convert('L').point(lambda v: 255 if v <= SOFT_T else 0).histogram()
    return hist[255] / float(diff.width * diff.height)


def bg_ratio(diff, soft, panel, limit):
    """Berapa bagian latar potret yang BUKAN wallpaper (0 = sama persis).

    Sama seperti bg_match tapi mengabaikan kartu + bayangannya + panel, jadi
    lebih ketat: dipakai untuk memastikan potret memang layar login di atas
    wallpaper yang kita kenal.
    """
    from PIL import Image, ImageDraw, ImageStat

    keep = Image.new('L', diff.size, 255)       # 255 = area yang diperiksa
    pad = (max(0, soft[0] - SHADOW_PAD), max(0, soft[1] - SHADOW_PAD),
           min(diff.width, soft[2] + SHADOW_PAD), min(diff.height, soft[3] + SHADOW_PAD))
    ImageDraw.Draw(keep).rectangle(pad, fill=0)         # buang kartu + bayangannya
    if panel:
        ImageDraw.Draw(keep).rectangle(
            (0, 0, diff.width, min(limit, panel[3] + STRIP_EXTRA)), fill=0)   # + panel
    outside = Image.composite(diff.convert('L'), Image.new('L', diff.size, 0), keep)
    beda = ImageStat.Stat(outside.point(lambda v: 255 if v > SOFT_T else 0)).sum[0] / 255.0
    luas = ImageStat.Stat(keep).sum[0] / 255.0
    return beda / max(1.0, luas)


# ------------------------------------------------------------------- kartu
def top_edge(diff, core, y_min, frac=0.6):
    """Baris pertama yang area bedanya sudah LEBAR → tepi ATAS badan kartu.

    core[1] tidak bisa dipakai langsung sebagai tepi kartu: bagian atas kartu
    itu kaca tipis di atas wallpaper, bedanya kecil, jadi kotak "beda kuat"
    baru mulai di kontennya (avatar/teks) — jam akan ketarik turun ke tengah
    kartu. Di sini diukur LEBAR: baris pertama yang piksel bedanya membentang
    ≥ frac dari lebar kartu (bayangan di atas kartu lebarnya jauh lebih sempit,
    jadi tidak ikut terbaca).
    """
    from PIL import Image

    gray = diff.convert('L')
    mask = gray.point(lambda v: 255 if v >= SOFT_T else 0)
    w, h = mask.size
    rows = mask.crop((0, y_min, w, h)).resize((1, h - y_min), Image.BOX).getdata()
    # rata-rata tiap baris (BOX) → jumlah piksel per baris = rata2 * lebar / 255
    need = max(40, int((core[2] - core[0]) * frac)) * 255.0 / w
    for i, v in enumerate(rows):
        if v >= need:
            return y_min + i
    return core[1]


def build_card(shot_path, bg_path, out_path, core, soft, mask_box=None):
    """Potong kartu dari potret + pisahkan bayangannya jadi lapisan semi-transparan.

    `core` = kotak "beda kuat" (badan kartu); `mask_box` menimpanya kalau tepi
    atas kartu terdeteksi lebih tinggi (bagian atas kartu cuma kaca tipis,
    bedanya kecil, jadi core bisa mulai di bawah tepi aslinya).
    """
    from PIL import Image, ImageChops, ImageDraw, ImageFilter

    shot = Image.open(shot_path).convert('RGB')
    bg = Image.open(bg_path).convert('RGB')
    if shot.size != bg.size:
        shot = shot.resize(bg.size, Image.LANCZOS)

    x0, y0, x1, y1 = soft
    crop = shot.crop((x0, y0, x1, y1))
    shadow_src = ImageChops.difference(shot.crop((x0, y0, x1, y1)), bg.crop((x0, y0, x1, y1)))

    # lapisan 1: bayangan lembut di sekeliling kartu (alpha dari beda vs wallpaper)
    shadow_alpha = shadow_src.convert('L').point(lambda v: min(255, v * 3))
    shadow_layer = Image.new('RGBA', crop.size, (0, 0, 0, 0))
    shadow_layer.putalpha(shadow_alpha)

    # lapisan 2: badan kartu (isi asli potret), dibentuk rounded-rect + tepi halus
    mb = mask_box or core
    core_box = (mb[0] - x0, mb[1] - y0, mb[2] - x0, mb[3] - y0)
    core_layer = crop.convert('RGBA')
    mask = Image.new('L', crop.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(core_box, radius=26, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(0.6))       # haluskan tepi
    core_layer.putalpha(mask)

    card = Image.alpha_composite(shadow_layer, core_layer)
    card.save(out_path)
    return out_path


# ------------------------------------------------------------------- panel
def build_panel_strip(shot_path, out_strip, strip_h):
    """Strip panel atas (panel + bayangannya) — dipakai overlay apa adanya.

    PANEL SAJA (band atas setinggi strip_h), bukan seluruh layar: overlay
    menggambar hasil ini di atas wallpaper-nya sendiri, jadi kalau isinya ikut
    membawa kartu login, kartu akan terlihat sejak layar pertama.

    Panel greeter sekarang tanpa jam (jam digambar overlay), jadi strip ini
    cukup dipotong utuh — tidak ada yang perlu ditambal. Tujuannya cuma satu:
    saat idle panel sudah terlihat persis seperti nanti, sehingga tidak ada
    elemen yang "muncul mendadak".
    """
    from PIL import Image

    shot = Image.open(shot_path).convert('RGB')
    band = shot.crop((0, 0, shot.width, max(1, min(shot.height, strip_h)))).copy()
    band.save(out_strip)
    return out_strip


# -------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--shot', required=True, help='potret layar login')
    ap.add_argument('--wallpaper', required=True, help='wallpaper resmi greeter')
    ap.add_argument('--outdir', required=True)
    ap.add_argument('--panel-limit', type=int, default=PANEL_LIMIT)
    a = ap.parse_args()

    try:
        from PIL import Image, ImageChops
    except ImportError:
        print('{"error":"python3-pil tidak ada"}')
        return 0

    os.makedirs(a.outdir, exist_ok=True)
    out = {'card': None, 'panel': None, 'card_top': 0, 'top_gap': 0}

    sh = Image.open(a.shot).convert('RGB')
    bg = Image.open(a.wallpaper).convert('RGB')
    if sh.size != bg.size:
        sh = sh.resize(bg.size, Image.LANCZOS)
    diff = ImageChops.difference(sh, bg)

    soft = bbox_of(diff, SOFT_T, y_min=a.panel_limit)
    core = bbox_of(diff, CORE_T, y_min=a.panel_limit)
    panel = bbox_of(diff.crop((0, 0, diff.width, a.panel_limit)), SOFT_T)
    out['bg_match'] = round(bg_match(diff), 4)
    if not core or not soft:
        out['error'] = 'kartu login tidak terdeteksi'
        print(json.dumps(out))
        return 0
    # kewarasan: kartu login tidak mungkin hampir seluas layar. Kalau iya,
    # potretnya bukan layar login yang kita harapkan → batalkan.
    cw, ch = core[2] - core[0], core[3] - core[1]
    if cw > 0.85 * diff.width or ch > 0.85 * diff.height or cw < 120 or ch < 90:
        out['error'] = 'kartu login tidak wajar (%dx%d)' % (cw, ch)
        print(json.dumps(out))
        return 0

    card_rect = (max(0, soft[0] - SHADOW_PAD), max(0, soft[1] - SHADOW_PAD),
                 min(bg.width, soft[2] + SHADOW_PAD), min(bg.height, soft[3] + SHADOW_PAD))
    # tepi ATAS kartu (tanpa bayangan/glow) → acuan mask kartu + letak jam
    ctop = int(top_edge(diff, core, a.panel_limit))
    build_card(a.shot, a.wallpaper, os.path.join(a.outdir, 'card.png'), core, card_rect,
               mask_box=(core[0], min(ctop, core[1]), core[2], core[3]))
    out['card'] = list(card_rect)
    out['card_top'] = ctop
    out['bg_ratio'] = round(bg_ratio(diff, soft, panel, a.panel_limit), 5)
    log('kartu di %s (tepi atas %d)' % (out['card'], out['card_top']))

    if panel:
        out['panel'] = list(panel)
        # strip = panel + bayangannya; overlay memakai tinggi ini juga sebagai
        # "top_gap" supaya jalur cadangan (tanpa strip) tetap rapi.
        out['top_gap'] = min(bg.height, panel[3] + STRIP_EXTRA)
        build_panel_strip(a.shot, os.path.join(a.outdir, 'panel.png'), out['top_gap'])
        log('strip panel %dx%d' % (bg.width, out['top_gap']))
    else:
        log('panel tidak terdeteksi')
    print(json.dumps(out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
