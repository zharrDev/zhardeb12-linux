-- ============================================================================
--  anime-glass.lua — info sistem yang BENAR-BENAR menyatu dengan wallpaper
--
--  Filosofi desain:
--    Widget = satu potongan wallpaper (anime-haze.png) yang ditampilkan
--    dengan OPACITY BERVARIASI di berbagai ketinggian:
--      - atas  : wallpaper menunjukkan lebih jelas (seperti "banner alami")
--      - tengah: wallpaper sedikit redup (kontras untuk teks & bar)
--      - bawah : wallpaper memudar ke nol (tepian tanpa garis)
--
--    Tidak ada elemen terpisah (banner terpisah, avatar bulat, kartu gelap).
--    Yang ada: SATU gambar wallpaper + teks + bar — semuanya mengambang
--    di atasnya dengan opacity yang berubah-ubah. Hasil: widget terasa
--    seperti bagian dari wallpaper itu sendiri, bukan overlay yang ditempel.
--
--  Warna diambil dari pywal (~/.cache/wal/colors) untuk aksen bar/divider.
-- ============================================================================
require 'cairo'

local HOME = os.getenv('HOME')
local FONT = 'JetBrainsMono Nerd Font Mono'
local HAZEIMG = HOME .. '/.config/conky/anime-haze.png'
local HAZE_A = 0.88 -- kepekatan latar wallpaper

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

local ACC  = rgba(C[6], 1.00)
local ACCS = rgba(C[6], 0.50)
local FGL  = rgba(C[7], 1.00)
local SUB  = rgba(C[7], 0.72)
local TRK  = rgba(C[1], 0.28)
local SHADOW = {0, 0, 0, 0.78}
local WHITE = {1, 1, 1, 1}

-- --- cache gambar -----------------------------------------------------------
local _img_cache = {}
local function image_surface(path)
    local cached = _img_cache[path]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end
    local surf = cairo_image_surface_create_from_png(path)
    if surf == nil or cairo_image_surface_get_width(surf) == 0 then
        _img_cache[path] = false
        return nil
    end
    _img_cache[path] = surf
    return surf
end

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
        cairo_move_to(cr, tx + 1.0, y + 1.0)
        cairo_show_text(cr, s)
    end
    cairo_set_source_rgba(cr, col[1], col[2], col[3], col[4])
    cairo_move_to(cr, tx, y)
    cairo_show_text(cr, s)
end

-- Garis gradasi: transparan -> aksen -> transparan
local function gline(cr, x1, x2, y, col, alpha)
    local pat = cairo_pattern_create_linear(x1, 0, x2, 0)
    cairo_pattern_add_color_stop_rgba(pat, 0.00, col[1], col[2], col[3], 0)
    cairo_pattern_add_color_stop_rgba(pat, 0.20, col[1], col[2], col[3], (alpha or 0.45) * 0.7)
    cairo_pattern_add_color_stop_rgba(pat, 0.50, col[1], col[2], col[3], (alpha or 0.45) * 1.3)
    cairo_pattern_add_color_stop_rgba(pat, 0.80, col[1], col[2], col[3], (alpha or 0.45) * 0.7)
    cairo_pattern_add_color_stop_rgba(pat, 1.00, col[1], col[2], col[3], 0)
    cairo_set_line_width(cr, 1)
    cairo_set_source(cr, pat)
    cairo_move_to(cr, x1, y + 0.5)
    cairo_line_to(cr, x2, y + 0.5)
    cairo_stroke(cr)
    cairo_pattern_destroy(pat)
end

