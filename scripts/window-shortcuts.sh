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
#
# DUA HAL YANG BIKIN DORONGAN TERASA "LENGKET" (sudah diperbaiki di sini):
#   1) setelah pindah workspace, xfwm4 memindahkan FOKUS ke jendela lain yang
#      sudah ada di workspace tujuan. Dorongan berikutnya karena itu menggeser
#      jendela yang SALAH → jendela yang kita dorong terlihat "tertempel" diam.
#      Perbaikan: setelah hop, jendela yang dipindah difokuskan ulang (dengan
#      verifikasi + coba ulang), dan id-nya disimpan sesaat di state file
#      sehingga beberapa tekanan beruntun tetap menyasar jendela yang sama.
#   2) `wmctrl -e` men-set posisi FRAME, dan xfwm4 menaruh klien 2x extents
#      darinya sambil membatasi frame agar tidak keluar area kerja. Akibatnya
#      tidak semua (x,y) bisa dicapai: ada batas XMIN/YMIN/XMAX/YMAX. Semua
#      hasil hitungan sekarang dijepit ke batas itu, jadi jendela tidak pernah
#      "nyangkut" sebagian di luar layar / di bawah panel.
#
# Semua geometry pakai CLIENT geometry (wmctrl -lG) — satu sumber, tanpa
# konversi frame/client (itulah sumber drift vertikal sebelumnya).
#
# Uji tanpa menggeser apa pun:  DRY=1 WIN=0x<id> bash window-shortcuts.sh down
#
set -euo pipefail

STEP="${STEP:-80}"
DRY="${DRY:-0}"                 # 1 = hitung & cetak rencana, jangan pindahkan apa pun
STATE="${WINDOW_SHORTCUTS_STATE:-${XDG_RUNTIME_DIR:-/tmp}/anime-glass-window.state}"
# Berapa lama id jendela terakhir masih "dipegang" setelah pindah workspace (detik).
HOLD_SECS="${HOLD_SECS:-1.2}"

cmd="${1:-}"
[ -n "$cmd" ] || { echo "pakai: $0 close|min|max|left|right|up|down|open"; exit 1; }
command -v wmctrl >/dev/null 2>&1 || { echo "[gagal] wmctrl belum terpasang."; exit 1; }

norm_id() { printf '0x%08x' "$(( $1 ))" 2>/dev/null || printf '%s' "$1"; }
active_id() {
    xprop -root _NET_ACTIVE_WINDOW 2>/dev/null \
        | grep -oE '0x[0-9a-fA-F]+' | head -1 || true
}
alive_id() {  # jendela masih dikelola WM?
    [[ -n "$1" ]] || return 1
    wmctrl -l 2>/dev/null | awk -v id="$1" 'tolower($1)==tolower(id){found=1} END{exit !found}'
}

# id jendela aktif — bisa di-override via env WIN (untuk test)
AWID="$(active_id)"
AWID="$(printf '%s' "${WIN:-$AWID}" | tr -d ' ,' | grep -oE '^0x[0-9a-fA-F]+' || true)"
if [[ -z "$AWID" && -n "${WIN:-}" ]]; then          # WIN diberikan sebagai desimal?
    AWID="$(norm_id "${WIN}")"
fi
[[ -n "$AWID" ]] || { echo "[gagal] tidak ada jendela aktif."; exit 1; }
NORM="$(norm_id "$AWID")"

# --- dipakai untuk aksi geser saja: kalau barusan kita memindah sebuah jendela
# ke workspace lain, fokus sudah berpindah ke jendela lain di sana. Selama
# jendela itu masih hidup dan barusan (< HOLD_SECS), tetap sasar jendela itu.
HOLD_WID=""; HOPPED=0
if [[ -z "${WIN:-}" && -f "$STATE" ]]; then
    read -r S_WID S_TIME S_HOP _ < "$STATE" 2>/dev/null || true
    if [[ -n "${S_WID:-}" && "${S_HOP:-0}" = "1" && "${S_TIME:-}" =~ ^[0-9]+$ ]]; then
        now=$(date +%s)
        if [ $(( now - S_TIME )) -le "${HOLD_SECS%.*}" ]; then
            S_NORM="$(norm_id "$S_WID" 2>/dev/null || true)"
            if [[ -n "$S_NORM" ]] && alive_id "$S_NORM" && [ "$S_NORM" != "$NORM" ]; then
                HOLD_WID="$S_NORM"
            fi
        fi
    fi
