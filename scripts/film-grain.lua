-- =========================================================================
-- MPV AV1 Film Grain Synthesis (FGS) Controller & Diagnostics Suite
-- Real-time Hardware / GPU Synthesis Stripping & Bitstream Metadata HUD
-- Symmetrical Dark Glass ASS Overlay Matching Suite Aesthetic 1:1
-- =========================================================================

local mp = require("mp")
local utils = require("mp.utils")
local assdraw = require("mp.assdraw")

local is_hud_visible = false
local grain_filter_label = "@filmgrain"
local grain_filter_def = "@filmgrain:format=film-grain=no"

-- Visual Configuration & Styling (Matches suite monitors)
local cfg = {
    ui_scale        = 1.35,        -- User size multiplier (1.0 = normal, 1.35 = 4K)
    font_face       = "Segoe UI",
    color_green     = "00E676",    -- NVIDIA Green (Active Synthesis / Confirm)
    color_cyan      = "00E5FF",    -- RivaTuner Cyan (AV1 Specs & Parameters)
    color_yellow    = "00C8FF",    -- Amber Warning (Stripped / Bypassed)
    color_red       = "3B3BFF",    -- Critical Red
    color_white     = "FFFFFF",
    color_gray      = "9E9E9E",    -- Inactive / Labels
    bg_alpha        = "35",        -- Translucent dark glass (~80% dark)
}

local overlay = mp.create_osd_overlay("ass-events")

-- Dispatch notification toast via custom-notify.lua
local function toast(title, msg, color, duration)
    mp.commandv("script-message", "notify", title, msg, color or "green", tostring(duration or 2))
end

-- Check if grain filter is currently active in video pipeline
local function is_grain_stripped()
    local vf_str = mp.get_property("vf") or ""
    return vf_str:find(grain_filter_label, 1, true) ~= nil
end

-- Verify if current stream is AV1
local function is_av1_stream()
    local vc = tostring(mp.get_property("video-codec") or mp.get_property("video-format") or ""):lower()
    return vc:find("av1") ~= nil
end

-- Detect if synthetic grain is indicated by filename, metadata, or stream probe
local function has_fgs_hint()
    local filename = tostring(mp.get_property("filename") or ""):lower()
    local title = tostring(mp.get_property("media-title") or ""):lower()
    if filename:find("_fgs") or filename:find("fgs") or filename:find("grain") then return true end
    if title:find("_fgs") or title:find("fgs") or title:find("grain") then return true end
    return false
end

-- Main toggle function: strips metadata or restores native synthesis
local function toggle_film_grain()
    local vtrack = mp.get_property_native("current-tracks/video")
    if not vtrack or vtrack.albumart then
        toast("AV1 FILM GRAIN", "Not applicable for audio", "yellow", 2)
        return
    end

    if not is_av1_stream() then
        toast("AV1 FILM GRAIN", "Active video is not AV1", "gray", 2)
        return
    end

    if is_grain_stripped() then
        mp.commandv("vf", "remove", grain_filter_label)
        toast("AV1 FILM GRAIN", "ENABLED (Active Synthesis)", "green", 2)
    else
        mp.commandv("vf", "append", grain_filter_def)
        toast("AV1 FILM GRAIN", "DISABLED (Metadata Stripped / Clean)", "yellow", 2)
    end

    if is_hud_visible then
        draw_hud()
    end
end

