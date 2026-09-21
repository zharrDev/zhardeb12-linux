-- ============================================================================
--  anime-glass.lua — info sistem yang MENYATU dengan wallpaper (tanpa kartu)
--
--  Cara "no border"-nya:
--   1. Latar widget = POTONGAN WALLPAPER-nya sendiri (dibuat oleh
--      update-wallpaper.sh: anime-haze.png = crop di posisi widget, di-blur
--      + digelapkan). Jadi bagian dalam widget terlihat seperti wallpaper
--      yang diburamkan — bukan panel yang ditempel.
--   2. Tepinya diberi mask "produk" (profil vertikal x horizontal) yang
--      turun mulus dan MENYENTUH NOL tepat di keempat sisi window — tidak
--      ada garis, sudut, atau sisi lurus yang terlihat.
--   3. Banner anime juga ber-feather di semua tepi dan digeser turun dari
--      tepi atas supaya tidak terpotong lurus oleh batas window.
--   4. Teks diberi bayangan gelap tipis -> tetap terbaca tanpa kotak.
--
--  Ringan: gambar (banner/avatar/haze) di-decode SEKALI per proses conky;
--  blur kaca asli ditangani picom (dual_kawase), bukan CPU conky.
--
--  Warna diambil dari pywal (~/.cache/wal/colors) agar senada wallpaper.
-- ============================================================================
require 'cairo'

local HOME = os.getenv('HOME')
local FONT = 'JetBrainsMono Nerd Font Mono'
local BANNER = HOME .. '/.config/conky/anime-banner.png'
local AVATAR = HOME .. '/.config/conky/anime-avatar.png'
local HAZEIMG = HOME .. '/.config/conky/anime-haze.png'
local HAZE_A = 0.82 -- kepekatan latar "kaca" (potongan wallpaper)

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

-- warna tema
local ACC  = rgba(C[6], 1.00) -- aksen utama (warna wallpaper)
local ACCS = rgba(C[6], 0.55) -- aksen lembut (divider/footer)
local FGL  = rgba(C[7], 1.00) -- teks utama
local SUB  = rgba(C[7], 0.80) -- teks sekunder
local TRK  = rgba(C[1], 0.34) -- track bar (transparan — menyatu wallpaper)
local HAZE = rgba(C[1], 1.00) -- warna aura (fallback bila gambar kaca belum ada)
local SHADOW = {0, 0, 0, 0.74} -- bayangan teks/bar
local WHITE = {1, 1, 1, 1}

-- --- cache gambar (decode sekali per proses) --------------------------------
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
    -- font mono: lebar karakter kira-kira 0.6em, cukup akurat untuk rata kanan/tengah
    local w = string.len(s) * size * 0.6
    local tx = x
    if align == 'right' then tx = x - w end
    if align == 'center' then tx = x - w / 2 end
    if not no_shadow then
        -- bayangan gelap tipis: teks tetap terbaca di wallpaper terang
        cairo_set_source_rgba(cr, SHADOW[1], SHADOW[2], SHADOW[3], SHADOW[4])
        cairo_move_to(cr, tx + 1.2, y + 1.2)
        cairo_show_text(cr, s)
    end
    cairo_set_source_rgba(cr, col[1], col[2], col[3], col[4])
    cairo_move_to(cr, tx, y)
    cairo_show_text(cr, s)
end

-- Garis gradasi: transparan -> aksen -> transparan (tanpa ujung yang terlihat)
local function gline(cr, x1, x2, y, col, alpha)
    local pat = cairo_pattern_create_linear(x1, 0, x2, 0)
    cairo_pattern_add_color_stop_rgba(pat, 0.00, col[1], col[2], col[3], 0)
    cairo_pattern_add_color_stop_rgba(pat, 0.20, col[1], col[2], col[3], (alpha or 0.5) * 0.7)
    cairo_pattern_add_color_stop_rgba(pat, 0.50, col[1], col[2], col[3], (alpha or 0.5) * 1.35)
    cairo_pattern_add_color_stop_rgba(pat, 0.80, col[1], col[2], col[3], (alpha or 0.5) * 0.7)
    cairo_pattern_add_color_stop_rgba(pat, 1.00, col[1], col[2], col[3], 0)
    cairo_set_line_width(cr, 1)
    cairo_set_source(cr, pat)
    cairo_move_to(cr, x1, y + 0.5)
    cairo_line_to(cr, x2, y + 0.5)
    cairo_stroke(cr)
    cairo_pattern_destroy(pat)
