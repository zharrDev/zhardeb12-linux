#!/usr/bin/env bash
#
# xfce-anime-setup.sh — Installer Xfce Anime Glassmorphism (Debian 12)
# -----------------------------------------------------------------
# Ringkasan:
#   - Install picom (glassmorphism ringan)
#   - Install Nerd Font (JetBrainsMono)
#   - Install tema GTK (Catppuccin Mocha) + Icon pack (Tela-circle/Papirus)
#   - Pasang konfigurasi (picom, terminal, gtk, kitty bila perlu)
#   - Setup wallpaper anime (portrait -> landscape 1920x1080 blur-fill)
#   - Matikan compositor bawaan xfwm4, aktifkan picom + autostart
#   - Opsional: panel floating (`--apply-panel`), pywal (`--pywal`, `--skip-install`)
#
# Cara pakai:
#   bash xfce-anime-setup.sh                        # instal + konfigurasi
#   bash xfce-anime-setup.sh --apply-panel          # + panel floating
#   bash xfce-anime-setup.sh --pywal                # + pywal warna otomatis
#   bash xfce-anime-setup.sh --apply-panel --pywal # semua opsi
#   bash xfce-anime-setup.sh --skip-install         # hanya konfigurasi (tanpa apt/git/curl)
#   RESOLUTION=2560x1440 bash xfce-anime-setup.sh   # resolusi kustom
#   THEME=whitesur bash xfce-anime-setup.sh         # tema alternatif
#   ICONS=papirus bash xfce-anime-setup.sh          # icon alternatif
#
# Prinsip: aman (idempotent), backup otomatis (.bak), ringan.
# -----------------------------------------------------------------

set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"   # direktori skrip ini
CFG_DIR="$HOME/.config"
THEME_DIR="$HOME/.themes"
ICON_DIR="$HOME/.icons"
FONT_DIR="$HOME/.local/share/fonts"
WALL_DIR="$HOME/Pictures/Wallpapers/Anime"
AUTOSTART_DIR="$HOME/.config/autostart"

RESOLUTION="${RESOLUTION:-1920x1080}"
THEME="${THEME:-catppuccin}"         # catppuccin | whitesur
ICONS="${ICONS:-papirus}"           # tela-circle | papirus (default: papirus, lebih stabil di Debian 12)
WITH_KITTY=0
WITH_PYWAL=0
APPLY_PANEL=0
SKIP_INSTALL=0

usage() {
    sed -n '3,15p' "$0" | sed 's/^# //; s/^#//'
    echo
    echo "Opsi:"
    echo "  --apply-panel   Panel floating (semi-transparan) di tengah atas"
    echo "  --pywal         Pasang + aktifkan pywal (warna UI mengikuti wallpaper)"
    echo "  --skip-install  Mode konfigurasi saja (skip apt/git/curl/download)"
    echo "  -h | --help     Bantuan"
    echo
    echo "Variabel lingkungan:"
    echo "  RESOLUTION=2560x1440   Resolusi wallpaper landscape (default: 1920x1080)"
    echo "  THEME=whitesur         Tema GTK alternatif (default: catppuccin)"
    echo "  ICONS=papirus          Icon pack (default: papirus)"
    echo "  WITH_KITTY=1           Install + konfigurasi kitty terminal"
    exit 0
}

die()  { printf '\033[1;31m[gagal]\033[0m %s\n' "$*" >&2; exit 1; }
warn() { printf '\033[1;33m[peringatan]\033[0m %s\n' "$*"; }
msg()  { printf '\033[1;36m[setup]\033[0m %s\n' "$*"; }

# Opsi baris perintah
for arg in "$@"; do
    case "$arg" in
        -h|--help) usage ;;
        --apply-panel) APPLY_PANEL=1 ;;
        --pywal)      WITH_PYWAL=1 ;;
        --skip-install) SKIP_INSTALL=1 ;;
        *) die "Opsi tidak dikenal: $arg (coba -h)" ;;
    esac
done

# ================= 1. Helper =================
install_file() { mkdir -p "$(dirname "$2")" && cp -f "$1" "$2"; }

set_xfconf() {
    local channel="$1" path="$2" type="$3" val="$4"
    xfconf-query -c "$channel" -p "$path" -t "$type" -s "$val" 2>/dev/null || true
}

apt_install() {
    if ! dpkg -l "$1" 2>/dev/null | grep -q "^ii"; then
        msg "Memasang paket: $1..."
        sudo apt-get install -y "$1" || die "Gagal memasang $1 (jalankan: sudo apt install $1)."
    else
        msg "Paket $1 sudah terpasang."
    fi
}

