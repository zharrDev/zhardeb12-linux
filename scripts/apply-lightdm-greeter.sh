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
#   - Tekstur kaca blur (frosted glass) -> glass-panel.jpg + glass-bar.jpg
#     (potongan wallpaper persis di area kartu & panel, blur pre-baked)
#   - Avatar user -> /usr/share/pixmaps/anime-glass-avatar.png + ~/.face
#   - Font Inter + tema/ikon system-wide (senada sesi desktop)
#   - Konfig greeter: kartu TENGAH layar, jam+tanggal Indonesia, panel glass
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
if ! command -v lightdm-gtk-greeter >/dev/null 2>&1 || ! dpkg -s fonts-inter >/dev/null 2>&1 \
   || ! dpkg -s accountsservice >/dev/null 2>&1; then
    say "Memasang paket (dilewati bila sudah ada)..."
    apt-get update -qq || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq lightdm lightdm-gtk-greeter fonts-inter accountsservice
fi
ok "lightdm + lightdm-gtk-greeter + fonts-inter + accountsservice siap"

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
# PENTING: copy harus BERSIH (hapus dulu tujuan lama) — cp -rn bisa meninggalkan
# tree parsial bila terganggu, dan tema ikon parsial = greeter CRASH (abort GTK).
for d in "/home/$REAL_USER/.themes"/catppuccin-mocha-blue* "/home/$REAL_USER/.themes"/Catppuccin*; do
    [ -d "$d" ] || continue
    rm -rf "/usr/share/themes/$(basename "$d")"
    cp -r "$d" /usr/share/themes/
done
ICON_SYS="/usr/share/icons/Tela-circle-blue-dark"
if [ -d "/home/$REAL_USER/.icons/Tela-circle-blue-dark" ]; then
    mkdir -p /usr/share/icons
    rm -rf "$ICON_SYS"
    cp -r "/home/$REAL_USER/.icons/Tela-circle-blue-dark" /usr/share/icons/
    gtk-update-icon-cache -f "$ICON_SYS" >/dev/null 2>&1 || true
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
# arsip versi TAJAM (kalau nanti mau dipakai lagi: --bg-blur 0)
install -m 644 "$LOGIN_SRC" "$LOGIN_BG_DIR/login-bg-sharp.jpg"

# ---------------------------- 2b) aset tampilan login (background + kaca + avatar)
# Greeter TIDAK punya compositor -> blur dipakai di muka (pre-baked):
#   login-bg.jpg     : wallpaper di-blur lembut + digelapkan + vignette
#   glass-panel.jpg  : tekstur kaca kartu (crop tepat di area kartu, blur ringan)
#   glass-bar.jpg    : tekstur kaca panel atas (band paling atas background)
AVATAR_SRC="$SRC_DIR/config/lightdm/avatar/anime-avatar.png"
AVATAR_SYS="/usr/share/pixmaps/anime-glass-avatar.png"

# Resolusi layar (bila DISPLAY ada) supaya crop sesuai; kalau tidak -> 1920x1080
SCREEN_SIZE="1920x1080"
if command -v xrandr >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    RES="$(xrandr 2>/dev/null | awk '/[*]/ {print $1; exit}')"
    [ -n "$RES" ] && SCREEN_SIZE="$RES"
fi

if command -v python3 >/dev/null 2>&1 && [ -f "$SRC_DIR/scripts/login-assets.py" ]; then
    python3 "$SRC_DIR/scripts/login-assets.py" --src "$LOGIN_SRC" --outdir "$LOGIN_BG_DIR" \
        --size "$SCREEN_SIZE" --bg-blur 16 --card-blur 8 --dim 0.90 --vignette 0.60 \
        || say "gagal membuat aset login — pakai wallpaper apa adanya"
fi
# jaring terakhir: pastikan ketiga berkas ada (tanpa blur pun tetap tampil)
[ -f "$LOGIN_BG_DIR/login-bg.jpg" ]    || install -m 644 "$LOGIN_SRC" "$LOGIN_BG_DIR/login-bg.jpg"
[ -f "$LOGIN_BG_DIR/glass-panel.jpg" ] || cp "$LOGIN_BG_DIR/login-bg.jpg" "$LOGIN_BG_DIR/glass-panel.jpg"
[ -f "$LOGIN_BG_DIR/glass-bar.jpg" ]   || cp "$LOGIN_BG_DIR/login-bg.jpg" "$LOGIN_BG_DIR/glass-bar.jpg"
ok "Aset login -> login-bg.jpg (blur+vignette), glass-panel.jpg, glass-bar.jpg"

# Avatar anime untuk user login (juga dipakai greeter via default-user-image)
if [ -f "$AVATAR_SRC" ]; then
    install -m 644 "$AVATAR_SRC" "$AVATAR_SYS"
    ok "Avatar login -> $AVATAR_SYS"
    FACE="/home/$REAL_USER/.face"
    if [ -d "/home/$REAL_USER" ]; then
        if [ -f "$FACE" ]; then
            cp -a "$FACE" "${FACE}.bak.$(date +%s)"
            rm -f "$FACE"
        fi
        install -o "$REAL_USER" -g "$(id -gn "$REAL_USER")" -m 644 "$AVATAR_SRC" "$FACE"
        rm -f "/home/$REAL_USER/.face.icon"
        ln -sf .face "/home/$REAL_USER/.face.icon"
        ok "Avatar user -> $FACE (+ .face.icon; yang lama di-backup)"
    fi
