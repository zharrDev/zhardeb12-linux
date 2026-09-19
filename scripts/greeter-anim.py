#!/usr/bin/env python3
"""greeter-anim.py — overlay "wallpaper dulu, form login muncul belakangan".

Alur:

  1. Awal  : wallpaper (TAJAM, apa adanya) + JAM BESAR di TENGAH layar —
             caption kecil, jam + detik, garis aksen gradasi, dan hari/tanggal
             di bawahnya. Tanpa teks apa pun; cuma tiga titik halus di bawah
             sebagai penanda "menunggu".
             Panel asli (host/session/power) digambar dari potret greeter supaya
             tidak ada yang "muncul mendadak".
  2. Tombol: kartu login masuk dari bawah — slide + FLIP bersih (tanpa fade-in,
             glow, kilau, atau peregangan; kartunya sudah buram dari greeter),
             plus wallpaper zoom Ken-Burns. Caption/garis/tanggal memudar, lalu
             JAM BESAR terbang ke ATAS KARTU dan mengecil ke ukuran akhir — jadi
             setelah form muncul, jam ada DI ATAS form (di atas border kartu).
  3. Selesai: overlay menutup diri dan digantikan window kecil yang MENETAPKAN
             jam di posisi itu (gambar latar 1:1 + jam), jadi jam tetap ada
             tanpa perlu menyentuh widget greeter. Fokus tombol dikembalikan ke
             window greeter supaya langsung bisa mengetik password.

  Login sukses → window greeter dihancurkan dan sesi desktop mulai; overlay +
  jam menetap ikut hilang SEKETIKA (dipantau lewat `xprop -spy`, cadangan cek
  2 detik) supaya tidak ada sisa gambar yang menempel di atas desktop.

Semua kegagalan bersifat aman: gambar gagal dibaca / GTK error → script keluar
tanpa menampilkan apa pun, layar login tetap normal.

  python3 greeter-anim.py --wallpaper bg.jpg --card card.png \
      --card-x 645 --card-y 374 --card-top 452 [--panel-strip panel.png] \
      [--top-gap 83] [--hero 1] [--hero-size 120] [--clock-size 54] \
      [--clock-gap 64] [--stay 1] [--duration 700] [--auto 0]

  --auto N : kartu muncul sendiri setelah N detik (0 = nonaktif). Untuk demo.
  Selama kartu naik, Esc / klik kanan = batal kembali ke tampilan awal.
"""
import argparse
import math
import os
import subprocess
import sys
import time
import traceback

import cairo
import gi

gi.require_version('Gtk', '3.0')
gi.require_version('Pango', '1.0')
gi.require_version('PangoCairo', '1.0')
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib, Pango, PangoCairo  # noqa: E402

# --- tuning animasi (semua dalam ms / px) -----------------------------------
TICK_MS = 33            # ~30 fps: cukup mulus, separuh beban CPU saat boot dingin
BACK_R = 24             # jari-jari tombol kembali (lingkaran kaca kiri-bawah)
SLIDE_PX = 170          # jarak awal kartu di bawah posisi akhirnya
FLIP_START = 0.35       # skala Y awal (kartu "terlipat" dari bawah)
ENTER_PART = 0.72       # 72% waktu = masuk, 28% terakhir = "mendarat"
FLIP_PART = 0.50        # flip selesai di 50% waktu (lebih ringkas dari slide)
ZOOM_PEAK = 1.055       # zoom wallpaper di tengah animasi (naik lalu kembali)
DIM_PEAK = 0.14         # gelap maksimum wallpaper di tengah animasi
EXTRA_FADE = (0.05, 0.40)     # caption/garis/tanggal memudar pada rentang ini
HERO_FLY_PART = 0.78    # jam besar selesai terbang di 78% waktu
HERO_FADE = (0.54, 0.76)      # jam besar memudar…
FINAL_IN = (0.66, 0.86)       # …dan jam final (tajam) menyusul di titik yang
                              # sama. Tumpang-tindihnya cuma di 0,66–0,76 dan
                              # saat itu posisi/skala keduanya sudah sama, jadi
                              # tidak ada gambar dobel — hanya terasa "menajam"
ACCENT = (95 / 255.0, 162 / 255.0, 206 / 255.0)      # #5fa2ce
ACCENT2 = (122 / 255.0, 111 / 255.0, 212 / 255.0)    # #7a6fd4
LAVENDER = (0.80, 0.84, 1.0)
FONT_UI = 'Poppins, Inter'      # Poppins kalau ada, jatuh ke Inter kalau tidak
HINT_TEXT = ''
HINT_SUB = ''

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


def ease_out_back(t, s=1.0):
    t -= 1.0
    return t * t * ((s + 1.0) * t + s) + 1.0


def ease_in_out_sine(t):
    return 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, t)))


def span(p, lo, hi):
    """0 sebelum lo, 1 sesudah hi, mulus di antaranya."""
    if hi <= lo:
        return 1.0 if p >= hi else 0.0
    return max(0.0, min(1.0, (p - lo) / (hi - lo)))


def rounded_path(cr, x, y, w, h, r):
    r = min(r, w / 2.0, h / 2.0)
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    cr.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
    cr.close_path()


