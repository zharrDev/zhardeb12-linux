#!/usr/bin/env python3
"""greeter-anim.py — overlay "wallpaper dulu, form login muncul belakangan".

Menampilkan wallpaper saja + petunjuk. Begitu ada tombol diklik/ditekan, kartu
login masuk dari bawah dengan halus (slide + fade + sedikit efek flip), lalu
overlay menutup diri sehingga kartu login yang ASLI (digambar greeter) terlihat
di posisi yang sama — jadi serah-terimanya mulus tanpa lompatan.

  python3 greeter-anim.py --wallpaper bg.jpg --card card.png \
      --card-x 645 --card-y 374 [--top-gap 62] [--timeout 120] \
      [--duration 480] [--focus-window 0x400003] [--log /tmp/anim.log]

Seluruh kegagalan bersifat aman: kalau gambar tidak bisa dibaca, script keluar
tanpa menampilkan apa pun (layar login tetap normal).
"""
import argparse
import sys
import time

import gi

gi.require_version('Gtk', '3.0')
gi.require_version('PangoCairo', '1.0')
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib, Pango, PangoCairo  # noqa: E402

TICK_MS = 16
SLIDE_PX = 150          # jarak awal kartu di bawah posisi akhirnya
HINT_TEXT = 'Tekan tombol apa saja untuk masuk'


def log(path, msg):
    if not path:
        return
    try:
        with open(path, 'a') as f:
            f.write('[%s] %s\n' % (time.strftime('%H:%M:%S'), msg))
    except OSError:
        pass


def ease_out_cubic(t):
    return 1.0 - (1.0 - t) ** 3


