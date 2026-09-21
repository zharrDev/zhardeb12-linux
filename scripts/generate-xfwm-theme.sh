#!/usr/bin/env bash
#
# generate-xfwm-theme.sh — generate tema xfwm4 "Zhardeb-Glass-Rounded"
# dengan warna dari pywal (~/.cache/wal/colors).
#
# ---------------------------------------------------------------- PENTING --
# Tile xfwm4 di sini SENGAJA **TANPA alpha channel** (PNG24 / opacity penuh).
#
# Kenapa? Di setup ini (xfwm4 4.18 + picom sebagai satu-satunya compositor)
# xfwm4 TIDAK menggambar frame yang tile-nya punya alpha channel: jendela
# dirender tanpa titlebar sama sekali — terlihat seperti "header-nya ilang,
# cuma transparan" dan tombol window tidak pernah muncul. Sudah diuji:
#   - tema stok "Default" (tile opaque)      -> titlebar tampil normal
#   - Flat-Remix / tema ini (tile ARGB)      -> titlebar hilang
#   - mematikan picom, menyalakan compositor xfwm4, ganti font/tema: tetap hilang
# Jadi frame = OPAQUE, dan kesan "kaca" diambil alih oleh picom:
#   - rounded corners 14px  (corner-radius-rules class_g='xfwm4')
#   - blur + shadow halus di belakang jendela transparan (terminal/panel/conky)
# Terminal & panel tetap kaca karena transparansinya dari sisi klien.
#
# --------------------------------------------------------------- DESAIN ----
# Design ala By-LeyzS (Hyprland): titlebar gelap mengikuti wallpaper (pywal
# color0), garis aksen atas 2px + outline aksen 1px mengelilingi jendela,
# tombol window glyph modern (close=X, maximize=persegi, hide=garis).
#
# Output : ~/.themes/Zhardeb-Glass-Rounded/xfwm4/
# Pakai  : xfconf-query -c xfwm4 -p /general/theme -s Zhardeb-Glass-Rounded
#
set -euo pipefail
export LC_ALL=C

OUT="$HOME/.themes/Zhardeb-Glass-Rounded/xfwm4"
WAL_COLORS="$HOME/.cache/wal/colors"

# ---- warna dari pywal (fallback: navy Catppuccin + biru langit) ----
BG="0e1320"      # color0  (titlebar)
ACC="a55685"     # color5  (aksen / garis atas)
if [ -f "$WAL_COLORS" ]; then
    c0="$(sed -n '1p' "$WAL_COLORS" | tr -d '#')"
    c5="$(sed -n '6p' "$WAL_COLORS" | tr -d '#')"
    [ -n "$c0" ] && BG="$c0"
    [ -n "$c5" ] && ACC="$c5"
fi

TB_H=28     # tinggi titlebar
B_W=6       # tebal border sisi/bawah
T1_W=24     # lebar tile title-1 / title-5
TW=240      # lebar template frame
R=10        # lebar tile pojok (top-left/top-right)
TH=$(( TB_H + 64 + B_W + 4 ))

# ---- turunan warna (butuh ImageMagick) ----
# shade <#hex> <brightness%> : 80 = lebih gelap, 130 = lebih terang
shade() { convert xc:"#${1#\#}" -modulate "${2:-100},100,100" -alpha off -depth 8 \
            -format '%[hex:p{0,0}]' info: 2>/dev/null | tr -d '#'; }

BG_INACTIVE="$(shade "$BG" 74)"     # titlebar non-aktif (lebih gelap)
BG_HOVER="$(shade "$BG" 138)"       # latar tombol saat hover
BG_PRESS="$(shade "$BG" 158)"       # latar tombol saat ditekan
FG="eef1ff"                         # glyph tombol (aktif)
FG_DIM="9aa3c8"                     # glyph tombol (non-aktif)
FG_PRESS="ffffff"

mkdir -p "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[xfwm-theme] warna: titlebar=#$BG (non-aktif #$BG_INACTIVE) aksen=#$ACC"

# ---- render template frame (opaque, TANPA alpha) ----------------------
# Struktur: latar penuh BG + garis aksen 2px di tepi atas + outline aksen 1px
# di tepi kiri/kanan/bawah (menyambung dengan titlebar).
render_frame() { # render_frame <out> <bg>
    local out=$1 bg=$2
    convert -size "${TW}x${TH}" "xc:#$bg" \
        -fill "#$ACC" \
        -draw "rectangle 0,0 $((TW-1)),1" \
        -draw "rectangle 0,0 0,$((TH-1))" \
        -draw "rectangle $((TW-1)),0 $((TW-1)),$((TH-1))" \
        -draw "rectangle 0,$((TH-1)) $((TW-1)),$((TH-1))" \
        -alpha off -define png:color-type=2 -strip PNG24:"$out"
}

render_frame "$TMP/frame-active.png"   "$BG"
render_frame "$TMP/frame-inactive.png" "$BG_INACTIVE"

# ---- potong tile dari template ----------------------------------------
# PNG24 eksplisit: tile TIDAK boleh punya alpha channel (lihat catatan di atas).
slice() { # slice <frame> <state> <tile> <WxH+X+Y>
    convert "$1" -crop "$4" +repage -alpha off -strip \
        -define png:color-type=2 PNG24:"$OUT/$3-$2.png"
}

