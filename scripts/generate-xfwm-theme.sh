#!/usr/bin/env bash
#
# generate-xfwm-theme.sh — generate tema xfwm4 "Zhardeb-Glass-Rounded"
# dengan warna dari pywal (~/.cache/wal/colors).
#
# ------------------------------------------------------------ DESAIN --------
# FRAMELESS: **tanpa titlebar/header** sama sekali. Kontrol jendela lewat
# keyboard (Super+Q close / W minimize / A maximize / panah geser) atau
# Alt+drag untuk memindah. Yang tersisa cuma **outline aksen tipis (2px)**
# mengelilingi jendela — jadi isi jendela benar-benar mentok ke atas,
# tidak ada strip kosong/transparan seperti tema ber-titlebar.
#
# Sudut membulat + blur + shadow ditangani **picom** (corner-radius 14px,
# lihat config/picom/picom.conf), bukan oleh gambar tema.
#
# Ubah ketebalan kalau perlu:
#   TB_H=0 B_W=0 ... (TB_H = tinggi header; >12 akan memunculkan titlebar lagi)
#   TB_H=28 B_W=6 bash generate-xfwm-theme.sh     # kembali ke gaya ber-titlebar
#
# ------------------------------------------------------------- PENTING ------
# Tile di sini SENGAJA **TANPA alpha channel** (PNG24 / opaque penuh).
# xfwm4 4.18 di setup ini TIDAK menggambar frame yang tile-nya ber-alpha:
# jendela jadi tampak tanpa dekorasi sama sekali (sudah diuji: tema stok
# "Default" yang tile-nya opaque tampil normal, tema ber-alpha tidak).
#
# Output : ~/.themes/Zhardeb-Glass-Rounded/xfwm4/
# Pakai  : xfconf-query -c xfwm4 -p /general/theme -s Zhardeb-Glass-Rounded
#
set -euo pipefail
export LC_ALL=C

OUT="$HOME/.themes/Zhardeb-Glass-Rounded/xfwm4"
WAL_COLORS="$HOME/.cache/wal/colors"

# ---- warna dari pywal (fallback: navy Catppuccin + mauve) ----
BG="0e1320"      # color0  (gelap, untuk latar tombol bila titlebar dihidupkan)
ACC="a55685"     # color5  (warna outline/aksen)
if [ -f "$WAL_COLORS" ]; then
    c0="$(sed -n '1p' "$WAL_COLORS" | tr -d '#')"
    c5="$(sed -n '6p' "$WAL_COLORS" | tr -d '#')"
    [ -n "$c0" ] && BG="$c0"
    [ -n "$c5" ] && ACC="$c5"
fi

# ---- ukuran frame (bisa ditimpa lewat env) ----
TB_H="${TB_H:-2}"      # tinggi header/titlebar. 2 = frameless (tanpa header)
B_W="${B_W:-2}"        # tebal outline sisi/bawah
T1_W="${T1_W:-24}"     # lebar tile title-1 / title-5
TW="${TW:-240}"        # lebar template frame
R="${R:-10}"           # lebar tile pojok (top-left/top-right)
[ "$TB_H" -lt 1 ] && TB_H=1      # tinggi tile minimal 1px
[ "$B_W"  -lt 1 ] && B_W=1
WITH_TITLEBAR=0
[ "$TB_H" -ge 12 ] && WITH_TITLEBAR=1
TH=$(( TB_H + 64 + B_W + 4 ))

# ---- turunan warna (butuh ImageMagick) ----
shade() { convert xc:"#${1#\#}" -modulate "${2:-100},100,100" -alpha off -depth 8 \
            -format '%[hex:p{0,0}]' info: 2>/dev/null | tr -d '#'; }

mkdir -p "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[xfwm-theme] outline: aksen #$ACC tebal ${B_W}px (header: ${TB_H}px$([ "$WITH_TITLEBAR" = 0 ] && echo ' = frameless'))"

# ---- render template frame (opaque, TANPA alpha) ----------------------
# Kalau titlebar aktif: latar gelap BG + garis aksen di tepi atas.
# Kalau frameless     : seluruh frame = warna aksen (outline tipis).
render_frame() { # render_frame <out> <warna_dasar>
    if [ "$WITH_TITLEBAR" -eq 1 ]; then
        convert -size "${TW}x${TH}" "xc:#$1" \
            -fill "#$ACC" \
            -draw "rectangle 0,0 $((TW-1)),1" \
            -draw "rectangle 0,0 0,$((TH-1))" \
            -draw "rectangle $((TW-1)),0 $((TW-1)),$((TH-1))" \
            -draw "rectangle 0,$((TH-1)) $((TW-1)),$((TH-1))" \
            -alpha off -strip -define png:color-type=2 PNG24:"$2"
    else
        convert -size "${TW}x${TH}" "xc:#$1" \
            -alpha off -strip -define png:color-type=2 PNG24:"$2"
    fi
}

if [ "$WITH_TITLEBAR" -eq 1 ]; then
    render_frame "$BG"                       "$TMP/frame-active.png"
    render_frame "$(shade "$BG" 74)"         "$TMP/frame-inactive.png"
else
    render_frame "$ACC"                      "$TMP/frame-active.png"
    render_frame "$(shade "$ACC" 72)"        "$TMP/frame-inactive.png"
fi

# ---- potong tile dari template ----------------------------------------
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
    # ujung titlebar (pojok)
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

# ---- tombol window (hanya kalau titlebar dihidupkan) ------------------
if [ "$WITH_TITLEBAR" -eq 1 ]; then
    BW=20
    STROKE=1.7
    FG="eef1ff"; FG_DIM="9aa3c8"; FG_PRESS="ffffff"
    BG_INACTIVE="$(shade "$BG" 74)"
    BG_HOVER="$(shade "$BG" 138)"
    BG_PRESS="$(shade "$BG" 158)"

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
        gen_button "$b" active   "$BG"          "$FG"
        gen_button "$b" inactive "$BG_INACTIVE" "$FG_DIM"
        gen_button "$b" prelight "$BG"          "$ACC"      "$BG_HOVER"
        gen_button "$b" pressed  "$BG"          "$FG_PRESS" "$BG_PRESS"
        if [ "$b" = close ]; then
            gen_button "$b" active   "$BG"          "f38ba8"
            gen_button "$b" inactive "$BG_INACTIVE" "c97b93"
            gen_button "$b" prelight "$BG"          "ff9db8" "$BG_HOVER"
            gen_button "$b" pressed  "$BG"          "ffffff" "$BG_PRESS"
        fi
    done
    echo "[xfwm-theme] tombol window digambar (titlebar + tombol aktif)."
else
    # frameless: buang sisa tile tombol lama supaya tidak ada artefak
    rm -f "$OUT"/{close,maximize,hide,shade,stick,menu}-*.png
fi

# ---- themerc ----------------------------------------------------------
cat > "$OUT/themerc" <<EOF
# Zhardeb-Glass-Rounded — frame OPAQUE + outline aksen, rounded & blur dari picom
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
