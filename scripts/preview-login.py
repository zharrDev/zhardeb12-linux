#!/usr/bin/env python3
"""preview-login.py — lihat tampilan layar login TANPA logout/reboot.

Menampilkan window fullscreen yang dibuat dari **UI XML asli** lightdm-gtk-greeter
(diekstrak langsung dari binary) + **CSS tema yang sama** dengan produksi + avatar
+ panel + wallpaper (TAJAM, tanpa blur). Jadi yang kamu lihat di layar = tampilan
login sebenarnya.

  python3 scripts/preview-login.py [detik]     # default 20 detik, ESC = tutup

Hasilnya juga otomatis disimpan sebagai PNG (~/Pictures/anime-login-preview.png)
sehingga bisa dibuka/dilihat lagi kapan pun tanpa membuka preview.
"""
import argparse
import os
import subprocess
import sys
import tempfile

import gi

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib  # noqa: E402

SRC_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GREETER_BIN = '/usr/sbin/lightdm-gtk-greeter'
GLASS_INSTALLED = '/usr/share/backgrounds/anime-glass'
CSS_SRC = os.path.join(SRC_DIR, 'config/lightdm/themes/anime-glass-greeter/gtk-3.0/gtk.css')
AVATAR_SRC = os.path.join(SRC_DIR, 'config/lightdm/avatar/anime-avatar.png')
SHOT = os.path.expanduser('~/Pictures/anime-login-preview.png')
# Selalu mulai dari wallpaper login di REPO (bukan dari aset hasil deploy yang
# bisa ketinggalan versi lama): isinya sekarang gambar blue-girl.
BG_DIR = os.path.join(SRC_DIR, 'config/wallpapers/login')
BG_MAIN = os.path.join(BG_DIR, 'blue-girl.jpg')     # gambar blue-girl (1920x1080)
BG_CANDIDATES = [BG_MAIN]
if os.path.isdir(BG_DIR):
    BG_CANDIDATES += sorted(os.path.join(BG_DIR, n) for n in os.listdir(BG_DIR)
                            if n.lower().endswith(('.jpg', '.jpeg', '.png')))
BG_CANDIDATES.append(os.path.join(GLASS_INSTALLED, 'login-bg.jpg'))


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
    # parameter = SAMA dengan scripts/apply-lightdm-greeter.sh (latar TAJAM,
    # kartu tetap kaca buram) supaya pratinjau = yang muncul saat login asli
    subprocess.run([sys.executable, helper, '--src', bg_src, '--outdir', tmp,
                    '--size', '%dx%d' % (geo.width, geo.height),
                    '--bg-blur', '0', '--card-blur', '10', '--bar-blur', '14',
                    '--dim', '0.94', '--vignette', '0.62'], check=True)

    # CSS produksi, tapi url()-nya diarahkan ke aset lokal
    css = open(CSS_SRC, encoding='utf-8').read()
    css = css.replace('/usr/share/backgrounds/anime-glass/', tmp + '/')
    css_path = os.path.join(tmp, 'gtk.css')
    open(css_path, 'w', encoding='utf-8').write(css)
    return css_path, os.path.join(tmp, 'login-bg.jpg')


# ------------------------------------------------------------------- preview
def load_css(css_path):
    prov = Gtk.CssProvider()
    try:
        prov.load_from_path(css_path)
    except GLib.Error as e:
        print('[preview] CSS error: %s' % e.message)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_USER)


def build_screen(bg_path):
    """Susun layar login mock: wallpaper + panel atas + kartu login (tengah).

    Dipakai dua-duanya: pratinjau fullscreen DAN potret mock untuk animasi.
    """
    overlay = Gtk.Overlay()
    overlay.add(Gtk.Image.new_from_file(bg_path))

    pv = ScreenParts()
    stack = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    stack.pack_start(pv.build_panel(), False, False, 0)
    holder = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    holder.set_halign(Gtk.Align.CENTER)
    holder.set_valign(Gtk.Align.CENTER)
    holder.set_vexpand(True)
    holder.pack_start(pv.build_card(), False, False, 0)
    stack.pack_start(holder, True, True, 0)
    overlay.add_overlay(stack)
    return overlay, pv


