#!/usr/bin/env bash
#
# rotate-wallpaper.sh — ganti wallpaper anime bergiliran + samakan warna UI.
#
# Semua gambar asli dari koleksi terpusat dipakai bergantian:
#   - ~/Pictures/Wallpapers/Anime/
#   - ~/.config/wallpapers/originals/   (koleksi bawaan repo, ala By-LeyzS)
# Setiap ganti, update-wallpaper.sh dijalankan sehingga warna panel, terminal,
# conky (termasuk banner & hover biru) ikut wallpaper baru.
#
# Cara pakai:
#   ./rotate-wallpaper.sh          # ganti ke gambar berikutnya (manual)
#   ./rotate-wallpaper.sh --random # ganti ke gambar acak (alias --random)
#   IMGDIR=/path bash rotate-wallpaper.sh
#
set -euo pipefail

IMGDIR="${IMGDIR:-$HOME/Pictures/Wallpapers/Anime}"
STATE="$IMGDIR/.rotate-state"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# cari update-wallpaper.sh (di samping skrip ini, atau di repo setup)
UPDATE_SH="$SCRIPT_DIR/update-wallpaper.sh"
[ -x "$UPDATE_SH" ] || UPDATE_SH="$HOME/Documents/zhardeb/update-wallpaper.sh"
[ -x "$UPDATE_SH" ] || UPDATE_SH="$(pwd)/update-wallpaper.sh"
[ -x "$UPDATE_SH" ] || { echo "[rotate] update-wallpaper.sh tidak ditemukan."; exit 1; }

# mode acak -> langsung delegasi ke update-wallpaper.sh --random
if [ "${1:-}" = "--random" ] || [ "${1:-}" = "-r" ]; then
    exec bash "$UPDATE_SH" --random
fi

[ -d "$IMGDIR" ] || { echo "[rotate] folder tidak ada: $IMGDIR"; exit 1; }

# hanya gambar ASLI (bukan hasil konversi anime-*.jpg)
mapfile -t IMGS < <(find "$IMGDIR" -maxdepth 1 -type f \
    \( -iname '*.jpeg' -o -iname '*.png' \) | sort)
[ "${#IMGS[@]}" -gt 0 ] || { echo "[rotate] tidak ada gambar asli di $IMGDIR"; exit 1; }

CUR="$(cat "$STATE" 2>/dev/null || echo '')"

# pilih gambar berikutnya (setelah yang sedang dipakai)
NEXT=""
for i in "${!IMGS[@]}"; do
    if [ "${IMGS[$i]}" = "$CUR" ]; then
        NEXT="${IMGS[$(( (i + 1) % ${#IMGS[@]} ))]}"
        break
    fi
done
[ -n "$NEXT" ] || NEXT="${IMGS[0]}"

echo "$NEXT" > "$STATE"
echo "[rotate] ${NEXT##*/}"
exec bash "$UPDATE_SH" "$NEXT"