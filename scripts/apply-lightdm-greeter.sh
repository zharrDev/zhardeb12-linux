#!/usr/bin/env bash
#
# apply-lightdm-greeter.sh — deploy Anime Glass login screen config.
# Perlu sudo (menulis ke /etc/lightdm/ & /usr/share/themes/).
#
# Cara pakai:
#   sudo bash ~/Documents/zhardeb/scripts/apply-lightdm-greeter.sh
#
set -euo pipefail
SRC_DIR="$(cd "$(dirname "$0")" && cd .. && pwd)"
THEME_DIR="/usr/share/themes/anime-glass-greeter/gtk-3.0"
GREETER_CONF="/etc/lightdm/lightdm-gtk-greeter.conf"
LOGIN_BG_DIR="/usr/share/backgrounds/anime-glass"

echo "[login] Deploy Anime Glass login screen..."

# 1. Install tema greeter ke /usr/share/themes (readable semua user termasuk lightdm)
mkdir -p "$THEME_DIR"
cp -f "$SRC_DIR/config/lightdm/themes/anime-glass-greeter/gtk-3.0/gtk.css" "$THEME_DIR/gtk.css"
echo "[login] Theme CSS -> $THEME_DIR/gtk.css"

# 2. Install wallpaper login ke sistem
mkdir -p "$LOGIN_BG_DIR"
cp -f "$SRC_DIR/config/wallpapers/login/anime-login-bg.jpg" "$LOGIN_BG_DIR/login-bg.jpg"
chmod 644 "$LOGIN_BG_DIR/login-bg.jpg"
echo "[login] Wallpaper -> $LOGIN_BG_DIR/login-bg.jpg"

# 3. Backup & install greeter config
[ -f "$GREETER_CONF" ] && cp -a "$GREETER_CONF" "${GREETER_CONF}.bak.$(date +%s)" || true
# gunakan anime-login-bg.jpg sebagai background (path sistem, readable lightdm)
sed -e "s|/home/suo/Pictures/Wallpapers/Anime/purple-nature.png|${LOGIN_BG_DIR}/login-bg.jpg|g" \
    -e "s|/home/suo/.config/conky/anime-avatar.png|${LOGIN_BG_DIR}/login-bg.jpg|g" \
    "$SRC_DIR/config/lightdm/lightdm-gtk-greeter.conf" > "$GREETER_CONF"
chmod 644 "$GREETER_CONF"
echo "[login] Config -> $GREETER_CONF"
echo "[login] Selesai. Restart lightdm untuk lihat: sudo systemctl restart lightdm"
