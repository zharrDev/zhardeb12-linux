#!/usr/bin/env bash
#
# apply-lightdm-greeter.sh — deploy Anime Glass login screen (LightDM).
# Perlu sudo (menulis ke /etc/lightdm/ & /usr/share/).
#
# Cara pakai:
#   sudo bash ~/Documents/zhardeb/scripts/apply-lightdm-greeter.sh
#   sudo bash ~/Documents/zhardeb/scripts/apply-lightdm-greeter.sh --no-autologin
#
# Yang dipasang:
#   - Tema greeter custom (CSS glass) -> /usr/share/themes/anime-glass-greeter
#   - Wallpaper login -> /usr/share/backgrounds/anime-glass/login-bg.jpg
#     (prioritas: config/wallpapers/login/, fallback: wallpaper aktif desktop)
#   - Font Inter + tema/ikon system-wide (senada sesi desktop)
#   - Konfig greeter: jam+tanggal Indonesia, panel glass, kartu login glass
#   - Login otomatis (matikan dengan --no-autologin)
#
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && cd .. && pwd)"
THEME_DIR="/usr/share/themes/anime-glass-greeter/gtk-3.0"
GREETER_CONF="/etc/lightdm/lightdm-gtk-greeter.conf"
LOGIN_BG_DIR="/usr/share/backgrounds/anime-glass"
AUTOLOGIN=1
[ "${1:-}" = "--no-autologin" ] && AUTOLOGIN=0

say()  { printf '\033[1;36m[login]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ok]\033[0m %s\n' "$*"; }
REAL_USER="${SUDO_USER:-$USER}"

if [ "$(id -u)" -ne 0 ]; then
    printf '\033[1;31m[gagal]\033[0m jalankan dengan sudo\n' >&2
    exit 1
fi

# ---------------------------------------------------------------- 0) paket
if ! command -v lightdm-gtk-greeter >/dev/null 2>&1 || ! dpkg -s fonts-inter >/dev/null 2>&1; then
    say "Memasang paket (dilewati bila sudah ada)..."
    apt-get update -qq || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq lightdm lightdm-gtk-greeter fonts-inter
fi
ok "lightdm + lightdm-gtk-greeter + fonts-inter siap"

# Font Nerd Font user -> system-wide (agar tersedia di greeter & display manager)
for d in "/home/$REAL_USER/.local/share/fonts" "$HOME/.local/share/fonts"; do
    if [ -d "$d" ] && compgen -G "$d/*JetBrainsMono*" >/dev/null; then
        mkdir -p /usr/local/share/fonts/nerd
        cp -un "$d"/JetBrainsMonoNerdFont-*.ttf /usr/local/share/fonts/nerd/ 2>/dev/null || true
    fi
done
fc-cache -f >/dev/null 2>&1 || true

# ---------------------------------------------------- 1) tema greeter (CSS glass)
mkdir -p "$THEME_DIR"
cp -f "$SRC_DIR/config/lightdm/themes/anime-glass-greeter/gtk-3.0/gtk.css" "$THEME_DIR/gtk.css"
ok "Theme CSS -> $THEME_DIR/gtk.css"

# Tema GTK + ikon user -> system-wide (greeter berjalan sebagai user lightdm)
for d in "/home/$REAL_USER/.themes"/catppuccin-mocha-blue* "/home/$REAL_USER/.themes"/Catppuccin*; do
    [ -d "$d" ] || continue
    mkdir -p /usr/share/themes
    cp -rn "$d" /usr/share/themes/ 2>/dev/null || true
done
if [ -d "/home/$REAL_USER/.icons/Tela-circle-blue-dark" ]; then
    mkdir -p /usr/share/icons
    cp -rn "/home/$REAL_USER/.icons/Tela-circle-blue-dark" /usr/share/icons/ 2>/dev/null || true
fi

