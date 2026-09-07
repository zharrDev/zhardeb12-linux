#!/usr/bin/env bash
#
# xfce-anime-setup.sh
# ------------------------------------------------------------
# Setup otomatis Desktop Environment Xfce (Debian 12) dengan
# estetika "Anime Glassmorphism / Vibrant Aesthetic".
#
# Fitur:
#   - Install Picom (compositor) + konfigurasi glassmorphism ringan
#   - Install Nerd Font (JetBrainsMono Nerd Font)
#   - Install tema GTK (Catppuccin Mocha / WhiteSur) + Icon pack (Tela-circle / Papirus)
#   - Konfigurasi xfce4-terminal: palette pastel anime, background semi-transparan
#   - Panel Xfce floating & semi-transparan (opsional, --apply-panel)
#   - Wallpaper anime landscape (blur-fill) dari asset proyek ini
#   - Pywal untuk warna otomatis mengikuti wallpaper (opsional, --pywal)
#
# Cara pakai:
#   bash xfce-anime-setup.sh                 # install + terapkan konfigurasi
#   bash xfce-anime-setup.sh --apply-panel   # + ganti layout panel jadi floating
#   bash xfce-anime-setup.sh --pywal         # + install pywal16 (warna ikut wallpaper)
#   bash xfce-anime-setup.sh --kitty         # + konfigurasi kitty (bukan xfce4-terminal)
#
# Variabel lingkungan yang bisa diubah:
#   THEME=whitesur ICONS=papirus RESOLUTION=2560x1440 bash xfce-anime-setup.sh
#
# Aman & idempotent: semua berkas yang sudah ada di-backup dulu (.bak),
# tidak menghapus apa pun, hanya menambah/mengganti konfigurasi milik sendiri.
# ------------------------------------------------------------
set -euo pipefail

# ================= Konfigurasi =================
THEME="${THEME:-catppuccin}"        # catppuccin | whitesur
ICONS="${ICONS:-papirus}"         # tela-circle | papirus (default: papirus, lebih stabil di Debian 12)
RESOLUTION="${RESOLUTION:-1920x1080}"
WALL_DIR="$HOME/Pictures/Wallpapers/Anime"
FONT_DIR="$HOME/.local/share/fonts"
THEME_DIR="$HOME/.themes"
ICON_DIR="$HOME/.icons"
CFG_DIR="$HOME/.config"
AUTOSTART_DIR="$CFG_DIR/autostart"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Flag CLI
APPLY_PANEL=0
WITH_KITTY=0
WITH_PYWAL=0
SKIP_INSTALL=0
for arg in "$@"; do
    case "$arg" in
        --apply-panel) APPLY_PANEL=1 ;;
        --kitty)       WITH_KITTY=1 ;;
        --pywal)       WITH_PYWAL=1 ;;
        --skip-install) SKIP_INSTALL=1 ;;
        *) echo "Opsi tidak dikenal: $arg" >&2; exit 1 ;;
    esac
done

# ================= Helper =================
msg()  { printf '\033[1;36m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[peringatan]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[gagal]\033[0m %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Perintah '$1' tidak ditemukan. Jalankan ulang tanpa --skip-install."; }

apt_install() {
    local pkgs=("$@")
    sudo apt-get update -y
    sudo apt-get install -y "${pkgs[@]}"
}

# Backup lalu salin berkas, buat direktori induk bila perlu.
install_file() {  # <sumber> <tujuan>
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -e "$dst.bak" ]; then
        cp -a "$dst" "$dst.bak"
        msg "Backup konfigurasi lama -> $dst.bak"
    fi
    cp -f "$src" "$dst"
    msg "Pasang konfigurasi -> $dst"
}

set_xfconf() {  # <channel> <properti> <type> <nilai>
    local chan="$1" prop="$2" type="$3" val="$4"
    xfconf-query -c "$chan" -p "$prop" -s "$val" --create -t "$type" 2>/dev/null \
        || xfconf-query -c "$chan" -p "$prop" -s "$val" -t "$type" 2>/dev/null \
        || warn "Gagal set $chan:$prop (abaikan)"
}

# ================= 1. Cek sistem =================
[ -f /etc/debian_version ] || die "Skrip ini untuk Debian (atau turunan Debian)."
command -v sudo >/dev/null 2>&1 || die "sudo diperlukan."
need_cmd xfconf-query

