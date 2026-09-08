-- ============================================================================
--  anime-glass.lua — menggambar kartu glass elegan untuk conky
--  Warna diambil dari pywal (~/.cache/wal/colors) agar senada dengan wallpaper.
-- ============================================================================
require 'cairo'

local HOME = os.getenv('HOME')
local FONT = 'JetBrainsMono Nerd Font Mono'

-- --- warna dari pywal -------------------------------------------------------
local function wal_colors()
    local cols = {}
    local f = io.open(HOME .. '/.cache/wal/colors', 'r')
    if f then
        for line in f:lines() do
            local c = line:match('^%s*#([0-9a-fA-F]+)%s*$')
            if c and #c == 6 then cols[#cols + 1] = c end
        end
        f:close()
    end
    if #cols < 16 then -- fallback: palet wallpaper default
        cols = {'0a040a','F3254A','9B6C6D','AD7F7F','8B847B','A69E94','D4BEB2','c1c0c1','665366','F3254A','9B6C6D','AD7F7F','8B847B','A69E94','D4BEB2','c1c0c1'}
    end
    return cols
end

local C = wal_colors()

local function rgba(h, a)
    return {
        tonumber(h:sub(1, 2), 16) / 255,
        tonumber(h:sub(3, 4), 16) / 255,
        tonumber(h:sub(5, 6), 16) / 255,
        a or 1.0,
    }
end

-- warna-warna tema
local BG   = rgba(C[1], 0.82) -- latar kartu (gelap, semi-transparan)
local BORD = rgba(C[2], 0.60) -- garis tepi (aksen)
local ACC  = rgba(C[2], 1.00) -- aksen utama
local ACCS = rgba(C[2], 0.50) -- aksen lembut (divider, footer)
local FG   = rgba(C[7], 1.00) -- teks utama
local SUB  = rgba(C[6], 0.88) -- teks sekunder
local TRK  = rgba(C[1], 0.55) -- track bar

-- --- helper cairo -----------------------------------------------------------
local function round_rect(cr, x, y, w, h, r)
    r = math.min(r, h / 2, w / 2)
    cairo_new_sub_path(cr)
    cairo_arc(cr, x + w - r, y + r, r, -math.pi / 2, 0)
    cairo_arc(cr, x + w - r, y + h - r, r, 0, math.pi / 2)
    cairo_arc(cr, x + r, y + h - r, r, math.pi / 2, math.pi)
    cairo_arc(cr, x + r, y + r, r, math.pi, 3 * math.pi / 2)
    cairo_close_path(cr)
end

local function text(cr, s, x, y, size, weight, col, align)
    if not s or s == '' then return end
    cairo_select_font_face(cr, FONT, CAIRO_FONT_SLANT_NORMAL, weight)
    cairo_set_font_size(cr, size)
    -- font mono: lebar karakter kira-kira 0.6em, cukup akurat untuk rata kanan/tengah
    local w = string.len(s) * size * 0.6
    local tx = x
    if align == 'right' then tx = x - w end
    if align == 'center' then tx = x - w / 2 end
    cairo_set_source_rgba(cr, col[1], col[2], col[3], col[4])
    cairo_move_to(cr, tx, y)
    cairo_show_text(cr, s)
end

local function hline(cr, x1, x2, y, col)
    cairo_set_source_rgba(cr, col[1], col[2], col[3], col[4])
    cairo_set_line_width(cr, 1)
    cairo_move_to(cr, x1, y)
    cairo_line_to(cr, x2, y)
    cairo_stroke(cr)
end

local function bar(cr, x, y, w, h, pct, col)
    pct = math.max(0, math.min(100, pct or 0))
    local r = h / 2
    round_rect(cr, x, y, w, h, r)
    cairo_set_source_rgba(cr, TRK[1], TRK[2], TRK[3], TRK[4])
    cairo_fill(cr)
    if pct > 1 then
        local fw = math.max(w * pct / 100, h)
        round_rect(cr, x, y, fw, h, r)
        cairo_set_source_rgba(cr, col[1], col[2], col[3], col[4])
        cairo_fill(cr)
    end
end

