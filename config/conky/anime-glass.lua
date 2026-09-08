-- ============================================================================
--  anime-glass.lua — kartu glass elegan dengan banner anime + info sistem
--  Warna diambil dari pywal (~/.cache/wal/colors) agar senada dengan wallpaper.
-- ============================================================================
require 'cairo'

local HOME = os.getenv('HOME')
local FONT = 'JetBrainsMono Nerd Font Mono'
local BANNER = HOME .. '/.config/conky/anime-banner.png'
local AVATAR = HOME .. '/.config/conky/anime-avatar.png'

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

-- warna-warna tema
local BG   = rgba(C[1], 0.82) -- latar kartu (gelap, semi-transparan)
local BORD = rgba(C[2], 0.60) -- garis tepi (aksen)
local ACC  = rgba(C[2], 1.00) -- aksen utama
local ACCS = rgba(C[2], 0.50) -- aksen lembut (divider, footer)
local FGL  = rgba(C[7], 1.00) -- teks utama
local SUB  = rgba(C[6], 0.90) -- teks sekunder
local TRK  = rgba(C[1], 0.60) -- track bar
local WHITE = {1, 1, 1, 1}

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

-- bar dengan gradasi aksen + highlight atas
local function bar(cr, x, y, w, h, pct, col)
    pct = math.max(0, math.min(100, pct or 0))
    local r = h / 2
    -- track
    round_rect(cr, x, y, w, h, r)
    cairo_set_source_rgba(cr, TRK[1], TRK[2], TRK[3], TRK[4])
    cairo_fill(cr)
    if pct > 1 then
        local fw = math.max(w * pct / 100, h)
        local bright = lerp(col, WHITE, 0.35)
        -- gradasi kiri→kanan: aksen → lebih terang
        local pat = cairo_pattern_create_linear(x, 0, x + fw, 0)
        cairo_pattern_add_color_stop_rgba(pat, 0.0, col[1], col[2], col[3], 0.95)
        cairo_pattern_add_color_stop_rgba(pat, 1.0, bright[1], bright[2], bright[3], 0.95)
        round_rect(cr, x, y, fw, h, r)
        cairo_set_source(cr, pat)
        cairo_fill(cr)
        cairo_pattern_destroy(pat)
        -- highlight tipis di atas bar
        round_rect(cr, x, y, fw, math.max(2, h * 0.35), r)
        cairo_set_source_rgba(cr, 1, 1, 1, 0.28)
        cairo_fill(cr)
    end
end

