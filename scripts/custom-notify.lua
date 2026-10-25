-- =========================================================================
-- MPV NVIDIA Dark Glass Custom Notification HUD (custom-notify.lua)
-- Unified, Elegant OSD Toast System Matching Suite Aesthetic 1:1
-- =========================================================================

local mp = require("mp")
local assdraw = require("mp.assdraw")

local cfg = {
    ui_scale      = 1.35,         -- Matches suite DPI multiplier (1.0 = 1080p, 1.35 = 4K)
    font_face     = "Segoe UI",
    color_green   = "00E676",     -- NVIDIA Green
    color_cyan    = "00E5FF",     -- RivaTuner Cyan
    color_yellow  = "00C8FF",     -- Amber Warning / Toggles
    color_red     = "3B3BFF",     -- Alert Red
    color_white   = "FFFFFF",
    color_gray    = "9E9E9E",
    bg_alpha      = "30",         -- ~82% dark glass opacity
}

local overlay = mp.create_osd_overlay("ass-events")
local hide_timer = nil

local current_toast = {
    title = "",
    message = "",
    color = cfg.color_green,
    icon_color = cfg.color_green,
}

local function hide_toast()
    if hide_timer then
        hide_timer:kill()
        hide_timer = nil
    end
    overlay:remove()
end

local function draw_toast()
    local d = mp.get_property_native("osd-dimensions")
    if not d or d.w == 0 or d.h == 0 then return end

    overlay.res_x = d.w
    overlay.res_y = d.h

    local base_scale = math.max(1.0, d.h / 1080)
    local scale = base_scale * (cfg.ui_scale or 1.0)

    -- Typography
    local title_size = math.floor(11.5 * scale)
    local msg_size   = math.floor(13 * scale)

    -- Dynamic Width based on string length (clamped to clean min/max bounds)
    local max_chars = math.max(#current_toast.title, #current_toast.message)
    local box_w = math.max(math.floor(340 * scale), math.floor((max_chars * 7.5 + 64) * scale))
    local box_h = math.floor(54 * scale)

    -- Position: Centered at Top of Viewport
    local margin_y = math.floor(28 * scale)
    local x1 = math.floor((d.w - box_w) / 2)
    local x2 = x1 + box_w
    local y1 = margin_y
    local y2 = y1 + box_h

    local pad_x = math.floor(16 * scale)
    local ass = assdraw.ass_new()

    -- 1. Outer Translucent Rounded Glass Container
    ass:new_event()
    ass:append(string.format("{\\an7\\bord0\\shad0\\c&H0A0A0A&\\alpha&H%s&}", cfg.bg_alpha))
    ass:pos(0, 0)
    ass:draw_start()
    ass:round_rect_cw(x1, y1, x2, y2, 6 * scale)
    ass:draw_stop()

    -- 2. Top Accent Border (Matches toast category color)
    ass:new_event()
    ass:append(string.format("{\\an7\\bord0\\shad0\\c&H%s&\\alpha&H10&}", current_toast.icon_color))
    ass:pos(0, 0)
    ass:draw_start()
    ass:rect_cw(x1, y1, x2, y1 + math.max(2, math.floor(2.5 * scale)))
    ass:draw_stop()

    -- 3. Vector Diamond Status Icon
    local d_rad = math.max(3, math.floor(4 * scale))
    local d_cx = x1 + pad_x + d_rad
    local d_cy = y1 + math.floor(box_h / 2)

    ass:new_event()
    ass:append(string.format("{\\an7\\bord0\\shad0\\c&H%s&}", current_toast.icon_color))
    ass:pos(0, 0)
    ass:draw_start()
    ass:move_to(d_cx, d_cy - d_rad)
    ass:line_to(d_cx + d_rad, d_cy)
    ass:line_to(d_cx, d_cy + d_rad)
    ass:line_to(d_cx - d_rad, d_cy)
    ass:draw_stop()

    -- 4. Text Content (Header Category + Details)
    local text_x = d_cx + d_rad + math.floor(10 * scale)
    local line1_y = y1 + math.floor(8 * scale)
    local line2_y = line1_y + title_size + math.floor(3 * scale)

    -- Category / Title Tag
    ass:new_event()
    ass:append(string.format("{\\an7\\pos(%d,%d)\\fn%s\\b1\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}%s",
        text_x, line1_y, cfg.font_face, title_size, current_toast.color, current_toast.title:upper()))

    -- Message Body / Parameters
    ass:new_event()
    ass:append(string.format("{\\an7\\pos(%d,%d)\\fn%s\\b1\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}%s",
        text_x, line2_y, cfg.font_face, msg_size, cfg.color_white, current_toast.message))

    overlay.data = ass.text
    overlay:update()
end

-- Public Script Message Dispatcher
-- Usage: script-message notify "CATEGORY" "Message text" "color_tag" "duration_in_secs"
local function show_toast(title, message, color_tag, duration)
    title = title or "NOTIFICATION"
    message = message or ""
    duration = tonumber(duration) or 2.2

    local color = cfg.color_green
    local icon_color = cfg.color_green

    if color_tag == "cyan" then
        color = cfg.color_cyan
        icon_color = cfg.color_cyan
    elseif color_tag == "yellow" then
        color = cfg.color_yellow
        icon_color = cfg.color_yellow
    elseif color_tag == "red" then
        color = cfg.color_red
        icon_color = cfg.color_red
    elseif color_tag == "gray" or color_tag == "off" then
        color = cfg.color_gray
        icon_color = cfg.color_gray
    end

    current_toast.title = title
    current_toast.message = message
    current_toast.color = color
    current_toast.icon_color = icon_color

    draw_toast()

    if hide_timer then hide_timer:kill() end
    hide_timer = mp.add_timeout(duration, hide_toast)
end

mp.register_script_message("notify", show_toast)
mp.observe_property("osd-dimensions", "native", function()
    if hide_timer and hide_timer:is_enabled() then
        draw_toast()
    end
end)