end

-- bar: track transparan + isi gradasi aksen, dengan bayangan tipis
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
    cairo_set_source_rgba(cr, 0, 0, 0, 0.45)
    cairo_fill(cr)
    track(0, 0)
    cairo_set_source_rgba(cr, TRK[1], TRK[2], TRK[3], TRK[4])
    cairo_fill(cr)
    if pct > 1 then
        local fw = math.max(w * pct / 100, h)
        local bright = lerp(col, WHITE, 0.35)
        local pat = cairo_pattern_create_linear(x, 0, x + fw, 0)
        cairo_pattern_add_color_stop_rgba(pat, 0.0, col[1], col[2], col[3], 0.98)
        cairo_pattern_add_color_stop_rgba(pat, 1.0, bright[1], bright[2], bright[3], 0.98)
        cairo_new_sub_path(cr)
        cairo_arc(cr, x + fw - r, y + r, r, -math.pi / 2, math.pi / 2)
        cairo_arc(cr, x + fw - r, y + h - r, r, 0, math.pi / 2)
        cairo_arc(cr, x + r, y + h - r, r, math.pi / 2, math.pi)
        cairo_arc(cr, x + r, y + r, r, math.pi, 3 * math.pi / 2)
        cairo_close_path(cr)
        cairo_set_source(cr, pat)
        cairo_fill(cr)
        cairo_pattern_destroy(pat)
        cairo_new_sub_path(cr)
        cairo_arc(cr, x + fw - r, y + r, r, -math.pi / 2, math.pi / 2)
        cairo_arc(cr, x + fw - r, y + h - r, r, 0, math.pi / 2)
        cairo_arc(cr, x + r, y + h - r, r, math.pi / 2, math.pi)
        cairo_arc(cr, x + r, y + r, r, math.pi, 3 * math.pi / 2)
        cairo_close_path(cr)
        cairo_set_source_rgba(cr, 1, 1, 1, 0.22)
        cairo_fill(cr)
    end
end

-- Mask "produk": profil vertikal x horizontal. Keduanya turun dengan lengkung
-- halus dan MENYENTUH NOL tepat di tepi window -> tidak ada garis/sudut.
local function soft_mask(cr, x, y, w, h, strength)
    strength = strength or 1.0
    cairo_set_operator(cr, CAIRO_OPERATOR_DEST_IN)

    local vs = {{0, 0}, {0.04, 0.12}, {0.08, 0.40}, {0.14, 0.76},
                {0.21, 0.97}, {0.50, 1}, {0.79, 0.97}, {0.86, 0.76},
                {0.92, 0.40}, {0.96, 0.12}, {1, 0}}
    local pat = cairo_pattern_create_linear(x, y, x, y + h)
    for _, s in ipairs(vs) do
        cairo_pattern_add_color_stop_rgba(pat, s[1], 0, 0, 0, s[2] * strength)
    end
    cairo_rectangle(cr, x, y, w, h)
    cairo_set_source(cr, pat)
    cairo_fill(cr)
    cairo_pattern_destroy(pat)

    local hs = {{0, 0}, {0.05, 0.12}, {0.09, 0.40}, {0.15, 0.76},
                {0.23, 0.97}, {0.50, 1}, {0.77, 0.97}, {0.85, 0.76},
                {0.91, 0.40}, {0.95, 0.12}, {1, 0}}
    pat = cairo_pattern_create_linear(x, y, x + w, y)
    for _, s in ipairs(hs) do
        cairo_pattern_add_color_stop_rgba(pat, s[1], 0, 0, 0, s[2])
    end
    cairo_rectangle(cr, x, y, w, h)
    cairo_set_source(cr, pat)
    cairo_fill(cr)
    cairo_pattern_destroy(pat)

    cairo_set_operator(cr, CAIRO_OPERATOR_OVER)