# ================= 2. Install paket =================
if [ "$SKIP_INSTALL" -eq 0 ]; then
    msg "Menginstall paket pendukung (picom, terminal, font, tooling)..."
    apt_install picom xfce4-terminal imagemagick unzip curl \
        fonts-inter fonts-noto-color-emoji \
        xsettingsd xfce4-settings python3-pip

    # --- Nerd Font: JetBrainsMono ---
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
        msg "Nerd Font sudah terpasang, lewati unduhan."
    else
        msg "Mengunduh JetBrainsMono Nerd Font (~80 MB)..."
        mkdir -p "$FONT_DIR"
        curl -fL --retry 3 -o /tmp/jetbrains-nerd.zip \
            https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip \
            || die "Gagal mengunduh Nerd Font (periksa koneksi)."
        unzip -oq /tmp/jetbrains-nerd.zip -d "$FONT_DIR" || die "Gagal mengekstrak font."
        rm -f /tmp/jetbrains-nerd.zip
        fc-cache -f >/dev/null 2>&1 || true
        msg "Nerd Font terpasang."
    fi

    # --- Tema GTK: Catppuccin (default, pastel & ringan) ---
    if [ "$THEME" = "catppuccin" ]; then
        if [ -d "$THEME_DIR/catppuccin-mocha-blue-standard+default" ]; then
            msg "Tema Catppuccin sudah ada, lewati unduhan."
        else
            msg "Mengunduh tema GTK Catppuccin Mocha..."
            mkdir -p "$THEME_DIR"
            curl -fL --retry 3 -o /tmp/catppuccin-gtk.zip \
                "https://github.com/catppuccin/gtk/releases/latest/download/catppuccin-mocha-blue-standard%2Bdefault.zip" \
                || die "Gagal mengunduh tema Catppuccin."
            unzip -oq /tmp/catppuccin-gtk.zip -d "$THEME_DIR" || die "Gagal mengekstrak tema."
            rm -f /tmp/catppuccin-gtk.zip
        fi
        GTK_THEME="catppuccin-mocha-blue-standard+default"
        XFWM_THEME="$GTK_THEME"

    # --- Tema GTK: WhiteSur (alternatif, glassy macOS-like) ---
    elif [ "$THEME" = "whitesur" ]; then
        if [ -d "$THEME_DIR/WhiteSur-dark" ]; then
            msg "Tema WhiteSur sudah ada, lewati instalasi."
        else
            msg "Mengunduh & menginstall tema WhiteSur (butuh git)..."
            apt_install git
            rm -rf /tmp/WhiteSur-gtk-theme
            git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/WhiteSur-gtk-theme \
                || die "Gagal clone WhiteSur."
            /tmp/WhiteSur-gtk-theme/install.sh -d "$THEME_DIR" -t all -T || warn "Installer WhiteSur gagal."
        fi
        GTK_THEME="WhiteSur-dark"
        XFWM_THEME="WhiteSur-dark"
    else
        die "THEME tidak dikenal: $THEME (pilihan: catppuccin | whitesur)"
    fi

    # --- Icon pack ---
    if [ "$ICONS" = "tela-circle" ]; then
        if [ -d "$ICON_DIR/Tela-circle-dark" ]; then
            msg "Icon pack Tela-circle sudah ada, lewati unduhan."
            ICON_THEME="Tela-circle-dark"
        else
            msg "Mengunduh icon pack Tela-circle (jika gagal, akan fallback ke Papirus)..."
            mkdir -p "$ICON_DIR"
            if curl -fL --retry 2 -o /tmp/tela-circle.zip \
                https://github.com/vinceliuice/Tela-circle-icon-theme/releases/latest/download/Tela-circle-dark.zip \
                && unzip -oq /tmp/tela-circle.zip -d "$ICON_DIR" 2>/dev/null && [ -d "$ICON_DIR/Tela-circle-dark" ]; then
                msg "Tela-circle berhasil diunduh."
                ICON_THEME="Tela-circle-dark"
            else
                warn "Tidak bisa mengunduh Tela-circle (repo GitHub tidak menyediakan asset zip terbaru)."
                warn "Fallback ke Papirus (via apt)..."
                apt_install papirus-icon-theme
                ICON_THEME="Papirus-Dark"
            fi
            rm -f /tmp/tela-circle.zip
        fi
    elif [ "$ICONS" = "papirus" ]; then
        apt_install papirus-icon-theme
        ICON_THEME="Papirus-Dark"
    else
        die "ICONS tidak dikenal: $ICONS (pilihan: tela-circle | papirus)"
    fi
