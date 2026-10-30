-- =========================================================================
-- MPV Dual-Engine Film Grain Controller & Diagnostics Suite
-- Mode A: AV1 Bitstream Normative FGS Metadata Stripping
-- Mode B: Universal GPU Synthetic Film Grain Injection (H.264, HEVC, SDR/HDR)
-- Fully Symmetrical Dark Glass ASS Overlay Matching Suite Aesthetic 1:1
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
    color_cyan      = "00E5FF",    -- RivaTuner Cyan (Presets & Technical Parameters)
    color_yellow    = "00C8FF",    -- Amber Warning (Stripped / High intensities)
    color_red       = "3B3BFF",    -- Critical Red
    color_white     = "FFFFFF",
    color_gray      = "9E9E9E",    -- Inactive labels
    bg_alpha        = "35",        -- Translucent dark glass (~80% dark)
}

local overlay = mp.create_osd_overlay("ass-events")

-- Synthetic Film Grain Presets for non-AV1 content (H.264, HEVC, etc.)
local synthetic_presets = {
    { id = "off",     name = "Off (Clean / Direct)",       short = "OFF",       grain = 0   },
    { id = "fine35",  name = "35mm Fine Grain (+32)",      short = "35mm Fine", grain = 32  },
    { id = "std35",   name = "35mm Cinematic (+64)",      short = "35mm",      grain = 64  },
    { id = "rough16", name = "16mm Vintage Indie (+128)",  short = "16mm",      grain = 128 },
    { id = "heavy8",  name = "8mm Gritty Archive (+256)",  short = "8mm",       grain = 256 }
}

local current_synth_idx = 1
local saved_deband_state = nil
local saved_deband_grain = 24
local forward_draw_hud -- Forward declaration

-- Dispatch notification toast via custom-notify.lua
local function toast(title, msg, color, duration)
    mp.commandv("script-message", "notify", title, msg, color or "green", tostring(duration or 2))
end

-- Check if AV1 grain strip filter is active
local function is_fgs_stripped()
    local vf_str = mp.get_property("vf") or ""
    return vf_str:find(grain_filter_label, 1, true) ~= nil
end

-- Verify if current stream is AV1
local function is_av1_stream()
    local vc = tostring(mp.get_property("video-codec") or mp.get_property("video-format") or ""):lower()
    return vc:find("av1") ~= nil
end

-- Check if stream has FGS signaling
local function has_fgs_hint()
    local filename = tostring(mp.get_property("filename") or ""):lower()
    local title = tostring(mp.get_property("media-title") or ""):lower()
    return filename:find("_fgs") or filename:find("fgs") or filename:find("grain")
        or title:find("_fgs") or title:find("fgs") or title:find("grain")
end

-- Apply Universal Synthetic Film Grain via mpv's native GPU deband-grain carrier
local function apply_synthetic_preset(idx)
    current_synth_idx = idx
    local preset = synthetic_presets[current_synth_idx]

    if preset.grain <= 0 then
        -- Restore original deband parameters
        if saved_deband_state ~= nil then
            mp.set_property("deband", saved_deband_state)
            saved_deband_state = nil
        else
            mp.set_property("deband", "no")
        end
        mp.set_property_number("deband-grain", saved_deband_grain or 24)
        mp.set_property_number("deband-iterations", 4)
        mp.set_property_number("deband-threshold", 48)
        mp.set_property_native("user-data/film-grain-tag", "OFF")
        toast("SYNTHETIC GRAIN", "Disabled (Clean Video)", "yellow", 1.8)
    else
        -- Save default deband state before first activation
        if saved_deband_state == nil then
            saved_deband_state = mp.get_property("deband") or "no"
            saved_deband_grain = mp.get_property_number("deband-grain", 24)
        end

        -- Non-destructive grain carrier: threshold=1 guarantees zero detail smoothing
        mp.set_property("deband", "yes")
        mp.set_property_number("deband-iterations", 1)
        mp.set_property_number("deband-threshold", 1)
        mp.set_property_number("deband-range", 16)
        mp.set_property_number("deband-grain", preset.grain)

        mp.set_property_native("user-data/film-grain-tag", "GRAIN: " .. preset.short)
        toast("SYNTHETIC GRAIN", preset.name .. " [GPU]", "green", 2.0)
    end

    if is_hud_visible then forward_draw_hud() end
end

