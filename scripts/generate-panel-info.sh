#!/usr/bin/env bash
#
# generate-panel-info.sh — terapkan layout panel ala waybar By-LeyzS
#                         + widget info Conky anime-glass.
#
# Cara pakai (setelah login & panel berjalan):
#   bash generate-panel-info.sh
#   (atau: bash scripts/apply-leyzs-panel.sh — versi xfconf-only)
#
# Apa yang dilakukan:
#   1. Menata ulang panel XFCE ala waybar By-LeyzS (bar transparan penuh,
#      modul "chip" diberi bg+border aksen oleh gtk.css dari pywal):
#        showdesktop | applicationsmenu | clock (chip %H:%M:%S) |
#        pager (workspace bulat) | systemload (RAM) | systray |
#        pulseaudio | power-manager-plugin | separator | actions
#      - Memakai nama plugin yang BENAR (id = nama file .desktop), jadi
#        tidak ada lagi error "Plugin ... was not found" / notif gagal.
#      - Panel full-width (length=100 — PERSEN dari lebar layar) di tepi
#        atas (p=11), size 44, terkunci, background-style=2 (transparan).
#   2. Memasang & menjalankan widget Conky "anime-glass" (info CPU, RAM,
#      DISK, uptime, jam, tanggal) di kiri-tengah desktop. Warnanya otomatis
#      mengikuti wallpaper via pywal (~/.cache/wal/colors).
#
# Catatan:
#   - Info sistem (CPU/RAM/dll) TIDAK dipasang di panel; RAM ringan ada di
#     chip systemload, sisanya digantikan widget Conky di desktop.
#   - Warna chip mengikuti wallpaper lewat update-wallpaper.sh (pywal).
#
set -euo pipefail
export LC_NUMERIC=C   # hindari bug desimal koma (id_ID) di xfconf

PANEL="xfce4-panel"

# --- 0. Pastikan panel terpasang ---
command -v xfce4-panel >/dev/null 2>&1 || { echo "[gagal] xfce4-panel tidak terpasang."; exit 1; }
command -v xfconf-query >/dev/null 2>&1 || { echo "[gagal] xfconf-query tidak terpasang."; exit 1; }

# --- 1. Reset & set plugin panel (id = nama file .desktop yang benar) ---
for n in $(seq 1 20); do
    xfconf-query -c "$PANEL" -p "/plugins/plugin-$n" -r 2>/dev/null || true
done

set_plugin() {  # set_plugin <id> <nama>
    xfconf-query -c "$PANEL" -p "/plugins/plugin-$1" --create -t string -s "$2"
}

# layout ala waybar By-LeyzS: clock kiri, workspaces, sys kanan
set_plugin 1  showdesktop
set_plugin 2  applicationsmenu
set_plugin 3  clock
xfconf-query -c "$PANEL" -p /plugins/plugin-3/digital-format --create -t string -s "%H:%M:%S"
xfconf-query -c "$PANEL" -p /plugins/plugin-3/tooltip-format --create -t string -s "%A, %d %B %Y"
xfconf-query -c "$PANEL" -p /plugins/plugin-3/mode            --create -t uint   -s 2
xfconf-query -c "$PANEL" -p /plugins/plugin-3/digital-layout  --create -t uint   -s 3
xfconf-query -c "$PANEL" -p /plugins/plugin-3/ShowFrame       --create -t bool  -s false
set_plugin 4 pager
xfconf-query -c "$PANEL" -p /plugins/plugin-4/rows --create -t uint -s 1
xfconf-query -c "$PANEL" -p /plugins/plugin-4/mode --create -t uint -s 0
set_plugin 5 systemload
xfconf-query -c "$PANEL" -p /plugins/plugin-5/uptime --create -t bool -s false
xfconf-query -c "$PANEL" -p /plugins/plugin-5/cpu    --create -t bool -s false
xfconf-query -c "$PANEL" -p /plugins/plugin-5/memory --create -t bool -s true
xfconf-query -c "$PANEL" -p /plugins/plugin-5/swap   --create -t bool -s false
set_plugin 6 systray
set_plugin 7 pulseaudio
set_plugin 8 power-manager-plugin
set_plugin 9 separator
xfconf-query -c "$PANEL" -p /plugins/plugin-9/expand --create -t bool -s false
xfconf-query -c "$PANEL" -p /plugins/plugin-9/style  --create -t uint -s 0
set_plugin 10 actions

# urutan plugin & properti panel ala waybar By-LeyzS
xfconf-query -c "$PANEL" -p /panels/panel-1/plugin-ids \
    -t int -s 1 -t int -s 2 -t int -s 3 -t int -s 4 -t int -s 5 \
    -t int -s 6 -t int -s 7 -t int -s 8 -t int -s 9 -t int -s 10
xfconf-query -c "$PANEL" -p /panels/panel-1/length -s 100 2>/dev/null || true
xfconf-query -c "$PANEL" -p /panels/panel-1/length-adjust -s false 2>/dev/null || true
xfconf-query -c "$PANEL" -p /panels/panel-1/position -s "p=11;x=0;y=0" 2>/dev/null || true
xfconf-query -c "$PANEL" -p /panels/panel-1/position-locked -s true 2>/dev/null || true
xfconf-query -c "$PANEL" -p /panels/panel-1/size -s 44 2>/dev/null || true
xfconf-query -c "$PANEL" -p /panels/panel-1/nrows -s 1 2>/dev/null || true
xfconf-query -c "$PANEL" -p /panels/panel-1/mode -s 0 2>/dev/null || true
xfconf-query -c "$PANEL" -p /panels/panel-1/enter-opacity -s 100 2>/dev/null || true
xfconf-query -c "$PANEL" -p /panels/panel-1/leave-opacity -s 100 2>/dev/null || true
# bar transparan penuh ala window#waybar { background: transparent }
xfconf-query -c "$PANEL" -p /panels/panel-1/background-style -s 2 2>/dev/null || true

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
# tanpa -d/-o: conky di-daemonize sendiri oleh config (background=true)
nohup conky -c "$CONKY_CONF" >/tmp/conky-anime-glass.log 2>&1 &
sleep 2
if pgrep -f anime-glass.conf >/dev/null 2>&1; then
    echo "[ok] Conky anime-glass berjalan (kiri-tengah desktop, warna ikut wallpaper)."
else
    echo "[peringatan] Conky gagal start — cek /tmp/conky-anime-glass.log"
fi

echo ""
echo "Selesai. Panel ala By-LeyzS aktif (bar transparan, chip clock/pager/"
echo "systemload/systray/audio/power), info lengkap tetap di widget Conky."
echo "Ganti warna mengikuti wallpaper:  ./update-wallpaper.sh /path/gambar.jpg"