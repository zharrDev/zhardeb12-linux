# 🎐 Setup Desktop Xfce Anime — Glassmorphism & Vibrant Aesthetic (Debian 12)

Mirror proyek ini: **/home/suo/Documents/zhardeb**

Skrip + konfigurasi untuk **mempercantik tampilan Xfce** di Debian 12 dengan gaya
transparansi/blur (glassmorphism) yang elegan, ringan di RAM/CPU, dan warna UI
yang menyesuaikan wallpaper anime secara otomatis.

---

## 📦 Gambar yang tersedia

Semua gambar anime ada di `asset/`:

| File | Keterangan |
| --- | --- |
| `916764067907298333.jpeg` | **Hero / default wallpaper** (portrait 672×1195) |
| `968133251138558907.jpeg` | Anime lain |
| `1147432811330550518.jpeg` | Anime lain |
| `影.jpeg` | Anime lain |

Skrip otomatis membuat versi **landscape 1920×1080** dari tiap gambar dengan
teknik *blur-fill* (gambar tetap utuh di tengah, sisi kiri/kanan diisi blur).
Hasilnya ada di `~/Pictures/Wallpapers/Anime/anime-1920x1080.jpg` (dan seterusnya
untuk resolusi lain).

---

## 🚀 Cara pakai (3 langkah)

### 1. Jalankan installer

Dari folder proyek:
```bash
cd /home/suo/Documents/zhardeb
bash xfce-anime-setup.sh --apply-panel --pywal
```

Arti opsi:
| Opsi | Keterangan |
| --- | --- |
| (tanpa opsi) | Instal paket + konfigurasi + wallpaper |
| `--apply-panel` | Panel Xfce floating atas, semi-transparan (override konfigurasi panel) |
| `--pywal` | Pasang pywal + terapkan warna UI mengikuti wallpaper saat setup |
| `RESOLUTION=2560x1440` | Ubah resolusi wallpaper landscape (default 1920x1080) |
| `THEME=whitesur` | Ganti tema GTK jadi WhiteSur (default: Catppuccin Mocha) |
| `ICONS=tela-circle` | Paksa Tela-circle (bila gagal otomatis fallback ke Papirus) |

Skrip bersifat **idempotent** — jika dijalankan lagi, yang sudah selesai akan
 dilewati (paket, font, konfigurasi yang diberi backup `.bak`).

### 2. Logout → login kembali (atau restart X)

Agar tema, ikon, font, dan compositor picom diterapkan penuh.

### 3. Ganti wallpaper kapan saja

Pasang wallpaper anime baru:
```bash
./update-wallpaper.sh /path/ke/gambar-anime.jpg             # 1920x1080
./update-wallpaper.sh /path/ke/gambar-anime.jpg 2560x1440  # resolusi kustom
```
Skrip akan:
1. Salin gambar ke `~/Pictures/Wallpapers/Anime/`
2. Buat versi landscape (blur-fill)
3. Set sebagai wallpaper desktop
4. **Jalankan pywal** → warna seluruh UI ikut berubah:
   - warna panel, GTK, teks ikon desktop
   - palette terminal baru
5. Restart panel + kirim warna ke kitty (bila terpasang)

---

## 🎨 Rekomendasi Tema & Cara Menggantinya

| Komponen | Default (terinstall) | Alternatif | Catatan |
| --- | --- | --- | --- |
| Tema GTK | **Catppuccin Mocha** (pastel, ringan, cocok anime) | WhiteSur (glassy macOS) | `THEME=whitesur bash xfce-anime-setup.sh` |
| Icon pack | **Papirus** (stabil, tersedia di apt Debian 12) | Tela-circle | `ICONS=tela-circle bash xfce-anime-setup.sh` (bila gagal, otomatis fallback ke Papirus) |
| Font terminal | JetBrainsMono Nerd Font | FiraCode, CaskaydiaCove | ubah di Preferences terminal |
| Font UI | Inter | — | via `~/.config/gtk-3.0/settings.ini` |

**Cara ganti manual (GUI):** *Settings → Appearance* → pilih tema & ikon. Atau lewat baris:
```bash
xfconf-query -c xsettings -p /Gtk/ThemeName -s "catppuccin-mocha-blue-standard+default"
xfconf-query -c xsettings -p /Gtk/IconThemeName -s "Papirus-Dark"
```

---

## 🖥 Panel Floating (atas, horizontal, transparan + blur)

