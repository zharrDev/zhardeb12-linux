#!/usr/bin/env python3
"""login-assets.py — siapkan aset tampilan login dari satu file wallpaper.

Menghasilkan 3 berkas di --outdir:
  login-bg.jpg      wallpaper layar login: di-blur (opsional) + sedikit digelapkan
                    + vignette (tepi lebih gelap) supaya kartu login menonjol
  glass-panel.jpg   potongan TEPAT di area kartu (560x350) -> tekstur kaca kartu
  glass-bar.jpg     potongan band paling atas (1920x48) -> tekstur kaca panel

Blur kartu bisa lebih ringan daripada background (--card-blur) sehingga kartu
terlihat seperti kaca yang "menampakkan" detail, sementara latar lembut.

  python3 login-assets.py --src bg.jpg --outdir /tmp/out [--bg-blur 18] \
                          [--card-blur 8] [--dim 0.90] [--vignette 0.62] \
                          [--size 1920x1080]

--bg-blur 0   = latar TAJAM (tanpa blur). Kartu tetap bisa kaca buram lewat
                --card-blur tersendiri (kartu & latar memang terpisah).

Urutan prioritas mesin gambar: Pillow -> ImageMagick (convert) -> salin apa adanya.
"""
import argparse
import os
import shutil
import subprocess
import sys

PANEL_W, PANEL_H = 560, 350        # area kartu login
BAR_H = 48                         # tinggi band panel atas
FS_W, FS_H = 1920, 1080            # acuan layar (dapat diubah dengan --size)


def parse_args():
    global FS_W, FS_H
    p = argparse.ArgumentParser()
    p.add_argument('--src', required=True)
    p.add_argument('--outdir', required=True)
    p.add_argument('--bg-blur', type=float, default=18.0,
                   help='0 = latar tajam (tanpa blur)')
    p.add_argument('--card-blur', type=float, default=8.0)
    p.add_argument('--dim', type=float, default=0.90, help='pengali kecerahan background')
    p.add_argument('--vignette', type=float, default=0.62,
                   help='kecerahan di sudut layar (1.0 = tanpa vignette)')
    p.add_argument('--size', default='%dx%d' % (FS_W, FS_H),
                   help='resolusi layar acuan, mis. 1920x1080')
    a = p.parse_args()
    try:
        FS_W, FS_H = (int(v) for v in a.size.lower().split('x'))
    except ValueError:
        sys.exit('[assets] --size harus format LEBARxTINGGI, mis. 1920x1080')
    return a


