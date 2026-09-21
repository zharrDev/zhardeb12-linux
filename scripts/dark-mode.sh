#!/usr/bin/env bash
#
# dark-mode.sh — nuansa GELAP (3 varian) untuk desktop, dari wallpaper yang
# sedang dipakai. Dipanggil oleh shortcut:  Super + Alt + W
#
# Urutan putaran:  Terang -> Dark Mocha -> Dark Navy -> Dark Plum -> Terang
#
# Cara kerjanya (ringkas):
#   1. Wallpaper terang yang sedang aktif disimpan sebagai acuan.
#   2. Versi gelapnya dibuat dengan ImageMagick: gambar yang SAMA, diredam
#      kecerahannya lalu diberi tint khas tiap varian (mocha / navy / plum).
#      Jadi wallpaper tetap gambar langganan kamu — hanya suasananya malam.
#   3. Wallpaper gelap itu jadi sumber pywal, sehingga SELURUH UI (panel,
#      terminal, GTK, conky, outline jendela, notifikasi) otomatis ikut
#      gelap & senada — semua memang membaca palet pywal.
#   4. Transisi: overlay crossfade ber-easing (~0.9s) menutup layar
#      sementara warna UI berganti di belakangnya, jadi perpindahannya
#      terasa mulus, bukan "kedip".
#
# Opsi env:
#   FADE_TIME=0.8   durasi fade-in overlay (detik, default 0.55)
#   FADE_HOLD=6     maksimum overlay ditahan (detik, default 3.5); overlay
#                   ditutup lebih cepat begitu warna UI selesai diperbarui
#   NOTIFY=0        matikan notifikasi desktop
#   FORCE=<nama>    lompat langsung ke varian: light|mocha|navy|plum
#
set -uo pipefail

# --- varian gelap: nama | label | tint | modulate(bright,sat) | colorize ----
VARIANTS=(mocha navy plum)
LABELS=("Dark Mocha" "Dark Navy" "Dark Plum")
TINTS=('#4a3a2e' '#12203a' '#2a1740')
MODULATE=('48,60' '45,55' '46,60')
COLORIZE=(45 50 48)
EMOJI=("🌙" "🌊" "🔮")

# --- lokasi skrip pendukung -------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
find_tool() { # find_tool <nama> <kandidat...>
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

# --- lokasi state & gambar -------------------------------------------------
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zhardeb"
STATE_FILE="$STATE_DIR/dark-mode.state"
DARK_DIR="$HOME/Pictures/Wallpapers/Anime/.dark"   # titik = tidak ikut koleksi
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

set_wall_instant() { # fallback bila overlay transisi tidak bisa dipakai
    local img="$1" key
    for key in $(LC_ALL=C xfconf-query -c xfce4-desktop -l 2>/dev/null \
                 | grep 'last-image' || true); do
        xfconf-query -c xfce4-desktop -p "$key" -s "$img" 2>/dev/null || true
    done
}

# --- tentukan varian berikutnya --------------------------------------------
CUR="$(cat "$STATE_FILE" 2>/dev/null || echo light)"
CUR="${CUR//[[:space:]]/}"
case "${FORCE:-}" in
    light) NEXT="light" ;;
    mocha|navy|plum) NEXT="$FORCE" ;;
    "")
        case "$CUR" in
            light|"") NEXT="${VARIANTS[0]}" ;;                    # -> mocha
            mocha)    NEXT="${VARIANTS[1]}" ;;
            navy)     NEXT="${VARIANTS[2]}" ;;
            plum)     NEXT="light" ;;                             # kembali terang
            *)        NEXT="${VARIANTS[0]}" ;;
        esac
        ;;
    *) NEXT="${VARIANTS[0]}" ;;
esac

command -v convert >/dev/null 2>&1 || { warn "ImageMagick (convert) belum terpasang."; exit 1; }

