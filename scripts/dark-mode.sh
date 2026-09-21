#!/usr/bin/env bash
#
# dark-mode.sh — toggle mode gelap/terang dengan wallpaper darkmode.png.
# Dipanggil oleh shortcut:  Super + Alt + W
#
# Urutan putaran:  Terang ↔ Gelap
#
# Cara kerjanya:
#   1. Wallpaper terang disimpan sebagai acuan (snapshot).
#   2. Mode gelap memakai wallpaper `darkmode.png` (nighttime cityscape)
#      yang sudah tersedia di repo — tidak perlu ImageMagick generate.
#   3. Wallpaper itu jadi sumber pywal → seluruh UI (panel, terminal,
#      GTK, conky, outline, notifikasi) otomatis ikut gelap & senada.
#   4. Transisi: overlay crossfade ber-easing (0.55s fade-in + ditahan
#      sampai warna UI selesai diperbarui) → tidak ada kedip panel/terminal.
#
# Opsi env:
#   FADE_TIME=0.8   durasi fade-in overlay (detik, default 0.55)
#   FADE_HOLD=6     maksimum overlay ditahan (detik, default 3.5)
#   NOTIFY=0        matikan notifikasi desktop
#   FORCE=light|dark lompat langsung ke mode tertentu
#
set -uo pipefail

# --- lokasi skrip pendukung -------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
find_tool() {
    local n="$1"; shift
    for p in "$@"; do [ -f "$p" ] && { printf '%s' "$p"; return 0; }; done
    return 1
}
UPDATE_SH="$(find_tool update-wallpaper.sh \
    "$SCRIPT_DIR/update-wallpaper.sh" \
    "$HOME/Documents/zhardeb/update-wallpaper.sh" \
    "$HOME/.local/bin/update-wallpaper.sh")" || {
    echo "[dark-mode] update-wallpaper.sh tidak ditemukan." >&2; exit 1; }
FADE_PY="$(find_tool wallpaper-fade.py \
    "$SCRIPT_DIR/wallpaper-fade.py" \
    "$SCRIPT_DIR/scripts/wallpaper-fade.py" \
    "$HOME/Documents/zhardeb/scripts/wallpaper-fade.py" \
    "$HOME/.local/bin/scripts/wallpaper-fade.py" || true)"

# --- wallpaper gelap --------------------------------------------------------
DARK_SRC="$(find_tool darkmode.png \
    "$HOME/Documents/zhardeb/wallpapers/darkmode.png" \
    "$HOME/Pictures/Wallpapers/Anime/darkmode.png" || true)"
if [ -z "$DARK_SRC" ]; then
    echo "[dark-mode] darkmode.png tidak ditemukan." >&2; exit 1
fi

# --- lokasi state & gambar --------------------------------------------------
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zhardeb"
STATE_FILE="$STATE_DIR/dark-mode.state"
DARK_DIR="$HOME/Pictures/Wallpapers/Anime/.dark"
LIGHT_IMG="$DARK_DIR/light.jpg"

mkdir -p "$STATE_DIR" "$DARK_DIR"

msg()  { printf '\033[1;36m[dark-mode]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[dark-mode]\033[0m %s\n' "$*" >&2; }

notify() {
    [ "${NOTIFY:-1}" = "1" ] || return 0
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -t 2600 -a "Dark Mode" "$1" "$2" 2>/dev/null || true
}

# --- wallpaper yang sedang tampil ------------------------------------------
current_wall() {
    command -v xfconf-query >/dev/null 2>&1 || return 1
    local key val
    for key in $(LC_ALL=C xfconf-query -c xfce4-desktop -l 2>/dev/null \
                 | grep 'last-image' || true); do
        val="$(xfconf-query -c xfce4-desktop -p "$key" 2>/dev/null)" || continue
        [ -n "$val" ] && [ -f "$val" ] && { printf '%s' "$val"; return 0; }
    done
    return 1
}

set_wall_instant() {
    local img="$1" key
    for key in $(LC_ALL=C xfconf-query -c xfce4-desktop -l 2>/dev/null \
                 | grep 'last-image' || true); do
        xfconf-query -c xfce4-desktop -p "$key" -s "$img" 2>/dev/null || true
    done
}