else
    # Mode --skip-install: tetap butuh nama tema untuk diterapkan
    if [ "$THEME" = "catppuccin" ]; then
        GTK_THEME="catppuccin-mocha-blue-standard+default"; XFWM_THEME="$GTK_THEME"
    else
        GTK_THEME="WhiteSur-dark"; XFWM_THEME="WhiteSur-dark"
    fi
    [ "$ICONS" = "papirus" ] && ICON_THEME="Papirus-Dark" || ICON_THEME="Tela-circle-dark"  # note: bila Tela-circle gagal di --skip-install, folder Tela-circle-dark belum tentu ada di disk
fi

# ================= 3. Konfigurasi (picom, terminal, gtk) =================
msg "Menempatkan berkas konfigurasi di ~/.config/ ..."
mkdir -p "$CFG_DIR/picom" "$CFG_DIR/xfce4/terminal" "$CFG_DIR/gtk-3.0" "$CFG_DIR/autostart"

install_file "$SRC_DIR/config/picom/picom.conf"   "$CFG_DIR/picom/picom.conf"
install_file "$SRC_DIR/config/gtk-3.0/settings.ini" "$CFG_DIR/gtk-3.0/settings.ini"
install_file "$SRC_DIR/config/gtk-3.0/gtk.css"      "$CFG_DIR/gtk-3.0/gtk.css"

# terminalrc: isi ulang hanya jika belum pernah dibuat oleh skrip ini
TERM_RC="$CFG_DIR/xfce4/terminal/terminalrc"
if [ -e "$TERM_RC.bak" ]; then
    msg "terminalrc sudah dikonfigurasi sebelumnya, lewati."
else
    install_file "$SRC_DIR/config/xfce4/terminal/terminalrc" "$TERM_RC"
fi

if [ "$WITH_KITTY" -eq 1 ]; then
    msg "Menginstall kitty (opsional)..."
    apt_install kitty
    install_file "$SRC_DIR/config/kitty/kitty.conf" "$CFG_DIR/kitty/kitty.conf"
fi

