#!/bin/sh
#
# greeter-anim-launch.sh — dipanggil LightDM otomatis (greeter-setup-script)
#
# Tugasnya cuma menyalakan overlay animasi di latar belakang lalu keluar
# seketika, supaya greeter tidak tertunda sedetik pun. Semua kerjanya ada di
# greeter-anim-launch.py; kalau gagal, layar login tetap tampil normal.
#
LOG=/var/log/anime-glass-anim.log
DIR=/usr/local/share/anime-glass

[ -n "${DISPLAY:-}" ] || { echo "[anim] DISPLAY kosong, animasi dilewati" >>"$LOG"; exit 0; }
[ -x /usr/bin/python3 ] || exit 0
[ -f "$DIR/greeter-anim-launch.py" ] || exit 0

# X server milik LightDM butuh cookie ini saat root belum punya XAUTHORITY
if [ -z "${XAUTHORITY:-}" ] && [ -f /var/run/lightdm/root/:0 ]; then
    XAUTHORITY=/var/run/lightdm/root/:0
    export XAUTHORITY
fi

setsid /usr/bin/python3 "$DIR/greeter-anim-launch.py" >>"$LOG" 2>&1 &
exit 0