class ScreenParts:
    """Pembuat potongan layar login: panel atas + kartu (widget asli greeter)."""

    def build_panel(self):
        # margin/radius/tint pil diatur oleh CSS tema (sama dengan produksi),
        # bukan di kode — supaya pratinjau tidak "beda sendiri" dari greeter asli.
        panel = Gtk.EventBox()
        panel.set_name('panel_window')
        panel.set_halign(Gtk.Align.FILL)
        panel.set_valign(Gtk.Align.START)

        # Panel TANPA jam: persis seperti config/lightdm/lightdm-gtk-greeter.conf
        # (indicators=~host;~spacer;~session;~power). Jam digambar overlay animasi
        # besar di tengah layar, lalu menetap di atas kartu login.
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        menubar = Gtk.MenuBar()
        menubar.set_name('menubar')
        menubar.append(Gtk.MenuItem(label='suo@suo'))
        menubar.append(Gtk.MenuItem(label='Xfce Session'))
        box.pack_start(menubar, True, True, 0)

        for icon, wid in (('system-shutdown', 'shutdown_button'),
                          ('system-reboot', 'restart_button')):
            btn = Gtk.Button()
            btn.set_name(wid)
            btn.add(Gtk.Image.new_from_icon_name(icon, Gtk.IconSize.MENU))
            box.pack_start(btn, False, False, 0)
        panel.add(box)
        return panel

    def build_card(self):
        raw = load_greeter_xml()
        xml = '<interface>%s%s</interface>' % (extract_object(raw, 'user_liststore'),
                                               extract_object(raw, 'login_window'))
        b = Gtk.Builder()
        b.add_from_string(xml)
        card = b.get_object('login_window')

        model = b.get_object('user_liststore')
        model.append(['suo', 'Suo', 700])
        b.get_object('user_combobox').set_active(0)

        pw = b.get_object('password_entry')
        if pw:
            pw.set_placeholder_text('Masukkan password')
        for wid in ('username_entry', 'greeter_infobar'):
            w = b.get_object(wid)
            if w:
                w.set_no_show_all(True)
                w.hide()
        if os.path.isfile(AVATAR_SRC):
            b.get_object('user_image').set_from_pixbuf(
                GdkPixbuf.Pixbuf.new_from_file(AVATAR_SRC))
        return card


class LoginPreview(Gtk.Window):
    def __init__(self, seconds=20):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.tmp = tempfile.mkdtemp(prefix='anime-login-preview-')
        css_path, bg_path = prepare_assets(self.tmp)
        self.set_decorated(False)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_app_paintable(True)

        load_css(css_path)
        root, pv = build_screen(bg_path)
        self.pv = pv
        self.add(root)

        self.connect('key-press-event', self.on_key)
        self.connect('destroy', Gtk.main_quit)
        self.fullscreen()
        GLib.timeout_add_seconds(2, self.take_screenshot)
        GLib.timeout_add_seconds(seconds, self.close)

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


def mock_shot(out_path, bg=None, assets=None):
    """Render layar login ke PNG TANPA menampilkan apa pun.

    Hasilnya dipakai scripts/preview-login.sh --anim sebagai "potret layar
    login": dari situ greeter-textures.py mendeteksi kartu, panel, dan jam —
    pipeline yang sama persis dengan layar login sungguhan.

    --bg/--assets: pakai latar & tekstur kaca yang SUDAH dibuat (supaya latar
    potret benar-benar identik byte-per-byte dengan wallpaper yang diuji).
    """
    tmp = tempfile.mkdtemp(prefix='anime-login-mock-')
    if bg and assets:
        css = open(CSS_SRC, encoding='utf-8').read()
        css_path = os.path.join(tmp, 'gtk.css')
        open(css_path, 'w', encoding='utf-8').write(
            css.replace(GLASS_INSTALLED + '/', assets.rstrip('/') + '/'))
        bg_path = bg
    else:
        css_path, bg_path = prepare_assets(tmp)
    load_css(css_path)

    geo = Gdk.Display.get_default().get_monitor(0).get_geometry()
    root, _ = build_screen(bg_path)
    win = Gtk.OffscreenWindow()
    win.set_size_request(geo.width, geo.height)
    win.add(root)
    win.show_all()
    for _ in range(8):                       # biarkan GTK menata & menggambar
        while Gtk.events_pending():
            Gtk.main_iteration_do(False)
    pix = win.get_pixbuf()
    if pix is None:
        sys.exit('[preview] gagal merender potret mock')
    pix.savev(out_path, 'png', [], [])
    print('[preview] potret mock: %s (%dx%d)' % (out_path, pix.get_width(), pix.get_height()))
    return 0


def main():
    args = sys.argv[1:]
    if args and args[0] == '--mock-shot':
        ap = argparse.ArgumentParser(prog='preview-login.py --mock-shot')
        ap.add_argument('--mock-shot', metavar='PNG', required=True)
        ap.add_argument('--bg', default='', help='wallpaper yang sudah jadi')
        ap.add_argument('--assets', default='', help='dir berisi glass-panel/glass-bar')
        ns = ap.parse_args(args)
        return mock_shot(ns.mock_shot, ns.bg or None, ns.assets or None)
    seconds = int(args[0]) if args else 20
    print('[preview] menampilkan layar login selama %d detik (tekan ESC untuk menutup)' % seconds)
    LoginPreview(seconds).show_all()
    Gtk.main()
    return 0


if __name__ == '__main__':
    sys.exit(main())
