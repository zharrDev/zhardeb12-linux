#!/usr/bin/env python3
"""greeter-anim.py — overlay "wallpaper dulu, form login muncul belakangan".

Alur:

  1. Awal  : wallpaper saja + JAM BESAR di TENGAH layar (jam + detik + hari/
             tanggal, plus sapuan aksen) + splash kaca kecil di bawah
             ("Tekan tombol apa saja untuk masuk").
             Jam panel asli disembunyikan: overlay menggambar strip panel ASLI
             (hasil potret greeter) yang area jamnya sudah ditambal dari
             wallpaper — jadi tidak ada dua jam di layar.
  2. Tombol: kartu login masuk dari bawah (slide + FLIP + glow + sheen,
             wallpaper zoom Ken-Burns), dan JAM BESAR terbang ke ATAS menuju
             posisi jam panel sambil mengecil & memudar — jadi setelah form
             muncul, jam ada DI ATAS form (di panel).
             Di akhir animasi jam asli "muncul kembali" (crossfade) tepat di
             posisi yang sama → serah-terima mulus, tanpa lompatan.
  3. Selesai: overlay menutup diri; fokus dikembalikan ke window greeter →
             langsung bisa mengetik password.

Semua kegagalan bersifat aman: gambar gagal dibaca / GTK error → script keluar
tanpa menampilkan apa pun, layar login tetap normal.

  python3 greeter-anim.py --wallpaper bg.jpg --card card.png \
      --card-x 645 --card-y 374 [--panel-strip panel.png] \
      [--clock-x .. --clock-y .. --clock-w .. --clock-h ..] [--clock-crop clock.png] \
      [--top-gap 62] [--timeout 120] [--duration 700] [--hero 1] \
      [--hint "..."] [--hint-size 30] [--auto 0] [--focus-window 0x400003]

  --auto N : kartu muncul sendiri setelah N detik (0 = nonaktif). Untuk demo.
"""
import argparse
import math
import os
import sys
import time

import cairo
import gi

gi.require_version('Gtk', '3.0')
gi.require_version('Pango', '1.0')
gi.require_version('PangoCairo', '1.0')
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib, Pango, PangoCairo  # noqa: E402

# --- tuning animasi (semua dalam ms / px) -----------------------------------
TICK_MS = 16            # ~60 fps saat animasi; idle cuma repaint area kecil
SLIDE_PX = 170          # jarak awal kartu di bawah posisi akhirnya
FLIP_START = 0.35       # skala Y awal (kartu "terlipat" dari bawah)
ENTER_PART = 0.72       # 72% waktu = masuk, 28% terakhir = "mendarat"
FLIP_PART = 0.50        # flip selesai di 50% waktu (lebih ringkas dari slide)
ZOOM_PEAK = 1.055       # zoom wallpaper di tengah animasi (naik lalu kembali)
DIM_PEAK = 0.24         # gelap maksimum wallpaper di tengah animasi
HERO_FLY_PART = 0.80    # jam besar selesai terbang di 80% waktu
HERO_HOLD = 0.52        # jam besar mulai memudar setelah 52% waktu
HERO_END_SCALE_MIN = 0.20
CLOCK_IN_PART = 0.68    # jam asli mulai "muncul kembali" di 68% waktu
ACCENT = (95 / 255.0, 162 / 255.0, 206 / 255.0)      # #5fa2ce
ACCENT2 = (122 / 255.0, 111 / 255.0, 212 / 255.0)    # #7a6fd4
LAVENDER = (0.80, 0.84, 1.0)
HINT_TEXT = 'Tekan tombol apa saja untuk masuk'
HINT_SUB = 'klik di mana saja · kartu login akan muncul'

BULAN = ('Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
         'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember')
HARI = ('Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu')


def log(path, msg):
    if not path:
        return
    try:
        with open(path, 'a') as f:
            f.write('[%s] %s\n' % (time.strftime('%H:%M:%S'), msg))
    except OSError:
        pass


# --------------------------------------------------------------------- easing
def ease_out_cubic(t):
    return 1.0 - (1.0 - t) ** 3


def ease_out_expo(t):
    t = max(0.0, min(1.0, t))
    return 1.0 if t >= 1.0 else 1.0 - 2 ** (-10 * t)