# Tentukan nama paket picom di repo
PICOM_PKG="picom"
if ! apt-cache show "$PICOM_PKG" >/dev/null 2>&1; then
    PICOM_PKG="picom"   # fallback nama standar
fi

# ================= 2. Install paket & asset (skip bila --skip-install) =================
if [ "$SKIP_INSTALL" -eq 0 ]; then
    msg "Memasang dependensi..."
    apt_install xfce4-terminal xfce4-settings xfconf xfwm4 xfce4-panel xfce4-panel-plugin XRDesktop \
        picom git curl unzip fonts-inter fonts-cantarell xdg-utils xdg-user-dirs \
        python3-pip xdg-utils xfce4-settings xfce4-appfinder \
        conky lm-sensors xfce4-sensors-plugin

    # --- Compositor: picom (lebih ringan dari xfwm4 paint) ---
    apt_install "$PICOM_PKG"

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

    # --- Icon pack --- (catatan terbaru: Tela-circle tidak lagi menyediakan zip di release, jadi default ke Papirus)
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

# Window button layout: tombol (maximize, minimize, close) di kanan titlebar
# Format button_layout: [sebelah kiri] | [sebelah kanan]
#   Kodingan: H=Shade, M=Maximize, C=Minimize, &=separator, |=menu (kiri default),
#   '|' = pemisah sisi kiri-kanan, dan tombol tanpa prefix artinya di kanan.
#   Contoh: "HMC|"  -> Shade, Maximize, Minimize di kiri; Close di kanan.
#   Contoh: "|HMC"  -> Menu kiri; Shade, Maximize, Minimize di kanan.
#   Kita pilih: "HMC|" sehingga tombol close ada di kanan (paling kanan).
set_xfconf xfwm4 /general/button_layout string "HMC|"
# Title alignment: 0 = kiri, 1 = center, 2 = kanan (agar judul window rapi di kiri, tombol di kanan)
set_xfconf xfwm4 /general/title_alignment int 0

# ================= 6. Compositor: picom menggantikan compositor bawaan xfwm4 =================
msg "Mengaktifkan picom (matikan compositor bawaan xfwm4)..."
set_xfconf xfwm4 /general/use_compositing bool false

cat > "$AUTOSTART_DIR/picom.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Picom (compositor)
Comment=Glassmorphism compositor ringan
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

# ================= 9. Conky widget (info sistem di desktop) =================
# Kartu glass elegan di kiri-tengah layar: jam, tanggal, CPU, RAM, DISK, uptime.
# Warna otomatis mengikuti wallpaper (membaca ~/.cache/wal/colors dari pywal).
msg "Memasang Conky widget (anime-glass)..."
mkdir -p "$CFG_DIR/conky"
install_file "$SRC_DIR/config/conky/anime-glass.conf" "$CFG_DIR/conky/anime-glass.conf"
install_file "$SRC_DIR/config/conky/anime-glass.lua"  "$CFG_DIR/conky/anime-glass.lua"
cat > "$AUTOSTART_DIR/conky-anime-glass.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Conky Anime Glass
Comment=Widget info sistem (CPU, RAM, jam, tanggal) — kiri tengah desktop
Exec=sh -c "sleep 3 && conky -c $HOME/.config/conky/anime-glass.conf"
X-GNOME-Autostart-enabled=true
EOF
msg "Autostart conky -> $AUTOSTART_DIR/conky-anime-glass.desktop"
pkill -f anime-glass.conf 2>/dev/null || true
sleep 1
# tanpa -d/-o: conky di-daemonize sendiri oleh config (background=true)
nohup conky -c "$CFG_DIR/conky/anime-glass.conf" >/tmp/conky-anime-glass.log 2>&1 &
sleep 2
if pgrep -f anime-glass.conf >/dev/null 2>&1; then
    msg "Conky berjalan. Info sistem muncul di kiri-tengah desktop."
else
    warn "Conky gagal start — cek /tmp/conky-anime-glass.log"
fi

# ================= 10. Selesai =================
echo
msg "======================================================="
msg "Setup selesai!"
msg "  Tema GTK   : $GTK_THEME"
msg "  Icon pack  : $ICON_THEME"
msg "  Font       : JetBrainsMono Nerd Font + Inter"
msg "  Compositor : picom (glassmorphism ringan)"
msg "  Wallpaper  : $WALL_DIR/anime-${RESOLUTION}.jpg"
msg "  Tombol window (close/minimize/maximize) sudah di kanan titlebar."
msg ""
msg "Langkah terakhir: logout lalu login kembali (atau restart X),"
msg "agar tema, ikon, font, compositor, dan tombol window (close/min/maximize) diterapkan penuh."
msg "======================================================="