# --------------------------------------------------------------------- Pillow
def cover(im, w, h):
    """Perbesar + potong dari tengah supaya rasio gambar = rasio layar."""
    from PIL import Image
    sr, tr = im.width / im.height, w / h
    if sr > tr:                                  # sumber lebih lebar -> potong kiri/kanan
        nw = int(im.height * tr)
        im = im.crop(((im.width - nw) // 2, 0, (im.width - nw) // 2 + nw, im.height))
    else:                                        # sumber lebih tinggi -> potong atas/bawah
        nh = int(im.width / tr)
        im = im.crop((0, (im.height - nh) // 2, im.width, (im.height - nh) // 2 + nh))
    return im.resize((w, h), Image.LANCZOS)


def vignette_mask(w, h, floor):
    """Masker: putih di tengah -> `floor` di sudut (untuk menggelapkan tepi)."""
    from PIL import Image, ImageFilter, ImageOps
    m = ImageOps.invert(Image.radial_gradient('L'))          # hitam di tengah -> putih di tepi
    m = m.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(min(w, h) * 0.10))
    return m.point(lambda v: int(255 * (1.0 - (1.0 - floor) * (v / 255.0))))


def build_with_pillow(src, outdir, bg_blur, card_blur, dim, vig_floor):
    from PIL import Image, ImageFilter
    sharp = cover(Image.open(src).convert('RGB'), FS_W, FS_H)

    # 1) background layar: blur + digelapkan + vignette
    #    (--bg-blur 0 = latar TAJAM apa adanya, hanya vignette tipis)
    bg = sharp.filter(ImageFilter.GaussianBlur(bg_blur)) if bg_blur > 0 else sharp
    if dim != 1.0:
        bg = bg.point(lambda v: int(v * dim))
    bg = Image.composite(bg, Image.new('RGB', bg.size, (0, 0, 0)),
                         vignette_mask(FS_W, FS_H, vig_floor).convert('L'))
    bg.save(os.path.join(outdir, 'login-bg.jpg'), quality=92, optimize=True)

    # 2) kartu: potongan TEPAT di posisi kartu pada layar
    l, t = (FS_W - PANEL_W) // 2, (FS_H - PANEL_H) // 2
    card = sharp.crop((l, t, l + PANEL_W, t + PANEL_H))
    if card_blur > 0:
        card = card.filter(ImageFilter.GaussianBlur(card_blur))
    card.save(os.path.join(outdir, 'glass-panel.jpg'), quality=90, optimize=True)

    # 3) panel atas: band paling atas dari BACKGROUND (biar menyatu)
    bg.crop((0, 0, FS_W, BAR_H)).save(os.path.join(outdir, 'glass-bar.jpg'),
                                      quality=90, optimize=True)


# ---------------------------------------------------------------- ImageMagick
def build_with_convert(src, outdir, bg_blur, card_blur, dim, vig_floor):
    tmp = os.path.join(outdir, '.sharp.jpg')
    subprocess.run(['convert', src, '-resize', '%dx%d^' % (FS_W, FS_H),
                    '-gravity', 'center', '-extent', '%dx%d' % (FS_W, FS_H),
                    '+repage', tmp], check=True)
    # vignette IM6: radius x sigma + intensitas
    subprocess.run(['convert', tmp,
                    '-blur', '0x%g' % bg_blur,
                    '-modulate', '%g,100,100' % (dim * 100),
                    '-vignette', '0x%g' % (min(FS_W, FS_H) * 0.10),
                    os.path.join(outdir, 'login-bg.jpg')], check=True)
    subprocess.run(['convert', tmp, '-gravity', 'center',
                    '-crop', '%dx%d+0+0' % (PANEL_W, PANEL_H), '+repage',
                    '-blur', '0x%g' % card_blur,
                    os.path.join(outdir, 'glass-panel.jpg')], check=True)
    subprocess.run(['convert', os.path.join(outdir, 'login-bg.jpg'),
                    '-gravity', 'north', '-crop', '%dx%d+0+0' % (FS_W, BAR_H), '+repage',
                    os.path.join(outdir, 'glass-bar.jpg')], check=True)
    os.remove(tmp)


def main():
    a = parse_args()
    if not os.path.isfile(a.src):
        sys.exit('[assets] sumber wallpaper tidak ditemukan: %s' % a.src)
    os.makedirs(a.outdir, exist_ok=True)
    try:
        import PIL  # noqa: F401
        build_with_pillow(a.src, a.outdir, a.bg_blur, a.card_blur, a.dim, a.vignette)
        print('[assets] Pillow: background (blur %g + vignette %g) + tekstur kaca' %
              (a.bg_blur, a.vignette))
    except ImportError:
        if shutil.which('convert'):
            build_with_convert(a.src, a.outdir, a.bg_blur, a.card_blur, a.dim, a.vignette)
            print('[assets] ImageMagick: background (blur %g) + tekstur kaca' % a.bg_blur)
        else:
            print('[assets] Pillow & ImageMagick tidak ada — salin apa adanya', file=sys.stderr)
            for n in ('login-bg.jpg', 'glass-panel.jpg', 'glass-bar.jpg'):
                shutil.copy(a.src, os.path.join(a.outdir, n))
    return 0


if __name__ == '__main__':
    sys.exit(main())
