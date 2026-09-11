#!/usr/bin/env bash
IMG=""
for p in "$HOME/Documents/zhardeb/asset/影-removebg-preview.png" \
         "$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)/asset/影-removebg-preview.png" \
         "$HOME/.config/zhardeb/asset/影-removebg-preview.png"; do
    [ -f "$p" ] && IMG="$p" && break
done
MODE="${1:-auto}"
if [ "$MODE" = "auto" ]; then
    if [ -n "${KITTY_WINDOW_ID:-}" ] || [ "${TERM:-}" = "xterm-kitty" ]; then
        MODE="kitty"
    else
        _pp=$(ps -o comm= -p $PPID 2>/dev/null)
        case "$_pp" in *kitty*) MODE="kitty";; *) MODE="chafa";; esac
    fi
fi
LEFT=$(mktemp)
RIGHT=$(mktemp)
trap 'rm -f "$LEFT" "$RIGHT"' EXIT
if [ -n "$IMG" ]; then
    if [ "$MODE" = "kitty" ] && command -v kitty >/dev/null 2>&1; then
        if kitty +kitten icat --align left --place 32x16@0x0 --scale-up "$IMG" >"$LEFT" 2>/dev/null; then
            :
        elif kitty icat --align left --place 32x16@0x0 --scale-up "$IMG" >"$LEFT" 2>/dev/null; then
            :
        else
            chafa --format symbols --symbols block+border+space-wide-inverted --colors 256 --color-extractor median --work 9 --clear --size 32x16 "$IMG" >"$LEFT" 2>/dev/null || chafa --colors 256 --size 32x16 "$IMG" >"$LEFT" 2>/dev/null || echo "[img]" >"$LEFT"
        fi
    else
        if command -v chafa >/dev/null 2>&1; then
            chafa --format symbols --symbols block+border+space-wide-inverted --colors 256 --color-extractor median --work 9 --clear --size 32x16 "$IMG" >"$LEFT" 2>/dev/null || chafa --colors 256 --size 32x16 "$IMG" >"$LEFT" 2>/dev/null || echo "[img]" >"$LEFT"
        elif command -v jp2a >/dev/null 2>&1; then
            jp2a --width=32 "$IMG" >"$LEFT" 2>/dev/null || echo "[img]" >"$LEFT"
        else
            echo "" >"$LEFT"
        fi
    fi
else
    echo "" >"$LEFT"
fi
if command -v fastfetch >/dev/null 2>&1; then
    if [ -f "$HOME/.config/fastfetch/config.jsonc" ]; then
        fastfetch --logo none --config "$HOME/.config/fastfetch/config.jsonc" >"$RIGHT" 2>/dev/null || fastfetch --logo none >"$RIGHT" 2>/dev/null || fastfetch >"$RIGHT" 2>/dev/null
    else
        fastfetch --logo none >"$RIGHT" 2>/dev/null || fastfetch >"$RIGHT" 2>/dev/null
    fi
else
    {
        echo "OS: $(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '\"')"
        echo "Kernel: $(uname -r)"
        echo "Shell: $SHELL"
        echo "Uptime: $(uptime -p 2>/dev/null)"
        echo "User: $(whoami)@$(hostname)"
    } >"$RIGHT"
fi
COLS=$(tput cols 2>/dev/null || echo 80)
if [ "$COLS" -ge 90 ] && [ -s "$LEFT" ]; then
    pr -m -t -w "$COLS" "$LEFT" "$RIGHT" 2>/dev/null || paste "$LEFT" "$RIGHT" 2>/dev/null || { cat "$LEFT"; echo; cat "$RIGHT"; }
else
    [ -s "$LEFT" ] && cat "$LEFT" && echo
    cat "$RIGHT"
fi
printf '\033[0m\n'
