# ✨ Anime Glassmorphism — Xfce (Debian 12)

Setup otomatis agar Desktop Environment Xfce tampil **glassmorphism ala anime**:
transparan + blur tipis, sudut membulat, warna pastel, terminal senada —
**tetap ringan (RAM & CPU rendah)**.

---

## 📦 Isi Paket

| File | Fungsi |
|---|---|
| `xfce-anime-setup.sh` | Skrip utama: install & konfigurasi semua |
| `update-wallpaper.sh` | Tautkan wallpaper anime baru + warna otomatis (pywal) |
| `wallpapers/anime-1920x1080.jpg` | Wallpaper utama dari asetmu, sudah **landscape** (blur-fill) |
| `wallpapers/anime-*-1920x1080.jpg` | Versi landscape gambar anime lain di `asset/` |
| `config/picom/picom.conf` | Compositor: rounded corners, blur tipis, transparansi hemat daya |
| `config/xfce4/terminal/terminalrc` | xfce4-terminal: palette pastel anime + semi-transparan + Nerd Font |
| `config/xfce4/.../xfce4-panel.xml` | Panel floating (tengah-atas) semi-transparan |
| `config/gtk-3.0/settings.ini` | Fallback tema/ikon/font untuk aplikasi GTK |
| `config/kitty/kitty.conf` | Opsional bila memakai kitty |

---

## 🚀 Cara Pakai (3 Langkah)

### Langkah 1 — Jalankan skrip instalasi
```bash
cd /lokasi/folder-ini
bash xfce-anime-setup.sh
```
Skrip otomatis:
- `apt install` → picom, xfce4-terminal, imagemagick, unzip, curl, fonts Inter & emoji
- Unduh **JetBrainsMono Nerd Font** → `~/.local/share/fonts`
- Unduh **tema GTK Catppuccin Mocha** → `~/.themes` dan **ikon Tela-circle** → `~/.icons`
- Salin semua konfigurasi ke `~/.config/` (yang lama di-backup `.bak`)
- Salin wallpaper ke `~/Pictures/Wallpapers/Anime/` + buat versi landscape + set sebagai wallpaper
- Matikan compositor bawaan xfwm4, aktifkan **picom** (autostart dibuat)

**Opsi tambahan:**
```bash
bash xfce-anime-setup.sh --apply-panel   # + panel floating tengah-atas (backup otomatis)
bash xfce-anime-setup.sh --pywal         # + install pywal16 (warna ikut wallpaper)
bash xfce-anime-setup.sh --kitty         # + pasang & konfigurasi kitty
THEME=whitesur bash xfce-anime-setup.sh  # pakai WhiteSur (alternatif glassy macOS)
RESOLUTION=2560x1440 bash xfce-anime-setup.sh  # wallpaper buat layar 2K
```

### Langkah 2 — Restart sesi
Logout → login kembali (atau restart X). Tema, ikon, dan font baru terlihat penuh.

### Langkah 3 — Cek compositor
```bash
pgrep -x picom          # harus ada output PID
```
Kalau blur/transparansi belum muncul, cek troubleshooting di bawah.

---

## 🖼️ Menautkan Wallpaper Anime Baru (yang kamu unggah)

Semua wallpaper ditaruh di **`~/Pictures/Wallpapers/Anime/`** (dibuat otomatis).

1. Saat instalasi, **semua gambar di folder `asset/` proyek ini** otomatis disalin ke sana, dan `916764067907298333.jpeg` dijadikan wallpaper default. Taruh gambar anime baru ke folder itu, lalu:
```bash
./update-wallpaper.sh ~/Pictures/Wallpapers/Anime/nama-gambar.jpg
```
Skrip itu akan: menyalin gambar → membuat versi **landscape blur-fill** (gambar utuh di tengah, sisi kiri/kanan di-blur senada) → set sebagai wallpaper desktop → bila pywal terpasang, **warna seluruh UI ikut berubah otomatis** mengikuti warna dominan wallpaper:

- **Terminal** — palette 16 warna (xfce4-terminal / kitty)
- **Panel Xfce** — latar panel diambil dari warna dasar wallpaper (semi-transparan)
- **Aplikasi GTK** — `gtk.css` (latar, teks, seleksi, border, tooltip)
- **Teks ikon di desktop** — warna mengikuti foreground wallpaper