end

-- Latar "kaca" = potongan wallpaper (digelapkan + diburamkan oleh
-- update-wallpaper.sh). Digambar seukuran window ("cover", tengah) lalu
-- diberi soft_mask -> memudar mulus ke wallpaper aslinya di sekelilingnya.
local function draw_haze(cr, W, H)
    local surf = image_surface(HAZEIMG)
    if not surf then return false end
    local bw = cairo_image_surface_get_width(surf)
    local bh = cairo_image_surface_get_height(surf)
    if bw <= 0 or bh <= 0 then return false end

    cairo_push_group(cr)
    local s = math.max(W / bw, H / bh) -- cover: penuh tanpa distorsi
    cairo_save(cr)
    cairo_translate(cr, (W - bw * s) / 2, (H - bh * s) / 2)
    cairo_scale(cr, s, s)
    cairo_set_source_surface(cr, surf, 0, 0)
    cairo_paint_with_alpha(cr, HAZE_A)
    cairo_restore(cr)

    soft_mask(cr, 0, 0, W, H, 1.0)
    cairo_pop_group_to_source(cr)
    cairo_paint(cr)
    return true
end

-- Aura warna dominan wallpaper (fallback bila gambar kaca belum dibuat)
local function draw_aura(cr, W, H, col, peak)
    cairo_push_group(cr)
    cairo_set_source_rgba(cr, col[1], col[2], col[3], peak)
    cairo_rectangle(cr, 0, 0, W, H)
    cairo_fill(cr)
    soft_mask(cr, 0, 0, W, H, 1.0)
    cairo_pop_group_to_source(cr)
    cairo_paint(cr)
end

