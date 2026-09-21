-- ============================================================================
--  anime-glass.lua — info sistem yang TANPA latar, langsung di wallpaper
--
--  Desain: tidak ada gambar latar, tidak ada haze, tidak ada transparansi.
--  Teks & bar digambar langsung di atas conky window transparan — sehingga
--  wallpaper terlihat jelas di belakangnya. Widget terasa seperti bagian
--  dari artwork wallpaper, bukan overlay yang ditempel.
--
--  Warna: pywal (~/.cache/wal/colors) — jam pakai warna aksen wallpaper,
--  teks pakai foreground, bar pakai aksen gradient.
--  Bayangan teks gelap tebal supaya terbaca di wallpaper terang sekalipun.
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
    if #cols < 16 then
        cols = {'151c1d','B9A555','1F6DA2','5F6F96','9B7589','578DB9','5095C3','c4c6c6','5e7073','B9A555','1F6DA2','5F6F96','9B7589','578DB9','5095C3','c4c6c6'}
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

local function lerp(c1, c2, t)
    return { c1[1] + (c2[1] - c1[1]) * t, c1[2] + (c2[2] - c1[2]) * t,
             c1[3] + (c2[3] - c1[3]) * t, 1.0 }
end

-- Warna: putih bersih untuk semua teks
local CLOCK_COL = {1, 1, 1, 1}      -- jam: putih
local ACC       = rgba(C[6], 1.00)  -- aksen (bar, divider)
local ACC2      = {1, 1, 1, 0.80}   -- label: putih agak transparan
local FGL       = {1, 1, 1, 1}      -- teks utama: putih
local SUB       = {1, 1, 1, 0.70}   -- teks sekunder: putih redup
local SHADOW    = {0, 0, 0, 0.60}   -- bayangan gelap untuk kontras
local WHITE     = {1, 1, 1, 1}

-- --- helper cairo -----------------------------------------------------------
local function text(cr, s, x, y, size, weight, col, align, no_shadow)
    if not s or s == '' then return end
    cairo_select_font_face(cr, FONT, CAIRO_FONT_SLANT_NORMAL, weight)
    cairo_set_font_size(cr, size)
    local w = string.len(s) * size * 0.6
    local tx = x
    if align == 'right' then tx = x - w end
    if align == 'center' then tx = x - w / 2 end
    if not no_shadow then
        cairo_set_source_rgba(cr, SHADOW[1], SHADOW[2], SHADOW[3], SHADOW[4])
        cairo_move_to(cr, tx + 1.5, y + 1.5)
        cairo_show_text(cr, s)
    end
    cairo_set_source_rgba(cr, col[1], col[2], col[3], col[4])
    cairo_move_to(cr, tx, y)
    cairo_show_text(cr, s)
end

-- Garis gradasi
local function gline(cr, x1, x2, y, col, alpha)
    local pat = cairo_pattern_create_linear(x1, 0, x2, 0)
    cairo_pattern_add_color_stop_rgba(pat, 0.00, col[1], col[2], col[3], 0)
    cairo_pattern_add_color_stop_rgba(pat, 0.20, col[1], col[2], col[3], (alpha or 0.4) * 0.7)
    cairo_pattern_add_color_stop_rgba(pat, 0.50, col[1], col[2], col[3], (alpha or 0.4) * 1.3)
    cairo_pattern_add_color_stop_rgba(pat, 0.80, col[1], col[2], col[3], (alpha or 0.4) * 0.7)
    cairo_pattern_add_color_stop_rgba(pat, 1.00, col[1], col[2], col[3], 0)
    cairo_set_line_width(cr, 1)
    cairo_set_source(cr, pat)
    cairo_move_to(cr, x1, y + 0.5)
    cairo_line_to(cr, x2, y + 0.5)
    cairo_stroke(cr)
    cairo_pattern_destroy(pat)
end