> Mau warna terminal selalu nyala wal manual?
> ```bash
> wal -i ~/Pictures/Wallpapers/Anime/nama-gambar.jpg
> ```

---

## 🎨 Rekomendasi Tema & Cara Menggantinya

| Komponen | Default (terinstall) | Alternatif | Catatan |
|---|---|---|---|
| Tema GTK | **Catppuccin Mocha** (pastel, ringan, cocok anime) | WhiteSur (glassy macOS) | `THEME=whitesur bash xfce-anime-setup.sh` |
| Icon pack | **Papirus** (stabil, tersedia di apt Debian 12) | Tela-circle | `ICONS=tela-circle bash xfce-anime-setup.sh` (bila gagal, otomatis fallback ke Papirus) |
| Font terminal | JetBrainsMono Nerd Font | FiraCode, CaskaydiaCove | ubah di Preferences terminal |
| Font UI | Inter | — | via `~/.config/gtk-3.0/settings.ini` |

**Cara ganti manual (GUI):** *Settings → Appearance* → pilih tema & ikon. Atau lewat baris:
```bash
xfconf-query -c xsettings -p /Gtk/ThemeName -s "catppuccin-mocha-blue-standard+default"
xfconf-query -c xsettings -p /Gtk/IconThemeName -s "Tela-circle-dark"
```

---

## 🧊 Panel Floating (jika belum pakai `--apply-panel`)

Cara manual (2 menit, tanpa risiko):
1. Klik kanan panel → **Panel → Panel Preferences**
2. Buka **Display** → lepas centang *"Lock panel"*
3. Geser panel ke **tengah atas** layar (otomatis mengambang)
4. Tab **Appearance** → *"Background"* pilih **None** (transparan penuh) atau *"Solid color"* lalu atur opacity ~70% dengan warna gelap ungu
5. Klik kanan → **Lock panel** lagi

Atau otomatis (backup dibuat):
```bash
bash xfce-anime-setup.sh --apply-panel
```

---

## ⚡ Kenapa Tetap Ringan?

- **Blur tipis** (`blur-strength = 4`, metode `dual_kawase`) — jauh lebih hemat dari gaussian besar
- **Tanpa animasi berat** picom; shadow kecil; `unredir-if-possible` = fullscreen tanpa compositing
- **Tema Catppuccin** = warna polos, tanpa tekstur/efek berat
- Terminal semi-transparan = hanya alpha blending (GPU ringan), bukan transparansi berlapis
- Panel memakai alpha solid 0.72 — tidak ada blur berjalan di panel

Estimasi beban: **< 2–4% CPU** saat idle di picom, RAM tambahan **± 30–50 MB**.

---

## 🔧 Troubleshooting

| Masalah | Solusi |
|---|---|
| Picom tidak jalan | `picom --daemon` di terminal, lihat error. Di mesin tanpa GPU: ganti `backend = "glx"` → `"xrender"` di `~/.config/picom/picom.conf` |
| Sudut tidak membulat | Pastikan picom ≥ 10.1 (`picom --version`). Hapus baris `corner-radius` bila pakai versi lama |
| Terminal tidak blur | Cek `blur-background = true` aktif & picom berjalan; blur hanya muncul di belakang jendela **transparan** |
| Transparansi terminal tidak jalan | Preferences terminal → *Appearance* → centang "Use transparent background" |
| Panel hilang setelah `--apply-panel` | `cp ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml.bak ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml` lalu `xfce4-panel --restart` |
| Warna terminal tidak berubah setelah pywal | Jalankan ulang `./update-wallpaper.sh ...` atau buka terminal baru |
| `wal` tidak ditemukan | `export PATH="$HOME/.local/bin:$PATH"` (sudah ditambahkan ke `.bashrc` oleh skrip) |

---

## 🧹 Batal / Uninstall

- Hapus `~/.config/picom`, `~/.config/autostart/picom.desktop`, kembalikan `.bak` yang ada
- Hapus `~/.themes/catppuccin-*`, `~/.icons/Tela-circle-*`, font di `~/.local/share/fonts` (bila tak dipakai)
- Aktifkan lagi compositor bawaan: `xfconf-query -c xfwm4 -p /general/use_compositing -s true`