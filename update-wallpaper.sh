#!/usr/bin/env bash
#
# update-wallpaper.sh — ganti wallpaper anime & samakan warna seluruh UI
# ------------------------------------------------------------
# Cara pakai:
#   ./update-wallpaper.sh /path/ke/gambar-anime.jpg
#   ./update-wallpaper.sh /path/ke/gambar-anime.jpg 2560x1440   # resolusi kustom
#
# Yang dilakukan:
#   1. Salin gambar asli          -> ~/Pictures/Wallpapers/Anime/
#   2. Buat versi landscape (blur-fill) sesuai resolusi layar
#   3. Set sebagai wallpaper desktop Xfce (semua monitor)
#   4. Jalankan pywal (wal) bila terpasang, lalu samakan warna:
#        - Terminal (xfce4-terminal / kitty)
#        - Panel Xfce (warna latar mengikuti warna dominan wallpaper)
#        - Aplikasi GTK (gtk.css: bg, teks, seleksi, border)
#        - Teks ikon di desktop (font color)
#   5. Tampilkan ringkasan
# ------------------------------------------------------------
set -euo pipefail

IMG="${1:-}"
RES="${RESOLUTION:-${2:-1920x1080}}"

WALL_DIR="$HOME/Pictures/Wallpapers/Anime"
CFG_DIR="$HOME/.config"
PANEL_XML="$CFG_DIR/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
GTK_CSS="$CFG_DIR/gtk-3.0/gtk.css"
WAL_BIN="$(command -v wal || echo "$HOME/.local/bin/wal")"

msg()  { printf '\033[1;36m[wallpaper]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[peringatan]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[gagal]\033[0m %s\n' "$*" >&2; exit 1; }

[ -n "$IMG" ] || die "Berikan path gambar: ./update-wallpaper.sh /path/gambar.jpg"
[ -f "$IMG" ] || die "File tidak ditemukan: $IMG"
command -v convert >/dev/null 2>&1 || die "ImageMagick (convert) belum terpasang."
command -v xfconf-query >/dev/null 2>&1 || die "xfconf-query belum terpasang (Xfce)."

mkdir -p "$WALL_DIR" "$CFG_DIR/gtk-3.0"

# 1) Salin asli (lewati bila sudah berada di folder wallpaper)
if [ "$(readlink -f "$IMG")" != "$WALL_DIR/$(basename "$IMG")" ]; then
    cp -f "$IMG" "$WALL_DIR/$(basename "$IMG")"
    msg "Asli disalin -> $WALL_DIR/$(basename "$IMG")"
else
    msg "Gambar sudah ada di folder wallpaper."
fi

# 2) Versi landscape blur-fill
W="${RES%x*}"; H="${RES#*x}"
LANDSCAPE="$WALL_DIR/anime-${RES}.jpg"
convert "$IMG" \
    \( -clone 0 -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" -blur 0x35 -brightness-contrast -10 \) \
    \( -clone 0 -resize "x${H}" \) \
    -delete 0 -gravity center -composite -quality 92 "$LANDSCAPE"
msg "Landscape ${RES} -> $LANDSCAPE"

# 3) Set wallpaper desktop (semua monitor/workspace)
for key in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep 'last-image' || true); do
    xfconf-query -c xfce4-desktop -p "$key" -s "$LANDSCAPE" 2>/dev/null || true
done
msg "Wallpaper diterapkan ke desktop."

# 3b) Banner & avatar untuk widget conky anime-glass (gambar tetap dari asset,
#     bukan wallpaper — wallpaper desktop dipakai gambar landscape saja)
#     BANNER_IMG / AVATAR_IMG bisa di-override via env.
mkdir -p "$CFG_DIR/conky"
BANNER_IMG="${BANNER_IMG:-$WALL_DIR/影.jpeg}"
AVATAR_IMG="${AVATAR_IMG:-$WALL_DIR/968133251138558907.jpeg}"
if [ -f "$BANNER_IMG" ]; then
    convert "$BANNER_IMG" -resize 400x130^ -gravity North -extent 400x130 "$CFG_DIR/conky/anime-banner.png" 2>/dev/null \
        && msg "Banner conky -> $CFG_DIR/conky/anime-banner.png (${BANNER_IMG##*/})" \
        || warn "Gagal membuat banner conky."
else
    warn "Gambar banner tidak ditemukan: $BANNER_IMG"
fi
if [ -f "$AVATAR_IMG" ]; then
    convert "$AVATAR_IMG" -resize 56x56^ -gravity Center -extent 56x56 "$CFG_DIR/conky/anime-avatar.png" 2>/dev/null \
        && msg "Avatar conky -> $CFG_DIR/conky/anime-avatar.png (${AVATAR_IMG##*/})" \
        || warn "Gagal membuat avatar conky."
fi