else
    printf '\033[1;33m[!]\033[0m avatar tidak ditemukan: %s\n' "$AVATAR_SRC" >&2
fi

# ---------------------------------------------------- 3) konfig greeter
[ -f "$GREETER_CONF" ] && cp -a "$GREETER_CONF" "${GREETER_CONF}.bak.$(date +%s)" || true
sed -e "s|__LOGIN_BG__|${LOGIN_BG_DIR}/login-bg.jpg|g" \
    -e "s|__AVATAR__|${AVATAR_SYS}|g" \
    -e "s|__USER__|${REAL_USER}|g" \
    "$SRC_DIR/config/lightdm/lightdm-gtk-greeter.conf" > "$GREETER_CONF"
chmod 644 "$GREETER_CONF"
ok "Config -> $GREETER_CONF (backup: *.bak.*)"

# Verifikasi integritas ikon system — bila copy tidak lengkap (greeter berjalan
# sebagai user lightdm yang hanya membaca /usr/share), fallback ke Adwaita.
# CATATAN: harus SETELAH conf ditulis (section 3), bukan sebelumnya.
ICON_SYS="/usr/share/icons/Tela-circle-blue-dark"
if [ -f "$ICON_SYS/16/actions/image-missing.svg" ] && [ -d "$ICON_SYS/scalable/apps" ]; then
    ok "ikon system Tela-circle-blue-dark lengkap ($(find "$ICON_SYS" -name '*.svg' | wc -l) svg)"
else
    sed -i 's|^icon-theme-name=.*|icon-theme-name=Adwaita|' "$GREETER_CONF"
    ok "ikon system Tela tidak lengkap -> greeter fallback ke Adwaita"
fi

# ---------------------------------------------------- 4) session & autologin (via drop-in conf.d)
# LightDM membaca: /etc/lightdm/lightdm.conf.d/*.conf LALU /etc/lightdm/lightdm.conf.
# Karena main conf dibaca TERAKHIR (menimpa drop-in), semua key yang dulu pernah
# kita sed-kan ke main conf dikomentari lagi supaya drop-in jadi sumber kebenaran.
MAIN_CONF="/etc/lightdm/lightdm.conf"
[ -f "$MAIN_CONF" ] || touch "$MAIN_CONF"
cp -a "$MAIN_CONF" "${MAIN_CONF}.bak.$(date +%s)"
sed -i -E 's@^(\s*(greeter-session|user-session|autologin-user|autologin-user-timeout|autologin-session)=.*)@# \1   # dinonaktifkan oleh apply-lightdm-greeter (pindah ke conf.d/50-anime-glass.conf)@' "$MAIN_CONF"

# deteksi session yang tersedia (utamakan xfce)
USER_SESSION=""
for s in /usr/share/xsessions/*.desktop; do
    [ -f "$s" ] || continue
    n=$(basename "$s" .desktop)
    [ "$n" = "xfce" ] && USER_SESSION="xfce" && break
    [ -z "$USER_SESSION" ] && USER_SESSION="$n"
done
[ -n "$USER_SESSION" ] || USER_SESSION="xfce"

DROPIN="/etc/lightdm/lightdm.conf.d/50-anime-glass.conf"
mkdir -p /etc/lightdm/lightdm.conf.d
{
    echo "# Anime Glass — dibuat oleh scripts/apply-lightdm-greeter.sh"
    echo "[LightDM]"
    echo "greeter-session=lightdm-gtk-greeter"
    echo ""
    echo "[Seat:*]"
    echo "user-session=$USER_SESSION"
    if [ "$AUTOLOGIN" -eq 1 ]; then
        echo "autologin-user=$REAL_USER"
        echo "autologin-user-timeout=0"
        echo "autologin-session=$USER_SESSION"
    else
        echo "autologin-user="
    fi
} > "$DROPIN"
chmod 644 "$DROPIN"
ok "Konfig seat -> $DROPIN (session: $USER_SESSION)"

# grup 'autologin' WAJIB ada & user harus anggotanya — tanpa ini PAM menolak
# autologin dan lightdm bisa gagal total saat boot (seat error).
if [ "$AUTOLOGIN" -eq 1 ]; then
    getent group autologin >/dev/null 2>&1 || groupadd --system autologin
    id -nG "$REAL_USER" 2>/dev/null | grep -qw autologin || usermod -aG autologin "$REAL_USER"
    ok "user $REAL_USER masuk grup 'autologin'"
fi

if [ "$AUTOLOGIN" -eq 1 ]; then
    ok "login otomatis aktif untuk: $REAL_USER (matikan: sudo bash $0 --no-autologin)"
else
    ok "login otomatis dimatikan (tampil kartu login)"
fi

ok "SELESAI. Uji: sudo systemctl restart lightdm (sesi akan ditutup!) atau reboot."
