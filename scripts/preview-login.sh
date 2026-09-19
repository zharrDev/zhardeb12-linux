#!/usr/bin/env bash
#
# preview-login.sh — LIHAT tampilan layar login tanpa logout / reboot.
#
#   bash scripts/preview-login.sh            # pratinjau statis 20 detik (ESC = tutup)
#   bash scripts/preview-login.sh 40         # pratinjau statis 40 detik
#   bash scripts/preview-login.sh --anim     # coba ANIMASI: wallpaper dulu, lalu
#                                            # tekan tombol apa saja -> kartu login
#                                            # masuk dari bawah (seperti saat login)
#
# Pratinjau statis memakai UI XML asli greeter + CSS tema + avatar + panel +
# wallpaper. Mode --anim memakai overlay animasi yang sama dengan yang dipasang
# di layar login, jadi kamu bisa merasakan transisinya dulu.
#
# Screenshot hasil pratinjau disimpan ke ~/Pictures/anime-login-preview.png.
#
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BG_SHARP="/usr/share/backgrounds/anime-glass/login-bg-sharp.jpg"
BG_REPO="$SRC_DIR/config/wallpapers/login/anime-login-bg.jpg"

say() { printf '\033[1;36m[preview]\033[0m %s\n' "$*"; }

for dep in python3 identify; do
    command -v "$dep" >/dev/null 2>&1 || { say "$dep tidak ada"; exit 1; }
done
python3 -c 'import gi'  2>/dev/null || { say "python3-gi belum terpasang (sudo apt install python3-gi)"; exit 1; }
python3 -c 'import PIL' 2>/dev/null || { say "python3-pil belum terpasang (sudo apt install python3-pil)"; exit 1; }
[ -n "${DISPLAY:-}" ] || { say "DISPLAY kosong — jalankan dari sesi desktop (bukan SSH/tty)"; exit 1; }

# ------------------------------------------------------------------ mode demo
if [ "${1:-}" = "--anim" ]; then
    DETIK="${2:-30}"
    TMP="$(mktemp -d /tmp/anime-login-anim-XXXX)"
    SRC="$BG_SHARP"
    [ -f "$SRC" ] || SRC="$BG_REPO"
    SIZE="$(xrandr 2>/dev/null | awk '/[*]/ {print $1; exit}')"
    SIZE="${SIZE:-1920x1080}"

    say "menyiapkan aset & kartu login…"
    python3 "$SRC_DIR/scripts/login-assets.py" --src "$SRC" --outdir "$TMP" --size "$SIZE" >/dev/null
    python3 "$SRC_DIR/scripts/render-login-card.py" --assets "$TMP" --out "$TMP/card.png" >/dev/null

    CW="$(identify -format '%w' "$TMP/card.png")"
    CH="$(identify -format '%h' "$TMP/card.png")"
    SW="${SIZE%x*}"; SH="${SIZE#*x}"
    CX=$(( (SW - CW) / 2 )); CY=$(( (SH - CH) / 2 ))

    say "menampilkan transisi (tekan tombol apa saja; tutup otomatis $DETIK detik)…"
    exec python3 "$SRC_DIR/scripts/greeter-anim.py" \
        --wallpaper "$TMP/login-bg.jpg" --card "$TMP/card.png" \
        --card-x "$CX" --card-y "$CY" --top-gap 0 \
        --timeout "$DETIK" --duration 520 --log "$TMP/anim.log"
fi

# ----------------------------------------------------------- mode pratinjau biasa
DETIK="${1:-20}"
say "menampilkan preview layar login ($DETIK detik, ESC untuk menutup)…"
exec python3 "$SRC_DIR/scripts/preview-login.py" "$DETIK"