class Overlay(Gtk.Window):
    def __init__(self, a):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.a = a
        self.progress = 0.0
        self.animating = False
        self.pulse = 0.0
        self.focus_tries = 0

        self.wall = self.load_pixbuf(a.wallpaper)
        self.card = self.load_pixbuf(a.card)
        if self.wall is None or self.card is None:
            raise SystemExit(0)                     # aman: biarkan layar login normal

        disp = Gdk.Display.get_default()
        geo = disp.get_monitor(0).get_geometry()
        self.sw, self.sh = geo.width, geo.height
        self.top_gap = max(0, a.top_gap)
        self.h = self.sh - self.top_gap
        self.card_x, self.card_y = a.card_x, a.card_y - self.top_gap
        self.card_w, self.card_h = self.card.get_width(), self.card.get_height()

        self.set_decorated(False)
        self.set_skip_taskbar_hint(True)
        self.set_keep_above(True)
        self.set_type_hint(Gdk.WindowTypeHint.DOCK)
        self.set_can_focus(True)
        self.set_app_paintable(True)
        self.resize(self.sw, self.h)
        self.move(0, self.top_gap)

        self.area = Gtk.DrawingArea()
        self.area.set_size_request(self.sw, self.h)
        self.area.connect('draw', self.on_draw)
        self.add(self.area)

        self.connect('key-press-event', self.on_input)
        self.connect('button-press-event', self.on_input)
        self.connect('destroy', Gtk.main_quit)
        GLib.timeout_add(TICK_MS, self.on_tick)
        if a.timeout > 0:                            # jaring aman: jangan sampai terkunci
            GLib.timeout_add_seconds(a.timeout, self.reveal)

    # ---------------------------------------------------------------- pixbuf
    @staticmethod
    def load_pixbuf(path):
        try:
            return GdkPixbuf.Pixbuf.new_from_file(path)
        except Exception as e:
            log(getattr(sys, '_anim_log', None), 'gagal memuat %s: %s' % (path, e))
            return None

    # ----------------------------------------------------------------- draw
    def on_draw(self, _w, cr):
        # latar: wallpaper (dipotong tepat di bawah panel atas)
        cr.save()
        cr.scale(self.sw / self.wall.get_width(), self.h / self.wall.get_height())
        Gdk.cairo_set_source_pixbuf(cr, self.wall, 0, 0)
        cr.paint()
        cr.restore()

        if not self.animating and self.progress <= 0.0:
            self.draw_hint(cr)

        if self.progress > 0.0:
            self.draw_card(cr)
        return False

    def draw_hint(self, cr):
        alpha = 0.45 + 0.45 * self.pulse
        cx = self.sw / 2
        cy = max(self.sh * 0.72, self.card_y + self.card_h + 70) - self.top_gap

        layout = PangoCairo.create_layout(cr)
        layout.set_text(self.a.hint, -1)
        layout.set_font_description(Pango.FontDescription('Inter 13'))
        w, h = layout.get_pixel_size()
        cr.set_source_rgba(1, 1, 1, alpha)
        cr.move_to(cx - w / 2, cy)
        PangoCairo.show_layout(cr, layout)

        small = PangoCairo.create_layout(cr)
        small.set_text('(atau klik di mana saja)', -1)
        small.set_font_description(Pango.FontDescription('Inter 10'))
        sw, sh = small.get_pixel_size()
        cr.set_source_rgba(1, 1, 1, alpha * 0.72)
        cr.move_to(cx - sw / 2, cy + h + 8)
        PangoCairo.show_layout(cr, small)

    def draw_card(self, cr):
        p = ease_out_cubic(min(1.0, self.progress))
        dy = (1.0 - p) * SLIDE_PX                    # masuk dari bawah
        alpha = min(1.0, self.progress * 1.6)        # fade cepat di awal
        sy = 0.90 + 0.10 * p                         # sedikit "flip" membuka

        cx = self.card_x + self.card_w / 2
        bottom = self.card_y + self.card_h + dy
        cr.save()
        cr.translate(cx, bottom)
        cr.scale(1.0, sy)
        cr.translate(-cx, -bottom)
        Gdk.cairo_set_source_pixbuf(cr, self.card, self.card_x, self.card_y + dy)
        cr.paint_with_alpha(alpha)
        # kilau tipis saat kartu masih membuka
        if p < 0.75:
            glint = (0.75 - p) / 0.75 * 0.10
            cr.set_source_rgba(1, 1, 1, glint)
            cr.rectangle(self.card_x, self.card_y + dy, self.card_w, self.card_h)
            cr.fill()
        cr.restore()

    # ---------------------------------------------------------------- input
    def on_tick(self):
        self.pulse = abs((time.time() * 0.6) % 2 - 1)          # 0..1 naik-turun
        if self.pulse < 0.0:
            self.pulse = -self.pulse
        if self.animating:
            self.progress += TICK_MS / max(1.0, float(self.a.duration))
            if self.progress >= 1.0:
                self.progress = 1.0
                self.finish()
                return False
        self.area.queue_draw()
        return True

    def on_input(self, _w, _e):
        self.reveal()
        return True                                     # tombol pertama "dipakai" untuk muncul

    def reveal(self):
        if not self.animating and self.progress <= 0.0:
            self.animating = True
            log(self.a.log, 'reveal: kartu login muncul')
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
        # jalur 1: GDK (tanpa dependensi tambahan)
        try:
            gi.require_version('GdkX11', '3.0')
            from gi.repository import GdkX11
            win = GdkX11.X11Window.foreign_new_for_display(Gdk.Display.get_default(), xid)
            if win is not None:
                win.focus(Gdk.CURRENT_TIME)
                log(self.a.log, 'fokus dikembalikan ke 0x%x (gdk)' % xid)
                return
        except Exception as e:
            log(self.a.log, 'fokus via gdk gagal: %s' % e)
        # jalur 2: python-xlib, kalau terpasang
        try:
            from Xlib import display as xdisplay, X
            d = xdisplay.Display()
            d.set_input_focus(d.create_resource_object('window', xid), X.RevertToParent,
                              X.CurrentTime)
            d.sync()
            log(self.a.log, 'fokus dikembalikan ke 0x%x (xlib)' % xid)
        except Exception as e:
            log(self.a.log, 'fokus tidak bisa dikembalikan: %s' % e)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--wallpaper', required=True)
    ap.add_argument('--card', required=True)
    ap.add_argument('--card-x', type=int, required=True)
    ap.add_argument('--card-y', type=int, required=True)
    ap.add_argument('--top-gap', type=int, default=0)
    ap.add_argument('--hint', default=HINT_TEXT)
    ap.add_argument('--timeout', type=int, default=120, help='detik; 0 = tanpa auto-muncul')
    ap.add_argument('--duration', type=int, default=480, help='durasi animasi (ms)')
    ap.add_argument('--focus-window', default='')
    ap.add_argument('--log', default='')
    a = ap.parse_args()
    sys._anim_log = a.log

    try:
        ov = Overlay(a)
    except SystemExit:
        raise
    except Exception as e:
        log(a.log, 'overlay gagal dibuat: %s' % e)
        return 0                                    # aman: layar login tampil normal

    ov.show_all()
    ov.steal_focus()
    for ms in (60, 200, 500, 1000):                 # greeter sering merebut fokus lagi
        GLib.timeout_add(ms, lambda: (ov.animating or ov.steal_focus()) and False)
    log(a.log, 'overlay tampil (wallpaper saja) — menunggu tombol')
    Gtk.main()
    return 0


if __name__ == '__main__':
    sys.exit(main())