-- Banner anime dengan tepi ber-feather (memudar ke SEMUA arah) — tidak pernah
-- terlihat sebagai kotak. Digeser turun dari tepi atas window (oy).
local function draw_banner(cr, W, BH, oy)
    local surf = image_surface(BANNER)
    if not surf then return end
    local bw = cairo_image_surface_get_width(surf)
    local bh = cairo_image_surface_get_height(surf)
    if bw <= 0 or bh <= 0 then return end

    cairo_push_group(cr)
    cairo_save(cr)
    cairo_translate(cr, 0, oy)
    cairo_scale(cr, W / bw, BH / bh)
    cairo_set_source_surface(cr, surf, 0, 0)
    cairo_paint(cr)
    cairo_restore(cr)

    cairo_set_operator(cr, CAIRO_OPERATOR_DEST_IN)
    local vs = {{0, 0}, {0.08, 0.12}, {0.16, 0.42}, {0.28, 0.80},
                {0.42, 1}, {0.62, 1}, {0.76, 0.80}, {0.88, 0.42}, {1, 0}}
    local v = cairo_pattern_create_linear(0, oy, 0, oy + BH)
    for _, s in ipairs(vs) do
        cairo_pattern_add_color_stop_rgba(v, s[1], 0, 0, 0, s[2])
    end
    cairo_rectangle(cr, 0, oy, W, BH)
    cairo_set_source(cr, v)
    cairo_fill(cr)
    cairo_pattern_destroy(v)

    local hs = {{0, 0}, {0.10, 0.50}, {0.24, 0.92}, {0.50, 1},
                {0.76, 0.92}, {0.90, 0.50}, {1, 0}}
    local h = cairo_pattern_create_linear(0, 0, W, 0)
    for _, s in ipairs(hs) do
        cairo_pattern_add_color_stop_rgba(h, s[1], 0, 0, 0, s[2])
    end
    cairo_rectangle(cr, 0, oy, W, BH)
    cairo_set_source(cr, h)
    cairo_fill(cr)
    cairo_pattern_destroy(h)

    cairo_set_operator(cr, CAIRO_OPERATOR_OVER)
    cairo_pop_group_to_source(cr)
    cairo_paint(cr)
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
    local XL = 42
    local XR = W - 42

    -- 1) latar kaca (potongan wallpaper) — tepi memudar mulus, tanpa border
    if not draw_haze(cr, W, H) then
        draw_aura(cr, W, H, HAZE, 0.52)
    end

    -- 2) banner anime (tepi ber-feather, tanpa bingkai)
    draw_banner(cr, W, 118, 16)

    -- 3) header + avatar anime
    cairo_set_source_rgba(cr, ACC[1], ACC[2], ACC[3], ACC[4])
    cairo_arc(cr, XL + 4, 143, 4, 0, 2 * math.pi)
    cairo_fill(cr)
    text(cr, 'S Y S T E M   M O N I T O R', XL + 16, 148, 11, CAIRO_FONT_WEIGHT_BOLD, ACC, 'left')
    local av = image_surface(AVATAR)
    if av then
        local cx, cy, r = XR - 10, 146, 28
        cairo_set_source_rgba(cr, 0, 0, 0, 0.30)
        cairo_arc(cr, cx, cy, r + 2, 0, 2 * math.pi)
        cairo_fill(cr)
        cairo_save(cr)
        cairo_arc(cr, cx, cy, r, 0, 2 * math.pi)
        cairo_clip(cr)
        cairo_set_source_surface(cr, av, cx - r, cy - r)
        cairo_paint(cr)
        cairo_restore(cr)
        cairo_set_source_rgba(cr, ACC[1], ACC[2], ACC[3], 0.85)
        cairo_set_line_width(cr, 2)
        cairo_arc(cr, cx, cy, r, 0, 2 * math.pi)
        cairo_stroke(cr)
    end

    -- 4) jam besar + tanggal
    text(cr, conky_parse('${time %H:%M}'), XL, 196, 46, CAIRO_FONT_WEIGHT_BOLD, FGL, 'left')
    text(cr, conky_parse('${time %S}'), XR, 178, 15, CAIRO_FONT_WEIGHT_BOLD, ACC, 'right')
    text(cr, conky_parse('${time %A}'), XR, 200, 13, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    text(cr, conky_parse('${time %d %B %Y}'), XR, 217, 10.5, CAIRO_FONT_WEIGHT_NORMAL, SUB, 'right')

    -- 5) divider gradasi
    gline(cr, XL, XR, 236, ACC, 0.45)

    -- 6) CPU / RAM / DISK
    local cpu = tonumber(conky_parse('${cpu cpu0}')) or 0
    local ram = tonumber(conky_parse('${memperc}')) or 0
    local dsk = tonumber(conky_parse('${fs_used_perc /}')) or 0

    text(cr, 'CPU', XL, 267, 10.5, CAIRO_FONT_WEIGHT_BOLD, SUB, 'left')
    text(cr, string.format('%.0f%%', cpu), XR, 267, 12, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    bar(cr, XL, 276, XR - XL, 6, cpu, ACC)

    text(cr, 'RAM', XL, 307, 10.5, CAIRO_FONT_WEIGHT_BOLD, SUB, 'left')
    text(cr, string.format('%.0f%%', ram), XR, 307, 12, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    bar(cr, XL, 316, XR - XL, 6, ram, ACC)

    text(cr, 'DISK', XL, 347, 10.5, CAIRO_FONT_WEIGHT_BOLD, SUB, 'left')
    text(cr, string.format('%.0f%%', dsk), XR, 347, 12, CAIRO_FONT_WEIGHT_BOLD, FGL, 'right')
    bar(cr, XL, 356, XR - XL, 6, dsk, ACC)

    -- 7) divider gradasi
    gline(cr, XL, XR, 384, ACC, 0.45)

    -- 8) info baris
    local function row(label, value, y)
        text(cr, label, XL, y, 10, CAIRO_FONT_WEIGHT_BOLD, SUB, 'left')
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
    text(cr, '✦  A N I M E   G L A S S  ✦', W / 2, 524, 9.5, CAIRO_FONT_WEIGHT_BOLD, ACCS, 'center')
    text(cr, conky_parse('${time %Z}'), W / 2, 541, 8.5, CAIRO_FONT_WEIGHT_NORMAL, SUB, 'center')

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end
