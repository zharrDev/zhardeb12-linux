#!/usr/bin/env bash
#
# generate-panel-info.sh — terapkan layout panel XFCE pill + widget info Conky.
#
# Cara pakai (setelah login & panel berjalan):
#   bash generate-panel-info.sh
#
# Apa yang dilakukan:
#   1. Menata ulang panel XFCE menjadi pill (rounded, semi-transparan, blur):
#        showdesktop | applicationsmenu | tasklist | separator |
#        systray | pulseaudio | power-manager-plugin | separator |
#        clock (Hari, Tgl Bulan Tahun | Jam) | separator | actions
#      - Memakai nama plugin yang BENAR (id = nama file .desktop), jadi
#        tidak ada lagi error "Plugin ... was not found" / notif gagal.
#      - Panjang panel 560px, posisi floating di tengah-atas.
#   2. Memasang & menjalankan widget Conky "anime-glass" (info CPU, RAM,
#      DISK, uptime, jam, tanggal) di kiri-tengah desktop. Warnanya otomatis
#      mengikuti wallpaper via pywal (~/.cache/wal/colors).
#
# Catatan:
#   - Info sistem (CPU/RAM/dll) TIDAK lagi dipasang di panel lewat plugin
#     sensors/weather; itu digantikan widget Conky di desktop agar panel
#     tetap bersih & tidak rawan error.
#   - Warna panel mengikuti wallpaper lewat update-wallpaper.sh (pywal).
#
set -euo pipefail
export LC_NUMERIC=C   # hindari bug desimal koma (id_ID) di xfconf

PANEL="xfce4-panel"
HOME_C="${HOME:-$HOME}"

# --- 0. Pastikan panel terpasang ---
command -v xfce4-panel >/dev/null 2>&1 || { echo "[gagal] xfce4-panel tidak terpasang."; exit 1; }
command -v xfconf-query >/dev/null 2>&1 || { echo "[gagal] xfconf-query tidak terpasang."; exit 1; }

# --- 1. Reset & set plugin panel (id = nama file .desktop yang benar) ---
# PENTING: properti 'length' xfce4-panel adalah PERSEN (1-100) dari lebar layar,
# BUKAN piksel. Nilai >100 (mis. 480/560) akan memicu warning "invalid or out
# of range" dan membuat panel tampil aneh. Pakai length=100 untuk full-width.
# posisi p=11 = TOP (full-width, "mentok ke atas"), p=9 = top-center, p=0 = floating.
for n in $(seq 1 14); do
    xfconf-query -c "$PANEL" -p "/plugins/plugin-$n" -r 2>/dev/null || true
done

set_plugin() {  # set_plugin <id> <nama>
    xfconf-query -c "$PANEL" -p "/plugins/plugin-$1" --create -t string -s "$2"
}

set_plugin 1  showdesktop
set_plugin 2  applicationsmenu
set_plugin 3  tasklist
set_plugin 4  separator
set_plugin 5  systray
set_plugin 6  pulseaudio
set_plugin 7  power-manager-plugin
set_plugin 8  separator
set_plugin 9  clock
set_plugin 10 separator
set_plugin 11 actions

# format jam & tanggal di panel
xfconf-query -c "$PANEL" -p /plugins/plugin-9/digital-format --create -t string -s "%a, %d %b %Y  |  %H:%M" 2>/dev/null || true
xfconf-query -c "$PANEL" -p /plugins/plugin-9/tooltip-format --create -t string -s "%A, %d %B %Y" 2>/dev/null || true
xfconf-query -c "$PANEL" -p /plugins/plugin-9/mode --create -t uint -s 2 2>/dev/null || true

# urutan plugin & panjang panel (pill)
xfconf-query -c "$PANEL" -p /panels/panel-1/plugin-ids \
    -t int -s 1 -t int -s 2 -t int -s 3 -t int -s 4 -t int -s 5 \
    -t int -s 6 -t int -s 7 -t int -s 8 -t int -s 9 -t int -s 10 -t int -s 11
xfconf-query -c "$PANEL" -p /panels/panel-1/length -s 100 2>/dev/null || true
xfconf-query -c "$PANEL" -p /panels/panel-1/length-adjust -s true 2>/dev/null || true
xfconf-query -c "$PANEL" -p /panels/panel-1/position -s "p=11;x=0;y=0" 2>/dev/null || true
xfconf-query -c "$PANEL" -p /panels/panel-1/position-locked -s true 2>/dev/null || true
xfconf-query -c "$PANEL" -p /panels/panel-1/size -s 44 2>/dev/null || true

# --- 2. Restart panel ---
pkill -x xfce4-panel 2>/dev/null || true
sleep 1
nohup xfce4-panel >/dev/null 2>&1 &
sleep 2
pgrep -x xfce4-panel >/dev/null && echo "[ok] Panel XFCE berjalan (full-width di atas, transparan + blur, sudut pill)." \
    || echo "[peringatan] Panel tidak terdeteksi — coba: xfce4-panel &"

# --- 3. Widget Conky anime-glass (info sistem di kiri-tengah desktop) ---
CONKY_CONF="$HOME/.config/conky/anime-glass.conf"
CONKY_LUA="$HOME/.config/conky/anime-glass.lua"
if [ ! -f "$CONKY_CONF" ]; then
    SRC="$(cd "$(dirname "$0")/.." && pwd)"
    mkdir -p "$HOME/.config/conky" "$HOME/.config/autostart"
    cp -f "$SRC/config/conky/anime-glass.conf" "$CONKY_CONF"
    cp -f "$SRC/config/conky/anime-glass.lua"  "$CONKY_LUA"
    cat > "$HOME/.config/autostart/conky-anime-glass.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Conky Anime Glass
Comment=Widget info sistem (CPU, RAM, jam, tanggal) — kiri tengah desktop
Exec=sh -c "sleep 3 && conky -c $HOME/.config/conky/anime-glass.conf"
X-GNOME-Autostart-enabled=true
EOF
fi
pkill -f anime-glass.conf 2>/dev/null || true
sleep 1
if conky -c "$CONKY_CONF" -d -o /tmp/conky-anime-glass.log 2>/dev/null; then
    echo "[ok] Conky anime-glass berjalan (kiri-tengah desktop, warna ikut wallpaper)."
else
    echo "[peringatan] Conky gagal start — cek /tmp/conky-anime-glass.log"
fi

echo ""
echo "Selesai. Info CPU/RAM/jam/tanggal tampil di kiri-tengah desktop (conky),"
echo "panel pill di atas berisi menu, tasklist, systray, jam & tombol actions."
echo "Ganti warna mengikuti wallpaper:  ./update-wallpaper.sh /path/gambar.jpg"