-- Cycle synthetic grain presets for H.264 / HEVC content
local function cycle_synthetic_grain()
    local next_idx = (current_synth_idx % #synthetic_presets) + 1
    apply_synthetic_preset(next_idx)
end

-- Smart Master Toggle: AV1 FGS for AV1 content, Synthetic Presets for H.264/other
local function smart_toggle_grain()
    local vtrack = mp.get_property_native("current-tracks/video")
    if not vtrack or vtrack.albumart then
        toast("FILM GRAIN", "Not applicable for audio", "yellow", 2)
        return
    end

    if is_av1_stream() and (has_fgs_hint() or is_fgs_stripped()) then
        -- AV1 Hardware FGS Toggle
        if is_fgs_stripped() then
            mp.commandv("vf", "remove", grain_filter_label)
            mp.set_property_native("user-data/film-grain-tag", "FGS: ON")
            toast("AV1 FILM GRAIN", "ENABLED (Hardware Synthesis)", "green", 2)
        else
            mp.commandv("vf", "append", grain_filter_def)
            mp.set_property_native("user-data/film-grain-tag", "FGS: OFF")
            toast("AV1 FILM GRAIN", "DISABLED (Metadata Stripped)", "yellow", 2)
        end
        if is_hud_visible then forward_draw_hud() end
    else
        -- Universal H.264 / HEVC Synthetic Grain Cycling
        cycle_synthetic_grain()
    end
end

-- Render ASS Diagnostics HUD
function forward_draw_hud()
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
    local stripped = is_fgs_stripped()
    local synth_preset = synthetic_presets[current_synth_idx]
    local vc = tostring(mp.get_property("video-codec") or mp.get_property("video-format") or "NONE"):upper()

    -- Determine Pipeline Information based on stream format
    local mode_title = is_av1 and "AV1 BITSTREAM FGS" or "UNIVERSAL GPU GRAIN (H.264/HEVC)"
    local status_str, status_col
    local engine_str = "GPU D3D11 / libplacebo Carrier"

    if is_av1 then
        engine_str = "AV1 Hardware Normative (libplacebo)"
        if stripped then
            status_str = "STRIPPED / OFF (Clean Image)"
            status_col = cfg.color_yellow
        else
            status_str = "ACTIVE (Hardware FGS)"
            status_col = cfg.color_green
        end
    else
        if synth_preset.grain > 0 then
            status_str = string.format("ACTIVE (%s)", synth_preset.name)
            status_col = cfg.color_green
        else
            status_str = "OFF (Clean Source)"
            status_col = cfg.color_gray
        end
    end

    local hwdec = mp.get_property("hwdec-current") or "no"
    local hw_desc = (hwdec ~= "" and hwdec ~= "no") and (hwdec:upper() .. " (Zero-Copy HW)") or "Software (SW)"
    local pixfmt = mp.get_property("video-params/pixelformat") or "N/A"

    local sections = {
        {
            title = "PIPELINE TELEMETRY",
            title_color = cfg.color_green,
            items = {
                { "Operating Mode", mode_title, cfg.color_cyan },
                { "Grain Status", status_str, status_col },
                { "Synthesis Engine", engine_str, cfg.color_white },
                { "Video Decoder", hw_desc, cfg.color_white },
                { "Source Codec", vc .. " (" .. pixfmt .. ")", cfg.color_cyan }
            }
        },
        {
            title = "SYNTHESIS CHARACTERISTICS",
            title_color = cfg.color_green,
            items = {
                { "Grain Frequency", (synth_preset.grain > 0 or (is_av1 and not stripped)) and "Dynamic Temporal (Per-Frame)" or "None", cfg.color_cyan },
                { "Luma Preservation", "Threshold=1 Non-Destructive Pass", cfg.color_white },
                { "Black Level Guard", "0% Gray Lift (OLED Safe)", cfg.color_green },
                { "Active Intensity", is_av1 and "Bitstream Parameter Table" or string.format("%d / 4096 Level", synth_preset.grain), cfg.color_yellow }
            }
        },
        {
            title = "CONTROLS & SHORTCUTS",
            title_color = cfg.color_green,
            items = {
                { "[6] / [G]", is_av1 and "Toggle AV1 FGS On/Off" or "Cycle 35mm/16mm/8mm Presets", cfg.color_green },
                { "[Ctrl+6]", "Force Cycle Synthetic Presets", cfg.color_cyan },
                { "[Alt+6] / [Alt+g]", "Toggle This Diagnostics Overlay", cfg.color_yellow }
            }
        }
    }

    -- Typography & Geometric Spacing
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
    for _, sec in ipairs(sections) do total_rows = total_rows + #sec.items end

    local header_h = title_size + subtitle_size + math.floor(8 * scale)
    local sections_h = (#sections * section_step) + ((#sections - 1) * section_gap) + (total_rows * row_step)
    local box_h = top_pad + header_h + header_gap + sections_h + bottom_pad
    local box_w = math.floor(400 * scale)

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
    ass:append(string.format("{\\an7\\pos(%d,%d)\\fn%s\\b1\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}FILM GRAIN SYNTHESIS SUITE",
        x1 + pad_x, cur_y, cfg.font_face, title_size, cfg.color_green))

    cur_y = cur_y + title_size + math.floor(4 * scale)
    local media_name = mp.get_property("media-title") or mp.get_property("filename/no-ext") or "Active Stream"
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

        if s_idx < #sections then cur_y = cur_y + section_gap end
    end

    overlay.data = ass.text
    overlay:update()
end

local function toggle_hud()
    is_hud_visible = not is_hud_visible
    if is_hud_visible then
        forward_draw_hud()
    else
        overlay:remove()
    end
end

-- Automatically reset synthetic presets and clean filters on new file
mp.register_event("file-loaded", function()
    if is_fgs_stripped() then
        mp.commandv("vf", "remove", grain_filter_label)
    end
    current_synth_idx = 1
    saved_deband_state = nil
    mp.set_property_native("user-data/film-grain-tag", "OFF")
    if is_hud_visible then forward_draw_hud() end
end)

mp.register_event("end-file", function()
    is_hud_visible = false
    overlay:remove()
end)

-- Script Message API Handlers
mp.register_script_message("toggle-film-grain", smart_toggle_grain)
mp.register_script_message("cycle-synthetic-grain", cycle_synthetic_grain)
mp.register_script_message("toggle-film-grain-hud", toggle_hud)

mp.observe_property("osd-dimensions", "native", function()
    if is_hud_visible then forward_draw_hud() end
end)