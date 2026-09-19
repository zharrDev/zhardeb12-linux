#!/usr/bin/env bash
#
# preview-login.sh — LIHAT tampilan layar login tanpa logout / reboot.
#
# Menampilkan window fullscreen berisi UI greeter asli + CSS tema + avatar +
# wallpaper, jadi tampilannya sama seperti kartu login sungguhan. Otomatis
# menyimpan screenshot ke ~/Pictures/anime-login-preview.png.
#
#   bash scripts/preview-login.sh          # tampil 20 detik
#   bash scripts/preview-login.sh 40       # tampil 40 detik (ESC = tutup)
#
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DETIK="${1:-20}"

say() { printf '\033[1;36m[preview]\033[0m %s\n' "$*"; }

if ! command -v python3 >/dev/null 2>&1; then
    say "python3 tidak ada"; exit 1
fi
python3 -c 'import gi' 2>/dev/null || { say "python3-gi belum terpasang (sudo apt install python3-gi)"; exit 1; }
python3 -c 'import PIL' 2>/dev/null || { say "python3-pil belum terpasang (sudo apt install python3-pil)"; exit 1; }
if [ -z "${DISPLAY:-}" ]; then
    say "DISPLAY kosong — jalankan dari sesi desktop (bukan SSH/tty)"; exit 1
fi

say "menampilkan preview layar login ($DETIK detik, ESC untuk menutup)…"
exec python3 "$SRC_DIR/scripts/preview-login.py" "$DETIK"