-- bar: track gelap + gradasi aksen wallpaper
local function bar(cr, x, y, w, h, pct, col)
    pct = math.max(0, math.min(100, pct or 0))
    local r = h / 2
    local function track(ox, oy)
        cairo_new_sub_path(cr)
        cairo_arc(cr, x + w - r + ox, y + r + oy, r, -math.pi / 2, math.pi / 2)
        cairo_arc(cr, x + w - r + ox, y + h - r + oy, r, 0, math.pi)
        cairo_arc(cr, x + r + ox, y + h - r + oy, r, math.pi / 2, 3 * math.pi / 2)
        cairo_arc(cr, x + r + ox, y + r + oy, r, math.pi, 3 * math.pi / 2)
        cairo_close_path(cr)
    end
    -- track gelap
    track(0, 0)
    cairo_set_source_rgba(cr, 0, 0, 0, 0.45)
    cairo_fill(cr)
    -- isi bar
    if pct > 1 then
        local fw = math.max(w * pct / 100, h)
        local bright = lerp(col, WHITE, 0.35)
        local pat = cairo_pattern_create_linear(x, 0, x + fw, 0)
        cairo_pattern_add_color_stop_rgba(pat, 0.0, col[1], col[2], col[3], 0.95)
        cairo_pattern_add_color_stop_rgba(pat, 1.0, bright[1], bright[2], bright[3], 0.95)
        cairo_new_sub_path(cr)
        cairo_arc(cr, x + fw - r, y + r, r, -math.pi / 2, math.pi / 2)
        cairo_arc(cr, x + fw - r, y + h - r, r, 0, math.pi / 2)
        cairo_arc(cr, x + r, y + h - r, r, math.pi / 2, math.pi)
        cairo_arc(cr, x + r, y + r, r, math.pi, 3 * math.pi / 2)
        cairo_close_path(cr)
        cairo_set_source(cr, pat)
        cairo_fill(cr)
        cairo_pattern_destroy(pat)
    end
end

-- --- draw utama -------------------------------------------------------------
function conky_draw_card()
    if not conky_window then return end

    local cs = cairo_xlib_surface_create(
        conky_window.display, conky_window.drawable,
        conky_window.visual, conky_window.width, conky_window.height
    )
    local cr = cairo_create(cs)
    local W = conky_window.width
    local H = conky_window.height
    local XL = 36
    local XR = W - 36

    -- Jam besar + tanggal (langsung di wallpaper, tanpa latar)
    text(cr, conky_parse('${time %H:%M}'), XL, 84, 80, CAIRO_FONT_WEIGHT_BOLD, CLOCK_COL, 'left')
    text(cr, conky_parse('${time %S}'), XR, 66, 20, CAIRO_FONT_WEIGHT_BOLD, ACC, 'right')
    text(cr, conky_parse('${time %A}'), XR, 94, 14, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    text(cr, conky_parse('${time %d %B %Y}'), XR, 114, 12, CAIRO_FONT_WEIGHT_NORMAL, SUB, 'right')

    -- Divider
    gline(cr, XL, XR, 134, ACC, 0.40)

    -- CPU / RAM / DISK
    local cpu = tonumber(conky_parse('${cpu cpu0}')) or 0
    local ram = tonumber(conky_parse('${memperc}')) or 0
    local dsk = tonumber(conky_parse('${fs_used_perc /}')) or 0

    text(cr, 'CPU', XL, 166, 12, CAIRO_FONT_WEIGHT_BOLD, ACC2, 'left')
    text(cr, string.format('%.0f%%', cpu), XR, 166, 13, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    bar(cr, XL, 176, XR - XL, 6, cpu, ACC)

    text(cr, 'RAM', XL, 204, 12, CAIRO_FONT_WEIGHT_BOLD, ACC2, 'left')
    text(cr, string.format('%.0f%%', ram), XR, 204, 13, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    bar(cr, XL, 214, XR - XL, 6, ram, ACC)

    text(cr, 'DISK', XL, 242, 12, CAIRO_FONT_WEIGHT_BOLD, ACC2, 'left')
    text(cr, string.format('%.0f%%', dsk), XR, 242, 13, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    bar(cr, XL, 252, XR - XL, 6, dsk, ACC)

    -- Divider
    gline(cr, XL, XR, 278, ACC, 0.40)

    -- Info baris
    local function row(label, value, y)
        text(cr, label, XL, y, 12, CAIRO_FONT_WEIGHT_BOLD, ACC2, 'left')
        text(cr, value, XR, y, 13, CAIRO_FONT_WEIGHT_NORMAL, FGL, 'right')
    end

    local temp = conky_parse("${execpi 60 sensors | awk '/Package id 0:/ {print $4}'}")
    if temp == '' or temp == nil then temp = '—' end

    local topname = conky_parse('${top name 1}')
    local topcpu  = conky_parse('${top cpu 1}')
    if topname == '' or topname == nil then topname = '—' end

    row('UPTIME', conky_parse('${uptime}'), 306)
    row('PROSES', conky_parse('${running_processes}') .. ' / ' .. conky_parse('${processes}'), 334)
    row('SUHU', temp, 362)
    row('TOP', topname .. '  ' .. topcpu .. '%', 390)

    -- Footer
    text(cr, '✦  A N I M E   G L A S S  ✦', W / 2, 434, 10, CAIRO_FONT_WEIGHT_BOLD, ACC2, 'center')
    text(cr, conky_parse('${time %Z}'), W / 2, 452, 9, CAIRO_FONT_WEIGHT_NORMAL, SUB, 'center')

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end
