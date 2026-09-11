#!/usr/bin/env bash
#
# generate-xfwm-theme.sh — generate tema xfwm4 "Zhardeb-Glass-Rounded"
# dengan warna kaca + aksen dari pywal (~/.cache/wal/colors).
#
# Design ala By-LeyzS (Hyprland): rounding = 10, kaca semi-transparan,
# outline aksen mengelilingi jendela, tombol warna Flat-Remix.
#
# Metode: render SATU template frame utuh (sudut bulat + outline aksen +
# titlebar kaca 72% / border 55%) lalu di-potong jadi tile xfwm4 —
# sehingga semua tile konsisten dan sudut menyambung mulus.
#
# Output : ~/.themes/Zhardeb-Glass-Rounded/xfwm4/
# Pakai  : xfconf-query -c xfwm4 -p /general/theme -s Zhardeb-Glass-Rounded
#
set -euo pipefail

OUT="$HOME/.themes/Zhardeb-Glass-Rounded/xfwm4"
WAL_COLORS="$HOME/.cache/wal/colors"
FR="$HOME/.themes/Flat-Remix-Dark-XFWM/xfwm4"   # sumber glyph tombol

# ---- warna dari pywal (fallback: navy Catppuccin + biru langit) ----
BG="363815"      # color0  (kaca)
ACC="5FA2CE"     # color5  (outline aksen, biru langit)
if [ -f "$WAL_COLORS" ]; then
    c0="$(sed -n '1p' "$WAL_COLORS" | tr -d '#')"
    c5="$(sed -n '6p' "$WAL_COLORS" | tr -d '#')"
    [ -n "$c0" ] && BG="$c0"
    [ -n "$c5" ] && ACC="$c5"
fi

R=10        # rounding ala By-LeyzS (px)
TB_H=28     # tinggi titlebar
B_W=6       # tebal border sisi/bawah (kaca tipis)
T1_W=24     # lebar tile title-1 / title-5
TW=240      # lebar template frame
# tinggi template: titlebar + tile sisi vertikal (64) + bawah (B_W) + buffer
TH=$(( TB_H + 64 + B_W + 4 ))

# alpha (%): titlebar aktif/non-aktif, border, outline aksen
A_TITLE_A=72; A_TITLE_I=45; A_BORDER_A=55; A_BORDER_I=35; A_STROKE=60

mkdir -p "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