Panel di-setup oleh `xfce-anime-setup.sh --apply-panel` menjadi:
- **Posisi**: floating (mengambang) di tengah atas (`p=11;x=0;y=0`).
  Panel **bisa digerakkan**: klik kanan → *Unlock Panel*, lalu klik & drag ke
  posisi yang diinginkan, klik kanan → *Lock Panel* lagi bila sudah pas.
- **Plugin yang tampil**: Show Desktop → Aplikasi Menu → Tasklist (jendela) →
  separator → Systray (ikon sistem, battery/clock/icon lainnya yang terpasang)
  → separator → Clock → separator → Actions (lock screen, logout, dll).
- **Warna**: semi-transparan (RGBA `rgba(bg, 0.82)`), warna latar diupdate
  otomatis oleh pywal mengikuti warna dominan wallpaper.
- **Blur & transparansi**: ditangani picom (lihat `picom.conf`).

### Menambah Battery / CPU / Monitor ke panel (opsional)

Plugin **hardware sensors** dan **system load monitor** sudah terpasang di sistem
tetapi tidak dimasukkan di panel XML (karena properti masing-masing bersifat
spesifik). Tambahkan manual lewat GUI:

1. Klik kanan panel → **Panel Preferences** → tab **Add** (atau *Add/Remove*).
2. Pilih **Sensors** → tambahkan.
3. Pilih **System Load Monitor** → tambahkan.
4. Atur posisi plugin baru di panel (klik & drag).

⚠️ Jika tidak muncul di daftar *Add*, pastikan paket sudah terpasang:
```bash
sudo apt install xfce4-sensors-plugin xfce4-systemload-plugin
xfce4-panel --restart
```

---

## ⌨ Terminal — transparan, blur, palette anime

`xfce4-terminal` diset via `config/xfce4/terminal/terminalrc`:
- **Transparan** (`BackgroundMode=TRANSPARENT`, `BackgroundDarkness=0.82`).
- **Blur** di belakang terminal ditangani picom (`blur-method=dual_kawase`,
  `blur-strength=4`).
- **Palette pastel anime** (Catppuccin Mocha).
- Font: JetBrainsMono Nerd Font 11.

Hasil: terminal pertama kali dibuka terlihat **elegandengan wallpaper anime
terlihat di baliknya** (glassmorphism).

### Terminal “mulai dengan wallpaper sebagai background image” (opsional)

Secara bawaan terminal diset **transparan** (lebih ringan & elegan). Jika kamu
ingin terminal muncul dengan gambar wallpaper sebagai background image (bukan
transparan), atur manual lewat GUI:

1. Buka terminal → **Edit → Preferences**.
2. Tab **Appearance** (atau **General**).
3. **Background** → pilih **Solid** / **Image**, atur gambar wallpaper atau
   transparansi.

*Nota:* skrip/config ini tidak dapat memaksa background image via file
`terminalrc` — hanya bisa melalui GUI preferences terminal.

### Tombol window (close / minimize / maximize) di terminal

Di xfce4-terminal versi yang ada di sini (apt 1.0.4-1), tombol **window
decorations** (close/min/max/title) **tidak bisa diatur lewat file konfigurasi**
atau baris perintah — hanya lewat GUI:

1. Tampilkan terminal.
2. **Edit → Preferences → Appearance** (atau *Misc*).
3. Aktifkan **Window buttons** / **Show window decorations** (tergantung versi).

Bila ingin terminal tanpa judul tapi tetap ada tombol close/min/max di pojok,
atur “Window decorations” yang tersedia di menu preferences.

---

## 🧩 Kitty (opsional)

Kalau kamu lebih suka Kitty, skrip bisa menginstallnya dengan `WITH_KITTY=1`:
```bash
WITH_KITTY=1 bash xfce-anime-setup.sh
```
Konfigurasi ada di `config/kitty/kitty.conf`. Warna otomatis dari pywal
ditautkan via include `~/.cache/wal/colors-kitty.conf` setelah pertama kali
`update-wallpaper.sh` dijalankan.

---

## ⚙️ Compositor & performa

- **Compositor bawaan xfwm4** dimatikan, diganti **Picom** (melalui autostart
  `picom.desktop`).
