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

# 1) Salin asli
cp -f "$IMG" "$WALL_DIR/$(basename "$IMG")"
msg "Asli disalin -> $WALL_DIR/$(basename "$IMG")"

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
with open(gtk_css, "w") as f:
    f.write(css)
print("  gtk.css         : warna aplikasi GTK mengikuti wallpaper")

# --- c) Panel Xfce: latar panel diambil dari warna dominan (color0) ---
if os.path.exists(panel_xml):
    try:
        tree = ET.parse(panel_xml)
        root = tree.getroot()
        panels = root.find(".//property[@name='panels']")
        changed = False
        if panels is not None:
            for panel in panels.findall("property"):
                name = panel.get("name", "")
                if not re.match(r"^panel-\d+$", name):
                    continue
                # pastikan background-style = 1 (solid)
                style = panel.find("property[@name='background-style']")
                if style is not None:
                    style.set("value", "1")
                else:
                    ET.SubElement(panel, "property", {"name": "background-style", "type": "uint", "value": "1"})
                # set background-color (RGBA double) dari color0 wallpaper
                bg_arr = panel.find("property[@name='background-color']")
                if bg_arr is None:
                    bg_arr = ET.SubElement(panel, "property", {"name": "background-color", "type": "array"})
                vals = bg_arr.findall("value")
                rgb = hex_to_rgb(bg)
                new_vals = [f"{v/255:.6f}" for v in rgb] + ["0.72"]
                for i, v in enumerate(vals):
                    v.set("value", new_vals[i])
                for extra in new_vals[len(vals):]:
                    ET.SubElement(bg_arr, "value", {"type": "double", "value": extra})
                changed = True
        if changed:
            ET.indent(tree, space="")
            tree.write(panel_xml, encoding="UTF-8", xml_declaration=True)
            print("  panel xfce4     : latar panel mengikuti wallpaper")
    except Exception as e:
        print(f"  [abaikan] panel tidak diubah: {e}")
PY
        # Restart panel agar warna baru tampil
        if [ -f "$PANEL_XML" ]; then
            xfce4-panel --restart 2>/dev/null || pkill -x xfce4-panel 2>/dev/null || true
            msg "Panel di-restart untuk memakai warna baru."
        fi

        # Teks ikon desktop mengikuti foreground wallpaper
        fg_hex="$(sed -n '8p' "$HOME/.cache/wal/colors" 2>/dev/null || echo cdD6F4)"
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
    else
        warn "Hasil pywal tidak ditemukan di ~/.cache/wal/colors"
    fi
else
    warn "Pywal belum terpasang — warna UI memakai palette bawaan."
    warn "Install dulu: bash xfce-anime-setup.sh --pywal"
fi

echo
msg "Selesai. Wallpaper baru aktif: $LANDSCAPE"