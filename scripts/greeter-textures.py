#!/usr/bin/env python3
"""greeter-textures.py — dari SATU potret layar greeter, siapkan semua tekstur
yang dibutuhkan overlay animasi login.

Dipakai DUA tempat supaya pratinjau = kenyataan:
  • scripts/greeter-anim-launch.py (potret asli greeter saat layar login hidup)
  • scripts/preview-login.sh --anim (potret mock yang dirender sendiri)

Masukan : --shot (potret layar login) + --wallpaper (wallpaper resmi greeter)
Keluaran: card.png        potongan kartu login + bayangannya (RGBA)
          panel.png       strip panel atas TANPA jam — area jam "ditambal" dari
                          latar (lihat make_panel_strip) supaya saat idle tidak
                          ada dua jam di layar
          clock.png       potongan asli area jam (untuk crossfade di akhir
                          animasi → serah-terima ke jam asli mulus)
          (stdout) JSON   {"card":[x,y,w,h], "panel":[x,y,w,h]|null,
                           "clock":[x,y,w,h]|null, "top_gap":n}

Deteksi jam: jam adalah teks TERPANJANG di panel. Teks panel terang di atas
kaca yang lebih gelap dari wallpaper, jadi "piksel teks" = piksel yang jauh
lebih terang daripada wallpaper di posisi yang sama. Kata-kata lalu
dikelompokkan; kelompok dengan kata-kata tinggi (≥60% tinggi teks tertinggi)
dan lebar ≥120px dianggap JAM. Ikon power/shutdown kalah karena sempit, label
host/session kalah karena pendek (font 13px vs jam 23px).
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
CLOCK_TH = 52            # ambang "lebih terang dari wallpaper" (0-255)
CLOCK_GAP = 5            # celah antar huruf yang masih dianggap satu kata (px)
CLOCK_MERGE = 30         # jarak antar kata yang masih satu jam (px)
CLOCK_TALL = 0.70        # kata dianggap bagian jam kalau tingginya ≥ 70% teks tertinggi
CLOCK_MIN_W = 120        # lebar minimum kelompok jam (px)
CLOCK_MIN_H = 11         # tinggi minimum teks jam (px)
CLOCK_COL_MIN = 3        # minimal piksel terang per kolom agar dianggap "teks"
CLOCK_INSET_X = 4        # buang tepi kiri/kanan panel (garis highlight vertikal)
CLOCK_INSET_Y = 6        # buang tepi atas/bawah panel (garis highlight horizontal)
PATCH_LIFT = 6           # baris tepi panel yang tidak boleh ditambal (px)
GLASS_INSET = 5          # tepi panel yang dilewati saat mengukur tekstur kaca
GLASS_FIT_ERR = 2.5      # galat maksimum model kaca dari wallpaper (0-255)
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


def _column_flag(mask, w, h, min_px=1):
    """True untuk tiap kolom yang punya ≥ min_px piksel mask.

    BOX-resize memberi rata-rata tiap kolom (0-255), jadi jumlah piksel per
    kolom = rata-rata * tinggi / 255. Ambang min_px ini yang membuang garis
    highlight panel (tebal 1-2 px) supaya tidak dikira teks.
    """
    from PIL import Image
    col = mask.resize((w, 1), Image.BOX)    # rata-rata tiap kolom
    thr = min_px * 255.0 / max(1, h)
    return [1 if v >= thr else 0 for v in col.getdata()]


def _word_boxes(mask, w, h, gap):
    """Pecah mask jadi kata (run kolom berisi, celah ≤ gap dianggap satu kata)."""
    flags = _column_flag(mask, w, h, CLOCK_COL_MIN)
    words, start, blanks = [], None, 0
    for x, f in enumerate(flags):
        if f:
            if start is None:
                start = x
            blanks = 0
        elif start is not None:
            blanks += 1
            if blanks > gap:
                words.append((start, x - blanks + 1))
                start = None
    if start is not None:
        words.append((start, w))

    px = mask.load()
    out = []
    for x0, x1 in words:
        ys = [y for y in range(h) for x in range(x0, x1) if px[x, y]]
        if not ys:
            continue
        out.append((x0, min(ys), x1, max(ys) + 1))
    return out


def detect_clock(shot, bg, panel):
    """Kotak jam di strip panel, atau None kalau tidak yakin."""
    from PIL import ImageChops
    px0, py0, px1, py1 = panel
    # pindai bagian DALAM panel saja: garis highlight tepi panel (inset 1px di
    # atas/bawah + tepi kiri/kanan saat panel punya margin) lebih terang dari
    # wallpaper dan kalau ikut terbaca akan dianggap "teks terpanjang".
    bx0 = max(0, px0 + CLOCK_INSET_X)
    bx1 = max(bx0 + 1, px1 - CLOCK_INSET_X)
    ty0 = max(0, py0 + CLOCK_INSET_Y)
    ty1 = min(shot.height, py1 - CLOCK_INSET_Y)
    if ty1 - ty0 < CLOCK_MIN_H + 4:
        return None

    top = shot.crop((bx0, ty0, bx1, ty1)).convert('RGB')
    ref = bg.crop((bx0, ty0, bx1, ty1)).convert('RGB')
    # hanya piksel yang LEBIH TERANG dari wallpaper → teks/ikon panel
    bright = ImageChops.subtract(top, ref).convert('L')
    mask = bright.point(lambda v: 255 if v >= CLOCK_TH else 0)

    words = _word_boxes(mask, top.width, top.height, CLOCK_GAP)
    if not words:
        log('tidak ada kandidat teks di panel')
        return None
    hmax = max(w[3] - w[1] for w in words)
    hmin = max(CLOCK_MIN_H, int(hmax * CLOCK_TALL))
    # Jam (font 23px) jauh lebih tinggi dari label host/session (13px). Kata
    # pendek TETAP boleh ikut masuk kelompok (mis. pemisah "•" di antara tanggal
    # dan jam), tapi hanya kata TINGGI yang dihitung sebagai bukti "ini jam".
    groups, cur = [], []
    for w in sorted(words):
        if cur and w[0] - cur[-1][2] > CLOCK_MERGE:
            groups.append(cur)
            cur = []
        cur.append(w)
    if cur:
        groups.append(cur)

    def box(g):
        return (min(w[0] for w in g), min(w[1] for w in g),
                max(w[2] for w in g), max(w[3] for w in g))

    def tall_width(g):
        return sum(w[2] - w[0] for w in g if (w[3] - w[1]) >= hmin)

    best = max(groups, key=tall_width)
    if tall_width(best) < CLOCK_MIN_W:
        log('teks tinggi terlebar cuma %dpx (< %d) → jam tidak dikenali'
            % (tall_width(best), CLOCK_MIN_W))
        return None
    b = box(best)
    if (b[3] - b[1]) < hmin:
        log('kelompok jam terlalu tipis (%dpx) → jam tidak dikenali' % (b[3] - b[1]))
        return None
    # kembali ke koordinat layar
    return (b[0] + bx0, b[1] + ty0, b[2] + bx0, b[3] + ty0)


# ------------------------------------------------------------------- kartu
def bg_match(diff):
    """Bagian layar yang SAMA dengan wallpaper (0..1).

    Ini jaring aman utama: pada potret greeter yang wajar, sebagian besar layar
    memang wallpaper (yang beda cuma kartu + panel), jadi angkanya besar
    (>0.8). Kalau potretnya bukan wallpaper resmi (beda skala/warna), angkanya
    nyaris 0 dan animasi dibatalkan.
    """
    hist = diff.convert('L').point(lambda v: 255 if v <= SOFT_T else 0).histogram()
    return hist[255] / float(diff.width * diff.height)


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

    Dipakai sebagai jaring aman: kalau potret ternyata bukan wallpaper resmi
    (mis. beda skala/warna), animasi dibatalkan supaya layar login tidak
    berubah jadi aneh.
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


# ------------------------------------------------------------------- panel
def _fit_panel_glass(strip, bg, panel, clock, h):
    """Cari relasi P ≈ a·B + b antara panel (P) dan latar (B) dari piksel yang
    BUKAN jam. Panel = kaca semi-transparan di atas wallpaper, jadi relasinya
    memang linier — hasilnya tekstur kaca yang sangat mirip aslinya.
    Kembalikan (a[3], b[3]) atau None kalau tidak bisa.

    Sampel diambil hanya dari BAGIAN DALAM panel: sudut membulat, bayangan luar,
    dan garis highlight 1px di tepi panel tidak mengikuti relasi linier itu.
    """
    spp = strip.load()
    bpp = bg.load()
    px0, py0, px1, py1 = panel
    sx0, sx1 = px0 + GLASS_INSET, max(px0 + GLASS_INSET + 1, px1 - GLASS_INSET)
    sy0, sy1 = py0 + GLASS_INSET, min(h, py1 - GLASS_INSET)
    x0, y0, x1, y1 = clock if clock else (0, 0, 0, 0)
    y0 = max(0, y0 - PATCH_LIFT - 4)
    y1 = min(h, y1 + PATCH_LIFT + 4)
    samp = {0: [], 1: [], 2: []}
    step = max(1, strip.width // 480)          # ~480 sampel, cukup & cepat
    for y in range(sy0, sy1, 2):
        for x in range(sx0, sx1, step):
            if y0 <= y < y1 and x0 - 12 <= x < x1 + 12:
                continue                        # lewati area jam
            p, b = spp[x, y], bpp[x, y]
            for c in range(3):
                samp[c].append((b[c], p[c]))

    a = [0.0, 0.0, 0.0]
    bb = [0.0, 0.0, 0.0]
    for c in range(3):
        pts = samp[c]
        n = len(pts)
        if n < 40:
            return None
        mb = sum(p[0] for p in pts) / n
        mp = sum(p[1] for p in pts) / n
        var = sum((p[0] - mb) ** 2 for p in pts) / n
        if var < 8.0:                           # latar nyaris rata → lereng tak berarti
            return None
        cov = sum((p[0] - mb) * (p[1] - mp) for p in pts) / n
        a[c] = cov / var
        bb[c] = mp - a[c] * mb
        if not (0.05 <= a[c] <= 0.95):          # lereng tidak masuk akal → jangan dipakai
            return None
    # sisa (rata-rata |galat|) menentukan metode mana yang dipakai
    err = 0.0
    for c in range(3):
        for (b, p) in samp[c]:
            err += abs(a[c] * b + bb[c] - p)
    return a, bb, err / (3.0 * len(samp[0]))


def make_panel_strip(shot_path, bg_path, panel, clock, out_strip, out_clock):
    """Strip panel atas + versi TANPA jam (area jam ditambal dari latar).

    Jam ditambal, bukan sekadar dihapus, supaya saat idle di layar login tidak
    ada dua jam (jam besar di tengah + jam panel). Tambalan dibuat dari
    wallpaper: panel = kaca semi-transparan di atas wallpaper, jadi
    `P ≈ a·B + b` (a,b dicari dari piksel panel yang bukan jam).
    """
    from PIL import Image

    shot = Image.open(shot_path).convert('RGB')
    bg = Image.open(bg_path).convert('RGB')
    if shot.size != bg.size:
        shot = shot.resize(bg.size, Image.LANCZOS)
    px0, py0, px1, py1 = panel
    strip_h = min(shot.height, py1 + STRIP_EXTRA)
    strip = shot.crop((0, 0, shot.width, strip_h)).copy()
    w, h = strip.size

    clock_crop = None
    if clock:
        cx0, cy0, cx1, cy1 = clock
        bx0 = max(0, cx0 - 6); bx1 = min(w, cx1 + 6)
        by0 = max(0, cy0 - PATCH_LIFT); by1 = min(h, cy1 + PATCH_LIFT)
        clock_crop = shot.crop((bx0, by0, bx1, by1))
        clock_crop.save(out_clock)

        fit = _fit_panel_glass(strip, bg, panel, clock, h)
        spp = strip.load()
        bpp = bg.load()
        if fit and fit[2] <= GLASS_FIT_ERR:
            # tekstur kaca diprediksi dari wallpaper (akurat kalau latar panel
            # memang punya struktur, mis. langit terang)
            a, bb, fit_err = fit
            log('tambalan pakai wallpaper (galat %.2f px)' % fit_err)
            for y in range(by0, by1):
                for x in range(bx0, bx1):
                    b = bpp[x, y]
                    spp[x, y] = tuple(
                        max(0, min(255, int(a[c] * b[c] + bb[c]))) for c in range(3))
        else:
            # latar terlalu rata / model meleset → interpolasi mendatar dari kaca
            # di kiri-kanan jam (tepi sambungan pasti pas, variasinya halus)
            log('tambalan pakai interpolasi kaca kiri-kanan'
                + (' (galat model %.2f)' % fit[2] if fit else ''))
            for y in range(by0, by1):
                l = spp[max(0, bx0 - 3), y]
                r = spp[min(w - 1, bx1 + 2), y]
                span = max(1, (bx1 + 3) - (bx0 - 3))
                for x in range(bx0, bx1):
                    t = (x - (bx0 - 3)) / float(span)
                    spp[x, y] = tuple(max(0, min(255, int(l[c] + (r[c] - l[c]) * t)))
                                      for c in range(3))

        # haluskan tepi tambalan (biar tidak ada garis sambung)
        from PIL import ImageFilter
        band = strip.crop((bx0, by0, bx1, by1)).filter(ImageFilter.GaussianBlur(1.2))
        strip.paste(band, (bx0, by0))

    strip.save(out_strip)
    return out_strip, (clock_crop is not None)


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
    out = {'card': None, 'panel': None, 'clock': None, 'top_gap': 0}

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
    build_card(a.shot, a.wallpaper, os.path.join(a.outdir, 'card.png'), core, card_rect)
    out['card'] = list(card_rect)
    out['bg_ratio'] = round(bg_ratio(diff, soft, panel, a.panel_limit), 5)

    if panel:
        out['panel'] = list(panel)
        # strip = panel + bayangannya; overlay memakai tinggi ini juga sebagai
        # "top_gap" supaya jalur cadangan (tanpa strip) tetap rapi.
        out['top_gap'] = min(bg.height, panel[3] + STRIP_EXTRA)
        clock = detect_clock(sh, bg, panel)
        if clock:
            out['clock'] = list(clock)
            log('jam panel terdeteksi di %s' % (clock,))
        else:
            log('jam panel TIDAK terdeteksi → panel digambar tanpa tambalan')
        make_panel_strip(a.shot, a.wallpaper, panel, clock,
                         os.path.join(a.outdir, 'panel.png'),
                         os.path.join(a.outdir, 'clock.png'))
    else:
        log('panel tidak terdeteksi')
    print(json.dumps(out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
