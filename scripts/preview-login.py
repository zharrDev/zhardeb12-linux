#!/usr/bin/env python3
"""preview-login.py — lihat tampilan layar login TANPA logout/reboot.

Menampilkan window fullscreen yang dibuat dari **UI XML asli** lightdm-gtk-greeter
(diekstrak langsung dari binary) + **CSS tema yang sama** dengan produksi + avatar
+ panel + wallpaper. Jadi yang kamu lihat di layar = tampilan login sebenarnya.

  python3 scripts/preview-login.py [detik]     # default 20 detik, ESC = tutup

Hasilnya juga otomatis disimpan sebagai PNG (~/Pictures/anime-login-preview.png)
sehingga bisa dibuka/dilihat lagi kapan pun tanpa membuka preview.
"""
import os
import subprocess
import sys
import tempfile
from datetime import datetime

import gi

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib  # noqa: E402

SRC_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GREETER_BIN = '/usr/sbin/lightdm-gtk-greeter'
GLASS_INSTALLED = '/usr/share/backgrounds/anime-glass'
CSS_SRC = os.path.join(SRC_DIR, 'config/lightdm/themes/anime-glass-greeter/gtk-3.0/gtk.css')
AVATAR_SRC = os.path.join(SRC_DIR, 'config/lightdm/avatar/anime-avatar.png')
SHOT = os.path.expanduser('~/Pictures/anime-login-preview.png')
# selalu mulai dari wallpaper TAJAM (jangan dari yang sudah di-blur) supaya
# hasil preview sama dengan hasil deploy.
BG_CANDIDATES = [
    os.path.join(GLASS_INSTALLED, 'login-bg-sharp.jpg'),
    os.path.join(SRC_DIR, 'config/wallpapers/login/anime-login-bg.jpg'),
]


# ----------------------------------------------------------------- UI XML asli
def extract_object(xml, obj_id):
    """Ambil satu <object>...</object> berimbang (menghormati tag self-closing)."""
    start = xml.find('id="%s"' % obj_id)
    if start < 0:
        raise ValueError('objek %s tidak ada di UI greeter' % obj_id)
    start = xml.rfind('<object', 0, start)
    depth, i = 0, start
    while True:
        nxt_open = xml.find('<object', i)
        nxt_close = xml.find('</object>', i)
        if nxt_close < 0:
            raise ValueError('XML greeter tidak seimbang: %s' % obj_id)
        if 0 <= nxt_open < nxt_close:
            tag_end = xml.find('>', nxt_open)
            i = tag_end + 1
            if xml[tag_end - 1] != '/':
                depth += 1
        else:
            depth -= 1
            i = nxt_close + 9
            if depth == 0:
                return xml[start:i]


def load_greeter_xml():
    raw = open(GREETER_BIN, encoding='utf-8', errors='ignore').read()
    start = raw.find('<?xml version="1.0" encoding="UTF-8"?><interface>')
    end = raw.find('</interface>', start)
    if start < 0 or end < 0:
        raise SystemExit('[preview] UI XML greeter tidak ditemukan di %s' % GREETER_BIN)
    return raw[start:end + len('</interface>')]


# ----------------------------------------------------- siapkan tekstur & CSS
def prepare_assets(tmp):
    """Aset login dibuat oleh scripts/login-assets.py — logika yang SAMA dengan
    saat deploy, jadi yang tampil di preview = yang nanti muncul di login asli."""
    bg_src = next((p for p in BG_CANDIDATES if os.path.isfile(p)), None)
    if not bg_src:
        raise SystemExit('[preview] wallpaper login tidak ditemukan')
    # ukuran monitor utama (tanpa API deprecated)
    display = Gdk.Display.get_default()
    geo = display.get_monitor(0).get_geometry()

    helper = os.path.join(SRC_DIR, 'scripts/login-assets.py')
    subprocess.run([sys.executable, helper, '--src', bg_src, '--outdir', tmp,
                    '--size', '%dx%d' % (geo.width, geo.height),
                    '--bg-blur', '16', '--card-blur', '8', '--dim', '0.90',
                    '--vignette', '0.60'], check=True)

    # CSS produksi, tapi url()-nya diarahkan ke aset lokal
    css = open(CSS_SRC, encoding='utf-8').read()
    css = css.replace('/usr/share/backgrounds/anime-glass/', tmp + '/')
    css_path = os.path.join(tmp, 'gtk.css')
    open(css_path, 'w', encoding='utf-8').write(css)
    return css_path, os.path.join(tmp, 'login-bg.jpg')