-- banner anime (crop wallpaper) di bagian atas kartu
local function draw_banner(cr, W, BH)
    local surf = cairo_image_surface_create_from_png(BANNER)
    if surf == nil or cairo_image_surface_get_width(surf) == 0 then
        return
    end
    local bw = cairo_image_surface_get_width(surf)
    local bh = cairo_image_surface_get_height(surf)
    cairo_save(cr)
    -- clip ke bentuk kartu (agar sudut atas membulat)
    round_rect(cr, 0, 0, W, BH, 26)
    cairo_clip(cr)
    cairo_scale(cr, W / bw, BH / bh)
    cairo_set_source_surface(cr, surf, 0, 0)
    cairo_paint(cr)
    cairo_restore(cr)
    cairo_surface_destroy(surf)

    -- gradasi gelap di bawah banner agar menyatu dengan body kartu
    local pat = cairo_pattern_create_linear(0, BH - 70, 0, BH)
    cairo_pattern_add_color_stop_rgba(pat, 0.0, BG[1], BG[2], BG[3], 0.0)
    cairo_pattern_add_color_stop_rgba(pat, 1.0, BG[1], BG[2], BG[3], 1.0)
    cairo_save(cr)
    round_rect(cr, 0, 0, W, BH, 26)
    cairo_clip(cr)
    cairo_rectangle(cr, 0, BH - 70, W, 70)
    cairo_set_source(cr, pat)
    cairo_fill(cr)
    cairo_restore(cr)
    cairo_pattern_destroy(pat)
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
    local XL = 26
    local XR = W - 26

    -- 1) kartu glass
    round_rect(cr, 0, 0, W, H, 26)
    cairo_set_source_rgba(cr, BG[1], BG[2], BG[3], BG[4])
    cairo_fill(cr)

    -- 2) banner anime (top)
    draw_banner(cr, W, 120)

    -- 3) header + avatar anime (lingkaran kecil, gambar asset)
    cairo_set_source_rgba(cr, ACC[1], ACC[2], ACC[3], ACC[4])
    cairo_arc(cr, XL + 4, 143, 4, 0, 2 * math.pi)
    cairo_fill(cr)
    text(cr, 'S Y S T E M   M O N I T O R', XL + 16, 148, 11, CAIRO_FONT_WEIGHT_BOLD, ACC, 'left')
    local av = cairo_image_surface_create_from_png(AVATAR)
    if av ~= nil and cairo_image_surface_get_width(av) > 0 then
        local cx, cy, r = XR - 10, 146, 28
        cairo_save(cr)
        cairo_arc(cr, cx, cy, r, 0, 2 * math.pi)
        cairo_clip(cr)
        cairo_set_source_surface(cr, av, cx - r, cy - r)
        cairo_paint(cr)
        cairo_restore(cr)
        cairo_set_source_rgba(cr, ACC[1], ACC[2], ACC[3], ACC[4])
        cairo_set_line_width(cr, 2)
        cairo_arc(cr, cx, cy, r, 0, 2 * math.pi)
        cairo_stroke(cr)
    end
    cairo_surface_destroy(av)

    -- 4) jam besar + tanggal
    text(cr, conky_parse('${time %H:%M}'), XL, 196, 46, CAIRO_FONT_WEIGHT_BOLD, FGL, 'left')
    text(cr, conky_parse('${time %S}'), XR, 178, 15, CAIRO_FONT_WEIGHT_BOLD, ACC, 'right')
    text(cr, conky_parse('${time %A}'), XR, 200, 13, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    text(cr, conky_parse('${time %d %B %Y}'), XR, 217, 10.5, CAIRO_FONT_WEIGHT_NORMAL, SUB, 'right')

    -- 5) divider
    hline(cr, XL, XR, 236, ACCS)

    -- 6) CPU / RAM / DISK
    local cpu = tonumber(conky_parse('${cpu cpu0}')) or 0
    local ram = tonumber(conky_parse('${memperc}')) or 0
    local dsk = tonumber(conky_parse('${fs_used_perc /}')) or 0

    text(cr, '\u{F2DB}', XL, 266, 13, CAIRO_FONT_WEIGHT_BOLD, ACC, 'left')
    text(cr, 'CPU', XL + 20, 267, 11, CAIRO_FONT_WEIGHT_BOLD, FGL, 'left')
    text(cr, string.format('%.0f%%', cpu), XR, 267, 12, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    bar(cr, XL, 276, XR - XL, 6, cpu, ACC)

    text(cr, '\u{F538}', XL, 306, 13, CAIRO_FONT_WEIGHT_BOLD, ACC, 'left')
    text(cr, 'RAM', XL + 20, 307, 11, CAIRO_FONT_WEIGHT_BOLD, FGL, 'left')
    text(cr, string.format('%.0f%%', ram), XR, 307, 12, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    bar(cr, XL, 316, XR - XL, 6, ram, ACC)

    text(cr, '\u{F0A0}', XL, 346, 13, CAIRO_FONT_WEIGHT_BOLD, ACC, 'left')
    text(cr, 'DISK', XL + 20, 347, 11, CAIRO_FONT_WEIGHT_BOLD, FGL, 'left')
    text(cr, string.format('%.0f%%', dsk), XR, 347, 12, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    bar(cr, XL, 356, XR - XL, 6, dsk, ACC)

    -- 7) divider
    hline(cr, XL, XR, 384, ACCS)

    -- 8) info baris
    local function row(label, value, y)
        text(cr, label, XL, y, 10.5, CAIRO_FONT_WEIGHT_BOLD, SUB, 'left')
        text(cr, value, XR, y, 11, CAIRO_FONT_WEIGHT_NORMAL, FGL, 'right')
    end

    local temp = conky_parse("${execpi 60 sensors | awk '/Package id 0:/ {print $4}'}")
    if temp == '' or temp == nil then temp = '—' end

    local topname = conky_parse('${top name 1}')
    local topcpu  = conky_parse('${top cpu 1}')
    if topname == '' or topname == nil then topname = '—' end

    row('UPTIME', conky_parse('${uptime}'), 412)
    row('PROCESSES', conky_parse('${running_processes}') .. ' / ' .. conky_parse('${processes}'), 437)
    row('TEMP', temp, 462)
    row('TOP  CPU', topname .. '  ' .. topcpu .. '%', 487)

    -- 9) footer
    text(cr, '✦  A N I M E   G L A S S  ✦', W / 2, 522, 9.5, CAIRO_FONT_WEIGHT_BOLD, ACCS, 'center')
    text(cr, conky_parse('${time %Z}'), W / 2, 539, 8.5, CAIRO_FONT_WEIGHT_NORMAL, SUB, 'center')

    -- border kartu (di atas banner, tipis)
    round_rect(cr, 0.75, 0.75, W - 1.5, H - 1.5, 25)
    cairo_set_source_rgba(cr, BORD[1], BORD[2], BORD[3], BORD[4])
    cairo_set_line_width(cr, 1.5)
    cairo_stroke(cr)

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end