def ease_out_back(t, s=1.0):
    t -= 1.0
    return t * t * ((s + 1.0) * t + s) + 1.0


def ease_in_out_sine(t):
    return 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, t)))


def rounded_path(cr, x, y, w, h, r):
    r = min(r, w / 2.0, h / 2.0)
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    cr.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
    cr.close_path()


class Overlay(Gtk.Window):
    def __init__(self, a):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.a = a
        self.progress = 0.0
        self.animating = False
        self.focus_tries = 0
        self.hero_key = ''

        self.wall = self.load_pixbuf(a.wallpaper)
        self.card = self.load_pixbuf(a.card)
        if self.wall is None or self.card is None:
            raise SystemExit(0)                     # aman: biarkan layar login normal
        self.panel = self.load_pixbuf(a.panel_strip) if a.panel_strip else None
        self.clock_crop = self.load_pixbuf(a.clock_crop) if a.clock_crop else None

        geo = Gdk.Display.get_default().get_monitor(0).get_geometry()
        self.sw, self.sh = geo.width, geo.height
        # mode "panel strip": overlay menutup SELURUH layar (panel digambar
        # sendiri dari potret asli). Tanpa itu: mulai dari bawah panel.
        self.oy = 0 if self.panel is not None else max(0, a.top_gap)
        self.h = self.sh - self.oy

        # wallpaper di-scale SEKALI ke ukuran overlay (bukan tiap frame)
        self.wall_scaled = self.wall.scale_simple(
            self.sw, self.h, GdkPixbuf.InterpType.BILINEAR) or self.wall

        self.card_x, self.card_y = a.card_x, a.card_y - self.oy
        self.card_w, self.card_h = self.card.get_width(), self.card.get_height()

        self.set_decorated(False)
        self.set_skip_taskbar_hint(True)
        self.set_keep_above(True)
        self.set_type_hint(Gdk.WindowTypeHint.DOCK)
        self.set_can_focus(True)
        self.set_app_paintable(True)
        self.resize(self.sw, self.h)
        self.move(0, self.oy)

        self.area = Gtk.DrawingArea()
        self.area.set_size_request(self.sw, self.h)
        self.area.connect('draw', self.on_draw)
        self.add(self.area)

        # --- JAM BESAR: dirender sekali jadi pixbuf (di-render ulang tiap menit)
        self.hero_pix = None
        self.hero_rect = (0, 0, 0, 0)
        self.build_hero(reposition=True)

        # SPLASH: dirender sekali ke pixbuf (teks besar + plat kaca)
        self.hint_pix, self.hint_rect = self.build_hint()   # (x, y, w, h)
        hx, hy, hw, hh = self.hint_rect
        self.hint_area = (hx, hy, hx + hw, hy + hh)         # untuk queue_draw_area

        self.connect('key-press-event', self.on_input)
        self.connect('button-press-event', self.on_input)
        self.connect('destroy', Gtk.main_quit)
        GLib.timeout_add(TICK_MS, self.on_tick)
        GLib.timeout_add_seconds(4, self.refresh_hero)
        if a.timeout > 0:                            # jaring aman: jangan sampai terkunci
            GLib.timeout_add_seconds(a.timeout, self.reveal)
        if a.auto > 0:                               # demo/pratinjau tanpa menekan tombol
            GLib.timeout_add_seconds(a.auto, self.reveal)

    # ---------------------------------------------------------------- pixbuf
    @staticmethod
    def load_pixbuf(path):
        if not path:
            return None
        try:
            return GdkPixbuf.Pixbuf.new_from_file(path)
        except Exception as e:
            log(getattr(sys, '_anim_log', None), 'gagal memuat %s: %s' % (path, e))
            return None

    # ----------------------------------------------------------- JAM BESAR
    def hero_target(self):
        """Titik & skala akhir jam besar: pusat jam panel (kalau terdeteksi)."""
        a = self.a
        if a.clock_w > 0 and a.clock_h > 0:
            return (a.clock_x + a.clock_w / 2.0, a.clock_y + a.clock_h / 2.0 - self.oy,
                    float(a.clock_h))
        return (self.sw / 2.0, (self.oy + 30) / 2.0, 24.0)   # cadangan: tengah panel

    def build_hero(self, reposition=False):
        """Render jam besar (caption + jam + detik + garis aksen + tanggal) → pixbuf."""
        a = self.a
        if not a.hero:
            self.hero_pix = None
            return False
        now = time.localtime()
        hhmm = time.strftime('%H:%M', now)
        sec = time.strftime('%S', now)
        tanggal = '%s, %d %s %d' % (HARI[now.tm_wday], now.tm_mday,
                                    BULAN[now.tm_mon - 1], now.tm_year)
        key = '%s%s%s' % (hhmm, sec, tanggal)
        if key == self.hero_key and self.hero_pix is not None:
            return False
        self.hero_key = key

        fs = int(a.hero_size)
        cap_fs = max(10, int(fs * 0.135))
        date_fs = max(13, int(fs * 0.235))
        sec_fs = max(13, int(fs * 0.26))

        scratch = cairo.ImageSurface(cairo.FORMAT_ARGB32, 8, 8)
        scr = cairo.Context(scratch)

        def lay(text, font):
            l = PangoCairo.create_layout(scr)
            l.set_text(text, -1)
            l.set_font_description(Pango.FontDescription(font))
            return l, l.get_pixel_size()

        cap_l, (cap_w, cap_h) = lay(a.hero_caption, 'Inter %dpx' % cap_fs)
        time_l, (tw, th) = lay(hhmm, 'Inter Bold %dpx' % fs)
        sec_l, (sw2, sh2) = lay(sec, 'Inter Bold %dpx' % sec_fs)
        date_l, (dw, dh) = lay(tanggal, 'Inter %dpx' % date_fs)

        rule_w = int(max(110, min(232, tw * 0.52)))
        pad = 30
        w = int(max(tw + sw2 + 26, dw, cap_w) + pad * 2)
        gap1 = int(fs * 0.10)
        gap2 = int(fs * 0.16)
        h = pad + cap_h + gap1 + th + gap2 + 3 + gap2 + dh + pad

        surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
        cr = cairo.Context(surf)

        # --- glow lembut di belakang jam (radial, murah karena sekali render)
        gx, gy = w / 2.0, pad + cap_h + gap1 + th * 0.52
        gr = cairo.RadialGradient(gx, gy, 4, gx, gy, max(tw, th) * 0.78)
        gr.add_color_stop_rgba(0.0, ACCENT[0], ACCENT[1], ACCENT[2], 0.16)
        gr.add_color_stop_rgba(0.55, ACCENT2[0], ACCENT2[1], ACCENT2[2], 0.07)
        gr.add_color_stop_rgba(1.0, 0, 0, 0, 0.0)
        cr.set_source(gr)
        cr.rectangle(0, 0, w, h)
        cr.fill()

        # --- caption kecil bergaya spasi huruf (di atas)
        cr.move_to((w - cap_w) / 2.0, pad)
        cr.set_source_rgba(*ACCENT, 0.78)
        PangoCairo.show_layout(cr, cap_l)

        ty = pad + cap_h + gap1
        # --- jam: bayangan gelap tipis + isi putih, plus detik aksen
        tx = (w - (tw + sw2 + 26)) / 2.0
        for ox, oy, al in ((0, 2, 0.22), (0, 0, 0.55)):
            cr.save()
            cr.move_to(tx + ox, ty + oy)
            cr.set_source_rgba(0.02, 0.03, 0.07, al)
            PangoCairo.show_layout(cr, time_l)
            cr.restore()
        cr.move_to(tx, ty)
        cr.set_source_rgba(1, 1, 1, 0.98)
        PangoCairo.show_layout(cr, time_l)
        cr.move_to(tx + tw + 12, ty + th - sh2 - th * 0.12)
        cr.set_source_rgba(*LAVENDER, 0.92)
        PangoCairo.show_layout(cr, sec_l)

        # --- garis aksen bergradasi (biru → ungu)
        ry = ty + th + gap2
        rx = (w - rule_w) / 2.0
        lg = cairo.LinearGradient(rx, ry, rx + rule_w, ry)
        lg.add_color_stop_rgba(0.0, ACCENT[0], ACCENT[1], ACCENT[2], 0.0)
        lg.add_color_stop_rgba(0.5, LAVENDER[0], LAVENDER[1], LAVENDER[2], 0.85)
        lg.add_color_stop_rgba(1.0, ACCENT2[0], ACCENT2[1], ACCENT2[2], 0.0)
        cr.set_line_width(2.0)
        cr.set_source(lg)
        cr.move_to(rx, ry + 1)
        cr.line_to(rx + rule_w, ry + 1)
        cr.stroke()

        # --- tanggal
        cr.move_to((w - dw) / 2.0, ry + 3 + gap2)
        cr.set_source_rgba(0.88, 0.90, 1.0, 0.80)
        PangoCairo.show_layout(cr, date_l)

        pix = Gdk.pixbuf_get_from_surface(surf, 0, 0, w, h)
        if pix is None:
            self.hero_pix = None
            return False
        self.hero_pix = pix
        if reposition or self.hero_rect[2] == 0:
            self.hero_rect = (0, 0, w, h)
        # posisi idle & tujuan penerbangan (koordinat window overlay)
        self.hero_cx = self.sw / 2.0
        self.hero_cy = self.h * 0.46
        tx_c, ty_c, ch = self.hero_target()
        self.hero_dx, self.hero_dy = tx_c, ty_c
        self.hero_s_end = max(HERO_END_SCALE_MIN,
                              min(0.55, (ch * 1.25) / max(1.0, float(th))))
        # area idle jam (untuk repaint hemat)
        self.hero_area = (int(self.hero_cx - w / 2.0), int(self.hero_cy - h / 2.0),
                          int(self.hero_cx + w / 2.0), int(self.hero_cy + h / 2.0))
        if self.hero_area[0] < 0:
            self.hero_area = (0,) + self.hero_area[1:]
        return True

    def refresh_hero(self):
        if self.build_hero():
            self.area.queue_draw_area(*self.hero_area)     # ganti menit → repaint
        return True

    # ------------------------------------------------------- splash (sekali)
    PAD_X = 56          # padding kiri/kanan plat kaca
    PAD_TOP = 20
    PAD_BOTTOM = 40     # ruang untuk tiga titik indikator

    def build_hint(self):
        """Ukur teks lalu gambar plat kaca + SPLASH besar KE PIXBUF (sekali saja).

        Ukuran plat dihitung dari lebar teks yang sebenarnya (Pango), supaya teks
        tidak pernah mepet/terpotong walau --hint-size diubah-ubah.
        """
        fs = self.a.hint_size
        sub_fs = max(11, int(fs * 0.50))

        scratch = cairo.ImageSurface(cairo.FORMAT_ARGB32, 8, 8)
        scr = cairo.Context(scratch)
        title = PangoCairo.create_layout(scr)
        title.set_text(self.a.hint, -1)
        title.set_font_description(Pango.FontDescription('Inter Bold %dpx' % fs))
        tw, th = title.get_pixel_size()
        sub = PangoCairo.create_layout(scr)
        sub.set_text(self.a.hint_sub, -1)
        sub.set_font_description(Pango.FontDescription('Inter %dpx' % sub_fs))
        subw, subh = sub.get_pixel_size()

        w = int(min(self.sw - 90, max(560, max(tw, subw) + self.PAD_X * 2)))
        h = self.PAD_TOP + th + 16 + subh + self.PAD_BOTTOM
        surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
        cr = cairo.Context(surf)

        # plat kaca: tint navy + tepi terang halus + garis kilau di tepi atas
        rounded_path(cr, 1, 1, w - 2, h - 2, 28)
        grad = cairo.LinearGradient(0, 0, 0, h)
        grad.add_color_stop_rgba(0, 0.10, 0.12, 0.22, 0.60)
        grad.add_color_stop_rgba(1, 0.05, 0.06, 0.12, 0.74)
        cr.set_source(grad)
        cr.fill_preserve()
        cr.set_line_width(1.6)
        cr.set_source_rgba(1, 1, 1, 0.18)
        cr.stroke()
        cr.move_to(30, 2.2)
        cr.line_to(w - 30, 2.2)
        cr.set_line_width(1.1)
        cr.set_source_rgba(1, 1, 1, 0.22)
        cr.stroke()

        tx, ty = (w - tw) / 2.0, self.PAD_TOP
        # glow lembut di belakang judul: beberapa salinan geser 1-2px (murah & halus)
        for ox, oy, al in ((-2, 0, 0.10), (2, 0, 0.10), (0, -2, 0.10), (0, 2, 0.10), (0, 0, 0.16)):
            cr.save()
            cr.move_to(tx + ox, ty + oy)
            cr.set_source_rgba(*ACCENT, al)
            PangoCairo.show_layout(cr, title)
            cr.restore()
        cr.move_to(tx, ty)
        cr.set_source_rgba(1, 1, 1, 0.97)
        PangoCairo.show_layout(cr, title)

        # garis aksen tipis di kiri & kanan judul (hanya bila masih ada ruang)
        cr.set_line_width(2.6)
        cr.set_source_rgba(*ACCENT2, 0.60)
        for sx, ex in ((24, tx - 20), (tx + tw + 20, w - 24)):
            if ex - sx > 26:
                cr.move_to(sx, ty + th * 0.55)
                cr.line_to(ex, ty + th * 0.55)
        cr.stroke()

        # subjudul: lebih besar & terang, tepat di bawah judul
        cr.move_to((w - subw) / 2.0, ty + th + 16)
        cr.set_source_rgba(0.84, 0.88, 0.99, 0.85)
        PangoCairo.show_layout(cr, sub)

        x = (self.sw - w) // 2
        y = int(min(max(self.card_y + self.card_h + 66, self.card_y + self.card_h + 30),
                    self.h - h - 40))
        pix = Gdk.pixbuf_get_from_surface(surf, 0, 0, w, h)
        if pix is None:                              # jaga-jaga: biar login tetap normal
            raise SystemExit(0)
        self.hint_xy = (x, y)                        # sudut kiri-atas
        return pix, (x, y, w, h)                     # (x, y, lebar, tinggi)

    # ----------------------------------------------------------------- draw
    def on_draw(self, _w, cr):
        p = min(1.0, self.progress)

        # -------- wallpaper: zoom + meredup yang naik di tengah lalu kembali normal
        # (di akhir animasi = persis seperti wallpaper asli, jadi serah-terima ke
        #  kartu login buatan greeter tidak terasa "lompat")
        pulse = math.sin(math.pi * p) if p > 0.0 else 0.0
        z = 1.0 + (ZOOM_PEAK - 1.0) * pulse
        dim = DIM_PEAK * pulse
        cr.save()
        if z > 1.0:                      # zoom berpusat (Ken Burns) — origin tetap 0,0
            cr.translate(self.sw / 2.0, self.h / 2.0)
            cr.scale(z, z)
            cr.translate(-self.sw / 2.0, -self.h / 2.0)
        Gdk.cairo_set_source_pixbuf(cr, self.wall_scaled, 0, 0)
        cr.paint()
        cr.restore()
        if dim > 0:
            cr.set_source_rgba(0.03, 0.04, 0.09, dim)
            cr.paint()

        # -------- panel ASLI (potret greeter) — digambar apa adanya supaya panel
        # tidak "muncul mendadak"; area jamnya sudah ditambal (tanpa jam).
        if self.panel is not None:
            Gdk.cairo_set_source_pixbuf(cr, self.panel, 0, 0)
            cr.paint()

        # -------- splash: menghilang (naik + membesar + memudar) saat reveal
        if not self.animating and p <= 0.0:
            self.draw_hint(cr, 1.0)
        elif p > 0.0:
            # splash cepat menyingkir (crossfade) supaya tidak tumpang-tindih
            # dengan kartu yang sedang naik dari bawah
            fade = 1.0 - ease_out_cubic(min(1.0, p / 0.28))
            if fade <= 0.004:
                fade = 0.0
            if fade > 0:
                self.draw_hint(cr, fade)

        # -------- JAM BESAR (di tengah saat idle, terbang ke panel saat reveal)
        if self.hero_pix is not None and p < 1.0:
            self.draw_hero(cr, p)

        if p > 0.0:
            self.draw_card(cr, p)
            # -------- jam asli muncul kembali (crossfade) di akhir animasi
            if self.clock_crop is not None and p > CLOCK_IN_PART:
                al = ease_in_out_sine((p - CLOCK_IN_PART) / (1.0 - CLOCK_IN_PART))
                cr.save()
                cr.rectangle(self.a.clock_x - 6, self.a.clock_y - self.oy - 6,
                             self.clock_crop.get_width() + 12,
                             self.clock_crop.get_height() + 12)
                cr.clip()
                Gdk.cairo_set_source_pixbuf(cr, self.clock_crop,
                                            self.a.clock_x - 6, self.a.clock_y - self.oy - 6)
                cr.paint_with_alpha(al)
                cr.restore()
        return False

    def draw_hero(self, cr, p):
        """Jam besar: diam di tengah → terbang ke jam panel sambil mengecil & memudar."""
        w, h = self.hero_pix.get_width(), self.hero_pix.get_height()
        if p <= 0.0:
            cx, cy, s, alpha = self.hero_cx, self.hero_cy, 1.0, 1.0
        else:
            # naik dengan tenang (mulai pelan → tengah cepat → mendarat lembut),
            # bukan melesat di frame pertama (itu terasa seperti "teleport")
            t = ease_in_out_sine(min(1.0, p / HERO_FLY_PART))
            cx = self.hero_cx + (self.hero_dx - self.hero_cx) * t
            cy = self.hero_cy + (self.hero_dy - self.hero_cy) * t
            s = 1.0 + (self.hero_s_end - 1.0) * t
            if p < HERO_HOLD:
                alpha = 1.0
            else:
                alpha = 1.0 - ease_out_cubic((p - HERO_HOLD) / (1.0 - HERO_HOLD))
        if alpha <= 0.004:
            return
        cr.save()
        cr.translate(cx, cy)
        cr.scale(s, s)
        cr.translate(-w / 2.0, -h / 2.0)
        Gdk.cairo_set_source_pixbuf(cr, self.hero_pix, 0, 0)
        cr.paint_with_alpha(alpha)
        cr.restore()

    def draw_hint(self, cr, fade):
        """Splash (plat yang sudah jadi pixbuf) + aksen hidup: denyut & titik."""
        t = time.time()
        breathe = 0.5 + 0.5 * math.sin(t * 1.7)
        x, y, w, h = self.hint_rect          # x,y = posisi; w,h = ukuran

        # saat reveal: splash turun & mengecil sedikit — seperti "terdorong" kartu
        grow = 1.0 - 0.06 * (1.0 - fade)
        dy = (1.0 - fade) * 34.0
        cr.save()
        cr.translate(x + w / 2.0, y + h / 2.0 + dy)
        cr.scale(grow, grow)
        cr.translate(-(x + w / 2.0), -(y + h / 2.0))
        Gdk.cairo_set_source_pixbuf(cr, self.hint_pix, x, y)
        cr.paint_with_alpha((0.80 + 0.20 * breathe) * fade)
        cr.restore()

        # denyut lembut: garis aksen bawah menyapu kiri→kanan (murah: 1 gradasi)
        cr.save()
        cr.rectangle(x + 1, y + 1, w - 2, h - 2)
        cr.clip()
        sweep = (t * 0.30) % 1.0
        bw = w * 0.42
        bx = x - bw + (w + bw) * sweep
        g = cairo.LinearGradient(bx, 0, bx + bw, 0)
        g.add_color_stop_rgba(0.0, *ACCENT, 0.0)
        g.add_color_stop_rgba(0.5, *ACCENT, 0.30 * breathe * fade)
        g.add_color_stop_rgba(1.0, *ACCENT2, 0.0)
        cr.set_source(g)
        cr.paint()
        cr.restore()

        # tiga titik yang menyala bergantian (indikator "menunggu input")
        dot_r, gap = 4.6, 17.0
        cx = x + w / 2.0
        cy = y + h - 22
        active = int(t * 2.4) % 3
        for i in range(3):
            dx = cx + (i - 1) * gap
            on = 1.0 if i == active else 0.32
            cr.arc(dx, cy, dot_r * (1.15 if i == active else 1.0), 0, 2 * math.pi)
            cr.set_source_rgba(0.85, 0.89, 1.0, (0.30 + 0.70 * on) * fade)
            cr.fill()

    def draw_card(self, cr, p):
        """Kartu masuk: slide + FLIP (skala Y, poros bawah) + perspektif + glow + sheen."""
        enter = min(1.0, p / ENTER_PART)
        settle = ease_out_cubic(max(0.0, (p - ENTER_PART) / (1.0 - ENTER_PART)))

        # slide: sedikit "melambat di akhir" (bukan melesat lalu diam)
        e = ease_out_cubic(enter)
        dy = (1.0 - e) * SLIDE_PX
        alpha = min(1.0, p * 9.0)                    # solid cepat, biar FLIP-nya terlihat
        # FLIP: selesai di 55% waktu; dari 0.35 (terlipat) -> 1.0 dengan overshoot
        flip = ease_out_back(min(1.0, p / FLIP_PART), 0.9)
        sy = FLIP_START + (1.0 - FLIP_START) * flip
        # perspektif: melebar di tengah lintasan (kartu terasa mendekat ke kamera)
        sx = 1.0 + 0.06 * math.sin(math.pi * min(1.0, p / FLIP_PART)) * (1.0 - settle * 0.5)

        cx = self.card_x + self.card_w / 2.0
        bottom = self.card_y + self.card_h + dy

        # --- glow aksen di belakang kartu: muncul di tengah, habis di akhir
        ga = 0.55 * (math.sin(math.pi * p) ** 0.8) if p < 1.0 else 0.0
        if ga > 0.004:
            for pad, al in ((10, 0.20), (22, 0.12), (40, 0.07)):
                rounded_path(cr, self.card_x - pad, self.card_y + dy - pad,
                             self.card_w + pad * 2, self.card_h + pad * 2, 26 + pad)
                cr.set_source_rgba(*ACCENT, al * ga * 2)
                cr.fill()

        # --- kartu: transform (anchor di tepi bawah → terasa "terbuka" ke atas)
        cr.save()
        cr.translate(cx, bottom)
        cr.scale(sx, sy)
        cr.translate(-cx, -bottom)
        Gdk.cairo_set_source_pixbuf(cr, self.card, self.card_x, self.card_y + dy)
        cr.paint_with_alpha(alpha)

        # --- kilau (sheen) menyapu permukaan kartu, ikut miring saat flip
        if enter < 1.0:
            sheen = ease_in_out_sine(min(1.0, p / 0.62))
            bw = self.card_w * 0.26
            bx = self.card_x - bw + (self.card_w + 2 * bw) * sheen
            cr.save()
            cr.rectangle(self.card_x, self.card_y + dy, self.card_w, self.card_h)
            cr.clip()
            g = cairo.LinearGradient(bx, self.card_y + dy, bx + bw,
                                     self.card_y + dy + self.card_h)
            amp = 0.26 * (1.0 - enter * 0.5) * alpha
            g.add_color_stop_rgba(0.0, 1, 1, 1, 0.0)
            g.add_color_stop_rgba(0.5, 1, 1, 1, amp)
            g.add_color_stop_rgba(1.0, 0.80, 0.86, 1.0, 0.0)
            cr.set_source(g)
            cr.paint()
            cr.restore()
        cr.restore()

    # ------------------------------------------------- render 1 frame (dev)
    def render_frame(self, p, out_path):
        """Gambar satu frame animasi ke PNG tanpa menampilkan window.

        Dipakai untuk memeriksa/menyetel animasi (mis. lewat --frame-at).
        """
        surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, self.sw, self.h)
        cr = cairo.Context(surf)
        keep_p, keep_anim = self.progress, self.animating
        self.progress, self.animating = p, p > 0.0
        self.on_draw(self.area, cr)
        surf.write_to_png(out_path)
        self.progress, self.animating = keep_p, keep_anim
        return out_path

    # ---------------------------------------------------------------- input
    def on_tick(self):
        if self.animating:
            self.progress += TICK_MS / max(1.0, float(self.a.duration))
            if self.progress >= 1.0:
                self.progress = 1.0
                self.area.queue_draw()
                self.finish()
                return False
            self.area.queue_draw()                       # animasi: repaint penuh
        else:
            self.area.queue_draw_area(*self.hint_area)   # idle: cuma area splash
        return True

    def on_input(self, _w, _e):
        self.reveal()
        return True                                     # tombol pertama "dipakai" untuk muncul

    def reveal(self):
        if not self.animating and self.progress <= 0.0:
            self.animating = True
            log(self.a.log, 'reveal: jam besar terbang + kartu login muncul (durasi %sms)'
                % self.a.duration)
        return False

    def finish(self):
        log(self.a.log, 'selesai: overlay ditutup')
        self.restore_focus()
        self.close()

    # ---------------------------------------------------------------- fokus
    def steal_focus(self):
        """Ambil fokus keyboard supaya tombol pertama tidak masuk ke entry password."""
        win = self.get_window()
        if win is None:
            return False
        try:
            win.focus(Gdk.CURRENT_TIME)
        except Exception:
            return False
        return True

    def restore_focus(self):
        """Kembalikan fokus ke window greeter supaya langsung bisa mengetik."""
        wid = self.a.focus_window
        if not wid:
            return
        xid = int(str(wid), 0)
        try:
            gi.require_version('GdkX11', '3.0')
            from gi.repository import GdkX11
            win = GdkX11.X11Window.foreign_new_for_display(Gdk.Display.get_default(), xid)
            if win is not None:
                win.focus(Gdk.CURRENT_TIME)
                log(self.a.log, 'fokus dikembalikan ke 0x%x' % xid)
                return
        except Exception as e:
            log(self.a.log, 'fokus gagal dikembalikan: %s' % e)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--wallpaper', required=True)
    ap.add_argument('--card', required=True)
    ap.add_argument('--card-x', type=int, required=True)
    ap.add_argument('--card-y', type=int, required=True)
    ap.add_argument('--panel-strip', default='', help='strip panel asli (tanpa jam)')
    ap.add_argument('--clock-crop', default='', help='potongan asli area jam')
    ap.add_argument('--clock-x', type=int, default=0)
    ap.add_argument('--clock-y', type=int, default=0)
    ap.add_argument('--clock-w', type=int, default=0)
    ap.add_argument('--clock-h', type=int, default=0)
    ap.add_argument('--top-gap', type=int, default=0)
    ap.add_argument('--hero', type=int, default=1, help='1 = tampilkan jam besar di tengah')
    ap.add_argument('--hero-size', type=int, default=94, help='ukuran jam besar (px)')
    ap.add_argument('--hero-caption', default='SELAMAT DATANG')
    ap.add_argument('--hint', default=HINT_TEXT)
    ap.add_argument('--hint-sub', default=HINT_SUB)
    ap.add_argument('--hint-size', type=int, default=34, help='ukuran font splash (px)')
    ap.add_argument('--timeout', type=int, default=120, help='detik; 0 = tanpa auto-muncul')
    ap.add_argument('--auto', type=int, default=0, help='detik; kartu muncul sendiri (0=nonaktif)')
    ap.add_argument('--duration', type=int, default=700, help='durasi animasi (ms)')
    ap.add_argument('--focus-window', default='')
    ap.add_argument('--log', default='')
    # pengembangan/penyetelan: simpan beberapa frame animasi ke PNG lalu keluar
    ap.add_argument('--frame-at', default='', help='mis. 0,0.25,0.5,1 (progress 0..1)')
    ap.add_argument('--frame-out', default='', help='tulis frame ke <DIR>/frame-<n>.png')
    a = ap.parse_args()
    sys._anim_log = a.log

    try:
        ov = Overlay(a)
    except SystemExit:
        raise
    except Exception as e:
        log(a.log, 'overlay gagal dibuat: %s' % e)
        return 0                                    # aman: layar login tampil normal

    if a.frame_at and a.frame_out:
        os.makedirs(a.frame_out, exist_ok=True)
        for i, val in enumerate(a.frame_at.split(',')):
            print(ov.render_frame(float(val), os.path.join(a.frame_out, 'frame-%d.png' % i)))
        return 0

    ov.show_all()
    ov.steal_focus()
    for ms in (60, 200, 500, 1000):                 # greeter sering merebut fokus lagi
        GLib.timeout_add(ms, lambda: (ov.animating or ov.steal_focus()) and False)
    log(a.log, 'overlay tampil (wallpaper + jam besar) — menunggu tombol')
    Gtk.main()
    return 0


if __name__ == '__main__':
    sys.exit(main())