# 4) Pywal: samakan warna seluruh UI dengan warna dominan wallpaper
if [ -x "$WAL_BIN" ]; then
    msg "Menjalankan pywal (wal) agar warna UI mengikuti wallpaper..."
    "$WAL_BIN" -i "$IMG" -q -n || warn "wal gagal dijalankan (lihat pesan di atas)."

    COLORS_FILE="$HOME/.cache/wal/colors"
    if [ -f "$COLORS_FILE" ]; then
        python3 - "$COLORS_FILE" "$CFG_DIR" "$PANEL_XML" "$GTK_CSS" <<'PY'
import os, re, sys, xml.etree.ElementTree as ET

colors_file, cfg_dir, panel_xml, gtk_css = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

with open(colors_file) as f:
    colors = [l.strip() for l in f if l.strip()][:16]
if len(colors) < 16:
    sys.exit("Warna wal tidak lengkap")

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

bg, fg, base = colors[0], colors[7], colors[8]
accent = colors[5]  # pink/magenta dari wallpaper -> aksen seleksi
sel_fg = colors[0]

# --- a) Terminal xfce4-terminal ---
term_rc = f"{cfg_dir}/xfce4/terminal/terminalrc"
if os.path.exists(term_rc):
    kv = {
        "ColorPalette": ";".join(colors),
        "ColorForeground": fg,
        "ColorBackground": bg,
        "ColorCursor": accent,
    }
    with open(term_rc) as f:
        lines = f.readlines()
    seen, out = set(), []
    for line in lines:
        m = re.match(r"^(ColorPalette|ColorForeground|ColorBackground|ColorCursor)=", line)
        if m:
            key = m.group(1)
            if key in seen:
                continue
            seen.add(key)
            out.append(f"{key}={kv[key]}\n")
        else:
            out.append(line)
    for key, val in kv.items():
        if key not in seen:
            out.append(f"{key}={val}\n")
    with open(term_rc, "w") as f:
        f.writelines(out)
    print("  xfce4-terminal : palette mengikuti wallpaper")

# --- b) GTK (gtk.css) ---
def strip_hash(h):
    return h.lstrip("#")
css = f"""/* Ditulis otomatis oleh update-wallpaper.sh (pywal) — jangan edit manual */
@define-color theme_bg_color #{strip_hash(bg)};
@define-color theme_fg_color #{strip_hash(fg)};
@define-color theme_base_color #{strip_hash(base)};
@define-color theme_text_color #{strip_hash(fg)};
@define-color theme_selected_bg_color #{strip_hash(accent)};
@define-color theme_selected_fg_color #{strip_hash(bg)};
@define-color theme_unfocused_bg_color #{strip_hash(bg)};
@define-color theme_unfocused_fg_color #{strip_hash(fg)};
@define-color theme_unfocused_base_color #{strip_hash(base)};
@define-color theme_unfocused_text_color #{strip_hash(fg)};
@define-color theme_unfocused_selected_bg_color #{strip_hash(accent)};
@define-color theme_unfocused_selected_fg_color #{strip_hash(bg)};
@define-color borders #{strip_hash(colors[8])};
@define-color unfocused_borders #{strip_hash(colors[0])};
@define-color insensitive_bg_color #{strip_hash(colors[8])};
@define-color insensitive_fg_color #{strip_hash(colors[8])};
@define-color theme_tooltip_bg_color #{strip_hash(bg)};
@define-color theme_tooltip_fg_color #{strip_hash(fg)};
@define-color content_view_bg #{strip_hash(base)};
@define-color warning_color #{strip_hash(colors[3])};
@define-color error_color #{strip_hash(colors[1])};
@define-color success_color #{strip_hash(colors[2])};
"""
# Bagian ini string biasa (bukan f-string) karena memakai kurung kurawal CSS
css_static = """
/* ===== override widget agar aplikasi (Thunar, dll) ikut warna wallpaper ===== */
window, .background, decoration {
    background-color: @theme_bg_color;
}
headerbar, .titlebar, toolbar, .toolbar {
    background-color: shade(@theme_bg_color, 1.12);
}
entry {
    background-color: @theme_base_color;
    border-color: shade(@theme_bg_color, 1.5);
}
entry:focus {
    border-color: @theme_selected_bg_color;
}
button {
    background-color: shade(@theme_bg_color, 1.15);
    border-color: shade(@theme_bg_color, 1.45);
}
button:hover {
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
    border-color: @theme_selected_bg_color;
}
button:active, button:checked, button:checked:hover {
    background-color: shade(@theme_selected_bg_color, 0.78);
    color: #ffffff;
    border-color: shade(@theme_selected_bg_color, 0.78);
}
menu, menubar, .menu {
    background-color: @theme_bg_color;
}
menuitem:hover, menuitem:selected {
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
}
:selected {
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
}
treeview.view, list, row {
    background-color: @theme_bg_color;
}
treeview.view:hover, row:hover, .view:hover {
    background-color: alpha(@theme_selected_bg_color, 0.28);
}
tooltip, .tooltip {
    background-color: @theme_tooltip_bg_color;
    color: @theme_tooltip_fg_color;
    border: 1px solid @theme_selected_bg_color;
    border-radius: 8px;
}
scrollbar slider {
    background-color: alpha(@theme_selected_bg_color, 0.75);
    border-radius: 6px;
}
/* panel xfce: hover tombol (tasklist, menu, systray, clock, actions) */
#xfce4-panel button, #xfce4-panel .toggle,
.xfce4-panel button, .xfce4-panel .toggle {
    border-radius: 9px;
}
#xfce4-panel button:hover, #xfce4-panel .toggle:hover,
.xfce4-panel button:hover, .xfce4-panel .toggle:hover {
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
    border-color: @theme_selected_bg_color;
}
/* notifikasi xfce4-notifyd */
#XfceNotifyWindow {
    background-color: @theme_bg_color;
    border: 1px solid @theme_selected_bg_color;
    border-radius: 12px;
}
#XfceNotifyWindow label#summary {
    color: @theme_fg_color;
    font-weight: bold;
}
#XfceNotifyWindow label#body {
    color: @theme_fg_color;
}
#XfceNotifyWindow button:hover {
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
}
"""
css = css + css_static
with open(gtk_css, "w") as f:
    f.write(css)
