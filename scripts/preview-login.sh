#!/usr/bin/env bash
#
# preview-login.sh — LIHAT tampilan layar login tanpa logout / reboot.
#
#   bash scripts/preview-login.sh             # ANIMASI 30 detik: wallpaper TAJAM
#                                             # + jam besar & tanggal di tengah;
#                                             # tekan tombol apa saja -> kartu
#                                             # login naik & jam terbang ke atas
#                                             # form (tanggal hilang)
#   bash scripts/preview-login.sh 20          # sama, 20 detik
#   bash scripts/preview-login.sh 30 5        # sama, tapi kartu muncul sendiri
#                                             # setelah 5 detik (tanpa menekan)
#   bash scripts/preview-login.sh --card      # potret statis kartu login saja
#                                             # (tampilan asli greeter, tanpa jam)
#
# Alur animasi di sini memakai kelengkapan yang SAMA dengan layar login asli
# (preview-login.py merender potret greeter → greeter-textures.py memotong kartu
# & panel → greeter-anim.py memasang overlay), jadi yang terlihat = yang nanti
# muncul saat boot.
#
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BG_SHARP="/usr/share/backgrounds/anime-glass/login-bg-sharp.jpg"
# sumber utama = wallpaper login di repo (gambar blue-girl). Aset hasil deploy
# hanya dipakai kalau file repo tidak ada, supaya pratinjau tidak "ketinggalan
# versi" dari deploy lama.
BG_REPO="$SRC_DIR/config/wallpapers/login/blue-girl.jpg"

say() { printf '\033[1;36m[preview]\033[0m %s\n' "$*"; }

for dep in python3 identify; do
    command -v "$dep" >/dev/null 2>&1 || { say "$dep tidak ada"; exit 1; }
done
python3 -c 'import gi'  2>/dev/null || { say "python3-gi belum terpasang (sudo apt install python3-gi)"; exit 1; }
python3 -c 'import PIL' 2>/dev/null || { say "python3-pil belum terpasang (sudo apt install python3-pil)"; exit 1; }
[ -n "${DISPLAY:-}" ] || { say "DISPLAY kosong — jalankan dari sesi desktop (bukan SSH/tty)"; exit 1; }

# ------------------------------------------------------------------ mode pilih
MODE=anim
DETIK=30
AUTO=0
case "${1:-}" in
    --card) MODE=card; DETIK="${2:-20}" ;;
    --anim) MODE=anim; DETIK="${2:-30}"; AUTO="${3:-0}" ;;
    "") ;;
    *)      DETIK="$1" ;;        # angka = detik (mode animasi)
esac

# --------------------------------------------------------- mode animasi (bawaan)
if [ "$MODE" = "anim" ]; then
    TMP="$(mktemp -d /tmp/anime-login-anim-XXXX)"
    SRC="$BG_REPO"
    [ -f "$SRC" ] || SRC="$BG_SHARP"
    SIZE="$(xrandr 2>/dev/null | awk '/[*]/ {print $1; exit}')"
    SIZE="${SIZE:-1920x1080}"

    say "menyiapkan aset + potret mock layar login…"
    # parameter SAMA dengan deploy: latar tajam, kartu tetap kaca buram
    python3 "$SRC_DIR/scripts/login-assets.py" --src "$SRC" --outdir "$TMP" \
        --size "$SIZE" --bg-blur 0 --card-blur 10 --bar-blur 14 \
        --dim 0.94 --vignette 0.62 >/dev/null
    python3 "$SRC_DIR/scripts/preview-login.py" --mock-shot "$TMP/shot.png" \
        --bg "$TMP/login-bg.jpg" --assets "$TMP" >/dev/null

    if [ "$AUTO" -gt 0 ]; then
        say "TEKAN TOMBOL APA SAJA (kartu muncul sendiri setelah ${AUTO}s; selesai ${DETIK}s)…"
    else
        say "TEKAN TOMBOL APA SAJA untuk memunculkan kartu login (selesai ${DETIK}s)…"
    fi
    # linger-ttl: jam menetap di atas form ikut ditutup saat pratinjau selesai
    # (di layar login asli jam ini hidup terus sampai user berhasil login).
    ANIME_GLASS_WALLPAPER="$TMP/login-bg.jpg" \
    ANIME_GLASS_OVERLAY="$SRC_DIR/scripts/greeter-anim.py" \
    ANIME_GLASS_TEXTURES="$SRC_DIR/scripts/greeter-textures.py" \
    ANIME_GLASS_LOG="$TMP/anim.log" \
    ANIME_GLASS_ANIM_CONF="$TMP/anim.conf" \
    exec python3 "$SRC_DIR/scripts/greeter-anim-launch.py" --shot "$TMP/shot.png" \
        "--pass=--timeout=$DETIK" "--pass=--auto=$AUTO" "--pass=--linger-ttl=$DETIK"
fi

# ------------------------------------------------- mode potret kartu (statis)
say "menampilkan potret kartu login ($DETIK detik, ESC untuk menutup)…"
exec python3 "$SRC_DIR/scripts/preview-login.py" "$DETIK"
