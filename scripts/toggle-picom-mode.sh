#!/usr/bin/env bash
#
# toggle-picom-mode.sh — toggle picom antara mode glass (full blur) & lowmem.
#
# Cocok untuk sistem RAM terbatas (4GB) dengan GPU terintegrasi (Intel UHD)
# yang shares system RAM untuk framebuffer. Blur = GPU memory = system RAM.
#
#   ./toggle-picom-mode.sh          # toggle antar mode
#   ./toggle-picom-mode.sh glass    # mode glass (blur on, rounded 10px)
#   ./toggle-picom-mode.sh lowmem   # mode lowmem (blur off, rounded 5px)
#   ./toggle-picom-mode.sh status   # cek mode aktif
#
set -euo pipefail
PICOM_BIN="$HOME/.local/bin/picom"
CONF_GLASS="$HOME/.config/picom.conf"
CONF_LOWMEM="$HOME/.config/picom/picom-lowmem.conf"
STATE_FILE="$HOME/.cache/zhardeb/picom-mode"
mkdir -p "$HOME/.cache/zhardeb"

MODE="${1:-toggle}"

if [ "$MODE" = "status" ]; then
    if [ -f "$STATE_FILE" ]; then
        echo "picom mode: $(cat "$STATE_FILE")"
    else
        echo "picom mode: unknown"
    fi
    pgrep -x picom >/dev/null 2>&1 && echo "picom: running" || echo "picom: not running"
    exit 0
fi

# tentukan mode
if [ "$MODE" = "toggle" ]; then
    CUR=$(cat "$STATE_FILE" 2>/dev/null || echo "glass")
    if [ "$CUR" = "glass" ]; then MODE="lowmem"; else MODE="glass"; fi
fi

case "$MODE" in
    glass) CONF="$CONF_GLASS" ;;
    lowmem) CONF="$CONF_LOWMEM" ;;
    *) echo "mode tidak dikenal: $MODE (pilih: glass|lowmem|status)"; exit 1 ;;
esac

[ -x "$PICOM_BIN" ] || PICOM_BIN="picom"
[ -f "$CONF" ] || { echo "[gagal] config tidak ada: $CONF"; exit 1; }

# restart picom dengan config baru
if pgrep -x picom >/dev/null 2>&1; then
    pkill -x picom 2>/dev/null || true
    sleep 0.3
fi
nohup "$PICOM_BIN" --config "$CONF" --daemon </dev/null >/dev/null 2>&1 &
printf '%s' "$MODE" > "$STATE_FILE" 2>/dev/null || true
echo "picom di-switch ke mode: $MODE"