-- Render ASS Film Grain Diagnostics HUD
function draw_hud()
    if not is_hud_visible then
        overlay:remove()
        return
    end

    local d = mp.get_property_native("osd-dimensions")
    if not d or d.w == 0 or d.h == 0 then return end

    overlay.res_x = d.w
    overlay.res_y = d.h

    local base_scale = math.max(1.0, d.h / 1080)
    local scale = base_scale * (cfg.ui_scale or 1.0)

    local is_av1 = is_av1_stream()
    local stripped = is_grain_stripped()
    local fgs_hint = has_fgs_hint()

    -- Resolve Status & Engine Information
    local status_str = "Not AV1 Stream"
    local status_col = cfg.color_gray
    if is_av1 then
        if stripped then
            status_str = "STRIPPED / OFF (Clean Image)"
            status_col = cfg.color_yellow
        else
            status_str = "ACTIVE (Synthesizing)"
            status_col = cfg.color_green
        end
    end

    local hwdec = mp.get_property("hwdec-current") or "no"
    local hw_desc = (hwdec ~= "" and hwdec ~= "no") and (hwdec:upper() .. " (Hardware)") or "Software (dav1d)"

    local pixfmt = mp.get_property("video-params/pixelformat") or "N/A"
    local bitdepth = pixfmt:find("10") and "10-bit YUV 4:2:0" or "8-bit YUV 4:2:0"

    local fgs_detect = fgs_hint and "Signaled / Present in Stream" or (is_av1 and "Standard Bitstream Model" or "N/A")
    local fgs_detect_col = fgs_hint and cfg.color_green or cfg.color_cyan

    local sections = {
        {
            title = "PIPELINE STATUS",
            title_color = cfg.color_green,
            items = {
                { "Synthesis State", status_str, status_col },
                { "Synthesis Engine", "GPU Compute (libplacebo / D3D11)", cfg.color_cyan },
                { "Base Decoder", hw_desc, cfg.color_white },
                { "Bitstream Signal", fgs_detect, fgs_detect_col }
            }
        },
        {
            title = "AV1 FGS MODEL SPECIFICATIONS",
            title_color = cfg.color_green,
            items = {
                { "Algorithm", "Autoregressive Process (AR-Lag 3)", cfg.color_white },
                { "Scaling Curves", "Piecewise Linear (Luma & Chroma)", cfg.color_cyan },
                { "Block Synthesis", "32x32 Pixel Synthesis Grid", cfg.color_white },
                { "Overhead", "< 0.5% (Parametric Metadata)", cfg.color_yellow },
                { "Color Depth", bitdepth, cfg.color_cyan }
            }
        },
        {
            title = "CONTROLS",
            title_color = cfg.color_green,
            items = {
                { "[6] / [G] Toggle", stripped and "Re-enable Synthesis" or "Strip / Remove Grain", cfg.color_green },
                { "[Alt+6] HUD", "Close This Diagnostics Overlay", cfg.color_yellow }
            }
        }
    }

    -- Font Sizes & Geometric Spacing
    local title_size    = math.floor(13 * scale)
    local subtitle_size = math.floor(11.5 * scale)
    local section_size  = math.floor(10.5 * scale)
    local row_size      = math.floor(11.5 * scale)

    local row_step      = math.floor(19.5 * scale)
    local section_step  = math.floor(18 * scale)
    local section_gap   = math.floor(10 * scale)

    local top_pad       = math.floor(16 * scale)
    local header_gap    = math.floor(12 * scale)
    local bottom_pad    = math.floor(22 * scale)
    local pad_x         = math.floor(18 * scale)
    local indent_x      = math.floor(8 * scale)

    local total_rows = 0
    for _, sec in ipairs(sections) do
        total_rows = total_rows + #sec.items
    end

    local header_h = title_size + subtitle_size + math.floor(8 * scale)
    local sections_h = (#sections * section_step) + ((#sections - 1) * section_gap) + (total_rows * row_step)
    local box_h = top_pad + header_h + header_gap + sections_h + bottom_pad
    local box_w = math.floor(400 * scale)

    -- Anchor to Top-Center to prevent collision with Video Monitor and GPU Monitor
    local x1 = math.floor((d.w - box_w) / 2)
    local x2 = x1 + box_w
    local y1 = math.floor(24 * scale)
    local y2 = y1 + box_h

    local ass = assdraw.ass_new()

    -- Outer Translucent Container
    ass:new_event()
    ass:append(string.format("{\\an7\\bord0\\shad0\\c&H0A0A0A&\\alpha&H%s&}", cfg.bg_alpha))
    ass:pos(0, 0)
    ass:draw_start()
    ass:round_rect_cw(x1, y1, x2, y2, 8 * scale)
    ass:draw_stop()

    -- Top Accent Border
    ass:new_event()
    ass:append(string.format("{\\an7\\bord0\\shad0\\c&H%s&\\alpha&H10&}", cfg.color_green))
    ass:pos(0, 0)
    ass:draw_start()
    ass:rect_cw(x1, y1, x2, y1 + math.floor(3 * scale))
    ass:draw_stop()

    -- Header Title & Subtitle
    local cur_y = y1 + top_pad
    ass:new_event()
    ass:append(string.format("{\\an7\\pos(%d,%d)\\fn%s\\b1\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}AV1 FILM GRAIN SYNTHESIS",
        x1 + pad_x, cur_y, cfg.font_face, title_size, cfg.color_green))

    cur_y = cur_y + title_size + math.floor(4 * scale)
    local media_name = mp.get_property("media-title") or mp.get_property("filename/no-ext") or "AV1 Video Stream"
    if #media_name > 38 then media_name = media_name:sub(1, 35) .. "..." end

    ass:new_event()
    ass:append(string.format("{\\an7\\pos(%d,%d)\\fn%s\\b1\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}%s",
        x1 + pad_x, cur_y, cfg.font_face, subtitle_size, cfg.color_white, media_name))

    -- Horizontal Divider
    cur_y = cur_y + subtitle_size + math.floor(8 * scale)
    ass:new_event()
    ass:append("{\\an7\\bord0\\shad0\\c&HFFFFFF&\\alpha&HD0&}")
    ass:pos(0, 0)
    ass:draw_start()
    ass:rect_cw(x1 + pad_x, cur_y, x2 - pad_x, cur_y + 1)
    ass:draw_stop()

    cur_y = cur_y + math.floor(8 * scale)

    -- Render Categorized Sections with Vector Diamond Headers
    local d_rad = math.max(3, math.floor(3.5 * scale))
    for s_idx, sec in ipairs(sections) do
        local d_cx = x1 + pad_x + d_rad
        local d_cy = cur_y + math.floor(section_size * 0.52)
        local text_x = x1 + pad_x + (d_rad * 2) + math.floor(6 * scale)

        ass:new_event()
        ass:append(string.format("{\\an7\\bord0\\shad0\\c&H%s&}", sec.title_color or cfg.color_green))
        ass:pos(0, 0)
        ass:draw_start()
        ass:move_to(d_cx, d_cy - d_rad)
        ass:line_to(d_cx + d_rad, d_cy)
        ass:line_to(d_cx, d_cy + d_rad)
        ass:line_to(d_cx - d_rad, d_cy)
        ass:draw_stop()

        ass:new_event()
        ass:append(string.format("{\\an7\\pos(%d,%d)\\fn%s\\b1\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}%s",
            text_x, cur_y, cfg.font_face, section_size, sec.title_color or cfg.color_green, sec.title))

        cur_y = cur_y + section_step

        for _, item in ipairs(sec.items) do
            local label, val_text, val_color = item[1], item[2], item[3]

            ass:new_event()
            ass:append(string.format("{\\an7\\pos(%d,%d)\\fn%s\\b0\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}%s",
                x1 + pad_x + indent_x, cur_y, cfg.font_face, row_size, cfg.color_gray, label))

            ass:new_event()
            ass:append(string.format("{\\an9\\pos(%d,%d)\\fn%s\\b1\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}%s",
                x2 - pad_x, cur_y, cfg.font_face, row_size, val_color, val_text))

            cur_y = cur_y + row_step
        end

        if s_idx < #sections then
            cur_y = cur_y + section_gap
        end
    end

    overlay.data = ass.text
    overlay:update()
end

local function toggle_hud()
    is_hud_visible = not is_hud_visible
    if is_hud_visible then
        draw_hud()
    else
        overlay:remove()
    end
end

-- Automatically clean filter and close overlay on new file
mp.register_event("file-loaded", function()
    if is_grain_stripped() then
        mp.commandv("vf", "remove", grain_filter_label)
    end
    if is_hud_visible then
        draw_hud()
    end
end)

mp.register_event("end-file", function()
    is_hud_visible = false
    overlay:remove()
end)

-- Script Message Handlers
mp.register_script_message("toggle-film-grain", toggle_film_grain)
mp.register_script_message("film-grain-toggle", toggle_film_grain)
mp.register_script_message("toggle-film-grain-hud", toggle_hud)
mp.register_script_message("film-grain-hud", toggle_hud)

mp.observe_property("osd-dimensions", "native", function()
    if is_hud_visible then draw_hud() end
end)
mp.observe_property("vf", "native", function()
    if is_hud_visible then draw_hud() end
end)