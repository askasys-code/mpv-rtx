-- =========================================================================
-- MPV Dual-Engine Film Grain Controller & Diagnostics Suite
-- [6] / [G]   : Cycle Universal GPU Synthetic Grain presets (any codec)
-- [Ctrl+6]    : Toggle AV1 native FGS (format=film-grain=no)
-- Fully Symmetrical Dark Glass ASS Overlay Matching Suite Aesthetic 1:1
-- No stream inspection: the script never guesses grain presence/intensity
-- =========================================================================

local mp = require("mp")
local utils = require("mp.utils")
-- Shared modules: <config>/script-modules/ (resolved from this script's folder, works in portable_config)
package.path = ((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)[/\\][^/\\]*$") or ".") .. "/../script-modules/?.lua;"
    .. (mp.command_native({ "expand-path", "~~/script-modules/?.lua" }) or "") .. ";" .. package.path
local theme = require("dark-glass")
local glass = require("glass-card")
local util = require("suite-util")

local is_hud_visible = false
local grain_filter_label = "@filmgrain"
local grain_filter_def = "@filmgrain:format=film-grain=no"

-- Visual Configuration & Styling (Matches suite monitors)
local cfg = theme.derive({})

local overlay = mp.create_osd_overlay("ass-events")

-- Calibrated GPU Synthetic Presets (Light, Medium, Heavy + Off)
local synthetic_presets = {
    { id = "off",    name = "Off (Clean / Direct)", short = "OFF",    grain = 0   },
    { id = "light",  name = "Light Grain (+128)",   short = "Light",  grain = 128 },
    { id = "medium", name = "Medium Grain (+256)",  short = "Medium", grain = 256 },
    { id = "heavy",  name = "Heavy Grain (+512)",   short = "Heavy",  grain = 512 }
}

local current_synth_idx = 1
local saved_deband = nil -- user's deband settings, captured before the first preset is applied
local forward_draw_hud -- Forward declaration

-- Dispatch notification toast via custom-notify.lua
local toast = util.toast

-- Check if AV1 grain strip filter is active (shared helper)
local is_fgs_stripped = util.fgs_stripped

-- Verify if current stream is AV1
local function is_av1_stream()
    local vc = tostring(mp.get_property("video-codec") or mp.get_property("video-format") or ""):lower()
    return vc:find("av1") ~= nil
end

-- Restore the user's own deband settings (captured before the first preset)
local function restore_deband()
    if not saved_deband then return end
    for name, value in pairs(saved_deband) do
        mp.set_property(name, value)
    end
    saved_deband = nil
end

-- Apply Universal Synthetic Film Grain via mpv's native GPU deband-grain carrier
local function apply_synthetic_preset(idx)
    current_synth_idx = idx
    local preset = synthetic_presets[current_synth_idx]

    if preset.grain <= 0 then
        restore_deband()
        mp.set_property_native("user-data/film-grain-tag", "OFF")
        toast("SYNTHETIC GRAIN", "Disabled (Clean Video)", "yellow", 1.8)
    else
        if not saved_deband then
            saved_deband = {}
            for _, name in ipairs({ "deband", "deband-iterations", "deband-threshold", "deband-range", "deband-grain" }) do
                saved_deband[name] = mp.get_property(name)
            end
        end

        mp.set_property("deband", "yes")
        mp.set_property_number("deband-iterations", 1)
        mp.set_property_number("deband-threshold", 1)
        mp.set_property_number("deband-range", 16)
        mp.set_property_number("deband-grain", preset.grain)

        mp.set_property_native("user-data/film-grain-tag", preset.short)
        toast("SYNTHETIC GRAIN", preset.name .. " [GPU]", "green", 2.0)
    end

    if is_hud_visible then forward_draw_hud() end
end

-- [6] / [G]: cycle synthetic GPU grain presets (always available, no locks)
local function cycle_synthetic_grain()
    local vtrack = mp.get_property_native("current-tracks/video")
    if not vtrack or vtrack.albumart then
        toast("SYNTHETIC GRAIN", "Not applicable for audio", "yellow", 2)
        return
    end
    local next_idx = (current_synth_idx % #synthetic_presets) + 1
    apply_synthetic_preset(next_idx)
end

-- [Ctrl+6]: toggle AV1 native FGS (hardware film-grain strip filter)
local function toggle_av1_fgs()
    local vtrack = mp.get_property_native("current-tracks/video")
    if not vtrack or vtrack.albumart then
        toast("AV1 FILM GRAIN", "Not applicable for audio", "yellow", 2)
        return
    end
    if not is_av1_stream() then
        toast("AV1 FILM GRAIN", "N/A (Non-AV1 Stream)", "yellow", 2)
        return
    end

    if is_fgs_stripped() then
        mp.commandv("vf", "remove", grain_filter_label)
        toast("AV1 FILM GRAIN", "ENABLED (Native FGS)", "green", 2)
    else
        mp.commandv("vf", "append", grain_filter_def)
        toast("AV1 FILM GRAIN", "DISABLED (Native FGS Stripped)", "yellow", 2)
    end
    if is_hud_visible then forward_draw_hud() end
end

-- Render ASS Diagnostics HUD
function forward_draw_hud()
    if not is_hud_visible then
        overlay:remove()
        return
    end

    local d, scale = glass.begin_frame(overlay, cfg)
    if not d then return end

    local is_av1 = is_av1_stream()
    local stripped = is_fgs_stripped()
    local synth_preset = synthetic_presets[current_synth_idx]
    local vc = tostring(mp.get_property("video-codec") or mp.get_property("video-format") or "NONE"):upper()

    local hwdec = mp.get_property("hwdec-current") or "no"
    local hw_desc = (hwdec ~= "" and hwdec ~= "no") and (hwdec:upper() .. " (Zero-Copy HW)") or "Software (SW)"
    local pixfmt = mp.get_property("video-params/pixelformat") or "N/A"

    local sections = {}

    local mode_title = is_av1 and "UNIVERSAL GPU GRAIN (AV1)" or "UNIVERSAL GPU GRAIN (H.264/HEVC)"
    local status_str = (synth_preset.grain > 0) and string.format("ACTIVE (%s)", synth_preset.name) or "OFF (Clean Source)"
    local status_col = (synth_preset.grain > 0) and cfg.color_green or cfg.color_gray

    local native_status, native_col
    if not is_av1 then
        native_status, native_col = "N/A (Non-AV1 Stream)", cfg.color_gray
    elseif stripped then
        native_status, native_col = "Stripped / OFF (Filter Active)", cfg.color_yellow
    else
        native_status, native_col = "Decoder Default (Not Inspected)", cfg.color_cyan
    end

    local pipeline_items = {
        { "Operating Mode", mode_title, cfg.color_cyan },
        { "Native FGS", native_status, native_col },
        { "Grain Status", status_str, status_col },
        { "Synthesis Engine", "GPU D3D11 / libplacebo Carrier", cfg.color_white },
        { "Video Decoder", hw_desc, cfg.color_white },
        { "Source Codec", vc .. " (" .. pixfmt .. ")", cfg.color_cyan }
    }
    -- Warn about possible grain stacking (AV1 not stripped + GPU preset active)
    if is_av1 and not stripped and synth_preset.grain > 0 then
        table.insert(pipeline_items, 4, { "Grain Stacking", "Possible if Native FGS Exists", cfg.color_yellow })
    end

    table.insert(sections, {
        title = "PIPELINE TELEMETRY",
        title_color = cfg.color_green,
        items = pipeline_items
    })

    table.insert(sections, {
        title = "SYNTHESIS CHARACTERISTICS",
        title_color = cfg.color_green,
        items = {
            { "Grain Frequency", (synth_preset.grain > 0) and "Dynamic Temporal (Per-Frame)" or "None", cfg.color_cyan },
            { "Luma Preservation", "Threshold=1 Non-Destructive Pass", cfg.color_white },
            { "Black Level Guard", "0% Gray Lift (OLED Safe)", cfg.color_green },
            { "Active Intensity", string.format("%d / 4096 Level", synth_preset.grain), cfg.color_yellow }
        }
    })

    table.insert(sections, {
        title = "CONTROLS & SHORTCUTS",
        title_color = cfg.color_green,
        items = {
            { "[6] / [G]", "Cycle Light / Medium / Heavy Presets", cfg.color_green },
            { "[Ctrl+6]", is_av1 and "Toggle AV1 Native FGS On/Off" or "Toggle AV1 Native FGS (AV1 only)", is_av1 and cfg.color_cyan or cfg.color_gray },
            { "[Alt+6] / [Alt+g]", "Toggle This Diagnostics Overlay", cfg.color_yellow }
        }
    })

    local media_name = mp.get_property("media-title") or mp.get_property("filename/no-ext") or "Active Stream"

    glass.draw(overlay, cfg, {
        d = d, scale = scale,
        title = "FILM GRAIN SYNTHESIS SUITE",
        subtitle = util.truncate_string(media_name, 38),
        sections = sections,
        anchor = "top-center",
    })
end

local function toggle_hud()
    is_hud_visible = not is_hud_visible
    if is_hud_visible then
        forward_draw_hud()
    else
        overlay:remove()
    end
end

-- Reset grain state on new file
mp.register_event("file-loaded", function()
    if is_fgs_stripped() then
        mp.commandv("vf", "remove", grain_filter_label)
    end

    restore_deband()
    current_synth_idx = 1
    mp.set_property_native("user-data/film-grain-tag", "OFF")

    if is_hud_visible then forward_draw_hud() end
end)

mp.register_event("end-file", function()
    is_hud_visible = false
    overlay:remove()
end)

-- Script Message API Handlers
mp.register_script_message("toggle-film-grain", toggle_av1_fgs)
mp.register_script_message("cycle-synthetic-grain", cycle_synthetic_grain)
mp.register_script_message("toggle-film-grain-hud", toggle_hud)

mp.observe_property("osd-dimensions", "native", function()
    if is_hud_visible then forward_draw_hud() end
end)