# --- tentukan mode berikutnya -----------------------------------------------
CUR="$(cat "$STATE_FILE" 2>/dev/null || echo light)"
CUR="${CUR//[[:space:]]/}"
case "${FORCE:-}" in
    light|dark) NEXT="$FORCE" ;;
    "")
        case "$CUR" in
            light|"") NEXT="dark" ;;
            *)        NEXT="light" ;;
        esac
        ;;
    *) NEXT="dark" ;;
esac

# --- 1) acuan "terang" (snapshot saat pertama kali masuk mode gelap) ---------
if [ "$CUR" = "light" ] || [ ! -f "$LIGHT_IMG" ]; then
    SRC="$(current_wall || true)"
    if [ -n "${SRC:-}" ] && [ -f "$SRC" ] && \
       [ "$(readlink -f "$SRC")" != "$(readlink -f "$LIGHT_IMG" 2>/dev/null)" ]; then
        cp -f "$SRC" "$LIGHT_IMG"
        msg "Acuan terang: ${SRC##*/}"
    elif [ ! -f "$LIGHT_IMG" ]; then
        warn "Tidak bisa membaca wallpaper aktif — mode gelap dibatalkan."
        exit 1
    fi
fi

# --- 2) gambar untuk mode tujuan --------------------------------------------
if [ "$NEXT" = "light" ]; then
    IMG="$LIGHT_IMG"
    LABEL="Terang"
    EMO="☀️"
else
    IMG="$DARK_DIR/darkmode-wallpaper.jpg"
    # salin darkmode.png → darkmode-wallpaper.jpg (hanya bila belum ada atau
    # darkmode.png lebih baru, misal user mengganti file-nya)
    if [ ! -f "$IMG" ] || [ "$DARK_SRC" -nt "$IMG" ]; then
        cp -f "$DARK_SRC" "$IMG"
        msg "Wallpaper gelap: ${DARK_SRC##*/}"
    fi
    LABEL="Gelap"
    EMO="🌙"
fi

# --- 3) transisi: overlay crossfade -----------------------------------------
FADE_PID=""
FT="${FADE_TIME:-0.55}"
FH="${FADE_HOLD:-3.5}"
RELEASE_FILE="/tmp/zhardeb-fade-release"
rm -f "$RELEASE_FILE" 2>/dev/null || true
if [ -n "${DISPLAY:-}" ] && [ -n "${FADE_PY:-}" ] && [ -f "$FADE_PY" ]; then
    python3 "$FADE_PY" "$IMG" "$FT" "$FH" >/dev/null 2>&1 &
    FADE_PID=$!
fi

# --- 4) perbarui seluruh warna UI dari wallpaper baru -----------------------
# SET_WALL=0     → jangan set wallpaper sendiri (overlay yang melakukannya)
# KEEP_IN_PLACE  → jangan masukkan ke koleksi wallpaper
# BANNER/AVATAR  → conky tetap pakai artwork anime aslinya
if ! SET_WALL=0 \
     KEEP_IN_PLACE=1 \
     BANNER_IMG="$LIGHT_IMG" \
     AVATAR_IMG="$LIGHT_IMG" \
     bash "$UPDATE_SH" "$IMG" >"$STATE_DIR/dark-mode.log" 2>&1; then
    warn "Gagal menyamakan warna UI (lihat $STATE_DIR/dark-mode.log)."
fi

# --- 5) lepas kurtain transisi & pastikan wallpaper terpasang ---------------
[ -n "$FADE_PID" ] && touch "$RELEASE_FILE" 2>/dev/null || true
if [ -n "$FADE_PID" ]; then
    if ! wait "$FADE_PID" 2>/dev/null; then
        set_wall_instant "$IMG"
    fi
else
    set_wall_instant "$IMG"
fi

printf '%s' "$NEXT" > "$STATE_FILE"

msg "$EMO  Mode $LABEL aktif  (Super+Alt+W untuk beralih)"
notify "Mode: $LABEL" "Tekan Super+Alt+W untuk beralih ke mode $([ "$NEXT" = "light" ] && echo gelap || echo terang)."
