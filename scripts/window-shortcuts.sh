#!/usr/bin/env bash
#
# window-shortcuts.sh — kontrol jendela aktif via wmctrl (X11/Xfce).
# Dipakai oleh keyboard shortcut (xfce4-keyboard-shortcuts):
#
#   close   : Super+Q  — tutup jendela aktif
#   min     : Super+W  — minimize jendela aktif
#   max     : Super+A  — toggle maximize
#   left    : Super+Left  — geser 80px ke kiri
#   right   : Super+Right — geser 80px ke kanan
#   up      : Super+Up    — geser 80px ke atas
#   down    : Super+Down  — geser 80px ke bawah
#
# Bisa juga dipanggil manual: window-shortcuts.sh left|right|up|down|close|min|max
#
set -euo pipefail

STEP="${STEP:-80}"   # jarak geser (px)

cmd="${1:-}"
[ -n "$cmd" ] || { echo "pakai: $0 close|min|max|left|right|up|down"; exit 1; }
command -v wmctrl >/dev/null 2>&1 || { echo "[gagal] wmctrl belum terpasang."; exit 1; }

# id + geometry jendela AKTIF
AW=$(wmctrl -lG | awk -v me="$WINDOWID" '$3==0 {print; exit}' | head -1)
# ambil id jendela aktif via _NET_ACTIVE_WINDOW (paling akurat)
AWID=$(xprop -root _NET_ACTIVE_WINDOW | grep -oE '0x[0-9a-f]+')
[ -n "$AWID" ] || { echo "[gagal] tidak ada jendela aktif."; exit 1; }

geo() { xwininfo -id "$AWID" | awk '/Absolute upper-left X/ {x=$NF} /Absolute upper-left Y/ {y=$NF} /^ *Width:/ {w=$NF} /^ *Height:/ {h=$NF} END {print x, y, w, h}'; }

case "$cmd" in
    close)
        wmctrl -i -c "$AWID"
        ;;
    min)
        wmctrl -i -r "$AWID" -b add,hidden
        ;;
    max)
        wmctrl -i -r "$AWID" -b toggle,maximized_vert,maximized_horz
        ;;
    left|right|up|down)
        read -r x y w h <<< "$(geo)"
        case "$cmd" in
            left)  x=$((x - STEP)) ;;
            right) x=$((x + STEP)) ;;
            up)    y=$((y - STEP)); [ "$y" -lt 0 ] && y=0 ;;
            down)  y=$((y + STEP)) ;;
        esac
        wmctrl -i -r "$AWID" -e "0,$x,$y,$w,$h"
        ;;
    *)
        echo "aksi tidak dikenal: $cmd"; exit 1
        ;;
esac