# ------------------------------------------------------------------- preview
class LoginPreview(Gtk.Window):
    def __init__(self, seconds=20):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.tmp = tempfile.mkdtemp(prefix='anime-login-preview-')
        css_path, bg_path = prepare_assets(self.tmp)
        self.set_decorated(False)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_app_paintable(True)

        prov = Gtk.CssProvider()
        try:
            prov.load_from_path(css_path)
        except GLib.Error as e:
            print('[preview] CSS error: %s' % e.message)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_USER)

        # dasar: wallpaper
        overlay = Gtk.Overlay()
        bg = Gtk.Image.new_from_file(bg_path)
        overlay.add(bg)

        # isi di atas wallpaper: panel atas + kartu login (tengah)
        stack = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        stack.pack_start(self.build_panel(), False, False, 0)
        holder = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        holder.set_halign(Gtk.Align.CENTER)
        holder.set_valign(Gtk.Align.CENTER)
        holder.set_vexpand(True)
        holder.pack_start(self.build_card(), False, False, 0)
        stack.pack_start(holder, True, True, 0)
        overlay.add_overlay(stack)
        self.add(overlay)

        self.connect('key-press-event', self.on_key)
        self.connect('destroy', Gtk.main_quit)
        self.fullscreen()
        GLib.timeout_add_seconds(2, self.take_screenshot)
        GLib.timeout_add_seconds(seconds, self.close)

    # panel atas: meniru panel greeter (host | jam | sesi | power)
    def build_panel(self):
        # panel melintang penuh di tepi atas (sama seperti greeter asli),
        # dibungkus jadi "pill" mengambang ala desktop.
        panel = Gtk.EventBox()
        panel.set_name('panel_window')
        panel.set_halign(Gtk.Align.FILL)
        panel.set_margin_top(6)
        panel.set_margin_start(6)
        panel.set_margin_end(6)

        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        menubar = Gtk.MenuBar()
        menubar.set_name('menubar')
        host = Gtk.MenuItem(label='suo@suo')
        self.clock = Gtk.MenuItem(label='')
        self.clock.set_name('clock_menuitem')
        session = Gtk.MenuItem(label='Xfce Session')
        menubar.append(host)
        menubar.append(self.clock)
        menubar.append(session)
        box.pack_start(menubar, True, True, 0)

        for icon, wid in (('system-shutdown', 'shutdown_button'),
                          ('system-reboot', 'restart_button')):
            btn = Gtk.Button()
            btn.set_name(wid)
            btn.add(Gtk.Image.new_from_icon_name(icon, Gtk.IconSize.MENU))
            box.pack_start(btn, False, False, 0)
        panel.add(box)
        self.update_clock()
        GLib.timeout_add_seconds(1, self.update_clock)
        return panel

    def update_clock(self):
        now = datetime.now()
        menit = {1: 'Januari', 2: 'Februari', 3: 'Maret', 4: 'April', 5: 'Mei', 6: 'Juni',
                 7: 'Juli', 8: 'Agustus', 9: 'September', 10: 'Oktober', 11: 'November',
                 12: 'Desember'}
        hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'][now.weekday()]
        self.clock.set_label('%s, %02d %s %d  •  %02d:%02d' % (
            hari, now.day, menit[now.month], now.year, now.hour, now.minute))
        return True

    # kartu login: memakai widget ASLI greeter
    def build_card(self):
        raw = load_greeter_xml()
        xml = '<interface>%s%s</interface>' % (extract_object(raw, 'user_liststore'),
                                               extract_object(raw, 'login_window'))
        b = Gtk.Builder()
        b.add_from_string(xml)
        card = b.get_object('login_window')

        model = b.get_object('user_liststore')
        model.append(['suo', 'Suo', 700])
        combo = b.get_object('user_combobox')
        combo.set_active(0)

        pw = b.get_object('password_entry')
        if pw:
            pw.set_placeholder_text('Masukkan password')
        username = b.get_object('username_entry')
        if username:                      # di produksi tersembunyi bila user dipilih
            username.set_no_show_all(True)
            username.hide()
        infobar = b.get_object('greeter_infobar')   # hanya muncul bila ada pesan error
        if infobar:
            infobar.set_no_show_all(True)
            infobar.hide()
        if os.path.isfile(AVATAR_SRC):
            b.get_object('user_image').set_from_pixbuf(
                GdkPixbuf.Pixbuf.new_from_file(AVATAR_SRC))
        return card

    def take_screenshot(self):
        try:
            os.makedirs(os.path.dirname(SHOT), exist_ok=True)
            subprocess.run(['import', '-window', 'root', SHOT], timeout=20, check=True)
            print('[preview] screenshot disimpan: %s' % SHOT)
        except Exception as e:
            print('[preview] gagal screenshot: %s' % e)
        return False

    def on_key(self, _w, event):
        if event.keyval in (Gdk.KEY_Escape, Gdk.KEY_q):
            self.close()
        return True


def main():
    seconds = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    print('[preview] menampilkan layar login selama %d detik (tekan ESC untuk menutup)' % seconds)
    LoginPreview(seconds).show_all()
    Gtk.main()
    return 0


if __name__ == '__main__':
    sys.exit(main())