def _fail_open(fn):
    """Decorator callback GTK: exception -> fail-open, overlay tidak boleh
    mengunci layar login (macet fullscreen + makan semua input)."""
    def wrap(self, *args, **kwargs):
        try:
            return fn(self, *args, **kwargs)
        except Exception:
            try:
                self.fail_open(fn.__name__)
            except Exception:
                pass
            return False
    return wrap


class Overlay(Gtk.Window):
    def __init__(self, a):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.a = a
        self.progress = 0.0
        self.animating = False
        self.anim_start = 0.0     # monotonic saat animasi mulai (untuk watchdog)
        self.reversing = False    # True = animasi diputar balik ke tampilan awal
        self.linger = None
        self.back_btn = None      # tombol kembali (muncul setelah form tampil)
        self.back_armed = False   # True = linger dihancurkan oleh tombol kembali
        self.done = False
        self.watch = None
        self.idle_since = time.monotonic()   # anti-mash: abaikan input 300ms

        self.wall = self.load_pixbuf(a.wallpaper)
        self.card = self.load_pixbuf(a.card)
        if self.wall is None or self.card is None:
            raise SystemExit(0)                     # aman: biarkan layar login normal
        self.panel = self.load_pixbuf(a.panel_strip) if a.panel_strip else None

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
        self.card_cx = self.card_x + self.card_w / 2.0
        # tepi ATAS kartu yang sebenarnya (a.card_top), di koordinat overlay
        self.card_top = max(0, a.card_top - self.oy)

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

        # --- JAM: tiga lapis pixbuf (di-render sekali, dihitung ulang tiap menit)
        self.hero_key = ''
        self.pix_time = None        # jam besar (idle) + detik
        self.pix_extra = None       # caption + garis + tanggal
        self.pix_final = None       # jam final di atas kartu
        self.build_clock()

        # SPLASH/titik menunggu: pixbuf kecil (boleh kosong kalau tanpa teks)
        self.hint_pix, self.hint_rect = self.build_hint()
        hx, hy, hw, hh = self.hint_rect
        self.hint_area = (max(0, hx), max(0, hy), hx + hw, hy + hh)

        self.connect('key-press-event', self.on_input)
        self.connect('button-press-event', self.on_input)
        self.connect('realize', self.on_realize_input)
        self.connect('destroy', self.on_destroy)
        GLib.timeout_add(TICK_MS, self.on_tick)
        GLib.timeout_add_seconds(4, self.refresh_clock)
        GLib.timeout_add_seconds(1, self.on_watchdog)   # pengaman macet
        if not a.frame_at:                        # mode render frame: tidak perlu
            GLib.timeout_add_seconds(2, self.watch_greeter)   # cadangan
            self.start_greeter_watch()                        # deteksi langsung (xprop)
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

    # --------------------------------------------------------------- JAM
    @staticmethod
    def lay(cr, text, font):
        l = PangoCairo.create_layout(cr)
        l.set_text(text, -1)
        l.set_font_description(Pango.FontDescription(font))
        return l, l.get_pixel_size()

    def _time_pixbuf(self, fs, sec_fs=None):
        """Pixbuf: jam 'HH:MM' (putih tebal) + detik aksen di kanannya.

        Sengaja TAJAM: tanpa halo/glow (halo itu yang membuat jam terlihat
        kabur). Hanya bayangan gelap tipis 2px ke bawah supaya tetap terbaca di
        atas wallpaper yang terang.
        """
        now = time.localtime()
        hhmm = time.strftime('%H:%M', now)
        sec = time.strftime('%S', now)
        sec_fs = sec_fs or max(13, int(fs * 0.26))
        pad = 4                                  # ruang tipis untuk bayangan
        scratch = cairo.ImageSurface(cairo.FORMAT_ARGB32, 8, 8)
        scr = cairo.Context(scratch)
        tl, (tw, th) = self.lay(scr, hhmm, '%s Bold %dpx' % (FONT_UI, fs))
        sl, (sw2, sh2) = self.lay(scr, sec, '%s SemiBold %dpx' % (FONT_UI, sec_fs))

        w = tw + int(sw2 * 0.55) + sw2 + pad * 2
        h = th + pad * 2
        surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
        cr = cairo.Context(surf)
        tx, ty = pad, pad
        cr.move_to(tx, ty + 2)
        cr.set_source_rgba(0.02, 0.03, 0.07, 0.40)      # bayangan tipis, bukan blur
        PangoCairo.show_layout(cr, tl)
        cr.move_to(tx, ty)
        cr.set_source_rgba(1, 1, 1, 1.0)
        PangoCairo.show_layout(cr, tl)
        cr.move_to(tx + tw + int(sw2 * 0.55), ty + th - sh2 - th * 0.12)
        cr.set_source_rgba(*LAVENDER, 1.0)
        PangoCairo.show_layout(cr, sl)
        pix = Gdk.pixbuf_get_from_surface(surf, 0, 0, w, h)
        return pix, tw, th

    def _extra_pixbuf(self, fs):
        """Pixbuf: caption kecil + garis aksen gradasi + hari/tanggal."""
        a = self.a
        now = time.localtime()
        tanggal = '%s, %d %s %d' % (HARI[now.tm_wday], now.tm_mday,
                                    BULAN[now.tm_mon - 1], now.tm_year)
        cap_fs = max(11, int(fs * 0.155))
        date_fs = max(14, int(fs * 0.245))
        scratch = cairo.ImageSurface(cairo.FORMAT_ARGB32, 8, 8)
        scr = cairo.Context(scratch)
        cap_l, (cap_w, cap_h) = self.lay(scr, a.hero_caption, '%s %dpx' % (FONT_UI, cap_fs))
        date_l, (dw, dh) = self.lay(scr, tanggal, '%s %dpx' % (FONT_UI, date_fs))

        rule_w = int(max(110, min(236, dw * 0.55)))
        gap = max(8, int(fs * 0.16))
        w = int(max(dw, cap_w, rule_w) + 40)
        h = (cap_h if a.hero_caption else 0) + (gap if a.hero_caption else 0) \
            + 3 + gap + dh
        surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
        cr = cairo.Context(surf)
        y = 0
        if a.hero_caption:
            cr.move_to((w - cap_w) / 2.0, y)
            cr.set_source_rgba(0.78, 0.85, 1.0, 0.86)
            PangoCairo.show_layout(cr, cap_l)
            y += cap_h + gap
        rx = (w - rule_w) / 2.0
        lg = cairo.LinearGradient(rx, y, rx + rule_w, y)
        lg.add_color_stop_rgba(0.0, ACCENT[0], ACCENT[1], ACCENT[2], 0.0)
        lg.add_color_stop_rgba(0.5, LAVENDER[0], LAVENDER[1], LAVENDER[2], 0.85)
        lg.add_color_stop_rgba(1.0, ACCENT2[0], ACCENT2[1], ACCENT2[2], 0.0)
        cr.set_line_width(2.0)
        cr.set_source(lg)
        cr.move_to(rx, y + 1)
        cr.line_to(rx + rule_w, y + 1)
        cr.stroke()
        y += 3 + gap
        cr.move_to((w - dw) / 2.0, y)
        cr.set_source_rgba(0.90, 0.92, 1.0, 0.88)
        PangoCairo.show_layout(cr, date_l)
        return Gdk.pixbuf_get_from_surface(surf, 0, 0, w, h)

    def clock_target(self):
        """Titik jam FINAL: di tengah kartu, tepat di atas tepi atas kartu."""
        fh = self.pix_final.get_height() if self.pix_final else 80
        cy = self.card_top - self.a.clock_gap - fh / 2.0
        cy = max(fh / 2.0 + 6, cy)
        return self.card_cx, cy

    def build_clock(self):
        """Render jam: besar (idle) + final (di atas kartu) + caption/tanggal."""
        a = self.a
        if not a.hero:
            self.pix_time = self.pix_extra = self.pix_final = None
            return False
        now = time.localtime()
        key = '%s|%s|%d' % (time.strftime('%H:%M:%S', now), a.clock_size, a.hero_size)
        if key == self.hero_key and self.pix_time is not None:
            return False
        self.hero_key = key

        self.pix_time, tw, th = self._time_pixbuf(int(a.hero_size))
        self.pix_final, fw, fh = self._time_pixbuf(int(a.clock_size))
        self.pix_extra = self._extra_pixbuf(int(a.hero_size))
        if self.pix_time is None or self.pix_final is None:
            self.pix_time = self.pix_final = self.pix_extra = None
            return False

        self.gap_between = max(12, int(int(a.hero_size) * 0.20))
        self.big_cx, self.big_cy = self.sw / 2.0, self.h * 0.43
        self.final_cx, self.final_cy = self.clock_target()
        self.scale_end = float(a.clock_size) / max(1.0, float(a.hero_size))

        fw2, fh2 = self.pix_final.get_width(), self.pix_final.get_height()
        fx = int(self.final_cx - fw2 / 2.0)
        fy = int(self.final_cy - fh2 / 2.0)
        self.final_rect = (fx, fy, fw2, fh2)

        # area idle jam (untuk repaint hemat)
        hw = self.pix_time.get_width()
        th_tot = self.pix_time.get_height()
        eh = self.pix_extra.get_height() if self.pix_extra else 0
        top = int(self.big_cy - (th_tot + (self.gap_between + eh if eh else 0)) / 2.0)
        self.hero_area = (max(0, int(self.big_cx - hw / 2.0)), max(0, top),
                          int(self.big_cx + hw / 2.0) + 2,
                          top + th_tot + (self.gap_between + eh if eh else 0) + 2)
        return True

    def refresh_clock(self):
        if self.done:
            return False
        if self.build_clock():
            self.area.queue_draw_area(*self.hero_area)     # ganti menit → repaint
        return True

    # ------------------------------------------------------- splash (sekali)
    PAD_X = 56          # padding kiri/kanan plat kaca
    PAD_TOP = 20
    PAD_BOTTOM = 40     # ruang untuk tiga titik indikator

    def build_hint(self):
        """Plat splash (opsional) + tiga titik menunggu.

        Kalau teks splash dikosongkan (default sekarang), yang digambar hanya
        tiga titik halus di bawah layar — tidak ada tulisan "tekan tombol".
        """
        a = self.a
        if not a.hint:
            w, h = 150, 40
            x = (self.sw - w) // 2
            y = self.h - 118
            return None, (x, y, w, h)

        fs = a.hint_size
        sub_fs = max(11, int(fs * 0.50))
        scratch = cairo.ImageSurface(cairo.FORMAT_ARGB32, 8, 8)
        scr = cairo.Context(scratch)
        title, (tw, th) = self.lay(scr, a.hint, '%s Bold %dpx' % (FONT_UI, fs))
        sub, (subw, subh) = self.lay(scr, a.hint_sub, '%s %dpx' % (FONT_UI, sub_fs))

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
        for ox, oy, al in ((-2, 0, 0.10), (2, 0, 0.10), (0, -2, 0.10), (0, 2, 0.10), (0, 0, 0.16)):
            cr.save()
            cr.move_to(tx + ox, ty + oy)
            cr.set_source_rgba(*ACCENT, al)
            PangoCairo.show_layout(cr, title)
            cr.restore()
        cr.move_to(tx, ty)
        cr.set_source_rgba(1, 1, 1, 0.97)
        PangoCairo.show_layout(cr, title)

        cr.set_line_width(2.6)
        cr.set_source_rgba(*ACCENT2, 0.60)
        for sx, ex in ((24, tx - 20), (tx + tw + 20, w - 24)):
            if ex - sx > 26:
                cr.move_to(sx, ty + th * 0.55)
                cr.line_to(ex, ty + th * 0.55)
        cr.stroke()

        if a.hint_sub:
            cr.move_to((w - subw) / 2.0, ty + th + 16)
            cr.set_source_rgba(0.84, 0.88, 0.99, 0.85)
            PangoCairo.show_layout(cr, sub)

        x = (self.sw - w) // 2
        y = int(min(max(self.card_y + self.card_h + 66, self.card_y + self.card_h + 30),
                    self.h - h - 40))
        pix = Gdk.pixbuf_get_from_surface(surf, 0, 0, w, h)
        if pix is None:                              # jaga-jaga: biar login tetap normal
            raise SystemExit(0)
        return pix, (x, y, w, h)                     # (x, y, lebar, tinggi)

    # ----------------------------------------------------------------- draw
    def fail_open(self, where):
        """Jaring pengaman terakhir: sembunyikan overlay + kembalikan fokus ke
        greeter supaya user tetap bisa login apa pun yang terjadi."""
        try:
            log(self.a.log, 'fail-open %s, overlay disembunyikan:\n%s'
                % (where, traceback.format_exc()))
        except Exception:
            pass
        try:
            self.animating = False
            self.reversing = False
            self.hide()
            self.restore_focus()
        except Exception:
            pass

    def on_watchdog(self):
        """Paksa animasi selesai kalau tick macet (tidak pernah boleh gantung)."""
        try:
            if self.animating and self.anim_start > 0:
                limit = float(self.a.duration) / 1000.0 + 5.0
                if time.monotonic() - self.anim_start > limit:
                    log(self.a.log, 'watchdog: animasi lewat %ss, paksa selesai'
                        % round(limit, 1))
                    if self.reversing:
                        self._force_idle()
                    else:
                        self.progress = 1.0
                        self.finish()
        except Exception as e:
            log(self.a.log, 'watchdog gagal: %s' % e)
        return True                       # watchdog tidak boleh mati

    def _force_idle(self):
        self.progress = 0.0
        self.animating = False
        self.reversing = False
        self.done = False
        try:
            self.area.queue_draw()
        except Exception:
            pass
        self.steal_focus()

    @_fail_open
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
        # tidak "muncul mendadak".
        if self.panel is not None:
            Gdk.cairo_set_source_pixbuf(cr, self.panel, 0, 0)
            cr.paint()

        # -------- titik "menunggu tombol" (dan plat splash bila teksnya diisi)
        if p < 0.30:
            if p <= 0.0:
                self.draw_hint(cr, 1.0)
            else:
                fade = 1.0 - ease_out_cubic(min(1.0, p / 0.28))
                if fade > 0.004:
                    self.draw_hint(cr, fade)

        # -------- JAM
        if self.pix_time is not None:
            self.draw_clock(cr, p)

        if p > 0.0:
            self.draw_card(cr, p)
        return False

    def draw_clock(self, cr, p):
        """Jam besar di tengah → terbang ke atas kartu; tanggal memudar."""
        # --- caption + garis + tanggal (hanya saat idle; memudar lebih dulu
        #     supaya saat form muncul yang tertinggal cuma jam)
        ea = 1.0 - span(p, *EXTRA_FADE)
        if self.pix_extra is not None and ea > 0.004:
            ew, eh = self.pix_extra.get_width(), self.pix_extra.get_height()
            t_h = self.pix_time.get_height()
            ey = self.big_cy - (t_h + self.gap_between + eh) / 2.0 \
                + t_h + self.gap_between
            drift = -14.0 * span(p, *EXTRA_FADE)
            cr.save()
            Gdk.cairo_set_source_pixbuf(cr, self.pix_extra,
                                        self.big_cx - ew / 2.0, ey + drift)
            cr.paint_with_alpha(0.95 * ea)
            cr.restore()

        # --- jam BESAR: terbang + mengecil, lalu memudar menyerahkan ke jam final
        t = ease_in_out_sine(min(1.0, p / HERO_FLY_PART))
        w, h = self.pix_time.get_width(), self.pix_time.get_height()
        cx = self.big_cx + (self.final_cx - self.big_cx) * t
        cy = self.big_cy + (self.final_cy - self.big_cy) * t
        s = 1.0 + (self.scale_end - 1.0) * t
        alpha = 1.0 - ease_out_cubic(span(p, *HERO_FADE)) if p > 0 else 1.0
        if alpha > 0.004:
            cr.save()
            cr.translate(cx, cy)
            cr.scale(s, s)
            cr.translate(-w / 2.0, -h / 2.0)
            Gdk.cairo_set_source_pixbuf(cr, self.pix_time, 0, 0)
            cr.paint_with_alpha(alpha)
            cr.restore()

        # --- jam FINAL: digambar 1:1 (tanpa skala/transform apa pun) supaya
        # benar-benar tajam. Big clock sudah memudar HABIS sebelum ini muncul
        # (lihat HERO_FADE vs FINAL_IN), jadi tidak pernah ada dua jam
        # bertumpuk yang terlihat seperti gambar dobel/kabur.
        if p > 0.0 and self.pix_final is not None:
            al = ease_out_cubic(span(p, *FINAL_IN))
            if al > 0.004:
                fx, fy, fw, fh = self.final_rect
                cr.save()
                Gdk.cairo_set_source_pixbuf(cr, self.pix_final, fx, fy)
                cr.paint_with_alpha(al)          # tanpa transform = piksel 1:1
                cr.restore()

    def draw_hint(self, cr, fade):
        """Tiga titik menunggu + (kalau teksnya diisi) plat kaca splash."""
        t = time.time()
        breathe = 0.5 + 0.5 * math.sin(t * 1.7)
        x, y, w, h = self.hint_rect

        grow = 1.0 - 0.06 * (1.0 - fade)
        dy = (1.0 - fade) * 34.0
        if self.hint_pix is not None:
            cr.save()
            cr.translate(x + w / 2.0, y + h / 2.0 + dy)
            cr.scale(grow, grow)
            cr.translate(-(x + w / 2.0), -(y + h / 2.0))
            Gdk.cairo_set_source_pixbuf(cr, self.hint_pix, x, y)
            cr.paint_with_alpha((0.80 + 0.20 * breathe) * fade)
            cr.restore()

            # denyut lembut di permukaan plat (murah: 1 gradasi)
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
        cy = y + h - 22 if self.hint_pix is not None else y + h / 2.0
        active = int(t * 2.4) % 3
        for i in range(3):
            dx = cx + (i - 1) * gap
            on = 1.0 if i == active else 0.32
            cr.arc(dx, cy + dy * 0.4, dot_r * (1.15 if i == active else 1.0), 0, 2 * math.pi)
            cr.set_source_rgba(0.85, 0.89, 1.0, (0.28 + 0.62 * on) * fade)
            cr.fill()

    def draw_card(self, cr, p):
        """Kartu masuk: slide + FLIP (skala Y, poros bawah) — bersih tanpa blur.

        Sengaja TANPA fade-in, glow, kilau, atau peregangan mendatar: kartunya
        sudah buram dari greeter (kaca frosted), jadi lapisan tambahan hanya
        membuatnya terlihat "kabur" saat ngeflip. Sekarang kartu digambar solid
        (alpha penuh) dan hanya ber-scale Y — murni flip.
        """
        enter = min(1.0, p / ENTER_PART)
        e = ease_out_cubic(enter)                    # slide melambat di akhir
        dy = (1.0 - e) * SLIDE_PX
        # FLIP: selesai di 50% waktu; dari 0.35 (terlipat) -> 1.0 TANPA
        # overshoot (overshoot + fps rendah = terbaca melompat, bukan ngeflip)
        flip = ease_out_cubic(min(1.0, p / FLIP_PART))
        sy = FLIP_START + (1.0 - FLIP_START) * flip

        cx = self.card_x + self.card_w / 2.0
        bottom = self.card_y + self.card_h + dy

        # poros di tepi bawah → kartu terasa "terbuka" ke atas
        cr.save()
        cr.translate(cx, bottom)
        cr.scale(1.0, sy)
        cr.translate(-cx, -bottom)
        Gdk.cairo_set_source_pixbuf(cr, self.card, self.card_x, self.card_y + dy)
        cr.paint()
        cr.restore()

    # ------------------------------------------------- render 1 frame (dev)
    def render_frame(self, p, out_path):
        """Gambar satu frame animasi ke PNG tanpa menampilkan window."""
        surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, self.sw, self.h)
        cr = cairo.Context(surf)
        keep_p, keep_anim = self.progress, self.animating
        self.progress, self.animating = p, p > 0.0
        self.on_draw(self.area, cr)
        surf.write_to_png(out_path)
        self.progress, self.animating = keep_p, keep_anim
        return out_path

    # ---------------------------------------------------------- jam menetap
    def show_linger(self):
        """Window kecil: salinan 1:1 area di atas kartu + jam final.

        Greeter tidak menyediakan jam di atas kartu, jadi layar akhir "dipinjam"
        oleh window kecil ini. Isinya potongan wallpaper 1:1 sesuai posisinya di
        layar (jadi menyatu dengan latar), lalu jam final di atasnya — persis
        seperti frame terakhir overlay, sehingga pergantiannya tidak terlihat.
        """
        if self.pix_final is None:
            return
        x, y, w, h = self.final_rect
        # jepit ke dalam gambar latar (koordinat OVERLAY, bukan layar)
        x = max(0, min(x, self.sw - w))
        y = max(0, min(y, self.h - h))
        try:
            sub = GdkPixbuf.Pixbuf.new_subpixbuf(self.wall_scaled, x, y, w, h)
        except Exception as e:
            log(self.a.log, 'linger: potongan wallpaper gagal (%s)' % e)
            return
        surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
        cr = cairo.Context(surf)
        Gdk.cairo_set_source_pixbuf(cr, sub, 0, 0)
        cr.paint()
        Gdk.cairo_set_source_pixbuf(cr, self.pix_final, 0, 0)
        cr.paint()
        pix = Gdk.pixbuf_get_from_surface(surf, 0, 0, w, h)

        win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        win.set_decorated(False)
        win.set_skip_taskbar_hint(True)
        win.set_keep_above(True)
        win.set_type_hint(Gdk.WindowTypeHint.DOCK)
        win.set_can_focus(False)
        win.set_accept_focus(False)
        win.set_app_paintable(True)
        win.move(x, y + self.oy)
        win.add(Gtk.Image.new_from_pixbuf(pix))
        win.connect('realize', self._click_through)
        win.connect('destroy', self.on_linger_destroy)
        win.show_all()
        self.linger = win
        self.raise_floaters()
        log(self.a.log, 'jam menetap di (%d,%d) %dx%d' % (x, y + self.oy, w, h))
        if self.a.linger_ttl > 0:               # pratinjau: tutup sendiri nanti
            GLib.timeout_add_seconds(self.a.linger_ttl, self.close_linger)

    def on_linger_destroy(self, _w):
        self.linger = None
        if not self.back_armed:
            Gtk.main_quit()       # jalur normal (login / ttl): keluar

    # ------------------------------------------------------- tombol kembali
    # Setelah form tampil, tombol Cancel MILIK binary greeter (handler
    # cancel_cb di kode C) tidak bisa dikabel-ulang. Penggantinya: lingkaran
    # kaca "‹" kiri-bawah milik overlay — diklik = flip kembali ke tampilan
    # awal (wallpaper + jam besar), kartu greeter asli tetap di bawahnya.
    @staticmethod
    def paint_back(cr, size):
        """Gambar tombol kembali di atas cairo context (murni, bisa diuji)."""
        cx = cy = size / 2.0
        r = BACK_R
        cr.set_source_rgba(0, 0, 0, 0.45)                 # bayangan
        cr.arc(cx, cy + 2, r, 0, 2 * math.pi)
        cr.fill()
        cr.set_source_rgba(0.05, 0.06, 0.11, 0.72)        # kaca navy
        cr.arc(cx, cy, r, 0, 2 * math.pi)
        cr.fill()
        cr.set_source_rgba(0.37, 0.64, 0.81, 0.90)        # ring aksen #5fa2ce
        cr.set_line_width(2.5)
        cr.arc(cx, cy, r - 2, 0, 2 * math.pi)
        cr.stroke()
        lay = PangoCairo.create_layout(cr)                # chevron "‹"
        lay.set_text('‹', -1)
        lay.set_font_description(Pango.FontDescription('Poppins Bold 34px'))
        _tw, th = lay.get_pixel_size()
        cr.move_to(cx - 10, cy - th / 2.0 - 1)
        cr.set_source_rgba(1, 1, 1, 0.98)
        PangoCairo.show_layout(cr, lay)

    def on_draw_back(self, area, cr):
        alloc = area.get_allocation()
        self.paint_back(cr, alloc.width)
        return False

    def show_back(self):
        """Tampilkan tombol kembali setelah form login tampil."""
        try:
            size = BACK_R * 2 + 16
            x, y = 26, self.h - 26 - size
            win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
            win.set_decorated(False)
            win.set_skip_taskbar_hint(True)
            win.set_keep_above(True)
            win.set_type_hint(Gdk.WindowTypeHint.DOCK)
            win.set_can_focus(False)
            win.set_accept_focus(False)
            win.set_app_paintable(True)
            area = Gtk.DrawingArea()
            area.set_size_request(size, size)
            area.set_can_focus(False)
            area.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
            area.connect('draw', self.on_draw_back)
            area.connect('button-press-event', self.on_back_press)
            win.add(area)
            win.move(x, y + self.oy)
            win.show_all()
            self.back_btn = (win, x, y, size)
            self.raise_floaters()
            log(self.a.log, 'tombol kembali di (%d,%d)' % (x, y + self.oy))
        except Exception as e:
            log(self.a.log, 'tombol kembali gagal: %s' % e)

    @_fail_open
    def on_back_press(self, _w, e):
        try:
            bx = e.x - (BACK_R + 8)
            by = e.y - (BACK_R + 8)
            if bx * bx + by * by <= (BACK_R + 8) ** 2:
                self.do_back()
                return True
        except Exception:
            pass
        return False

    @_fail_open
    def do_back(self):
        """Flip kembali ke tampilan awal: tutup jam+tombol, putar animasi balik."""
        if self.reversing:
            return True           # abaikan klik ganda selama putar balik
        if not self.done and self.progress <= 0.0:
            return True           # sudah di tampilan awal, tidak ada yang dibalik
        if self.linger is not None:
            self.back_armed = True
            try:
                self.linger.destroy()
            except Exception:
                pass
            self.linger = None
            self.back_armed = False
        if self.back_btn is not None:
            try:
                self.back_btn[0].destroy()
            except Exception:
                pass
            self.back_btn = None
        self.done = False
        self.reversing = True
        self.animating = True
        self.anim_start = time.monotonic()
        try:
            self.show_all()          # overlay tadi di-hide, tampilkan lagi
        except Exception:
            pass
        log(self.a.log, 'membatalkan: flip kembali ke tampilan awal')

    @staticmethod
    def _click_through(win):
        """Area masuk dikosongkan: klik di atas jam diteruskan ke greeter."""
        try:
            win.input_shape_combine_region(cairo.Region())
        except Exception as e:
            log(getattr(sys, '_anim_log', None), 'input shape dilewati: %s' % e)

    # ---------------------------------------------------------------- input
    @_fail_open
    def on_tick(self):
        if self.animating:
            # Berbasis WAKTU nyata (bukan jumlah tick): frame boleh lambat di
            # boot dingin, tapi animasi tetap selesai tepat waktu.
            dur = max(1.0, float(self.a.duration)) / 1000.0
            el = time.monotonic() - self.anim_start
            if self.reversing:
                # putar balik: kartu turun + jam kembali ke tengah (flip back)
                self.progress = max(0.0, 1.0 - el / dur)
                if self.progress <= 0.0:
                    self.animating = False
                    self.reversing = False
                    self.done = False
                    self.idle_since = time.monotonic()
                    self.area.queue_draw()
                    self.steal_focus()
                    log(self.a.log, 'kembali ke tampilan awal (dibatalkan)')
                    return True
                self.area.queue_draw()
            else:
                self.progress = min(1.0, el / dur)
                if self.progress >= 1.0:
                    self.area.queue_draw()
                    self.finish()
                    return False
                self.area.queue_draw()                   # animasi: repaint penuh
        else:
            self.area.queue_draw_area(*self.hint_area)   # idle: cuma area kecil
        return True

    @staticmethod
    def _is_cancel(e):
        """Esc / klik kanan = batalkan (kembali ke tampilan awal)."""
        try:
            if e.type == Gdk.EventType.KEY_PRESS:
                return e.keyval == Gdk.KEY_Escape
            if e.type == Gdk.EventType.BUTTON_PRESS:
                return getattr(e, 'button', 0) == 3
        except Exception:
            pass
        return False

    @_fail_open
    def panel_strip_h(self):
        """Tinggi strip panel (koordinat overlay) yang diklik-tembuskan."""
        if self.oy != 0:
            return 0        # overlay mulai di bawah panel: tak ada yang dilubangi
        ph = self.panel.get_height() if self.panel is not None else 0
        if ph <= 0:
            ph = max(0, self.a.top_gap)
        return ph + 16      # + margin pil

    def on_realize_input(self, _w):
        self.apply_input_shape()

    def apply_input_shape(self):
        """Lubangi area panel: klik menu session/power diteruskan ke greeter
        (jadi dropdown BISA dibuka saat idle), klik di tempat lain tetap
        memunculkan form. Keyboard tidak berubah (fokus tetap di overlay)."""
        try:
            win = self.get_window()
            if win is None:
                return
            h = self.panel_strip_h()
            if h <= 0:
                return
            reg = cairo.Region(cairo.RectangleInt(0, 0, self.sw, self.h))
            reg.subtract(cairo.RectangleInt(0, 0, self.sw, min(h, self.h)))
            win.input_shape_combine_region(reg)
            log(self.a.log, 'input dilubangi setinggi %dpx untuk panel' % h)
        except Exception as e:
            log(self.a.log, 'input shape dilewati: %s' % e)

    def raise_floaters(self):
        """Tanpa WM, keep-above tidak ditegakkan: naikkan lagi window kecil
        (jam menetap + tombol kembali) supaya tak tertutup greeter."""
        wins = [self.linger]
        wins.append(self.back_btn[0] if self.back_btn else None)
        for w in wins:
            if w is None:
                continue
            try:
                gw = w.get_window()
                if gw is not None:
                    gw.raise_()
            except Exception:
                pass

    @_fail_open
    def on_input(self, _w, e):
        if self.done:
            return False          # animasi selesai: overlay utama sudah tutup
        if self.animating:
            # Selama kartu naik: Esc/klik-kanan = batal ke tampilan awal
            # (wallpaper + jam besar). Input lain: biarkan animasi lanjut.
            if self._is_cancel(e):
                self.animating = False
                self.progress = 0.0
                self.area.queue_draw()
                log(self.a.log, 'dibatalkan: kembali ke tampilan awal')
            return True
        # Idle: input apa pun (termasuk klik kanan) memunculkan form,
        # tapi abaikan 300ms setelah kembali idle (anti-mash tombol).
        if time.monotonic() - self.idle_since < 0.3:
            return True
        self.reveal()
        return True                                     # tombol pertama "dipakai" untuk muncul

    # ------------------------------------------------- apa lagi yang "nempel"?
    # Saat user berhasil login, window greeter dihancurkan dan sesi Xfce mulai.
    # Jam menetap kita harus hilang PERSIS di saat itu supaya tidak ada sisa
    # gambar di atas desktop. Dua jalur dipakai bersamaan:
    #   1. `xprop -spy`  → kejadian, begitu window hilang langsung terdeteksi
    #   2. cek tiap 2 detik → cadangan kalau xprop tak mendukung -spy
    # Kalau alat bantunya error kita TIDAK mematikan apa pun (lebih baik satu
    # window kecil tersisa daripada mengganggu proses login).
    def start_greeter_watch(self):
        wid = self.a.focus_window
        if not wid:
            return
        try:
            self.watch = subprocess.Popen(['xprop', '-spy', '-id', wid],
                                          stdout=subprocess.PIPE,
                                          stderr=subprocess.STDOUT, text=True)
        except Exception as e:
            log(self.a.log, 'xprop -spy tidak bisa jalan (%s) — pakai cek 2s' % e)
            return
        if self.watch.stdout is not None:
            GLib.io_add_watch(self.watch.stdout, GLib.IO_IN | GLib.IO_HUP,
                              self.on_greeter_io)

    def on_greeter_io(self, src, cond):
        try:
            line = src.readline()
        except Exception:
            line = ''
        if not (cond & GLib.IO_HUP) and line and 'BadWindow' not in line:
            return True                     # masih hidup, abaikan barisnya
        if self.greeter_gone():             # konfirmasi dulu sebelum bertindak
            self.quit_now('window greeter hilang (xprop)')
            return False
        return True                         # mis. xprop tak mendukung -spy

    def watch_greeter(self):
        """Cadangan periodik: pastikan jam tidak pernah tertinggal."""
        if not self.a.focus_window:
            return True
        self.raise_floaters()     # greeter bisa me-raise dirinya saat diklik
        if self.greeter_gone():
            self.quit_now('window greeter sudah tidak ada')
            return False
        return True

    def greeter_gone(self):
        try:
            r = subprocess.run(['xwininfo', '-id', self.a.focus_window],
                               capture_output=True, timeout=5)
        except Exception:
            return False
        return r.returncode != 0

    def quit_now(self, why):
        log(self.a.log, '%s → tutup jam & keluar' % why)
        if self.back_btn is not None:
            try:
                self.back_btn[0].destroy()
            except Exception:
                pass
            self.back_btn = None
        if self.linger is not None:
            self.linger.destroy()            # memicu Gtk.main_quit via handler
        else:
            Gtk.main_quit()

    def close_linger(self):
        """Tutup jam menetap (dipakai pratinjau: --linger-ttl)."""
        if self.back_btn is not None:
            try:
                self.back_btn[0].destroy()
            except Exception:
                pass
            self.back_btn = None
        if self.linger is not None:
            self.linger.destroy()
        else:
            Gtk.main_quit()
        return False

    def on_destroy(self, *_):
        # fokus dikembalikan ke greeter supaya user langsung bisa mengetik
        # password; window jam (kalau ada) tidak bisa merebutnya karena
        # accept-focus dimatikan.
        self.restore_focus()
        if getattr(self, 'watch', None) is not None:
            try:
                self.watch.terminate()      # jangan tinggalkan proses xprop
            except Exception:
                pass
        if self.linger is None:
            Gtk.main_quit()

    @_fail_open
    def reveal(self):
        if not self.animating and self.progress <= 0.0:
            self.animating = True
            self.anim_start = time.monotonic()
            log(self.a.log, 'reveal: kartu naik + jam terbang ke atas form (durasi %sms)'
                % self.a.duration)
        return False

    @_fail_open
    def finish(self):
        log(self.a.log, 'selesai: form tampil' + (' + jam menetap' if self.a.stay else ''))
        self.done = True
        self.animating = False    # penting: kalau tidak, watchdog mengeksekusi
                                  # finish() berulang tiap detik (tombol ‹ ganda)
        if self.a.stay and self.pix_final is not None:
            self.show_linger()
        self.show_back()
        self.restore_focus()     # langsung bisa mengetik password
        self.hide()              # disembunyikan (bukan close) supaya bisa flip balik

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
    ap.add_argument('--card-top', type=int, default=0,
                    help='tepi ATAS kartu (tanpa bayangan) — acuan jam di atas form')
    ap.add_argument('--panel-strip', default='', help='strip panel asli dari potret greeter')
    ap.add_argument('--top-gap', type=int, default=0)
    ap.add_argument('--hero', type=int, default=1, help='1 = tampilkan jam di tengah')
    ap.add_argument('--hero-size', type=int, default=120, help='ukuran jam besar (px)')
    ap.add_argument('--hero-caption', default='welcome suo')
    ap.add_argument('--clock-size', type=int, default=54, help='ukuran jam di atas form (px)')
    ap.add_argument('--clock-gap', type=int, default=64, help='jarak jam ke tepi atas kartu (px)')
    ap.add_argument('--stay', type=int, default=1, help='1 = jam menetap di atas form')
    ap.add_argument('--linger-ttl', type=int, default=0,
                    help='detik; jam menetap menutup diri sendiri (0 = biarkan hidup)')
    ap.add_argument('--hint', default=HINT_TEXT, help='teks splash (kosong = tanpa teks)')
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
    if a.card_top <= 0:                 # cadangan kalau tidak dikirim
        a.card_top = a.card_y + 80
    if a.stay and a.frame_at:
        a.stay = 0                      # mode frame tidak perlu window menetap

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

    def _try_focus(_ov):
        if not _ov.animating:                       # jangan merebut fokus saat animasi
            _ov.steal_focus()
        return False

    ov.show_all()
    ov.steal_focus()
    for ms in (60, 200, 500, 1000):                 # greeter sering merebut fokus lagi
        GLib.timeout_add(ms, _try_focus, ov)
    log(a.log, 'overlay tampil (wallpaper + jam besar) — menunggu tombol')
    Gtk.main()
    return 0


if __name__ == '__main__':
    sys.exit(main())