- Picom dikonfigurasikan di `config/picom/picom.conf`:
  - Rounded corners 12px (ringan, exclude maximized/fullscreen).
  - Shadow halus (opacity 0.22, radius 10).
  - Transparansi jendela tidak aktif 0.94.
  - Blur tipis `dual_kawase`, strength 4 (hemat GPU).
  - `unredir-if-possible = true` (fullscreen & idle → matikan compositing,
    hemat daya).

Estimasi beban: ~30–50 MB RAM, 2–4% CPU (tergantung GPU). Jika merasa berat,
kurangi `blur-strength` jadi 2 atau matikan blur sama sekali.

---

## 🌈 Warna otomatis mengikuti wallpaper (pywal)

Setelah pywal terpasang (opsi `--pywal` di installer, atau install manual
`pip install --user pywal16`), warna UI diupdate otomatis tiap kamu menjalankan
`update-wallpaper.sh`:

| Komponen | Cara update warna |
| --- | --- |
| **Panel Xfce** | Laten panel diupdate lewat file `xfce4-panel.xml`, warna dari `color0` wallpaper |
| **Aplikasi GTK** | `gtk.css` ditulis ulang (bg, fg, seleksi, border, tooltip, warna widget) |
| **Terminal xfce4-terminal** | Palette 16 warna + foreground/background/cursor di-update di `terminalrc` |
| **Kitty** | Di-include `colors-kitty.conf` hasil pywal (jika ada) |
| **Teks ikon desktop** | Font color diset sesuai foreground wallpaper |

Cara manual bila pywal sudah terpasang tapi warna tidak berubah:
```bash
./update-wallpaper.sh ~/Pictures/Wallpapers/Anime/nama-gambar.jpg
```
atau buka terminal baru (pywal ter-trigger saat terminal baru dibuka, tergantung
konfigurasi shell `.bashrc`/`.zshrc` yang menautkan `wal`).

---

## 🧹 Batal / Uninstall

- Hapus `~/.config/picom`, `~/.config/autostart/picom.desktop`, kembalikan `.bak`
  yang ada (misal `panel.xml.bak`, `terminalrc.bak`).
- Hapus `~/.themes/catppuccin-*`, `~/.icons/Tela-circle-*`, font di
  `~/.local/share/fonts` (bila tak dipakai).
- Kembalikan compositor bawaan: `xfconf-query -c xfwm4 -p /general/use_compositing -s true`.
- Uninstall pywal: `pip uninstall pywal16` (atau `pywal`).

---

## 📂 Struktur berkas

```
/home/suo/Documents/zhardeb/
├── xfce-anime-setup.sh        # installer utama (1-klik)
├── update-wallpaper.sh        # ganti wallpaper + warna UI otomatis
├── README.md                  # panduan ini
├── config/
│   ├── picom/picom.conf       # konfigurasi glassmorphism ringan
│   ├── xfce4/terminal/terminalrc
│   ├── xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
│   ├── gtk-3.0/settings.ini
│   ├── gtk-3.0/gtk.css        # override warna (ditulis ulang pywal)
│   └── kitty/kitty.conf
└── asset/                     # gambar anime asli (user upload)
```

---

## 🐛 Troubleshooting

- **Picom tidak berjalan**: cek driver GPU (glx/egl). Coba ganti backend di
  `picom.conf` jadi `backend = "egl";` atau `backend = "xrender";`.
- **Panel tidak muncul / error**: restore dari `panel.xml.bak`, lalu
  `xfce4-panel --restart`.
- **Warna terminal tidak berubah setelah pywal**: jalankan ulang
  `./update-wallpaper.sh /path/gambar.jpg` atau buka terminal baru.
- **Tema Catppuccin / icon tidak apply**: logout → login, atau jalankan ulang
  `xfce-anime-setup.sh --skip-install` (set xsettings & xfwm theme).
- **Terminal transparan tapi tidak blur**: pastikan picom berjalan & `blur-background = true` di `picom.conf`.
- **Gambar wallpaper terlalu kecil/retak**: edit resolusi di `RESOLUTION=...`
  atau `update-wallpaper.sh ... 2560x1440` sesuai ukuran layar.

---

## 📌 Catatan release

- Tema GTK Catppuccin: URL download menggunakan asset
  `catppuccin-mocha-blue-standard+default.zip` (v1.0.3+), bukan nama lama.
- Icon pack Tela-circle: repo ini tidak lagi menyediakan `Tela-circle-dark.zip`
  di release terbaru, jadi default otomatis ke Papirus dan `ICONS=tela-circle`
  akan fallback ke Papirus bila unduhan gagal.