# ---------------------------------------------------- 2) wallpaper login
# Prioritas: gambar landscape di config/wallpapers/login/ repo.
# Fallback : wallpaper aktif desktop (anime-1920x1080.jpg, sudah landscape).
LOGIN_SRC=""
for f in "$SRC_DIR"/config/wallpapers/login/*.jpg \
         "$SRC_DIR"/config/wallpapers/login/*.jpeg \
         "$SRC_DIR"/config/wallpapers/login/*.png; do
    [ -f "$f" ] && LOGIN_SRC="$f" && break
done
if [ -z "$LOGIN_SRC" ]; then
    for f in "/home/$REAL_USER/Pictures/Wallpapers/Anime/anime-1920x1080.jpg" \
             "$HOME/Pictures/Wallpapers/Anime/anime-1920x1080.jpg"; do
        [ -f "$f" ] && LOGIN_SRC="$f" && break
    done
fi
[ -n "$LOGIN_SRC" ] || { printf '[login] tidak ada wallpaper login ditemukan\n' >&2; exit 1; }

mkdir -p "$LOGIN_BG_DIR"
install -m 644 "$LOGIN_SRC" "$LOGIN_BG_DIR/login-bg.jpg"
ok "Wallpaper -> $LOGIN_BG_DIR/login-bg.jpg ($(basename "$LOGIN_SRC"))"

# ---------------------------------------------------- 3) konfig greeter
[ -f "$GREETER_CONF" ] && cp -a "$GREETER_CONF" "${GREETER_CONF}.bak.$(date +%s)" || true
sed -e "s|__LOGIN_BG__|${LOGIN_BG_DIR}/login-bg.jpg|g" \
    -e "s|__USER__|${REAL_USER}|g" \
    "$SRC_DIR/config/lightdm/lightdm-gtk-greeter.conf" > "$GREETER_CONF"
chmod 644 "$GREETER_CONF"
ok "Config -> $GREETER_CONF (backup: *.bak.*)"

# ---------------------------------------------------- 4) greeter session + autologin
# rapikan dulu: gabungkan baris greeter-session ganda jadi satu
sed -i 's|^#\?greeter-session=.*|greeter-session=lightdm-gtk-greeter|' /etc/lightdm/lightdm.conf
awk '!/^greeter-session=/ || !seen[$0]++' /etc/lightdm/lightdm.conf > /tmp/lightdm.conf.tmp \
    && mv /tmp/lightdm.conf.tmp /etc/lightdm/lightdm.conf
if [ "$AUTOLOGIN" -eq 1 ]; then
    sed -i "s|^#\?autologin-user=.*|autologin-user=$REAL_USER|"  /etc/lightdm/lightdm.conf
    sed -i 's|^#\?autologin-user-timeout=.*|autologin-user-timeout=0|' /etc/lightdm/lightdm.conf
    sed -i 's|^#\?autologin-session=.*|autologin-session=xfce|'  /etc/lightdm/lightdm.conf
    grep -q "^autologin-user=" /etc/lightdm/lightdm.conf || \
        sed -i "0,/\[Seat:\*\]/s//&\nautologin-user=$REAL_USER\nautologin-user-timeout=0\nautologin-session=xfce/" /etc/lightdm/lightdm.conf
    # autologin-session kadang tidak ada barisnya — tambahkan setelah autologin-user
    grep -q "^autologin-session=" /etc/lightdm/lightdm.conf || \
        sed -i "/^autologin-user=/a autologin-session=xfce" /etc/lightdm/lightdm.conf
    ok "login otomatis aktif untuk: $REAL_USER (matikan: sudo bash $0 --no-autologin)"
else
    sed -i 's|^#\?autologin-user=.*|autologin-user=|' /etc/lightdm/lightdm.conf
    ok "login otomatis dimatikan (tampil kartu login)"
fi

ok "SELESAI. Uji: sudo systemctl restart lightdm (sesi akan ditutup!) atau reboot."
