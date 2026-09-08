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
| Icon pack | **Tela-circle-blue-dark** (style bulat, folder **biru** — cocok wallpaper) | Papirus-Dark | `ICONS=papirus bash xfce-anime-setup.sh` (fallback otomatis bila Tela-circle gagal) |
| Font terminal | JetBrainsMono Nerd Font | FiraCode, CaskaydiaCove | ubah di Preferences terminal |
| Font UI | Inter | — | via `~/.config/gtk-3.0/settings.ini` |

**Cara ganti manual (GUI):** *Settings → Appearance* → pilih tema & ikon. Atau lewat baris:
```bash
xfconf-query -c xsettings -p /Gtk/ThemeName -s "catppuccin-mocha-blue-standard+default"
xfconf-query -c xsettings -p /Gtk/IconThemeName -s "Papirus-Dark"
```

---

## 🖥 Panel Atas (full-width, horizontal, transparan + blur, sudut pill)

Panel di-setup oleh `xfce-anime-setup.sh --apply-panel` (atau
`bash scripts/generate-panel-info.sh`) menjadi:
- **Posisi**: **mentok di tepi atas** (`p=11` = TOP), **full-width**
  (`length=100` = 100% lebar layar), terkunci. Sudut membulat halus (pill)
  via picom `corner-radius`.
- **Plugin yang tampil** (urutan kiri → kanan):
  `showdesktop` → `applicationsmenu` → `tasklist` → separator → `systray`
  (ikon sistem, battery, dll) → `pulseaudio` → `power-manager-plugin` →
  separator → `clock` (format `Sen, 08 Sep 2026 | 14:30`) → separator →
  `actions` (lock screen, logout, dll).
- **Warna**: semi-transparan (RGBA `rgba(bg, 0.78)`), warna latar diupdate
  otomatis oleh pywal mengikuti warna dominan wallpaper.
- **Blur & transparansi**: ditangani picom (lihat `picom.conf`).

> ⚠️ **PENTING (kenapa panel dulu “gak muncul / notif failed”)**:
> 1. Nama plugin yang salah — id plugin = nama file `.desktop`
>    (mis. `xfce4-sensors-plugin`, `pulseaudio-plugin`, `power-manager-plugin`
>    → salah satunya `xfce4-sensors` / `pulseaudio` / `power-manager-plugin`
>    yang SALAH adalah `xfce4-sensors` tanpa `-plugin`). Plugin yang gagal
>    otomatis dibuang panel → panel tampak kosong/gagal.
> 2. Nilai `length` > 100 — properti `length` xfce4-panel adalah **persen**
>    (rentang 1–100), bukan piksel. Nilai lama 480/520/560 memicu
>    `invalid or out of range` dan panel menyusut tak terkendali.
> 3. `LC_NUMERIC=id_ID` (desimal koma) membuat angka terlihat seperti
>    `480,000000` — jalankan perintah dengan `export LC_NUMERIC=C`.

> ℹ️ **Info sistem (CPU/RAM/dll) TIDAK lagi dipasang di panel** — digantikan
> widget **Conky** di desktop (lihat bagian berikutnya) agar panel tetap bersih
> dan tidak rawan error.

---

## 🪟 Widget Info Desktop — Conky “Anime Glass” (kiri-tengah)

Kartu glass elegan di **kiri-tengah layar** berisi:
- **Banner anime** di bagian atas (crop dari wallpaper aktif — gambar dari
  `asset/`), menyatu dengan kartu via gradasi gelap
- Jam besar (HH:MM + detik), hari, tanggal, bulan, tahun
- Bar **CPU**, **RAM**, **DISK** bergradasi (dengan ikon Nerd Font)
- Uptime, jumlah proses, suhu CPU, proses teratas

File: `config/conky/anime-glass.conf` + `config/conky/anime-glass.lua`
(terpasang ke `~/.config/conky/`, autostart via `conky-anime-glass.desktop`).
Banner: `~/.config/conky/anime-banner.png` (di-generate otomatis oleh
`update-wallpaper.sh` setiap ganti wallpaper).

**Warna otomatis mengikuti wallpaper**: conky membaca `~/.cache/wal/colors`
(hasil pywal). Ganti wallpaper → warna kartu + banner ikut berubah:
```bash
./update-wallpaper.sh /path/ke/gambar-anime.jpg
```

Jalankan manual:
```bash
conky -c ~/.config/conky/anime-glass.conf
```

> 💡 Jika ingin widget dipindah: ubah `gap_x` / `gap_y` di
> `~/.config/conky/anime-glass.conf` lalu restart conky.

---

## 🖼 Penempatan Gambar Asset (wallpaper desktop = hanya yang landscape)

Wallpaper **desktop dipakai gambar landscape saja** (`916764067907298333.jpeg`),
sesuai permintaan. Gambar asset lainnya ditempatkan di lokasi yang cocok:

| Gambar | Tempat |
| --- | --- |
| `916764067907298333.jpeg` (landscape) | **Wallpaper desktop** + sumber warna UI (pywal) |
| `影.jpeg` | **Banner conky** (atas kartu anime-glass) |
| `968133251138558907.jpeg` | **Avatar conky** (lingkaran kecil di header kartu) |
| `1147432811330550518.jpeg` | **Background terminal kitty** (dim, `background_opacity 0.45`) |

Banner & avatar di-generate oleh `update-wallpaper.sh` ke
`~/.config/conky/anime-banner.png` & `anime-avatar.png`.

> ⚙️ Rotasi wallpaper **tidak lagi otomatis** (autostart dihapus). Kalau tetap
> mau bergiliran manual, gunakan `~/.local/bin/rotate-wallpaper.sh` (semua
> gambar di `~/Pictures/Wallpapers/Anime/`); state disimpan di
> `~/Pictures/Wallpapers/Anime/.rotate-state`.

---

## 🎯 Warna Aplikasi, Hover, dan Notifikasi Ikut Wallpaper

- **Aplikasi GTK (Thunar, dialog, dll)**: `~/.config/gtk-3.0/gtk.css`
  di-generate oleh `update-wallpaper.sh` berisi override widget langsung
  (background window, toolbar, entry, menu, list) memakai warna dominan
  wallpaper — jadi Thunar & aplikasi lain senada wallpaper, bukan warna
  tema bawaan.
- **Hover biru (semua tombol/menu/panel/tasklist)**: warna hover diambil dari
  palet wallpaper (aksen biru `colors[5]`) lewat `theme_selected_bg_color` —
  `button:hover`, `menuitem:hover`, `row:hover`, tombol panel, dll.
- **Notifikasi (xfce4-notifyd)**: `#XfceNotifyWindow` di gtk.css — latar warna
  wallpaper, border + tombol aksen biru.
- **Ikon**: Tela-circle-blue-dark — style bulat seperti awal, folder **biru** (bukan merah) senada wallpaper.

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
│   ├── conky/anime-glass.conf # widget info desktop (kiri-tengah)
│   ├── conky/anime-glass.lua  # gambar kartu glass (warna dari pywal)
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
- **Panel tidak muncul / error “plugin not found”**: biasanya karena nama
  plugin salah. Nama plugin = nama file `.desktop` (misal `xfce4-sensors-plugin`,
  bukan `xfce4-sensors`). Jalankan `bash scripts/generate-panel-info.sh` untuk
  menata ulang panel dengan nama plugin yang benar, lalu `xfce4-panel --restart`.
  (Catatan: karena `LC_NUMERIC=id_ID` (koma), panel bisa mengeluh soal nilai
  `length` — tidak fatal; jalankan skrip dengan `export LC_NUMERIC=C`.)
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