hex2rgb() { local h="${1#\#}"; printf '%d,%d,%d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"; }
BG_RGB=$(hex2rgb "$BG"); ACC_RGB=$(hex2rgb "$ACC")

# ---- render template frame (satu kali per state) ----------------------
# frame = rounded-rect kaca: border alpha a_b + titlebar alpha a_t
# + outline aksen 1.5px. Metode: -fill rgba langsung (tanpa CopyOpacity,
# yang terbukti merusak alpha channel di PNG palet).
render_frame() { # render_frame <out> <a_title> <a_border>
    local out=$1 a_t=$2 a_b=$3
    # 1) layer border: rounded-rect penuh alpha a_b
    convert -size "${TW}x${TH}" xc:none \
        -fill "rgba($BG_RGB,0.$(printf '%02d' $a_b))" \
        -draw "roundrectangle 0,0 $((TW-1)),$((TH-1)) $R,$R" "$TMP/f1.png"
    # 2) mask: putih (alpha penuh) hanya di area DI BAWAH titlebar,
    #    area titlebar dibiarkan transparan → DstIn menghapus border
    #    di area titlebar (supaya alpha titlebar tidak menumpuk border)
    convert -size "${TW}x${TH}" xc:none \
        -fill white -draw "rectangle 0,$TB_H $((TW-1)),$((TH-1))" "$TMP/mask_keep.png"
    convert "$TMP/f1.png" "$TMP/mask_keep.png" -compose DstIn -composite "$TMP/f1b.png"
    # 3) layer titlebar: rounded-rect alpha a_t, di-crop sebatas tinggi
    #    titlebar (TB_H) — pojok ikut kurva radius (tetap transparan)
    convert -size "${TW}x${TH}" xc:none \
        -fill "rgba($BG_RGB,0.$(printf '%02d' $a_t))" \
        -draw "roundrectangle 0,0 $((TW-1)),$((TH-1)) $R,$R" \
        -crop "${TW}x${TB_H}+0+0" +repage "$TMP/tb.png"
    # 4) gabung — titlebar & border tidak overlap: alpha tidak menumpuk
    convert "$TMP/f1b.png" "$TMP/tb.png" -gravity North -composite "$TMP/f3.png"
    # 5) outline aksen 1.5px mengikuti rounded-rect (PNG32 = RGBA 8-bit)
    convert "$TMP/f3.png" \
        -stroke "rgba($ACC_RGB,0.$(printf '%02d' $A_STROKE))" -strokewidth 1.5 -fill none \
        -draw "roundrectangle 0.75,0.75 $((TW-2)),$((TH-2)) $R,$R" \
        -define png:color-type=6 -define png:bit-depth=8 -define png:format=png32 \
        -type TrueColorAlpha "$out"
}

echo "[xfwm-theme] warna: kaca=#$BG aksen=#$ACC (dari pywal)"
render_frame "$TMP/frame-active.png"   "$A_TITLE_A" "$A_BORDER_A"
render_frame "$TMP/frame-inactive.png" "$A_TITLE_I" "$A_BORDER_I"

# ---- potong tile dari template ----------------------------------------
# urutan xfwm4: pojok kiri-atas bulat, kanan-atas bulat, bawah kiri/kanan bulat
# PNG32 eksplisit (8-bit RGBA): tanpa ini ImageMagick menghasilkan PNG
# 4-bit colormap yang gagal dirender xfwm4 (titlebar tampil hitam).
slice() { # slice <frame> <st> <tile> <WxH+X+Y>
    convert "$1" -crop "$3" +repage -define png:color-type=6 -define png:bit-depth=8 \
        -define png:format=png32 -type TrueColorAlpha "$OUT/$2.png"
}

for st in active inactive; do
    F="$TMP/frame-$st.png"
    # titlebar: kiri (title-1), tengah (2,3,4 — tileable 28px), kanan (title-5)
    slice "$F" "title-1-$st" "${T1_W}x${TB_H}+0+0"
    slice "$F" "title-2-$st" "28x${TB_H}+$T1_W+0"
    slice "$F" "title-3-$st" "28x${TB_H}+$T1_W+0"
    slice "$F" "title-4-$st" "28x${TB_H}+$T1_W+0"
    slice "$F" "title-5-$st" "${T1_W}x${TB_H}+$((TW-T1_W))+0"
    # pojok atas (kaca + lengkungan outline, radius R)
    slice "$F" "top-left-$st"  "${R}x${TB_H}+0+0"
    slice "$F" "top-right-$st" "${R}x${TB_H}+$((TW-R))+0"
    # sisi vertikal (tileable tinggi 64) — mulai di bawah titlebar
    slice "$F" "left-$st"  "${B_W}x64+0+$TB_H"
    slice "$F" "right-$st" "${B_W}x64+$((TW-B_W))+$TB_H"
    # bawah + pojok bawah (tileable lebar 64)
    slice "$F" "bottom-$st" "64x${B_W}+$R+$((TH-B_W))"
    slice "$F" "bottom-left-$st"  "${R}x${B_W}+0+$((TH-B_W))"
    slice "$F" "bottom-right-$st" "${R}x${B_W}+$((TW-R))+$((TH-B_W))"
done

# ---- tombol: salin glyph Flat-Remix (close merah / min oranye / max biru)
if [ -d "$FR" ]; then
    for b in close hide maximize menu shade stick; do
        for st in active inactive prelight pressed; do
            [ -f "$FR/$b-$st.png" ] && cp -f "$FR/$b-$st.png" "$OUT/"
        done
    done
    echo "[xfwm-theme] tombol disalin dari Flat-Remix (glyph asli)."
else
    echo "[xfwm-theme] PERINGATAN: Flat-Remix tidak ada — tombol polos."
    for b in close hide maximize; do
        for st in active inactive prelight pressed; do
            convert -size 20x20 xc:none -fill "rgba($ACC_RGB,0.25)" \
                -draw "circle 10,10 8,10" "$OUT/$b-$st.png"
        done
    done
    for st in active inactive pressed; do
        convert -size 20x20 xc:none "$OUT/menu-$st.png"
    done
fi

# ---- themerc ----------------------------------------------------------
cat > "$OUT/themerc" <<EOF
# Zhardeb-Glass-Rounded — kaca ala By-LeyzS, warna dari pywal
# (di-generate ulang oleh scripts/generate-xfwm-theme.sh, jangan edit manual)
button_offset=6
button_spacing=2
show_app_icon=true
full_width_title=true
title_horizontal_offset=6
title_vertical_offset_active=1
title_vertical_offset_inactive=1
active_text_color=#ffffff
active_text_shadow_color=#000000
inactive_text_color=#c4c6c6
inactive_text_shadow_color=#000000
title_shadow_active=true
title_shadow_inactive=false
shadow_delta_height=0
shadow_delta_width=0
shadow_delta_x=0
shadow_delta_y=0
shadow_opacity=0
EOF

echo "[xfwm-theme] selesai -> $OUT ($(ls "$OUT" | wc -l) file)"
echo "[xfwm-theme] aktifkan: xfconf-query -c xfwm4 -p /general/theme -s Zhardeb-Glass-Rounded"
