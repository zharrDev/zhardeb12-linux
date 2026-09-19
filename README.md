# 🎐 Setup Desktop Xfce Anime — Glassmorphism & Vibrant Aesthetic (Debian 12)

Mirror proyek ini: **/home/suo/Documents/zhardeb**

Skrip + konfigurasi untuk **mempercantik tampilan Xfce** di Debian 12 dengan gaya
transparansi/blur (glassmorphism) yang elegan, ringan di RAM/CPU, dan warna UI
yang menyesuaikan wallpaper anime secara otomatis.

> ✨ **Design language ala [By-LeyzS-Arch-Hyprland-Dotfiles](https://github.com/L3yzs/By-LeyzS-Arch-Hyprland-Dotfiles)**
> (diporting dari Hyprland/Wayland ke Xfce/X11 — memakai wallpaper kita sendiri):
> - **Bar transparan penuh** + modul "chip" berborder aksen ala waybar
> - **Workspaces bulat** (pager Xfce) radius 50%
> - Font **JetBrainsMono Nerd Font bold** di seluruh UI
> - **Cava** visualizer audio dengan warna dari wallpaper (pywal)
> - **Btop** monitor sistem bertema pywal
> - **Fastfetch** info sistem dengan box border + logo anime ASCII (dari wallpaper)
> - Hover chip = tukar warna (bg ↔ aksen) seperti waybar By-LeyzS

---

## 📦 Gambar yang tersedia

Koleksi wallpaper terpusat ala By-LeyzS-Arch-Hyprland-Dotfiles:

| Lokasi | Isi |
| --- | --- |
| `config/wallpapers/originals/` | **Koleksi repo** — gambar anime asli (8 gambar: 4 bawaan + 4 dari By-LeyzS-Arch-Hyprland-Dotfiles) |
| `~/.config/wallpapers/originals/` | Koleksi yang disalin ke sistem oleh installer |
| `~/Pictures/Wallpapers/Anime/` | Gambar hasil upload manual + versi landscape |

Gambar asli:

| File | Keterangan |
| --- | --- |
| `916764067907298333.jpeg` | **Hero / default wallpaper** (portrait 672×1195) |
| `968133251138558907.jpeg` | Anime lain |
| `1147432811330550518.jpeg` | Anime lain |
| `影.jpeg` | Anime lain |
| `blue-girl.png` | Anime biru (dari By-LeyzS) |
| `cyan-girl2.png` | Anime cyan (dari By-LeyzS) |
| `city-girl-sunset.png` | Anime sunset (dari By-LeyzS) |
| `purple-nature.png` | Anime ungu (dari By-LeyzS) |

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
./update-wallpaper.sh --random                              # pilih acak dari koleksi
```
> 📐 **Hanya gambar landscape** (rasio ≥ 1.5) yang dipakai sebagai wallpaper
> desktop — `--random` dan rotasi otomatis melewati gambar portrait/square
> (gambar itu tetap dipakai untuk banner/avatar conky & login screen).

Skrip akan:
1. Salin gambar ke `~/Pictures/Wallpapers/Anime/`
2. Buat versi landscape (blur-fill)
3. Set sebagai wallpaper desktop **dengan crossfade 0.4s** (`scripts/wallpaper-fade.py`;
   matikan via `./update-wallpaper.sh --no-fade ...` atau `FADE=0`, durasi via `FADE_TIME=0.8`)
4. **Jalankan pywal** → warna seluruh UI ikut berubah:
   - warna panel, GTK, teks ikon desktop
   - palette terminal baru
5. Restart panel + kirim warna ke kitty (bila terpasang)

Rotasi bergilir semua gambar koleksi:
```bash
./rotate-wallpaper.sh           # bergilir (urut)
./rotate-wallpaper.sh --random  # acak
```

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

## ✨ Komponen ala By-LeyzS (port ke Xfce)

### Tema XFWM `Zhardeb-Glass-Rounded` (jendela kaca rounded ala Hyprland)

- **Pojok rounded 10px** (persis `rounding = 10` By-LeyzS), titlebar kaca
  **72% aktif / 45% non-aktif**, border kaca 55%, **outline aksen pywal**
  (biru langit) mengelilingi jendela.
- Warna **otomatis ikut wallpaper** — di-generate dari pywal oleh
  `scripts/generate-xfwm-theme.sh` setiap `update-wallpaper.sh` jalan.
- Tombol close/min/max **glyph Flat-Remix asli** (merah/oranye/biru).
- Snapshot tema tersimpan di `config/xfwm4/Zhardeb-Glass-Rounded/`.

### Shortcut window (Super/Windows key)

| Shortcut | Fungsi |
| --- | --- |
| `Super + Q` | **Close** jendela aktif |
| `Super + W` | **Minimize** |
| `Super + A` | **Maximize** toggle |
| `Super + ←` | Geser jendela ke kiri (80px) — **mentok kiri → nembus ke workspace kiri** |
| `Super + →` | Geser ke kanan — **mentok kanan → nembus ke workspace kanan** |
| `Super + ↑` | Geser ke atas — **mentok atas → nembus ke workspace ATAS** (ditempel di bawah) |
| `Super + ↓` | Geser ke bawah — **mentok bawah → nembus ke workspace BAWAH** (ditempel di atas) |

Diimplementasikan via `scripts/window-shortcuts.sh` (wmctrl) — di-bind
oleh installer ke `xfce4-keyboard-shortcuts`. Jarak geser bisa diubah:
`STEP=40 ~/.local/bin/window-shortcuts.sh left`.

Grid workspace dibaca dari `_NET_DESKTOP_LAYOUT` (di mesin ini **2×2**), jadi
"bawah" = workspace **+2** (baris bawah pada kolom yang sama), bukan +1. Batas
gerak memakai `_NET_WORKAREA`, jadi panel atas (44px) tidak pernah ketimpa.

Dua hal yang bikin dorongan terasa "lengket" sudah dibereskan di script ini:

1. **Fokus ikut pindah.** Setelah nembus ke workspace lain, xfwm4 memindahkan
   fokus ke jendela lain yang sudah ada di sana — dorongan berikutnya jadi
   menggeser jendela yang SALAH, dan jendela yang kamu dorong terlihat
   "tertempel" diam. Sekarang jendela yang dipindah **difokuskan ulang** (dengan
   verifikasi + coba ulang) dan id-nya dipegang sesaat (±1,2 detik) di state
   file, jadi beberapa tekanan beruntun tetap menyasar jendela yang sama.
   Setel lamanya: `HOLD_SECS=0.8 ~/.local/bin/window-shortcuts.sh down`.
2. **Batas posisi yang bisa dicapai.** `wmctrl -e` men-set posisi *frame* dan
   xfwm4 menaruh klien 2× extents darinya sambil membatasi frame agar tidak
   keluar area kerja — jadi tidak semua koordinat bisa dicapai. Semua hasil
   hitungan (termasuk saat "mentok") sekarang dijepit ke batas nyata itu, jadi
   jendela tidak lagi nyangkut sebagian di bawah panel atau keluar layar.

Uji tanpa menggeser apa pun (dry-run) dan bersihkan binding ganda xfwm4:
```bash
DRY=1 WIN=$(xprop -root _NET_ACTIVE_WINDOW | awk '{print $5}') \
    bash scripts/window-shortcuts.sh down      # cetak rencana saja
bash scripts/apply-workspace-shortcuts.sh      # pastikan Super+↑/↓ tidak dobel
```

| Komponen | By-LeyzS (Hyprland) | Zhardeb (Xfce) |
| --- | --- | --- |
| Bar | waybar transparan + chip | Xfce panel `background-style=2` + chip via `gtk.css` |
| Workspaces | `#workspaces button` bulat | plugin **pager** + `#pager-button` radius 50% |
| CPU/RAM | modul `cpu`/`memory` | plugin **systemload** (RAM) + conky |
| Audio | `pulseaudio` modul | plugin **pulseaudio** (chip) |
| Visualizer | cava `source=background` | **cava** sama persis (warna pywal) |
| System monitor | btop `TTY` theme | **btop** + `btopwal.theme` (pywal) |
| Sysinfo | fastfetch + arch.txt logo | **fastfetch** + logo anime ASCII (auto dari wallpaper via `jp2a`) |
| Terminal | kitty opacity 0.6 + trail | **kitty** port sama + pywal include |
| Notifikasi | swaync border aksen | xfce4-notifyd via `gtk.css` (border 2px aksen, radius 20px) |

Cara pakai:
```bash
bash scripts/apply-leyzs-panel.sh    # tata panel ala waybar By-LeyzS
fastfetch                            # info sistem + logo anime
cava                                 # visualizer audio (warna wallpaper)
btop                                 # monitor sistem (tema pywal)
```

Logo fastfetch di-regenerate otomatis dari wallpaper aktif setiap
`update-wallpaper.sh` dijalankan (ala By-LeyzS yang pakai arch.txt statis).

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
| `config/wallpapers/login/blue-girl.jpg` | **Background layar login LightDM** (1920×1080, dipakai TAJAM) + sumber tekstur kaca kartu login |
| `影-removebg-preview.png` | **Avatar user di kartu login LightDM** (bulat 160px, sudah disiapkan di `config/lightdm/avatar/`) |

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
- **Design language ala By-LeyzS**: panel & widget memakai gaya *pill modules*
  (border-radius 14, border aksen 2px, hover = tukar warna seperti waybar) dan
  notifikasi bergaya *swaync* — kartu gelap glass + border aksen 2px +
  sudut 20px + judul berwarna aksen. Semua warna tetap dari pywal.
- **Notifikasi (xfce4-notifyd)**: `#XfceNotifyWindow` di gtk.css — latar gelap
  glass, border aksen 2px, sudut 20px, judul aksen, tombol aksen.
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
  - Rounded corners 14px — termasuk **terminal xfce4-terminal & kitty**
    (padding kitty 12/16px supaya teks tidak menempel sudut).
  - **Animasi smooth**: buka window slide-in naik 0.18s, tutup/minimize
    slide-out turun 0.15s (semua window, termasuk buka tab baru terminal),
    fade opacity halus (fade-in 0.045 / fade-out 0.035).
  - Shadow off (hemat GPU; hanya glass/transparan yang dipakai).
  - Opacity semua window = 1.0 (solid; hanya terminal/panel/conky yang transparan).
  - Blur tipis `dual_kawase`, strength 3 (hemat GPU).
  - `unredir-if-possible = true` (fullscreen & idle → matikan compositing).
  - **Crossfade wallpaper** 0.4s saat ganti wallpaper (`scripts/wallpaper-fade.py`).

Estimasi beban: ~35–45 MB RAM, 2–4% CPU (tergantung GPU).

>**Toggle lowmem mode** (untuk sistem RAM terbatas / Intel UHD yang shares RAM):
>```bash
>./scripts/toggle-picom-mode.sh         # toggle glass ↔ lowmem
>./scripts/toggle-picom-mode.sh glass    # blur on, corner 8px
>./scripts/toggle-picom-mode.sh lowmem   # blur OFF, corner 5px (hemat GPU RAM)
>./scripts/toggle-picom-mode.sh status   # cek mode aktif
>```
>Mode `lowmem` pakai `config/picom/picom-lowmem.conf` (blur off, shadow off,
>corner 5px) — hemat VRAM/GPU memory yang dialokasikan dari system RAM.

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

## 🔒 Lock screen ringan (light-locker)

Lock screen memakai **light-locker** (~10 MB RAM) — jauh lebih ringan dari
xscreensaver. Installer menulis override autostart
`~/.config/autostart/light-locker.desktop` (menimpa versi polos dari
`/etc/xdg/autostart/` sehingga hanya satu instance) dengan flag:
- `--lock-on-suspend` — kunci layar otomatis saat suspend/resume
- `--lock-on-lid` — kunci saat laptop lid ditutup

---

## 🔐 Tampilan Login Screen (LightDM) — v4 "Frosted Aurora"

Layar login dibuat senada dengan desktop: **wallpaper anime TAJAM (tanpa blur)**
sebagai latar, **JAM BESAR + tanggal di tengah layar** saat idle, lalu **kartu
login kaca buram (frosted glass) di TENGAH layar** — ukuran besar, sudut
membulat 24px, border gradasi biru→ungu→lavender, **avatar anime bulat** untuk
user, entry password & tombol pill dengan glow aksen. Setelah kartu muncul, jam
naik dan **menetap di ATAS form** (di atas border kartu).

Wallpaper login aktif: `config/wallpapers/login/blue-girl.jpg` (**anime
blue-girl**, navy gelap sehingga kartu kaca & jam kontras). Ganti kapan saja
dengan menaruh gambar landscape lain di folder itu lalu deploy ulang.

```bash
sudo bash scripts/apply-lightdm-greeter.sh                # pasang (login otomatis aktif)
sudo bash scripts/apply-lightdm-greeter.sh --no-autologin # tampil kartu login (ketik password)
```

Yang dipasang:
- `/usr/share/backgrounds/anime-glass/login-bg.jpg` — **wallpaper login TAJAM**
  (tanpa blur; hanya `--dim 0.94` + vignette tipis `0.62` supaya kartu & jam
  menonjol). Versi mentahnya juga diarsipkan sebagai `login-bg-sharp.jpg`.
  Sumber: `config/wallpapers/login/` (fallback: wallpaper aktif desktop)
- `/usr/share/backgrounds/anime-glass/glass-panel.jpg` + `glass-bar.jpg` —
  **tekstur kaca** dari wallpaper yang sama: kartu (crop area kartu 560×350,
  blur `--card-blur 10`) dan **pil header** (band atas 48px, blur sendiri
  `--bar-blur 14`) — jadi kartu & header tetap terasa kaca buram walau latar
  layar sengaja dibiarkan tajam
- Generator asetnya satu tempat: `scripts/login-assets.py` — dipakai baik oleh
  script deploy **maupun** preview. Nada blurnya bisa disetel:
  ```bash
  python3 scripts/login-assets.py --src wallpaper.jpg --outdir /tmp/out \
      --bg-blur 0 --card-blur 10 --bar-blur 14 --dim 0.94 --vignette 0.62 \
      --size 1920x1080
  #  --bg-blur 0   = latar TAJAM (tanpa blur)  ← dipakai sekarang
  #  --bg-blur 16  = latar makin lembut (kalau mau gaya dreamy lagi)
  #  --card-blur   = kekaburan tekstur kaca kartu (10 = kaca halus)
  #  --bar-blur    = kekaburan tekstur pil header (14 = kaca buram)
  #  --dim         = pengali kecerahan latar   --vignette 0.62 = sudut lebih gelap
  ```
  Ganti wallpaper login? Taruh saja gambar landscape baru di
  `config/wallpapers/login/` (jpg/png) lalu jalankan deploy ulang — warna blur,
  vignette, dan tekstur kaca kartu otomatis mengikuti gambar itu.
- `/usr/share/pixmaps/anime-glass-avatar.png` — **avatar user** untuk kartu login,
  sekaligus dipasang ke `~/.face` (yang lama di-backup `~/.face.bak.<tanggal>`)
- `/usr/share/themes/anime-glass-greeter/` — tema CSS glass khusus greeter
- Tema GTK + ikon **Tela-circle-blue-dark** + font **Inter 11** system-wide
- `lightdm-gtk-greeter.conf` — kartu `position=50%,center`, dan **HEADER
  berbentuk PIL kaca** di atas: mengambang (`margin: 10px 20px`), radius 26px
  (≥ tinggi/2 → ujung membulat), tekstur `glass-bar.jpg` (blur 14px) + tint navy
  transparan 0.44, teks **Poppins 13px**. Isinya
  `indicators=~host;~spacer;~session;~power` — **jam TIDAK di panel**, jam
  digambar overlay animasi (lihat bawah)
- Konfigurasi lama otomatis dibackup (`*.bak.<tanggal>`)

**Jam di layar login:** saat idle jam tampil **besar di tengah** (font Poppins,
fallback Inter) dengan caption kecil, garis gradasi biru→ungu, dan **hari/tanggal
Indonesia** di bawahnya. Setelah kamu menekan tombol apa saja, **tanggal hilang**
dan jam itu terbang **ke atas kartu login** (di atas border form) lalu menetap di
sana — jadi setelah form muncul, jam ada **di atas form**.

**Ganti avatar (mis. pakai wajah lain):** ganti satu file ini lalu deploy ulang.
```bash
cd ~/Documents/zhardeb
cp ~/gambar-avatar-baru.png config/lightdm/avatar/anime-avatar-source.png
python3 - <<'PY'
from PIL import Image, ImageDraw
src = Image.open("config/lightdm/avatar/anime-avatar-source.png").convert("RGBA")
s = min(src.size); sq = src.crop(((src.width-s)//2, (src.height-s)//2, (src.width-s)//2+s, (src.height-s)//2+s))
b = sq.resize((640, 640), Image.LANCZOS)
m = Image.new("L", (640, 640), 0); ImageDraw.Draw(m).ellipse((0, 0, 639, 639), fill=255)
b.putalpha(m); b.resize((160, 160), Image.LANCZOS).save("config/lightdm/avatar/anime-avatar.png")
PY
sudo bash scripts/apply-lightdm-greeter.sh --no-autologin
```

> Kenapa blur-nya "dibakar" (pre-baked) bukan realtime? Greeter LightDM jalan
> **tanpa compositor**, jadi blur realtime tidak mungkin dan tidak ada efek
> berat saat login. Tekstur kaca dipotong **tepat di posisi kartu/panel** pada
> wallpaper (1:1 sesuai resolusi layar) sehingga hasilnya menyatu dengan latar —
> prinsip sama seperti dotfiles Hyprland (By-LeyzS) yang memakai blur + wallpaper.

### ✨ Animasi: JAM BESAR di tengah → form login menyusul

Saat layar login muncul, yang tampil **cuma wallpaper (TAJAM, tanpa blur) + JAM
BESAR di tengah layar**: caption kecil `welcome suo`, jam `HH:MM` besar
+ detik aksen, garis gradasi biru→ungu, dan **hari/tanggal Indonesia** di
bawahnya. Tidak ada tulisan "tekan enter" — cuma **tiga titik halus** di bawah
layar yang menyala bergantian sebagai penanda menunggu.

**Panel atas digambar apa adanya** dari strip panel potret greeter (panelnya
memang sudah tanpa jam), jadi tidak ada elemen yang "muncul mendadak".

Begitu ada tombol ditekan (atau diklik), dalam ±0,7 detik:

| Lapisan | Efek |
| --- | --- |
| Tanggal + caption | memudar lebih dulu (jadi saat form muncul tinggal jam) |
| Jam besar | terbang **ke atas kartu** sambil mengecil (kurva halus: pelan → cepat → mendarat lembut) — berakhir persis di **atas border form** |
| Jam final | versi **tajam** (digambar 1:1, tanpa skala) muncul menyusul di titik & ukuran yang sama, lalu **menetap** di sana |
| Kartu | **FLIP** — skala vertikal 0.35→1 dengan sedikit overshoot (terbuka dari bawah) + slide `ease-out` 170px |
| Wallpaper | zoom Ken-Burns + sedikit menggelap di tengah animasi, lalu **kembali persis normal** |
| Titik menunggu | memudar sambil turun sedikit (crossfade) |

Di akhir animasi **kartu kembali identik dengan yang digambar greeter** (sudah
diukur: frame terakhir beda **<0,4% piksel** dari layar login asli — praktis cuma
jam yang kita tambahkan). Setelah itu overlay menutup diri dan digantikan
**window kecil berisi jam** yang menetap di atas form:

- isinya **potongan wallpaper 1:1** sesuai posisinya di layar + jam final →
  menyatu sempurna dengan latar, tidak ada kotak yang terlihat;
- **tidak bisa menerima fokus & klik** (area masuknya dikosongkan) — jadi kamu
  tetap bisa langsung mengetik password dan menekan tombol di kartu;
- begitu kamu **berhasil login**, window greeter dihancurkan dan sesi desktop
  mulai → overlay + jam ini **ikut hilang seketika (±0,1 detik)**; tidak ada
  sisa gambar (termasuk jam) yang menempel di atas desktop. Dipantau dua jalur:
  `xprop -spy` (berbasis kejadian, langsung) + cek tiap 2 detik sebagai cadangan.

> **Jamnya tajam, flip-nya bersih.** Jam digambar **tanpa halo/glow** (halo itu
> yang membuatnya terlihat kabur) — hanya bayangan gelap 2px supaya tetap
> terbaca; saat pindah dari jam besar ke jam final pun posisi/ukuran keduanya
> sudah sama, jadi tidak ada gambar dobel. Kartu digambar **solid (alpha penuh)**
> — tanpa fade-in, glow, kilau, atau peregangan mendatar. Kartu login memang
> sudah buram dari greeter (kaca frosted), jadi lapisan tambahan hanya membuatnya
> terlihat "kabur" saat ngeflip. Sekarang murni flip (skala Y) + slide.

Semua efek digambar dengan Cairo (tanpa blur realtime) dan jam besar + ekstra
di-render **sekali** jadi pixbuf — saat idle repaint-nya cuma area kecil (titik
menunggu), dan repaint penuh hanya ±0,7 detik saat animasi jalan (RAM greeter
tetap ±20–30 MB).

Semua tekstur dipotong dari **satu potret layar login** oleh satu tool:
`scripts/greeter-textures.py` → `card.png` (kartu + bayangannya), `panel.png`
(strip panel + bayangan), plus kotak kartu & **tepi atas kartu** (`card_top` —
acuan menaruh jam di atas form) dalam JSON. Tool yang sama dipakai **jalur
produksi** (`greeter-anim-launch.py`) dan **pratinjau** (`preview-login.sh`) —
jadi yang kamu lihat di pratinjau = yang nanti muncul saat login. Deteksi dijaga
ketat (kartu harus masuk akal, latar potret harus ≥75% sama dengan wallpaper) dan
kalau ada yang aneh animasinya langsung dibatalkan — layar login tampil normal.

Aman by design: **autentikasi tetap milik `lightdm-gtk-greeter` bawaan**, lapisan
animasi hanya melukis di atasnya. Kalau overlay gagal/tidak jalan, layar login
langsung tampil normal; kalau tidak ada tombol ditekan, kartu muncul sendiri
setelah 120 detik (jadi tidak mungkin "terkunci").

```bash
bash scripts/preview-login.sh          # 30 detik: tekan tombol -> lihat transisinya
bash scripts/preview-login.sh 30 5     # kartu muncul sendiri setelah 5 detik
bash scripts/preview-login.sh --card   # potret statis kartu login asli (tanpa jam)
```

Setelan (ubah di sini, tidak perlu edit script) — `/etc/lightdm/anime-glass-anim.conf`:
```ini
enabled=1        # 0 = matikan animasi (kartu login langsung tampil)
duration=700     # durasi kartu masuk+flip (ms) — 500 = cepat, 900 = dramatis
timeout=120      # detik; kartu muncul sendiri bila tak ada tombol ditekan
auto=0           # >0 = kartu muncul sendiri setelah N detik (demo/pratinjau)
hint_size=34     # ukuran font splash — dipakai HANYA kalau hint diisi
# hint=          # teks splash: KOSONG = tanpa teks (hanya tiga titik halus)
# hint_sub=
hero=1           # 1 = tampilkan JAM BESAR + tanggal di tengah sebelum form muncul
hero_size=120    # ukuran font jam besar (px) — 72 kecil, 120 ekstra besar
hero_caption=welcome suo   # tulisan kecil di atas jam (kosongkan bila tak mau)
clock_size=54    # ukuran jam setelah form muncul (di atas kartu, px)
clock_gap=64     # jarak jam ke tepi atas kartu login (px)
stay=1           # 1 = jam tetap menampil di atas form setelah animasi
```

Mematikan animasi: `sudo bash scripts/apply-lightdm-greeter.sh --no-anim`.
Log-nya ada di `/var/log/anime-glass-anim.log`.

Keamanan: semua callback overlay fail-open (error → overlay sembunyi +
fokus kembali ke greeter, login tidak pernah terkunci) + watchdog memaksa
animasi selesai bila tick macet lebih dari `durasi+5 detik`.

Membatalkan: selama kartu naik, **Esc / klik kanan** kembali ke tampilan awal;
setelah form tampil, klik lingkaran kaca **‹** kiri-bawah untuk flip kembali.
(Tombol Cancel di kartu milik binary greeter — perilakunya bawaan LightDM.)

**Menyetel animasi tanpa login berulang** — render beberapa frame ke PNG lalu
periksa (0 = wallpaper + jam besar, 1 = kartu mendarat + jam di atas form):
```bash
T=/tmp/frames; mkdir -p $T
python3 scripts/login-assets.py --src config/wallpapers/login/blue-girl.jpg \
    --outdir $T --bg-blur 0 --card-blur 10 --size 1920x1080
python3 scripts/preview-login.py --mock-shot $T/shot.png \
    --bg $T/login-bg.jpg --assets $T          # potret greeter (mock)
ANIME_GLASS_WALLPAPER=$T/login-bg.jpg \
ANIME_GLASS_OVERLAY=$PWD/scripts/greeter-anim.py \
ANIME_GLASS_TEXTURES=$PWD/scripts/greeter-textures.py \
python3 scripts/greeter-anim-launch.py --shot $T/shot.png \
    "--pass=--frame-at=0,0.3,0.6,1" "--pass=--frame-out=$T/out"
```

> Kalau layar login bermasalah setelah deploy: `Ctrl+Alt+F2` → login TTY →
> `sudo bash ~/Documents/zhardeb/scripts/apply-lightdm-greeter.sh --no-anim`
> (atau `--no-autologin` untuk memunculkan kartu login biasa) lalu `sudo reboot`.
> Semua berkas `*.conf` lama di-backup otomatis saat deploy, jadi selalu bisa
> dibalikkan.

### 👀 Lihat hasilnya tanpa logout / reboot
```bash
bash scripts/preview-login.sh         # animasi di layar, 30 detik (tekan tombol!)
bash scripts/preview-login.sh 40      # 40 detik
bash scripts/preview-login.sh --card  # potret statis kartu login (ESC = tutup)
```
Mode bawaan (`preview-login.sh`) menjalankan **transisi asli** di layar: kamu
lihat wallpaper tajam + jam besar dulu, tekan tombol apa saja, lalu kartu login
masuk dari bawah dan **jam menetap di atas form** — persis pengalaman saat boot
(mode `--card` merender layar login dari **UI XML asli greeter + CSS tema +
avatar + panel + wallpaper**, lalu menyimpan screenshot-nya ke
`~/Pictures/anime-login-preview.png`).

Greeter asli sendiri tidak bisa dipratinjau saat sesi desktop hidup karena daemon
`lightdm` memegang seat — karena itu pratinjau memakai komponen & pipeline yang
sama supaya yang kamu lihat = yang nanti muncul.

> Ringan: greeter GTK polos tanpa efek berat — hanya CSS & transparansi, RAM
> greeter ±20–30 MB. Uji tanpa reboot: `sudo systemctl restart lightdm`
> (simpan pekerjaan dulu, sesi akan ditutup).

### 🩺 Troubleshooting login screen

**Cek dulu apakah LightDM hidup:**
```bash
systemctl status lightdm
```

**LightDM gagal / tidak tampil sama sekali?** Penyebab umum:
1. **Autologin tanpa grup `autologin`** — PAM menolak autologin dan seat gagal.
   Solusi (script versi baru melakukannya otomatis):
   ```bash
   sudo groupadd --system autologin
   sudo usermod -aG autologin $USER
   ```
2. **`/etc/lightdm/lightdm.conf` rusak** (key duplikat/tercampur antar section).
   Script versi baru tidak lagi menyuntik key ke main conf — semuanya lewat
   drop-in `/etc/lightdm/lightdm.conf.d/50-anime-glass.conf`, dan key lama di
   main conf dikomentari otomatis. Kembalikan backup `lightdm.conf.bak.*` bila
   perlu.
3. **Cek log penyebab persisnya:**
   ```bash
   sudo journalctl -b -u lightdm --no-pager | tail -30
   sudo cat /var/log/lightdm/lightdm.log | tail -30
   ```

> Catatan: tampilan kartu login pakai selector widget asli greeter
> (`#login_window`, `#content_frame`, `#buttonbox_frame`) sesuai sample resmi
> Debian — versi CSS lama memakai selector yang salah sehingga kartu tampak
> polos/gelap.

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
├── update-wallpaper.sh        # ganti wallpaper + warna UI otomatis (--random)
├── rotate-wallpaper.sh        # rotasi wallpaper bergilir/acak
├── README.md                  # panduan ini
├── scripts/
│   ├── apply-leyzs-panel.sh   # tata panel ala waybar By-LeyzS
│   ├── generate-panel-info.sh # tata ulang panel + conky
│   ├── apply-lightdm-greeter.sh  # deploy layar login (CSS, wallpaper, avatar, animasi)
│   ├── login-assets.py        # generator aset login (blur+vignette, tekstur kaca)
│   ├── render-login-card.py   # render kartu login (UI greeter asli) jadi PNG
│   ├── preview-login.py       # pratinjau layar login tanpa logout
│   ├── preview-login.sh       # pratinjau (bawaan = animasi, --card = statis)
│   ├── greeter-textures.py    # potong kartu + strip panel dari potret layar login
│   ├── greeter-anim.py        # overlay animasi (jam besar → atas form, kartu naik)
│   ├── greeter-anim-launch.py # penyiap overlay di sesi greeter (--shot = pratinjau)
│   ├── window-shortcuts.sh    # Super+←/→/↑/↓ (geser + nembus workspace)
│   └── greeter-anim-launch.sh # dipanggil LightDM (greeter-setup-script)
├── config/
│   ├── wallpapers/            # koleksi wallpaper terpusat (originals/)
│   ├── picom/picom.conf       # konfigurasi glassmorphism ringan
│   ├── conky/anime-glass.conf # widget info desktop (kiri-tengah)
│   ├── conky/anime-glass.lua # gambar kartu glass (warna dari pywal)
│   ├── cava/config            # visualizer audio (warna pywal) — ala By-LeyzS
│   ├── btop/btop.conf         # monitor sistem (tema pywal) — ala By-LeyzS
│   ├── fastfetch/             # sysinfo + logo anime ASCII — ala By-LeyzS
│   ├── xfce4/terminal/terminalrc
│   ├── xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
│   ├── gtk-3.0/settings.ini
│   ├── gtk-3.0/gtk.css        # override warna (ditulis ulang pywal)
│   └── kitty/kitty.conf       # port kitty By-LeyzS (opacity 0.6 + pywal)
└── asset/                     # gambar anime asli (user upload)
```

---

## 🐛 Troubleshooting

- **Firefox "kecil banget" + bercak blur saat minimize/restore**: penyebabnya
  animasi `hide`/`show` picom — xfwm4 tidak memberi target geometri taskbar,
  jadi window digambar menyusut ke ukuran mungil dan blur `dual_kawase`
  ikut ter-render di window kecil itu. Sudah diperbaiki: animasi hide/show
  dihapus dari `picom.conf` (minimize/restore memakai fade halus saja) dan
  Firefox dikecualikan dari blur. Solusi bila muncul lagi: hapus animasi
  dengan trigger `hide`/`show` di `config/picom/picom.conf`.
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

- **Login screen v5.2** — **HEADER jadi PIL kaca**: mengambang dengan ujung
  membulat penuh, tekstur `glass-bar.jpg` yang kini **di-blur tersendiri**
  (`--bar-blur 14`, dulu ikut latar sehingga jadi tajam), tint lebih transparan,
  dan teks **Poppins**. Jam juga dibersihkan: **tanpa halo/glow** (biang "kabur")
  dan jam final digambar 1:1 sehingga tajam; serah-terima jam besar → jam final
  kini di titik yang sama tanpa gambar dobel.
- **Login screen v5.1** — flip kartu dibersihkan (solid, tanpa fade-in/glow/
  kilau/peregangan) dan transisi setelah login benar-benar bersih: overlay +
  jam menetap hilang **±0,1 detik** setelah window greeter dihancurkan (dipantau
  `xprop -spy` + cadangan 2 detik), jadi tidak ada yang menempel di desktop.
- **Login screen v5** — latar login jadi **TAJAM** (tanpa blur; kartu tetap kaca
  buram), panel **tanpa jam**, dan alur baru: idle = wallpaper + **jam besar &
tanggal di tengah** (tanpa teks "tekan enter", hanya tiga titik halus) → tekan
  tombol → tanggal hilang, kartu naik, jam **terbang & menetap di atas form**
  (window kecil, klik-tembus, ikut menutup saat kamu berhasil login). Jam memakai
  font **Poppins** (fallback Inter). Wallpaper login: **blue-girl.jpg**.
  Setelan baru: `clock_size`, `clock_gap`, `stay`, `linger-ttl` (khusus pratinjau).
- **Login screen v4.1** — splash layar login diperbesar (font 34px + tiga titik
  indikator), animasi kartu masuk diperdalam (flip + sheen + glow + zoom
  Ken-Burns yang kembali normal di akhir).
- **Shortcut `Super+↑/↓`** kini "nembus" ke workspace atas/bawah memakai grid
  `_NET_DESKTOP_LAYOUT` (2×2 di mesin ini) dan `_NET_WORKAREA`; binding xfwm4
  yang dobel otomatis dibersihkan oleh `scripts/apply-workspace-shortcuts.sh`.
- Tema GTK Catppuccin: URL download menggunakan asset
  `catppuccin-mocha-blue-standard+default.zip` (v1.0.3+), bukan nama lama.
- Icon pack Tela-circle: repo ini tidak lagi menyediakan `Tela-circle-dark.zip`
  di release terbaru, jadi default otomatis ke Papirus dan `ICONS=tela-circle`
  akan fallback ke Papirus bila unduhan gagal.
