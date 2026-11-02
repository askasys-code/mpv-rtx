-- =========================================================================
-- Glass Card Renderer (glass-card.lua)
-- Shared ASS engine for the "dark glass" section cards used by
-- nvidia-monitor, video-monitor, sound-monitor, film-grain and clip-maker.
-- Usage: local glass = require("glass-card")
-- =========================================================================

local assdraw = require("mp.assdraw")

local M = {}

-- Reads OSD size, syncs the overlay resolution and returns (d, scale).
-- Returns nil when the OSD is not ready yet.
function M.begin_frame(overlay, cfg)
    local d = mp.get_property_native("osd-dimensions")
    if not d or d.w == 0 or d.h == 0 then return nil end

    overlay.res_x = d.w
    overlay.res_y = d.h

    local base_scale = math.max(1.0, d.h / 1080)
    return d, base_scale * (cfg.ui_scale or 1.0)
end

-- Typography & geometric spacing. `o` overrides: header_gap, bottom_pad, pad_x
function M.metrics(scale, o)
    o = o or {}
    return {
        scale         = scale,
        title_size    = math.floor(13 * scale),
        subtitle_size = math.floor(11.5 * scale),
        section_size  = math.floor(10.5 * scale),
        row_size      = math.floor(11.5 * scale),

        row_step      = math.floor(19.5 * scale),
        section_step  = math.floor(18 * scale),
        section_gap   = math.floor(10 * scale),

        top_pad       = math.floor(16 * scale),
        header_gap    = math.floor((o.header_gap or 12) * scale),
        bottom_pad    = math.floor((o.bottom_pad or 22) * scale),
        pad_x         = math.floor((o.pad_x or 18) * scale),
        indent_x      = math.floor(8 * scale),
    }
end

-- Vector diamond + title tag of a section header. Returns nothing.
function M.section_header(ass, cfg, g, x1, cur_y, title, color)
    local d_rad = math.max(3, math.floor(3.5 * g.scale))
    local d_cx = x1 + g.pad_x + d_rad
    local d_cy = cur_y + math.floor(g.section_size * 0.52)
    local text_x = x1 + g.pad_x + (d_rad * 2) + math.floor(6 * g.scale)

    ass:new_event()
    ass:append(string.format("{\\an7\\bord0\\shad0\\c&H%s&}", color))
    ass:pos(0, 0)
    ass:draw_start()
    ass:move_to(d_cx, d_cy - d_rad)
    ass:line_to(d_cx + d_rad, d_cy)
    ass:line_to(d_cx, d_cy + d_rad)
    ass:line_to(d_cx - d_rad, d_cy)
    ass:draw_stop()

    ass:new_event()
    ass:append(string.format("{\\an7\\pos(%d,%d)\\fn%s\\b1\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}%s",
        text_x, cur_y, cfg.font_face, g.section_size, color, title))
end

-- Draws every section (header + label/value rows). Returns the new cur_y.
function M.sections(ass, cfg, g, x1, x2, cur_y, sections)
    for s_idx, sec in ipairs(sections) do
        M.section_header(ass, cfg, g, x1, cur_y, sec.title, sec.title_color or cfg.color_green)

        cur_y = cur_y + g.section_step

        for _, item in ipairs(sec.items) do
            local label, val_text, val_color = item[1], item[2], item[3]

            -- Label (Left-aligned + Indented: \an7)
            ass:new_event()
            ass:append(string.format("{\\an7\\pos(%d,%d)\\fn%s\\b0\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}%s",
                x1 + g.pad_x + g.indent_x, cur_y, cfg.font_face, g.row_size, cfg.color_gray, label))

            -- Value (Right-aligned: \an9)
            ass:new_event()
            ass:append(string.format("{\\an9\\pos(%d,%d)\\fn%s\\b1\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}%s",
                x2 - g.pad_x, cur_y, cfg.font_face, g.row_size, val_color or cfg.color_white, val_text))

            cur_y = cur_y + g.row_step
        end

        if s_idx < #sections then
            cur_y = cur_y + g.section_gap
        end
    end
    return cur_y
end