-- bar: track transparan + gradasi aksen
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
    track(0, 1)
    cairo_set_source_rgba(cr, 0, 0, 0, 0.40)
    cairo_fill(cr)
    track(0, 0)
    cairo_set_source_rgba(cr, TRK[1], TRK[2], TRK[3], TRK[4])
    cairo_fill(cr)
    if pct > 1 then
        local fw = math.max(w * pct / 100, h)
        local bright = lerp(col, WHITE, 0.30)
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
    local XL = 38
    local XR = W - 38

    -- === LANGKAH 1: Gambar wallpaper sebagai latar dengan opacity bervariasi ===
    -- Ini SATU-SATUNYA latar — tidak ada kartu, tidak ada haze terpisah.
    -- Wallpaper ditampilkan dengan opacity tinggi di atas ("banner alami")
    -- dan memudur ke bawah (text contrast zone → tepian tanpa garis).
    local surf = image_surface(HAZEIMG)
    if surf then
        local bw = cairo_image_surface_get_width(surf)
        local bh = cairo_image_surface_get_height(surf)
        if bw > 0 and bh > 0 then
            -- draw wallpaper full-size
            cairo_push_group(cr)
            local s = math.max(W / bw, H / bh)
            cairo_save(cr)
            cairo_translate(cr, (W - bw * s) / 2, (H - bh * s) / 2)
            cairo_scale(cr, s, s)
            cairo_set_source_surface(cr, surf, 0, 0)
            cairo_paint_with_alpha(cr, HAZE_A)
            cairo_restore(cr)

            -- === Langkah 2: Varying opacity mask ===
            -- Vertical: atas = wallpaper jelas (0.92), tengah = sedikit redup
            -- (0.70 untuk kontras teks), bawah = memudar ke 0 (tepi tanpa garis).
            -- Horizontal: kedua sisi memudar ke 0 (tepi tanpa garis).
            cairo_set_operator(cr, CAIRO_OPERATOR_DEST_IN)

            -- Vertical profile
            local vs = {
                {0.00, 0.92}, {0.05, 0.92}, {0.10, 0.90}, {0.16, 0.85},
                {0.22, 0.76}, {0.30, 0.68}, {0.40, 0.64}, {0.55, 0.64},
                {0.70, 0.68}, {0.80, 0.72}, {0.88, 0.55}, {0.94, 0.25},
                {0.98, 0.08}, {1.00, 0.00},
            }
            local vpat = cairo_pattern_create_linear(0, 0, 0, H)
            for _, s in ipairs(vs) do
                cairo_pattern_add_color_stop_rgba(vpat, s[1], 0, 0, 0, s[2])
            end
            cairo_rectangle(cr, 0, 0, W, H)
            cairo_set_source(cr, vpat)
            cairo_fill(cr)
            cairo_pattern_destroy(vpat)

            -- Horizontal profile
            local hs = {
                {0.00, 0.00}, {0.05, 0.18}, {0.10, 0.55}, {0.17, 0.88},
                {0.26, 1.00}, {0.50, 1.00}, {0.74, 1.00}, {0.83, 0.88},
                {0.90, 0.55}, {0.95, 0.18}, {1.00, 0.00},
            }
            local hpat = cairo_pattern_create_linear(0, 0, W, 0)
            for _, s in ipairs(hs) do
                cairo_pattern_add_color_stop_rgba(hpat, s[1], 0, 0, 0, s[2])
            end
            cairo_rectangle(cr, 0, 0, W, H)
            cairo_set_source(cr, hpat)
            cairo_fill(cr)
            cairo_pattern_destroy(hpat)

            cairo_set_operator(cr, CAIRO_OPERATOR_OVER)
            cairo_pop_group_to_source(cr)
            cairo_paint(cr)
        end
    end

    -- === LANGKAH 3: Jam besar + tanggal (di atas wallpaper) ===
    text(cr, conky_parse('${time %H:%M}'), XL, 115, 52, CAIRO_FONT_WEIGHT_BOLD, FGL, 'left')
    text(cr, conky_parse('${time %S}'), XR, 100, 16, CAIRO_FONT_WEIGHT_BOLD, ACC, 'right')
    text(cr, conky_parse('${time %A}'), XR, 124, 13, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    text(cr, conky_parse('${time %d %B %Y}'), XR, 142, 10.5, CAIRO_FONT_WEIGHT_NORMAL, SUB, 'right')

    -- === LANGKAH 4: Divider gradasi ===
    gline(cr, XL, XR, 162, ACC, 0.45)

    -- === LANGKAH 5: CPU / RAM / DISK ===
    local cpu = tonumber(conky_parse('${cpu cpu0}')) or 0
    local ram = tonumber(conky_parse('${memperc}')) or 0
    local dsk = tonumber(conky_parse('${fs_used_perc /}')) or 0

    text(cr, 'CPU', XL, 192, 10, CAIRO_FONT_WEIGHT_BOLD, SUB, 'left')
    text(cr, string.format('%.0f%%', cpu), XR, 192, 11.5, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    bar(cr, XL, 201, XR - XL, 5, cpu, ACC)

    text(cr, 'RAM', XL, 226, 10, CAIRO_FONT_WEIGHT_BOLD, SUB, 'left')
    text(cr, string.format('%.0f%%', ram), XR, 226, 11.5, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    bar(cr, XL, 235, XR - XL, 5, ram, ACC)

    text(cr, 'DISK', XL, 260, 10, CAIRO_FONT_WEIGHT_BOLD, SUB, 'left')
    text(cr, string.format('%.0f%%', dsk), XR, 260, 11.5, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    bar(cr, XL, 269, XR - XL, 5, dsk, ACC)

    -- === LANGKAH 6: Divider ===
    gline(cr, XL, XR, 296, ACC, 0.45)

    -- === LANGKAH 7: Info baris ===
    local function row(label, value, y)
        text(cr, label, XL, y, 9.5, CAIRO_FONT_WEIGHT_BOLD, SUB, 'left')
        text(cr, value, XR, y, 10.5, CAIRO_FONT_WEIGHT_NORMAL, FGL, 'right')
    end

    local temp = conky_parse("${execpi 60 sensors | awk '/Package id 0:/ {print $4}'}")
    if temp == '' or temp == nil then temp = '—' end

    local topname = conky_parse('${top name 1}')
    local topcpu  = conky_parse('${top cpu 1}')
    if topname == '' or topname == nil then topname = '—' end

    row('UPTIME', conky_parse('${uptime}'), 322)
    row('PROSES', conky_parse('${running_processes}') .. ' / ' .. conky_parse('${processes}'), 347)
    row('SUHU', temp, 372)
    row('TOP', topname .. '  ' .. topcpu .. '%', 397)

    -- === LANGKAH 8: Footer halus ===
    text(cr, '✦  A N I M E   G L A S S  ✦', W / 2, 440, 9, CAIRO_FONT_WEIGHT_BOLD, ACCS, 'center')
    text(cr, conky_parse('${time %Z}'), W / 2, 456, 8, CAIRO_FONT_WEIGHT_NORMAL, SUB, 'center')

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end
