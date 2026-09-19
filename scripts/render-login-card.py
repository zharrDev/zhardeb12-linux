#!/usr/bin/env python3
"""render-login-card.py — render kartu login (UI greeter asli + CSS tema) ke PNG.

Dipakai oleh preview/animasi untuk mendapatkan gambar kartu login yang PERSIS
seperti yang digambar lightdm-gtk-greeter: widget diambil dari UI XML asli
binary greeter, CSS dari tema, avatar dari config/lightdm/avatar/.

  python3 render-login-card.py --out /tmp/card.png [--user Suo] [--assets DIR]

--assets: direktori berisi glass-panel.jpg & glass-bar.jpg (kalau kosong, pakai
/usr/share/backgrounds/anime-glass/ apa adanya).
"""
import argparse
import os
import subprocess
import sys

import gi

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib  # noqa: E402

SRC_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GREETER_BIN = '/usr/sbin/lightdm-gtk-greeter'
CSS_SRC = os.path.join(SRC_DIR, 'config/lightdm/themes/anime-glass-greeter/gtk-3.0/gtk.css')
AVATAR = os.path.join(SRC_DIR, 'config/lightdm/avatar/anime-avatar.png')
INSTALLED = '/usr/share/backgrounds/anime-glass/'


def extract_object(xml, obj_id):
    start = xml.find('id="%s"' % obj_id)
    if start < 0:
        raise SystemExit('[card] objek %s tidak ada di UI greeter' % obj_id)
    start = xml.rfind('<object', 0, start)
    depth, i = 0, start
    while True:
        nxt_open, nxt_close = xml.find('<object', i), xml.find('</object>', i)
        if nxt_close < 0:
            raise SystemExit('[card] XML greeter tidak seimbang: %s' % obj_id)
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


def build_css(assets_dir):
    css = open(CSS_SRC, encoding='utf-8').read()
    if assets_dir:
        css = css.replace(INSTALLED, assets_dir.rstrip('/') + '/')
    return css


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--user', default='Suo')
    ap.add_argument('--username', default='suo')
    ap.add_argument('--assets', default='')
    ap.add_argument('--placeholder', default='Masukkan password')
    a = ap.parse_args()

    if not os.path.exists(GREETER_BIN):
        sys.exit('[card] %s tidak ada' % GREETER_BIN)
    raw = open(GREETER_BIN, encoding='utf-8', errors='ignore').read()
    s = raw.find('<?xml version="1.0" encoding="UTF-8"?><interface>')
    e = raw.find('</interface>', s)
    raw = raw[s:e + len('</interface>')]
    xml = '<interface>%s%s</interface>' % (extract_object(raw, 'user_liststore'),
                                           extract_object(raw, 'login_window'))

    prov = Gtk.CssProvider()
    try:
        prov.load_from_data(build_css(a.assets).encode())
    except GLib.Error as e:
        print('[card] CSS error: %s' % e.message, file=sys.stderr)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_USER)

    b = Gtk.Builder()
    b.add_from_string(xml)
    card = b.get_object('login_window')
    model = b.get_object('user_liststore')
    model.append([a.username, a.user, 700])
    b.get_object('user_combobox').set_active(0)
    pw = b.get_object('password_entry')
    if pw:
        pw.set_placeholder_text(a.placeholder)
    for wid in ('username_entry', 'greeter_infobar'):     # tak tampil di kondisi normal
        w = b.get_object(wid)
        if w:
            w.set_no_show_all(True)
            w.hide()
    if os.path.isfile(AVATAR):
        b.get_object('user_image').set_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file(AVATAR))

    win = Gtk.OffscreenWindow()
    win.add(card)
    win.show_all()
    while Gtk.events_pending():
        Gtk.main_iteration_do(False)
    win.get_pixbuf().savev(a.out, 'png', [], [])
    print('[card] %s (%dx%d)' % (a.out, card.get_allocated_width(), card.get_allocated_height()))
    return 0


if __name__ == '__main__':
    sys.exit(main())