-- Renders a complete card into `overlay`.
-- spec = {
--   d, scale          (from begin_frame)
--   title, subtitle, sections = { { title=, title_color=, items = { {label, value, color} } } }
--   anchor            "top-left" | "top-right" | "top-center" | "bottom-left"
--   width             logical width (default 400)
--   header_gap, bottom_pad, pad_x   spacing overrides (see metrics)
--   divider_gap       gap under the header divider (default 8)
--   thin_accent       true = slimmer top accent bar
--   backdrop          function(ass, d, scale) drawn before the card
--   block             { height = function(g) -> px, draw = function(ass, g, x1, x2, cur_y) }
--                     custom content placed between header and sections
-- }
function M.draw(overlay, cfg, spec)
    local d, scale = spec.d, spec.scale
    local g = M.metrics(scale, spec)
    local sections = spec.sections or {}

    local total_rows = 0
    for _, sec in ipairs(sections) do
        total_rows = total_rows + #sec.items
    end

    local block_h = spec.block and spec.block.height(g) or 0
    local header_h = g.title_size + g.subtitle_size + math.floor(8 * scale)
    local sections_h = (#sections * g.section_step) + (math.max(0, #sections - 1) * g.section_gap) + (total_rows * g.row_step)
    local box_h = g.top_pad + header_h + g.header_gap + block_h + sections_h + g.bottom_pad
    local box_w = math.floor((spec.width or 400) * scale)

    local margin_x = math.floor(24 * scale)
    local margin_y = math.floor(24 * scale)
    local anchor = spec.anchor or "top-left"
    local x1, y1
    if anchor == "top-right" then
        x1 = (d.w - margin_x) - box_w
    elseif anchor == "top-center" then
        x1 = math.floor((d.w - box_w) / 2)
    else
        x1 = margin_x
    end
    local x2 = x1 + box_w
    y1 = margin_y
    local y2 = y1 + box_h

    if anchor == "bottom-left" then
        y2 = d.h - margin_y
        y1 = y2 - box_h
        -- Safety check: ensure card never clips above top boundary
        if y1 < margin_y then
            y1 = margin_y
            y2 = y1 + box_h
        end
    end

    local ass = assdraw.ass_new()

    if spec.backdrop then
        spec.backdrop(ass, d, scale)
    end

    -- 1. Outer Translucent Rounded Glass Container
    ass:new_event()
    ass:append(string.format("{\\an7\\bord0\\shad0\\c&H0A0A0A&\\alpha&H%s&}", cfg.bg_alpha))
    ass:pos(0, 0)
    ass:draw_start()
    ass:round_rect_cw(x1, y1, x2, y2, 8 * scale)
    ass:draw_stop()

    -- 2. Top Accent Border (NVIDIA Green)
    local accent_h = spec.thin_accent and math.max(2, math.floor(2.5 * scale)) or math.floor(3 * scale)
    ass:new_event()
    ass:append(string.format("{\\an7\\bord0\\shad0\\c&H%s&\\alpha&H10&}", cfg.color_green))
    ass:pos(0, 0)
    ass:draw_start()
    ass:rect_cw(x1, y1, x2, y1 + accent_h)
    ass:draw_stop()

    -- 3. Header Block: Title & Subtitle
    local cur_y = y1 + g.top_pad
    ass:new_event()
    ass:append(string.format("{\\an7\\pos(%d,%d)\\fn%s\\b1\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}%s",
        x1 + g.pad_x, cur_y, cfg.font_face, g.title_size, cfg.color_green, spec.title))

    cur_y = cur_y + g.title_size + math.floor(4 * scale)
    ass:new_event()
    ass:append(string.format("{\\an7\\pos(%d,%d)\\fn%s\\b1\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}%s",
        x1 + g.pad_x, cur_y, cfg.font_face, g.subtitle_size, cfg.color_white, spec.subtitle))

    -- Subtle Horizontal Divider under Header
    cur_y = cur_y + g.subtitle_size + math.floor(8 * scale)
    ass:new_event()
    ass:append("{\\an7\\bord0\\shad0\\c&HFFFFFF&\\alpha&HD0&}")
    ass:pos(0, 0)
    ass:draw_start()
    ass:rect_cw(x1 + g.pad_x, cur_y, x2 - g.pad_x, cur_y + 1)
    ass:draw_stop()

    cur_y = cur_y + math.floor((spec.divider_gap or 8) * scale)

    -- 4. Optional custom block, then the categorized sections
    if spec.block then
        spec.block.draw(ass, g, x1, x2, cur_y)
        cur_y = cur_y + block_h
    end

    M.sections(ass, cfg, g, x1, x2, cur_y, sections)

    overlay.data = ass.text
    overlay:update()
end

return M