-- --- draw utama -------------------------------------------------------------
function conky_draw_card()
    if not conky_window then return end

    local cs = cairo_xlib_surface_create(
        conky_window.display,
        conky_window.drawable,
        conky_window.visual,
        conky_window.width,
        conky_window.height
    )
    local cr = cairo_create(cs)

    local W = conky_window.width
    local H = conky_window.height
    local XL = 26            -- tepi kiri teks
    local XR = W - 26        -- tepi kanan teks

    -- 1) kartu glass
    round_rect(cr, 0, 0, W, H, 26)
    cairo_set_source_rgba(cr, BG[1], BG[2], BG[3], BG[4])
    cairo_fill(cr)
    round_rect(cr, 0.75, 0.75, W - 1.5, H - 1.5, 25)
    cairo_set_source_rgba(cr, BORD[1], BORD[2], BORD[3], BORD[4])
    cairo_set_line_width(cr, 1.5)
    cairo_stroke(cr)

    -- 2) header
    cairo_set_source_rgba(cr, ACC[1], ACC[2], ACC[3], ACC[4])
    cairo_arc(cr, XL + 4, 34, 4, 0, 2 * math.pi)
    cairo_fill(cr)
    text(cr, 'S Y S T E M   M O N I T O R', XL + 16, 39, 11, CAIRO_FONT_WEIGHT_BOLD, ACC, 'left')

    -- 3) jam besar + tanggal
    text(cr, conky_parse('${time %H:%M}'), XL, 100, 46, CAIRO_FONT_WEIGHT_BOLD, FG, 'left')
    text(cr, conky_parse('${time %S}'), XR, 82, 15, CAIRO_FONT_WEIGHT_BOLD, ACC, 'right')
    text(cr, conky_parse('${time %A}'), XR, 104, 13, CAIRO_FONT_WEIGHT_BOLD, FG, 'right')
    text(cr, conky_parse('${time %d %B %Y}'), XR, 121, 10.5, CAIRO_FONT_WEIGHT_NORMAL, SUB, 'right')

    -- 4) divider
    hline(cr, XL, XR, 140, ACCS)

    -- 5) CPU / RAM / DISK
    local cpu = tonumber(conky_parse('${cpu cpu0}')) or 0
    local ram = tonumber(conky_parse('${memperc}')) or 0
    local dsk = tonumber(conky_parse('${fs_used_perc /}')) or 0

    text(cr, '\u{F2DB}', XL, 168, 13, CAIRO_FONT_WEIGHT_BOLD, ACC, 'left')
    text(cr, 'CPU', XL + 20, 169, 11, CAIRO_FONT_WEIGHT_BOLD, FG, 'left')
    text(cr, string.format('%.0f%%', cpu), XR, 169, 12, CAIRO_FONT_WEIGHT_BOLD, FG, 'right')
    bar(cr, XL, 178, XR - XL, 6, cpu, ACC)

    text(cr, '\u{F538}', XL, 208, 13, CAIRO_FONT_WEIGHT_BOLD, ACC, 'left')
    text(cr, 'RAM', XL + 20, 209, 11, CAIRO_FONT_WEIGHT_BOLD, FG, 'left')
    text(cr, string.format('%.0f%%', ram), XR, 209, 12, CAIRO_FONT_WEIGHT_BOLD, FG, 'right')
    bar(cr, XL, 218, XR - XL, 6, ram, ACC)

    text(cr, '\u{F0A0}', XL, 248, 13, CAIRO_FONT_WEIGHT_BOLD, ACC, 'left')
    text(cr, 'DISK', XL + 20, 249, 11, CAIRO_FONT_WEIGHT_BOLD, FG, 'left')
    text(cr, string.format('%.0f%%', dsk), XR, 249, 12, CAIRO_FONT_WEIGHT_BOLD, FG, 'right')
    bar(cr, XL, 258, XR - XL, 6, dsk, ACC)

    -- 6) divider
    hline(cr, XL, XR, 286, ACCS)

    -- 7) info baris
    local function row(label, value, y)
        text(cr, label, XL, y, 10.5, CAIRO_FONT_WEIGHT_BOLD, SUB, 'left')
        text(cr, value, XR, y, 11, CAIRO_FONT_WEIGHT_NORMAL, FG, 'right')
    end

    local temp = conky_parse("${execpi 60 sensors | awk '/Package id 0:/ {print $4}'}")
    if temp == '' or temp == nil then temp = '—' end

    local topname = conky_parse('${top name 1}')
    local topcpu  = conky_parse('${top cpu 1}')
    if topname == '' or topname == nil then topname = '—' end

    row('UPTIME', conky_parse('${uptime}'), 316)
    row('PROCESSES', conky_parse('${running_processes}') .. ' / ' .. conky_parse('${processes}'), 341)
    row('TEMP', temp, 366)
    row('TOP  CPU', topname .. '  ' .. topcpu .. '%', 391)

    -- 8) footer
    text(cr, '✦  A N I M E   G L A S S  ✦', W / 2, 430, 9.5, CAIRO_FONT_WEIGHT_BOLD, ACCS, 'center')
    text(cr, conky_parse('${time %Z}'), W / 2, 448, 8.5, CAIRO_FONT_WEIGHT_NORMAL, SUB, 'center')

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end