for st in active inactive; do
    F="$TMP/frame-$st.png"
    # titlebar: kiri (title-1), tengah (2,3,4 — tileable), kanan (title-5)
    slice "$F" "$st" title-1 "${T1_W}x${TB_H}+0+0"
    slice "$F" "$st" title-2 "28x${TB_H}+$T1_W+0"
    slice "$F" "$st" title-3 "28x${TB_H}+$T1_W+0"
    slice "$F" "$st" title-4 "28x${TB_H}+$T1_W+0"
    slice "$F" "$st" title-5 "${T1_W}x${TB_H}+$((TW-T1_W))+0"
    # ujung titlebar (pojok) — ikut membawa outline aksen
    slice "$F" "$st" top-left  "${R}x${TB_H}+0+0"
    slice "$F" "$st" top-right "${R}x${TB_H}+$((TW-R))+0"
    # sisi vertikal (tileable tinggi 64) — mulai di bawah titlebar
    slice "$F" "$st" left  "${B_W}x64+0+$TB_H"
    slice "$F" "$st" right "${B_W}x64+$((TW-B_W))+$TB_H"
    # bawah + pojok bawah (tileable lebar 64)
    slice "$F" "$st" bottom "64x${B_W}+$R+$((TH-B_W))"
    slice "$F" "$st" bottom-left  "${R}x${B_W}+0+$((TH-B_W))"
    slice "$F" "$st" bottom-right "${R}x${B_W}+$((TW-R))+$((TH-B_W))"
done

# ---- tombol window (opaque, glyph digambar sendiri) -------------------
# Tanpa alpha channel juga — supaya pasti dirender xfwm4.
BW=20       # kanvas tombol
STROKE=1.7

# glyph "-draw" untuk setiap tombol (array, biar aman dari escaping)
glyph_of() { # glyph_of <nama> -> isi array GLYPH
    case "$1" in
        close)    GLYPH=(-draw "line 6,6 14,14" -draw "line 14,6 6,14") ;;
        maximize) GLYPH=(-draw "rectangle 6,6 14,14") ;;
        hide)     GLYPH=(-draw "line 6,10 14,10") ;;
        shade)    GLYPH=(-draw "polyline 6,8 10,12 14,8") ;;
        stick)    GLYPH=(-draw "circle 10,10 10,6.5") ;;
        menu)     GLYPH=(-draw "rectangle 5,7 15,8" -draw "rectangle 5,10 15,11" -draw "rectangle 5,13 15,14") ;;
        *)        GLYPH=(-draw "line 6,10 14,10") ;;
    esac
}

gen_button() { # gen_button <nama> <state> <latar> <warna_glyph> [<warna_bulatan>]
    local name="$1" st="$2" bg="$3" fg="$4" disc="${5:-}"
    local args=(-size "${BW}x${BW}" "xc:#$bg")
    if [ -n "$disc" ]; then
        args+=(-fill "#$disc" -stroke none -draw "circle 10,10 10,4")
    fi
    glyph_of "$name"
    args+=(-stroke "#$fg" -strokewidth "$STROKE" -fill none "${GLYPH[@]}")
    convert "${args[@]}" -alpha off -strip -define png:color-type=2 \
        PNG24:"$OUT/$name-$st.png"
}

for b in close maximize hide shade stick menu; do
    gen_button "$b" active   "$BG"          "$FG"                  # glyph terang
    gen_button "$b" inactive "$BG_INACTIVE" "$FG_DIM"              # glyph redup
    gen_button "$b" prelight "$BG"          "$ACC"    "$BG_HOVER"   # hover: aksen
    gen_button "$b" pressed  "$BG"          "$FG_PRESS" "$BG_PRESS" # ditekan
    # close tetap merah lembut supaya gampang dikenali
    if [ "$b" = close ]; then
        gen_button "$b" active   "$BG"          "f38ba8"
        gen_button "$b" inactive "$BG_INACTIVE" "c97b93"
        gen_button "$b" prelight "$BG"          "ff9db8" "$BG_HOVER"
        gen_button "$b" pressed  "$BG"          "ffffff" "$BG_PRESS"
    fi
done

echo "[xfwm-theme] tombol digambar ulang (glyph sendiri, opaque)."

# ---- themerc ----------------------------------------------------------
cat > "$OUT/themerc" <<EOF
# Zhardeb-Glass-Rounded — frame OPAQUE + aksen pywal, rounded & blur dari picom
# (di-generate ulang oleh scripts/generate-xfwm-theme.sh, jangan edit manual)
button_offset=6
button_spacing=4
show_app_icon=false
full_width_title=true
title_horizontal_offset=8
title_vertical_offset_active=1
title_vertical_offset_inactive=1
active_text_color=#ffffff
active_text_shadow_color=#000000
inactive_text_color=#c9cdea
inactive_text_shadow_color=#000000
title_shadow_active=false
title_shadow_inactive=false
shadow_delta_height=0
shadow_delta_width=0
shadow_delta_x=0
shadow_delta_y=0
shadow_opacity=0
EOF

echo "[xfwm-theme] selesai -> $OUT ($(ls "$OUT" | wc -l) file)"
echo "[xfwm-theme] aktifkan: xfconf-query -c xfwm4 -p /general/theme -s Zhardeb-Glass-Rounded"
