#!/usr/bin/env bash
#
# generate-panel-info.sh — tambah plugin informasi (jam, tanggal, CPU, RAM, cuaca)
# ke panel XFCE floating.
#
# Cara pakai (setelah login):
#   bash generate-panel-info.sh
#
# Apa yang dilakukan:
#   - Menambahkan plugin-panel:
#       • clock          → jam + tanggal (format: "Hari, DD Mon YYYY | HH:MM")
#       • xfce4-sensors → CPU%, RAM usage, suhu (info sistem)
#       • weather       → cuaca daerah (opsional)
#   - Mengatur posisi plugin di panel (kiri = info, kanan = menu/systray/actions).
#
# Plugin yang tersedia di sistem (diperiksa dari /usr/share/xfce4/panel/plugins):
#
set -euo pipefail

PANEL_NAME="xfce4-panel"

# --- 1. Pastikan panel berjalan & kita punya hak akses ke xfconf ---
xfce4-panel --query >/dev/null 2>&1 || { echo "[peringatan] panel tidak berjalan."; exit 0; }

# --- 2. Tentukan urutan plugin yang diinginkan ---
# Urutan kiri→kanan di panel:
#   showdesktop | separator | applicationsmenu | separator | clock | separator |
#   xfce4-sensors | separator | weather | separator | systray | separator |
#   tasklist | separator | actions
#
# ID plugin yang sudah ada di panel saat ini akan dipertahankan.
# Plugin baru akan dimasukkan dengan ID baru yang belum dipakai.
#
# NOTE: xfconf-query -c xfce4-panel -p /plugins/plugin-X -s value
#       akan menambah/mengganti plugin pada ID X. Sebaiknya kita sanggupkan
#       ID baru yang belum dipakai.

declare -a WANTED=(
    "clock"
    "xfce4-sensors"
    "weather"
)

# --- 3. Ambil daftar plugin ID yang sedang dipakai ---
CURRENT_IDS=$(xfconf-query -c "$PANEL_NAME" -p "/panels/panel-1/plugin-ids" \
    -t int 2>/dev/null | tr ',' ' ' | tr -d '[]' || true)

echo "Plugin IDs saat ini: $CURRENT_IDS"

# --- 4. Tentukan ID baru untuk tiap plugin yang ingin ditambahkan ---
next_id=1
for id in $CURRENT_IDS; do
    if [ "$id" -gt "$next_id" ]; then
        break
    fi
    next_id=$((id + 1))
done

declare -A PLUGIN_ID_MAP
for plugin in "${WANTED[@]}"; do
    if ! echo "$CURRENT_IDS" | grep -qw "$plugin"; then
        PLUGIN_ID_MAP["$plugin"]=$next_id
        next_id=$((next_id + 1))
        echo "Plugin baru: $plugin → ID ${PLUGIN_ID_MAP[$plugin]}"
    else
        echo "Plugin $plugin sudah ada di panel."
    fi
done

# --- 5. Set plugin baru ke panel (via xfconf-query) ---
for plugin in "${WANTED[@]}"; do
    if [ -n "${PLUGIN_ID_MAP[$plugin]+_}" ]; then
        local id="${PLUGIN_ID_MAP[$plugin]}"
        xfconf-query -c "$PANEL_NAME" -p "/plugins/plugin-$id" \
            -s "$plugin" -t string 2>/dev/null || \
            echo "[peringatan] gagal men-set plugin $plugin"
    fi
done

# --- 6. Atur properti khusus (untuk clock, sensors, weather) ---
# Clock: format tanggal & jam yang elegan (contoh: "Sen, 23 Feb 2026 | 14:30")
for id in "${!PLUGIN_ID_MAP[@]}"; do
    case "${PLUGIN_ID_MAP[$id]}" in
        clock)
            # Mengatur format clock (jika properti tersedia)
            xfconf-query -c "$PANEL_NAME" -p "/plugins/plugin-${PLUGIN_ID_MAP[$id]}/format" \
                -s "%a, %d %b %Y  |  %H:%M" -t string 2>/dev/null || true
            ;;
        xfce4-sensors)
            # Tidak ada properti khusus yang wajib diatur; plugin sudah menampilkan
            # CPU, RAM, suhu secara default.
            ;;
        weather)
            # Weather mungkin perlu konfigurasi lokasi. Biarkan default untuk saat ini.
            ;;
    esac
done

# --- 7. Restart panel ---
xfce4-panel --restart 2>/dev/null || pkill -x xfce4-panel 2>/dev/null || true
echo "Panel di-restart. Plugin info (clock, sensors, weather) akan muncul."

# --- 8. Catatan tambahan ---
echo ""
echo "Catatan:"
echo "  • Clock muncul di panel dengan format tanggal & jam."
echo "  • CPU & RAM muncul dari xfce4-sensors-plugin."
echo "  • Cuaca dari weather-plugin (opsional)."
echo "  • Panel semi-transparan (rgba(30,30,46,0.82)) — warna diatur oleh pywal."
echo ""
echo "Jika plugin tidak muncul, buka Panel Preferences → Add → pilih plugin yang diinginkan."