print("  gtk.css         : warna aplikasi GTK mengikuti wallpaper")
PY

# --- c) Panel Xfce: warna latar panel via xfconf-query (andal) ---
        if command -v xfconf-query >/dev/null 2>&1; then
            PANEL_BG="$(sed -n '1p' "$COLORS_FILE" 2>/dev/null || echo '#363815')"
            eval "$(python3 - "$PANEL_BG" <<'PY2'
import sys
h = sys.argv[1].lstrip('#')
r, g, b = (int(h[i:i+2], 16)/255 for i in (0, 2, 4))
print(f"PANEL_R={r:.6f} PANEL_G={g:.6f} PANEL_B={b:.6f}")
PY2
)"
            for PN in $(LC_NUMERIC=C xfconf-query -c xfce4-panel -p /panels -v 2>/dev/null | grep -Eo 'panel-[0-9]+' | sort -u); do
                LC_NUMERIC=C xfconf-query -c xfce4-panel -p "/panels/$PN/background-style" -s 1 2>/dev/null || true
                LC_NUMERIC=C xfconf-query -c xfce4-panel -p "/panels/$PN/background-rgba" \
                    -t double -s "$PANEL_R" -t double -s "$PANEL_G" -t double -s "$PANEL_B" -t double -s 0.72 2>/dev/null || true
            done
            echo "  panel xfce4     : latar panel mengikuti wallpaper (xfconf)"
            pkill -x xfce4-panel 2>/dev/null || true
            sleep 1
            nohup xfce4-panel >/dev/null 2>&1 &
            msg "Panel di-restart untuk memakai warna baru."
        fi

        # Teks ikon desktop mengikuti foreground wallpaper
        fg_hex="$(sed -n '8p' "$HOME/.cache/wal/colors" 2>/dev/null | tr -d '#' || echo cdD6F4)"
        # konversi hex -> rgb desimal
        r=$((16#${fg_hex:0:2})); g=$((16#${fg_hex:2:2})); b=$((16#${fg_hex:4:2}))
        xfconf-query -c xfce4-desktop -p /desktop-icons/font-color \
            -s "rgba($r,$g,$b,1)" --create -t string 2>/dev/null || true
        msg "Warna teks ikon desktop disamakan."

        # kitty: warna otomatis via include
        KITTY_CONF="$CFG_DIR/kitty/kitty.conf"
        if [ -f "$KITTY_CONF" ] && [ -f "$HOME/.cache/wal/colors-kitty.conf" ]; then
            if ! grep -q "colors-kitty.conf" "$KITTY_CONF"; then
                printf '\n# Warna otomatis dari pywal\ninclude ~/.cache/wal/colors-kitty.conf\n' >> "$KITTY_CONF"
            fi
            msg "Kitty: warna otomatis dari pywal aktif."
        fi

        # conky (anime-glass): restart agar warna kartu mengikuti wallpaper baru
        # (tanpa -d/-o: conky di-daemonize oleh config background=true sendiri)
        if [ -f "$CFG_DIR/conky/anime-glass.conf" ]; then
            pkill -f anime-glass.conf 2>/dev/null || true
            sleep 1
            nohup conky -c "$CFG_DIR/conky/anime-glass.conf" >/tmp/conky-anime-glass.log 2>&1 &
            sleep 2
            pgrep -f anime-glass.conf >/dev/null 2>&1 \
                && msg "Conky di-restart dengan warna baru." \
                || warn "Conky gagal restart — cek /tmp/conky-anime-glass.log"
        fi
    else
        warn "Hasil pywal tidak ditemukan di ~/.cache/wal/colors"
    fi
else
    warn "Pywal belum terpasang — warna UI memakai palette bawaan."
    warn "Install dulu: bash xfce-anime-setup.sh --pywal"
fi

echo
msg "Selesai. Wallpaper baru aktif: $LANDSCAPE"