# --- 1) acuan "terang" (snapshot saat pertama kali masuk mode gelap) --------
if [ "$CUR" = "light" ] || [ ! -f "$LIGHT_IMG" ]; then
    SRC="$(current_wall || true)"
    if [ -n "${SRC:-}" ] && [ -f "$SRC" ] && [ "$(readlink -f "$SRC")" != "$(readlink -f "$LIGHT_IMG" 2>/dev/null)" ]; then
        cp -f "$SRC" "$LIGHT_IMG"
        msg "Acuan terang: ${SRC##*/}"
    elif [ ! -f "$LIGHT_IMG" ]; then
        warn "Tidak bisa membaca wallpaper aktif — mode gelap dibatalkan."
        exit 1
    fi
fi

# --- 2) gambar untuk mode tujuan -------------------------------------------
if [ "$NEXT" = "light" ]; then
    IMG="$LIGHT_IMG"
    LABEL="Terang"
    EMO="☀️"
else
    IDX=0
    for i in "${!VARIANTS[@]}"; do
        [ "${VARIANTS[$i]}" = "$NEXT" ] && IDX=$i
    done
    IMG="$DARK_DIR/dark-$NEXT.jpg"
    # cache: hanya dibuat ulang bila acuan berubah
    if [ ! -f "$IMG" ] || [ "$LIGHT_IMG" -nt "$IMG" ]; then
        msg "Membuat varian ${LABELS[$IDX]}..."
        convert "$LIGHT_IMG" \
            -modulate "${MODULATE[$IDX]},100" \
            -fill "${TINTS[$IDX]}" -colorize "${COLORIZE[$IDX]}" \
            -quality 92 "$IMG" || { warn "Gagal membuat varian gelap."; exit 1; }
    fi
    LABEL="${LABELS[$IDX]}"
    EMO="${EMOJI[$IDX]}"
fi

# --- 3) transisi: overlay crossfade (jalan di latar belakang) ---------------
# Overlay naik cepat, lalu DITAHAN sampai warna UI selesai berganti — jadi
# yang terlihat hanya satu crossfade mulus, bukan kedipan panel/terminal.
FADE_PID=""
FT="${FADE_TIME:-0.55}"
FH="${FADE_HOLD:-3.5}"
RELEASE_FILE="/tmp/zhardeb-fade-release"
rm -f "$RELEASE_FILE" 2>/dev/null || true
if [ -n "${DISPLAY:-}" ] && [ -n "${FADE_PY:-}" ] && [ -f "$FADE_PY" ]; then
    python3 "$FADE_PY" "$IMG" "$FT" "$FH" >/dev/null 2>&1 &
    FADE_PID=$!
fi

# --- 4) perbarui seluruh warna UI dari wallpaper baru ----------------------
# SET_WALL=0    -> jangan set wallpaper sendiri (overlay yang melakukannya)
# LANDSCAPE_FILE-> gambar sudah seukuran layar, tak perlu blur-fill
# KEEP_IN_PLACE -> jangan masukkan versi gelap ke koleksi wallpaper
# BANNER/AVATAR -> conky tetap pakai artwork anime aslinya (bukan versi gelap)
if ! SET_WALL=0 \
     LANDSCAPE_FILE="$IMG" \
     KEEP_IN_PLACE=1 \
     BANNER_IMG="$LIGHT_IMG" \
     AVATAR_IMG="$LIGHT_IMG" \
     bash "$UPDATE_SH" "$IMG" >"$STATE_DIR/dark-mode.log" 2>&1; then
    warn "Gagal menyamakan warna UI (lihat $STATE_DIR/dark-mode.log)."
fi

# --- 5) lepas kurtain transisi & pastikan wallpaper terpasang --------------
[ -n "$FADE_PID" ] && touch "$RELEASE_FILE" 2>/dev/null || true
if [ -n "$FADE_PID" ]; then
    if ! wait "$FADE_PID" 2>/dev/null; then
        set_wall_instant "$IMG"
    fi
else
    set_wall_instant "$IMG"
fi

printf '%s' "$NEXT" > "$STATE_FILE"

msg "$EMO  $LABEL aktif  (Super+Alt+W untuk lanjut)"
notify "Tema: $LABEL" "Tekan Super+Alt+W lagi untuk varian berikutnya."
