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
#   open    : Super+Return   — buka terminal (kitty 1280x720+50+50)
#
# "NEMBUS" TEPI → WORKSPACE (ala movetoworkspace di Hyprland):
#   • mentok kiri/kanan  → jendela pindah ke workspace kiri/kanan + viewport ikut
#   • mentok atas        → jendela pindah ke workspace ATAS  (ditempel di bawah)
#   • mentok bawah       → jendela pindah ke workspace BAWAH (ditempel di atas)
#   Grid workspace dibaca dari _NET_DESKTOP_LAYOUT (di mesin ini 2 kolom x 2 baris),
#   jadi "bawah" = workspace + jumlah kolom, bukan sekadar +1.
#   Kalau workspace tidak bisa dipindah (mis. cuma 1 workspace), jendela cuma
#   ditempel rapi ke tepi area kerja — tidak ada yang keluar layar.
#
# Semua geometry pakai CLIENT geometry (wmctrl -lG) — satu sumber, tanpa
# konversi frame/client (itulah sumber drift vertikal sebelumnya).
#
# Uji tanpa menggeser apa pun:  DRY=1 WIN=0x<id> bash window-shortcuts.sh down
#
set -euo pipefail

STEP="${STEP:-80}"
DRY="${DRY:-0}"                 # 1 = hitung & cetak rencana, jangan pindahkan apa pun

cmd="${1:-}"
[ -n "$cmd" ] || { echo "pakai: $0 close|min|max|left|right|up|down|open"; exit 1; }
command -v wmctrl >/dev/null 2>&1 || { echo "[gagal] wmctrl belum terpasang."; exit 1; }

# id jendela aktif — bisa di-override via env WIN (untuk test)
AWID="${WIN:-$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '/_NET_ACTIVE_WINDOW/ {for(i=1;i<=NF;i++){gsub(",","",$i); if($i ~ /^0x[0-9a-f]+$/ && $i != "0x0"){print $i; exit}}}')}"
[[ -n "$AWID" ]] || { echo "[gagal] tidak ada jendela aktif."; exit 1; }

case "$cmd" in
    open)
        # buka terminal dengan ukuran & posisi tetap (kitty default)
        if command -v kitty >/dev/null 2>&1; then
            nohup kitty --geometry 1280x720+50+50 \
                ${TERMINAL_CMD:--e "$SHELL"} >/dev/null 2>&1 &
        else
            nohup xfce4-terminal --geometry=140x36+50+50 >/dev/null 2>&1 &
        fi
        ;;
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

        # ----- area kerja (sudah memperhitungkan panel) -----
        WA=$(xprop -root _NET_WORKAREA 2>/dev/null | awk -F'=' '{gsub(/[^0-9,]/,"",$2); print $2}' || true)
        IFS=, read -r WAX WAY WAW WAH _ <<< "${WA:-0,0,$SCREEN_W,$SCREEN_H}"
        : "${WAX:=0}" "${WAY:=0}" "${WAW:=$SCREEN_W}" "${WAH:=$SCREEN_H}"
        BOTTOM=$((WAY + WAH))
        RIGHT=$((WAX + WAW))

        # ----- workspace aktif, jumlahnya, dan lebar grid (kolom) -----
        ws_line=$(wmctrl -d 2>/dev/null | awk '$2=="*"{print NR-1; exit}' || true)
        : "${ws_line:=0}"
        NWS=$(wmctrl -d 2>/dev/null | wc -l || true)
        : "${NWS:=1}"
        LAY=$(xprop -root _NET_DESKTOP_LAYOUT 2>/dev/null | awk -F'=' '{gsub(/[^0-9,]/,"",$2); print $2}' || true)
        IFS=, read -r _ L_COLS L_ROWS _ <<< "${LAY:-0,0,0,0}"
        COLS=$(( ${L_COLS:-0} )); ROWS=$(( ${L_ROWS:-0} ))
        if [ "$COLS" -le 0 ]; then
            if [ "$ROWS" -gt 1 ]; then COLS=$(( (NWS + ROWS - 1) / ROWS )); else COLS=1; fi
        fi
        [ "$COLS" -ge 1 ] || COLS=1

        case "$cmd" in
            left)  x=$((x - STEP)) ;;
            right) x=$((x + STEP)) ;;
            up)    y=$((y - STEP)) ;;
            down)  y=$((y + STEP)) ;;
        esac

        # ----- "nembus" tepi: pindah workspace + jendela ikut -----
        TARGET=""; NOTE=""
        if [ "$cmd" = right ] && [ $((x + w)) -gt "$RIGHT" ]; then
            TARGET=$(( (ws_line + 1) % NWS ));  x=$WAX        # masuk dari kiri
        elif [ "$cmd" = left ] && [ "$x" -lt "$WAX" ]; then
            TARGET=$(( (ws_line - 1 + NWS) % NWS )); x=$((RIGHT - w))   # masuk dari kanan
        elif [ "$cmd" = down ] && [ $((y + h)) -gt "$BOTTOM" ]; then
            TARGET=$(( (ws_line + COLS) % NWS )); y=$WAY      # masuk dari atas
        elif [ "$cmd" = up ] && [ "$y" -lt "$WAY" ]; then
            TARGET=$(( (ws_line - COLS % NWS + NWS) % NWS )); y=$((BOTTOM - h))  # dari bawah
        fi

        if [ -n "$TARGET" ]; then
            if [ "$TARGET" = "$ws_line" ] || [ "$NWS" -le 1 ]; then
                # tidak ada workspace tujuan → tempel rapi ke tepi, jangan keluar layar
                case "$cmd" in
                    right) x=$((RIGHT - w)) ;;
                    left)  x=$WAX ;;
                    down)  y=$((BOTTOM - h)) ;;
                    up)    y=$WAY ;;
                esac
                NOTE=" (mentok: tanpa workspace tujuan)"
                TARGET=""
            else
                if [ "$DRY" = "1" ]; then
                    NOTE=" -> pindah ke workspace $TARGET (dari $ws_line, grid ${COLS} kolom)"
                else
                    wmctrl -i -r "$AWID" -t "$TARGET" 2>/dev/null || true
                    wmctrl -s "$TARGET" 2>/dev/null || true
                    NOTE=" -> pindah ke workspace $TARGET"
                fi
            fi
        fi

        if [ "$DRY" = "1" ]; then
            printf 'DRY %-5s win=%dx%d di (%d,%d) -> (%d,%d)%s\n' \
                "$cmd" "$w" "$h" "$x" "$y" "$((x - CAL_X))" "$((y - CAL_Y))" "$NOTE"
            exit 0
        fi

        # set posisi via EWMH — dengan kompensasi kalibrasi xfwm4
        wmctrl -i -r "$AWID" -e "0,$((x - CAL_X)),$((y - CAL_Y)),$w,$h" 2>/dev/null || true
        [ -n "$NOTE" ] && echo "[window] $cmd$NOTE" || true
        ;;
    *) echo "aksi tidak dikenal: $cmd"; exit 1 ;;
esac