# ================= 4. Wallpaper anime (landscape blur-fill) =================
# Semua gambar di asset/ disalin ke ~/Pictures/Wallpapers/Anime/;
# gambar utama (916764067907298333.jpeg) dipakai sebagai wallpaper default.
mkdir -p "$WALL_DIR"
PRIMARY="916764067907298333.jpeg"
DEFAULT_IMG=""
for f in "$SRC_DIR"/asset/*.jpeg "$SRC_DIR"/asset/*.jpg "$SRC_DIR"/asset/*.png; do
    [ -f "$f" ] || continue
    cp -f "$f" "$WALL_DIR/$(basename "$f")"
    [ "$(basename "$f")" = "$PRIMARY" ] && DEFAULT_IMG="$f"
done
msg "Semua gambar anime disalin -> $WALL_DIR/"

# Fallback: bila gambar utama tidak ada, pakai gambar pertama yang ditemukan
if [ -z "$DEFAULT_IMG" ]; then
    for f in "$SRC_DIR"/asset/*.jpeg "$SRC_DIR"/asset/*.jpg "$SRC_DIR"/asset/*.png; do
        [ -f "$f" ] && DEFAULT_IMG="$f" && break
    done
fi

if [ -n "$DEFAULT_IMG" ]; then
    LANDSCAPE="$WALL_DIR/anime-${RESOLUTION}.jpg"
    if [ ! -e "$LANDSCAPE" ]; then
        msg "Membuat wallpaper landscape ${RESOLUTION} (blur-fill)..."
        W="${RESOLUTION%x*}"; H="${RESOLUTION#*x}"
        convert "$DEFAULT_IMG" \
            \( -clone 0 -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" -blur 0x35 -brightness-contrast -10 \) \
            \( -clone 0 -resize "x${H}" \) \
            -delete 0 -gravity center -composite -quality 92 "$LANDSCAPE"
    fi
    msg "Wallpaper landscape -> $LANDSCAPE"

    # Terapkan sebagai wallpaper desktop Xfce (semua monitor/workspace)
    for key in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep 'last-image' || true); do
        xfconf-query -c xfce4-desktop -p "$key" -s "$LANDSCAPE" 2>/dev/null || true
    done
    msg "Wallpaper diterapkan ke desktop."
else
    warn "Tidak ada gambar di folder asset/ — wallpaper dilewati."
fi

# ================= 5. Terapkan tema GTK, ikon, font =================
msg "Menerapkan tema & font ke Xfce..."
set_xfconf xsettings /Gtk/ThemeName    string "$GTK_THEME"
set_xfconf xsettings /Gtk/IconThemeName string "$ICON_THEME"
set_xfconf xsettings /Gtk/FontName     string "Inter 10"
set_xfconf xsettings /Net/ThemeName    string "$GTK_THEME"
set_xfconf xfwm4 /general/theme        string "$XFWM_THEME"
set_xfconf xfwm4 /general/title_font   string "Inter Bold 9"

# ================= 6. Compositor: picom menggantikan compositor bawaan xfwm4 =================
msg "Mengaktifkan picom (matikan compositor bawaan xfwm4)..."
set_xfconf xfwm4 /general/use_compositing bool false

cat > "$AUTOSTART_DIR/picom.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Picom (compositor)
Comment=Glassmorphism compositor
Exec=picom --daemon
X-GNOME-Autostart-enabled=true
EOF
msg "Autostart picom -> $AUTOSTART_DIR/picom.desktop"
pkill -x picom 2>/dev/null || true
picom --daemon 2>/dev/null && msg "Picom berjalan." || warn "Picom gagal start (cek driver GPU)."

# ================= 7. Panel floating (opsional) =================
if [ "$APPLY_PANEL" -eq 1 ]; then
    PANEL_XML="$CFG_DIR/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
    if [ -e "$PANEL_XML" ] && [ ! -e "$PANEL_XML.bak" ]; then
        cp -a "$PANEL_XML" "$PANEL_XML.bak"
        msg "Backup panel -> $PANEL_XML.bak"
    fi
    install_file "$SRC_DIR/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" "$PANEL_XML"
    xfce4-panel --restart 2>/dev/null || pkill -x xfce4-panel 2>/dev/null || true
    msg "Panel floating diterapkan. Jika posisi belum pas, buka kunci panel lalu geser."
fi

# ================= 8. Pywal (opsional) =================
if [ "$WITH_PYWAL" -eq 1 ]; then
    if command -v wal >/dev/null 2>&1; then
        msg "Pywal sudah terpasang."
    else
        msg "Menginstall pywal16 (fork pywal yang terpelihara)..."
        python3 -m pip install --user --break-system-packages pywal16 2>/dev/null \
            || python3 -m pip install --user pywal16 \
            || die "Gagal install pywal (coba: pip install --user pywal16)."
    fi
    # Pastikan ~/.local/bin ada di PATH untuk sesi berikutnya
    grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null || \
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

    # Terapkan warna dari wallpaper utama SEKARANG (panel, GTK, terminal, ikon)
    if [ -n "${DEFAULT_IMG:-}" ] && command -v convert >/dev/null 2>&1; then
        msg "Menerapkan warna UI mengikuti wallpaper utama (pywal)..."
        "$SRC_DIR/update-wallpaper.sh" "$DEFAULT_IMG" "$RESOLUTION" \
            || warn "update-wallpaper gagal — jalankan manual: ./update-wallpaper.sh /path/gambar.jpg"
    fi
    msg "Pywal siap. Ganti wallpaper kapan saja:  ./update-wallpaper.sh /path/ke/gambar-anime.jpg"
fi

# ================= 9. Selesai =================
echo
msg "======================================================="
msg "Setup selesai!"
msg "  Tema GTK   : $GTK_THEME"
msg "  Icon pack  : $ICON_THEME"
msg "  Font       : JetBrainsMono Nerd Font + Inter"
msg "  Compositor : picom (glassmorphism ringan)"
msg "  Wallpaper  : $WALL_DIR/anime-${RESOLUTION}.jpg"
msg ""
msg "Langkah terakhir: logout lalu login kembali (atau restart X),"
msg "agar tema, ikon, dan font diterapkan penuh."
msg "======================================================="