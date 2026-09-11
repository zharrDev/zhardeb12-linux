#!/usr/bin/env bash
#
# window-shortcuts.sh — kontrol jendela aktif via wmctrl (X11/Xfce).
#
#   close   : Super+Q  — tutup jendela aktif
#   min     : Super+W  — minimize jendela aktif
#   max     : Super+A  — toggle maximize
#   left    : Super+Left    — geser 80px ke kiri
#   right   : Super+Right   — geser 80px ke kanan
#   up      : Super+Up      — geser 80px ke atas
#   down    : Super+Down    — geser 80px ke bawah
#
# Mentok tepi layar (kiri/kanan) → jendela dipindah ke workspace sebelah
# dan viewport ikut berpindah (ala movefocus/movetoworkspace Hyprland).
#
# Semua geometry pakai CLIENT geometry (wmctrl -lG) — satu sumber, tanpa
# konversi frame/client (itulah sumber drift vertikal sebelumnya).
#
set -euo pipefail

STEP="${STEP:-80}"

cmd="${1:-}"
[ -n "$cmd" ] || { echo "pakai: $0 close|min|max|left|right|up|down"; exit 1; }
command -v wmctrl >/dev/null 2>&1 || { echo "[gagal] wmctrl belum terpasang."; exit 1; }

# id jendela aktif — bisa di-override via env WIN (untuk test)
AWID="${WIN:-$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '/_NET_ACTIVE_WINDOW/ {for(i=1;i<=NF;i++){gsub(",","",$i); if($i ~ /^0x[0-9a-f]+$/ && $i != "0x0"){print $i; exit}}}')}"
[[ -n "$AWID" ]] || { echo "[gagal] tidak ada jendela aktif."; exit 1; }

case "$cmd" in
    close)  wmctrl -i -c "$AWID" ;;
    min)    wmctrl -i -r "$AWID" -b add,hidden ;;
    max)    wmctrl -i -r "$AWID" -b toggle,maximized_vert,maximized_horz ;;
    left|right|up|down)
        # normalisasi id: xprop "0x268e288" vs wmctrl "0x0268e288" → samakan
        NORM=$(printf '0x%08x' "$((AWID))" 2>/dev/null) || NORM="$AWID"
        # client geometry dari wmctrl -lG — kolom: id desk x y w h host title
        g=$(wmctrl -lG 2>/dev/null | awk -v id="$NORM" 'tolower($1)==tolower(id){print; exit}')
        [[ -n "$g" ]] || g=$(wmctrl -lG 2>/dev/null | awk -v id="$AWID" 'tolower($1) ~ tolower(id)"$"{print; exit}')
        [[ -n "$g" ]] || { echo "[gagal] geometry tidak terbaca."; exit 1; }
        read -r _ _ x y w h _ <<< "$g"

        # dimensi layar — awk TANPA exit (mencegah SIGPIPE xdpyinfo dgn pipefail)
        dims=$(xdpyinfo 2>/dev/null | awk '/dimensions:/ {gsub(/[x ]+/," ",$2); print $2}')
        dims=$(echo "$dims" | head -1)
        SCREEN_W=${dims%% *}; SCREEN_H=${dims##* }
        : "${SCREEN_W:=1920}" "${SCREEN_H:=1080}"

        # Kalibrasi xfwm4 (terukur): wmctrl -e men-set FRAME NW, xfwm4
        # kemudian menempatkan CLIENT di (set + left+right, set + top+top).
        # Kompensasi supaya hasil client = target yang dihitung.
        ext=$(xprop -id "$AWID" _NET_FRAME_EXTENTS 2>/dev/null | awk -F'=' '{gsub(/[^0-9,]/,"",$2); split($2,a,","); print a[1]+0, a[2]+0, a[3]+0, a[4]+0}')
        read -r EXL EXR EXT EXB <<< "$ext"; : "${EXL:=0}" "${EXR:=0}" "${EXT:=0}" "${EXB:=0}"
        CAL_X=$((EXL + EXR))
        CAL_Y=$((EXT + EXT))

        case "$cmd" in
            left)  x=$((x - STEP)) ;;
            right) x=$((x + STEP)) ;;
            up)    y=$((y - STEP)); [ "$y" -lt 0 ] && y=0 ;;
            down)  y=$((y + STEP)) ;;
        esac

        # workspace aktif & jumlah workspace (baris bertanda '*')
        ws_line=$(wmctrl -d 2>/dev/null | awk '$2=="*"{print NR-1; exit}' || true)
        : "${ws_line:=0}"
        NWS=$(wmctrl -d 2>/dev/null | wc -l || true)
        : "${NWS:=1}"

        # mentok tepi → pindah workspace + jendela ikut
        if [ "$cmd" = right ] && [ $((x + w)) -gt "$SCREEN_W" ]; then
            NEXT=$(( (ws_line + 1) % NWS ))
            if [ "$NEXT" != "$ws_line" ]; then
                wmctrl -i -r "$AWID" -t "$NEXT" 2>/dev/null || true
                wmctrl -s "$NEXT" 2>/dev/null || true
                x=0
            else
                x=$((SCREEN_W - w))
            fi
        elif [ "$cmd" = left ] && [ "$x" -lt 0 ]; then
            PREV=$(( (ws_line - 1 + NWS) % NWS ))
            if [ "$PREV" != "$ws_line" ]; then
                wmctrl -i -r "$AWID" -t "$PREV" 2>/dev/null || true
                wmctrl -s "$PREV" 2>/dev/null || true
                x=$((SCREEN_W - w))
            else
                x=0
            fi
        fi

        # set posisi via EWMH — dengan kompensasi kalibrasi xfwm4
        wmctrl -i -r "$AWID" -e "0,$((x - CAL_X)),$((y - CAL_Y)),$w,$h" 2>/dev/null || true
        ;;
    *) echo "aksi tidak dikenal: $cmd"; exit 1 ;;
esac
