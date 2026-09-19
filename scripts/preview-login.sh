#!/usr/bin/env bash
#
# preview-login.sh — LIHAT tampilan layar login tanpa logout / reboot.
#
#   bash scripts/preview-login.sh            # pratinjau statis 20 detik (ESC = tutup)
#   bash scripts/preview-login.sh 40         # pratinjau statis 40 detik
#   bash scripts/preview-login.sh --anim     # coba ANIMASI: wallpaper dulu, lalu
#                                            # tekan tombol apa saja -> kartu login
#                                            # masuk dari bawah (seperti saat login)
#   bash scripts/preview-login.sh --anim 30 5  # sama, tapi kartu muncul sendiri
#                                            # setelah 5 detik (tanpa tekan tombol)
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
# sumber utama = wallpaper login di repo (gambar blue-girl). Aset hasil deploy
# hanya dipakai kalau file repo tidak ada, supaya pratinjau tidak "ketinggalan
# versi" dari deploy lama.
BG_REPO="$SRC_DIR/config/wallpapers/login/anime-login-bg.jpg"

say() { printf '\033[1;36m[preview]\033[0m %s\n' "$*"; }

for dep in python3 identify; do
    command -v "$dep" >/dev/null 2>&1 || { say "$dep tidak ada"; exit 1; }
done
python3 -c 'import gi'  2>/dev/null || { say "python3-gi belum terpasang (sudo apt install python3-gi)"; exit 1; }
python3 -c 'import PIL' 2>/dev/null || { say "python3-pil belum terpasang (sudo apt install python3-pil)"; exit 1; }
[ -n "${DISPLAY:-}" ] || { say "DISPLAY kosong — jalankan dari sesi desktop (bukan SSH/tty)"; exit 1; }

# ------------------------------------------------------------------ mode demo
# Alur pratinjau = alur PRODUKSI: potret layar login → greeter-textures.py
# memotong kartu/panel/jam → greeter-anim-launch.py menjalankan overlay.
if [ "${1:-}" = "--anim" ]; then
    DETIK="${2:-30}"
    AUTO="${3:-0}"          # >0: kartu muncul sendiri setelah N detik (demo)
    TMP="$(mktemp -d /tmp/anime-login-anim-XXXX)"
    SRC="$BG_REPO"
    [ -f "$SRC" ] || SRC="$BG_SHARP"
    SIZE="$(xrandr 2>/dev/null | awk '/[*]/ {print $1; exit}')"
    SIZE="${SIZE:-1920x1080}"

    say "menyiapkan aset + potret mock layar login…"
    python3 "$SRC_DIR/scripts/login-assets.py" --src "$SRC" --outdir "$TMP" \
        --size "$SIZE" --bg-blur 16 --card-blur 8 --dim 0.90 --vignette 0.60 >/dev/null
    python3 "$SRC_DIR/scripts/preview-login.py" --mock-shot "$TMP/shot.png" \
        --bg "$TMP/login-bg.jpg" --assets "$TMP" >/dev/null

    say "menampilkan transisi (tekan tombol apa saja; tutup otomatis $DETIK detik)…"
    ANIME_GLASS_WALLPAPER="$TMP/login-bg.jpg" \
    ANIME_GLASS_OVERLAY="$SRC_DIR/scripts/greeter-anim.py" \
    ANIME_GLASS_TEXTURES="$SRC_DIR/scripts/greeter-textures.py" \
    ANIME_GLASS_LOG="$TMP/anim.log" \
    ANIME_GLASS_ANIM_CONF="$TMP/anim.conf" \
    exec python3 "$SRC_DIR/scripts/greeter-anim-launch.py" --shot "$TMP/shot.png" \
        "--pass=--timeout=$DETIK" "--pass=--auto=$AUTO"
fi

# ----------------------------------------------------------- mode pratinjau biasa
DETIK="${1:-20}"
say "menampilkan preview layar login ($DETIK detik, ESC untuk menutup)…"
exec python3 "$SRC_DIR/scripts/preview-login.py" "$DETIK"
