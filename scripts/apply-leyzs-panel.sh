#!/usr/bin/env bash
#
# apply-leyzs-panel.sh — tata panel Xfce ala waybar By-LeyzS:
#   clock (chip) | pager (workspaces bulat) | cpu+ram (systemload) | tray | audio | power
# Ditata via xfconf-query sehingga aman tanpa menimpa file XML kapan pun.
#
set -euo pipefail
export LC_NUMERIC=C   # hindari bug desimal koma (id_ID) di xfconf

PANEL="xfce4-panel"
command -v xfconf-query >/dev/null 2>&1 || { echo "[gagal] xfconf-query tidak ada."; exit 1; }
command -v "$PANEL"   >/dev/null 2>&1 || { echo "[gagal] xfce4-panel tidak ada."; exit 1; }

# --- helper ------------------------------------------------------------
set_plugin() {  # set_plugin <id-num> <nama-plugin>
    xfconf-query -c "$PANEL" -p "/plugins/plugin-$1" --create -t string -s "$2"
}
del_plugin() {
    xfconf-query -c "$PANEL" -p "/plugins/plugin-$1" -r 2>/dev/null || true
}

# --- 1. Reset plugin lama ----------------------------------------------
for n in $(seq 1 20); do del_plugin "$n"; done

# --- 2. Layout ala waybar By-LeyzS (config.jsonc) ----------------------
# waybar:  left  = clock, pulseaudio, media
#          center= hyprland/workspaces
#          right = tray, cpu, memory, separator, headset, notification, power
# Xfce  :  kiri   = showdesktop, applicationsmenu, clock (chip besar ala By-LeyzS)
#          tengah = pager (workspaces — di-gaya bulat via gtk.css)
#          kanan  = systemload (cpu+ram ala cpu/memory waybar),
#                   systray, pulseaudio, power-manager, separator, actions
set_plugin 1  showdesktop
set_plugin 2  applicationsmenu
set_plugin 3  clock
# clock ala By-LeyzS: H:M:S (interval 1s), font chip
xfconf-query -c "$PANEL" -p "/plugins/plugin-3/digital-format" --create -t string -s "%H:%M:%S"
xfconf-query -c "$PANEL" -p "/plugins/plugin-3/tooltip-format" --create -t string -s "%A, %d %B %Y"
xfconf-query -c "$PANEL" -p "/plugins/plugin-3/mode"            --create -t uint   -s 2
xfconf-query -c "$PANEL" -p "/plugins/plugin-3/digital-layout" --create -t uint   -s 3
xfconf-query -c "$PANEL" -p "/plugins/plugin-3/ShowFrame"       --create -t bool  -s false

# tengah: pager = workspace bulat ala #workspaces waybar
set_plugin 4 pager
xfconf-query -c "$PANEL" -p "/plugins/plugin-4/rows" --create -t uint -s 1
# mode: 0=nomor, 1=miniprakrin, 2=piksel
xfconf-query -c "$PANEL" -p "/plugins/plugin-4/mode" --create -t uint -s 0

# kanan: systemload (cpu+ram) ala modul cpu/memory waybar By-LeyzS
set_plugin 5 systemload
xfconf-query -c "$PANEL" -p "/plugins/plugin-5/uptime"  --create -t bool -s false
xfconf-query -c "$PANEL" -p "/plugins/plugin-5/cpu"     --create -t bool -s false
xfconf-query -c "$PANEL" -p "/plugins/plugin-5/memory"  --create -t bool -s true
xfconf-query -c "$PANEL" -p "/plugins/plugin-5/swap"    --create -t bool -s false
set_plugin 6 systray
xfconf-query -c "$PANEL" -p "/plugins/plugin-6/known-items" --create -t string -s ulauncher 2>/dev/null || true
set_plugin 7 pulseaudio
set_plugin 8 power-manager-plugin
set_plugin 9 separator
xfconf-query -c "$PANEL" -p "/plugins/plugin-9/expand" --create -t bool -s false
xfconf-query -c "$PANEL" -p "/plugins/plugin-9/style"  --create -t uint -s 0
set_plugin 10 actions

# --- 3. Properti panel (bar ala waybar: full-width top, height 38) -----
xfconf-query -c "$PANEL" -p /panels/panel-1/plugin-ids \
    -t int -s 1 -t int -s 2 -t int -s 3 -t int -s 4 -t int -s 5 \
    -t int -s 6 -t int -s 7 -t int -s 8 -t int -s 9 -t int -s 10
xfconf-query -c "$PANEL" -p /panels/panel-1/length -s 100
xfconf-query -c "$PANEL" -p /panels/panel-1/length-adjust -s false
xfconf-query -c "$PANEL" -p /panels/panel-1/position -s "p=11;x=0;y=0"
xfconf-query -c "$PANEL" -p /panels/panel-1/size -s 44
xfconf-query -c "$PANEL" -p /panels/panel-1/position-locked -s true
xfconf-query -c "$PANEL" -p /panels/panel-1/autohide-behavior -s 0
xfconf-query -c "$PANEL" -p /panels/panel-1/nrows -s 1
xfconf-query -c "$PANEL" -p /panels/panel-1/mode -s 0
# enter/leave opacity penuh (By-LeyzS bar transparan penuh, chip sendiri berwarna)
xfconf-query -c "$PANEL" -p /panels/panel-1/enter-opacity -s 100
xfconf-query -c "$PANEL" -p /panels/panel-1/leave-opacity -s 100
# latar panel: transparan penuh ala window#waybar { background: transparent }
# modul "chip" diberi bg+border oleh gtk.css (update-wallpaper.sh)
xfconf-query -c "$PANEL" -p /panels/panel-1/background-style -s 2   # 2 = transparan (None)

# --- 4. Restart panel ----------------------------------------------------
pkill -x "$PANEL" 2>/dev/null || true
sleep 1
nohup "$PANEL" >/dev/null 2>&1 &
sleep 2
pgrep -x "$PANEL" >/dev/null \
    && echo "[ok] Panel ala By-LeyzS aktif: clock | pager | cpu/ram | tray | audio | power" \
    || { echo "[peringatan] Panel gagal start — coba: xfce4-panel &"; exit 0; }
