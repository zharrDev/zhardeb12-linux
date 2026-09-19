#!/usr/bin/env bash
#
# apply-workspace-shortcuts.sh — atur shortcut window & workspace xfwm4.
#
# Layout workspace di mesin ini 2x2 (rows=2 di workspace switcher), jadi panah
# atas/bawah benar-benar punya tujuan workspace.
#
# Hasil setelah dijalankan:
#   Super+←/→/↑/↓        geser window halus 80px, dan bila MENTOK TEPI → window
#                        "nembus" ke workspace sebelah / bawah / atas
#                        (logikanya di ~/.local/bin/window-shortcuts.sh)
#   Super+Shift+↑/↓      geser window halus 80px (cadangan bila perlu)
#   Super+Shift+←/→      pindah window ke workspace kiri / kanan (bawaan xfwm4)
#   Ctrl+Alt+←/→/↑/↓     pindah tampilan workspace (bawaan Xfce)
#
# PENTING: shortcut xfwm4 `move_window_*_workspace_key` SENGAJA dikosongkan untuk
# panah atas/bawah — kalau tidak, satu tombol (Super+↑/↓) akan memicu DUA aksi
# sekaligus: command kita + aksi bawaan xfwm4.
#
# Langsung aktif tanpa logout (xfconf memantau perubahan). Idempotent.
#
set -euo pipefail

export LC_ALL=C
CH="xfwm4"
say() { printf '\033[1;36m[shortcut]\033[0m %s\n' "$*"; }

set_key() {                       # set_key <nama-key> <nilai>
    local key="$1" val="$2"
    xfconf-query -c "$CH" -p "/$CH/keyboard_shortcuts/$key" -n -t string -s "$val" 2>/dev/null \
        || xfconf-query -c "$CH" -p "/$CH/keyboard_shortcuts/$key" -t string -s "$val"
}

unset_key() {                    # kembalikan key ke nilai bawaan/kosong
    local key="$1"
    xfconf-query -c "$CH" -p "/$CH/keyboard_shortcuts/$key" -r -R 2>/dev/null || true
}

say "Mengatur shortcut window/workspace…"

# panah ATAS/BAWAH ditangani window-shortcuts.sh (Super+↑/↓) termasuk "nembus"
# ke workspace bawah/atas — jadi binding bawaan xfwm4 harus dikosongkan.
unset_key move_window_up_workspace_key
unset_key move_window_down_workspace_key

set_key move_window_left_workspace_key   "<Super><Shift>Left"
set_key move_window_right_workspace_key  "<Super><Shift>Right"

# geser window halus (nudge) — cadangan di Super+Shift+panah atas/bawah
set_key move_window_up_key    "<Super><Shift>Up"
set_key move_window_down_key  "<Super><Shift>Down"

# pindah TAMPILAN workspace (kalau belum diatur, biarkan seperti bawaan Xfce)
for spec in "left_workspace_key:<Primary><Alt>Left" \
            "right_workspace_key:<Primary><Alt>Right" \
            "up_workspace_key:<Primary><Alt>Up" \
            "down_workspace_key:<Primary><Alt>Down"; do
    k="${spec%%:*}"; v="${spec#*:}"
    if [ -z "$(xfconf-query -c "$CH" -p "/$CH/keyboard_shortcuts/$k" 2>/dev/null || true)" ]; then
        set_key "$k" "$v" || true
    fi
done

say "Selesai. Ringkasan yang terpasang:"
printf '  %-34s %s\n' "Super+←/→/↑/↓ (command)" \
    "$(printf '%s' "$HOME/.local/bin/window-shortcuts.sh") {left,right,up,down}"
for k in move_window_left_key move_window_right_key move_window_up_key move_window_down_key \
         move_window_up_workspace_key move_window_down_workspace_key \
         move_window_left_workspace_key move_window_right_workspace_key \
         left_workspace_key right_workspace_key up_workspace_key down_workspace_key; do
    val="$(xfconf-query -c "$CH" -p "/$CH/keyboard_shortcuts/$k" 2>/dev/null || echo '-')"
    printf '  %-34s %s\n' "${k%_key}" "$val"
done