fi
[[ -n "$HOLD_WID" ]] && NORM="$HOLD_WID" && AWID="$HOLD_WID"

save_state() {  # $1 = 1 kalau aksi ini memindah jendela ke workspace lain
    { echo "$NORM $(date +%s) ${1:-0}"; } > "$STATE" 2>/dev/null || true
}

# Paksa fokus kembali ke jendela yang kita pindah supaya tekanan berikutnya
# menyasar jendela yang sama (bukan jendela lain yang kebetulan ada di sana).
refocus() {
    local i cur
    for i in 1 2 3 4 5 6; do
        cur="$(active_id)"
        [[ -n "$cur" ]] && [ "$(norm_id "$cur")" = "$NORM" ] && return 0
        wmctrl -i -a "$AWID" 2>/dev/null || true
        sleep 0.05
    done
    return 0
}

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

        # ----- posisi yang BENAR-BENAR bisa dicapai (lihat catatan #2 di atas) -----
        XMIN=$((WAX + CAL_X));  YMIN=$((WAY + CAL_Y))
        XMAX=$((RIGHT - w));    YMAX=$((BOTTOM - h))
        [ "$XMAX" -lt "$XMIN" ] && XMAX=$XMIN
        [ "$YMAX" -lt "$YMIN" ] && YMAX=$YMIN

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
                # tidak ada workspace tujuan → tempel rapi ke tepi area kerja
                case "$cmd" in
                    right) x=$XMAX ;;
                    left)  x=$XMIN ;;
                    down)  y=$YMAX ;;
                    up)    y=$YMIN ;;
                esac
                NOTE=" (mentok: tanpa workspace tujuan)"
                TARGET=""
            else
                HOPPED=1
                if [ "$DRY" = "1" ]; then
                    NOTE=" -> pindah ke workspace $TARGET (dari $ws_line, grid ${COLS} kolom)"
                else
                    wmctrl -i -r "$AWID" -t "$TARGET" 2>/dev/null || true
                    wmctrl -s "$TARGET" 2>/dev/null || true
                    NOTE=" -> pindah ke workspace $TARGET"
                fi
            fi
        fi

        # jepit ke batas yang bisa dicapai (jangan biarkan nyangkut di luar layar)
        [ "$x" -lt "$XMIN" ] && x=$XMIN
        [ "$x" -gt "$XMAX" ] && x=$XMAX
        [ "$y" -lt "$YMIN" ] && y=$YMIN
        [ "$y" -gt "$YMAX" ] && y=$YMAX

        if [ "$DRY" = "1" ]; then
            printf 'DRY %-5s win=%dx%d di (%d,%d) -> (%d,%d) [%d..%d x %d..%d]%s\n' \
                "$cmd" "$w" "$h" "$x" "$y" "$((x - CAL_X))" "$((y - CAL_Y))" \
                "$XMIN" "$XMAX" "$YMIN" "$YMAX" "$NOTE"
            exit 0
        fi

        # set posisi via EWMH — dengan kompensasi kalibrasi xfwm4
        wmctrl -i -r "$AWID" -e "0,$((x - CAL_X)),$((y - CAL_Y)),$w,$h" 2>/dev/null || true
        if [ "$HOPPED" = "1" ]; then
            refocus                        # ← ini yang menghilangkan efek "lengket"
            save_state 1
        else
            save_state 0
        fi
        [ -n "$NOTE" ] && echo "[window] $cmd$NOTE" || true
        ;;
    *) echo "aksi tidak dikenal: $cmd"; exit 1 ;;
esac
