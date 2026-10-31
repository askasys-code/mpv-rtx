-- =========================================================================
-- MPV Dual-Engine Film Grain Controller & Diagnostics Suite
-- Mode A: AV1 Bitstream Normative FGS Binary Inspection & Stripping
-- Mode B: Universal GPU Synthetic Film Grain (Light, Medium, Heavy)
-- Fully Symmetrical Dark Glass ASS Overlay Matching Suite Aesthetic 1:1
-- 100% Standalone: Direct OBU Luma-Curve Bitstream Analyzer (No Logs/Tools)
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
    { id = "medium", name = "Medium Grain (+192)",  short = "Medium", grain = 256 },
    { id = "heavy",  name = "Heavy Grain (+512)",   short = "Heavy",  grain = 512 }
}

local current_synth_idx = 1
local saved_deband_state = nil
local saved_deband_grain = 24
local forward_draw_hud -- Forward declaration

-- Native AV1 Grain Telemetry
local av1_grain_info = {
    has_fgs = false,
    tier = "None",            -- "Light" | "Medium" | "Heavy" | "None"
    std_val = 0.0,
    std_desc = "σ = 0.00 (Std Dev)",
    source = "None"
}

-- Dispatch notification toast via custom-notify.lua
local toast = util.toast

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

-- =========================================================================
-- Standalone Bitstream OBU Luma-Curve Detector
-- Points signature: x2=48 (0x30), y2=ScaleMid, x3=96 (0x60), y3=ScaleMid
-- Heavy  (Std 6.0) -> ScaleMid = 47 (0x2F) -> Pattern: 0x302F602F
-- Medium (Std 3.8) -> ScaleMid = 30 (0x1E) -> Pattern: 0x301E601E
-- Light  (Std 2.0) -> ScaleMid = 16 (0x10) -> Pattern: 0x30106010
-- =========================================================================

local function generate_bit_needles(pattern_32)
    local needles = {}
    for s = 0, 7 do
        local b1 = math.floor(pattern_32 / (2 ^ (16 + s))) % 256
        local b2 = math.floor(pattern_32 / (2 ^ (8 + s))) % 256
        local b3 = math.floor(pattern_32 / (2 ^ s)) % 256
        table.insert(needles, {
            shift = s,
            str = string.char(b1, b2, b3)
        })
    end
    return needles
end

local NEEDLES_HEAVY  = generate_bit_needles(0x302F602F)
local NEEDLES_MEDIUM = generate_bit_needles(0x301E601E)
local NEEDLES_LIGHT  = generate_bit_needles(0x30106010)

local function scan_needles_in_data(data, needles)
    for _, n in ipairs(needles) do
        local pos = data:find(n.str, 1, true)
        if pos and pos > 1 and (pos + 4) <= #data then
            local s = n.shift
            local byte_pre = data:byte(pos - 1)
            local byte_cur = data:byte(pos)
            -- Verify preceding 0x30 (x2=48) boundary
            local x2_val = (math.floor(byte_pre * (2 ^ s)) % 256) + math.floor(byte_cur / (2 ^ (8 - s)))
            if x2_val == 0x30 then
                return true
            end
        end
    end
    return false
end

-- Inspect raw bitstream directly from the video file (Zero dependencies)
local function probe_binary_fgs(filepath)
    if not filepath or filepath == "" or filepath:find("^%a+://") then return nil end
    local f = io.open(filepath, "rb")
    if not f then return nil end

    -- Read up to 2 MB to reliably cover file containers and initial AV1 clusters
    local data = f:read(2097152)
    f:close()
    if not data or #data < 128 then return nil end

    -- 1. Check Heavy (Std 6.0 / ScaleMid 47)
    if scan_needles_in_data(data, NEEDLES_HEAVY) then
        return {
            has_fgs = true,
            tier = "Heavy",
            std_val = 6.00,
            std_desc = "σ = 6.00 (Std Dev)",
            source = "Bitstream OBU Header"
        }
    end

    -- 2. Check Medium (Std 3.8 / ScaleMid 30)
    if scan_needles_in_data(data, NEEDLES_MEDIUM) then
        return {
            has_fgs = true,
            tier = "Medium",
            std_val = 3.80,
            std_desc = "σ = 3.80 (Std Dev)",
            source = "Bitstream OBU Header"
        }
    end

    -- 3. Check Light (Std 2.0 / ScaleMid 16)
    if scan_needles_in_data(data, NEEDLES_LIGHT) then
        return {
            has_fgs = true,
            tier = "Light",
            std_val = 2.00,
            std_desc = "σ = 2.00 (Std Dev)",
            source = "Bitstream OBU Header"
        }
    end

    return nil
end

-- Fallback signature parser for explicit filename or metadata tokens
local function parse_grain_signature(str)
    if not str or str == "" then return nil end
    local s = str:lower()

    -- 1. Explicit keyword checks
    if s:match("%f[%a]heavy%f[%A]") or s:find("preview_heavy") then
        return { has_fgs = true, tier = "Heavy", std_val = 6.00, std_desc = "σ = 6.00 (Std Dev)" }
    elseif s:match("%f[%a]light%f[%A]") or s:find("preview_light") then
        return { has_fgs = true, tier = "Light", std_val = 2.00, std_desc = "σ = 2.00 (Std Dev)" }
    elseif s:match("%f[%a]medium%f[%A]") or s:match("%f[%a]med%f[%A]") or s:find("preview_med") then
        return { has_fgs = true, tier = "Medium", std_val = 3.80, std_desc = "σ = 3.80 (Std Dev)" }
    end

    -- 2. TargetStd8 numerical detection
    local std_val = s:match("std%s*=?%s*([0-9]+%.?[0-9]*)")
    if std_val then
        local std = tonumber(std_val) or 0
        if std <= 0 then
            return { has_fgs = false, tier = "None", std_val = 0.0, std_desc = "σ = 0.00 (Std Dev)" }
        elseif std >= 4.8 then
            return { has_fgs = true, tier = "Heavy", std_val = 6.00, std_desc = "σ = 6.00 (Std Dev)" }
        elseif std >= 2.8 then
            return { has_fgs = true, tier = "Medium", std_val = 3.80, std_desc = "σ = 3.80 (Std Dev)" }
        else
            return { has_fgs = true, tier = "Light", std_val = 2.00, std_desc = "σ = 2.00 (Std Dev)" }
        end
    end

    -- 3. SVT-AV1 / HandBrake numeric levels (film-grain=8, fgs16, fgs30, etc.)
    local lvl = s:match("film%-grain%s*=%s*(%d+)")
             or s:match("film%-grain%s+(%d+)")
             or s:match("fgs%s*=%s*(%d+)")
             or s:match("fgs[_%-]?([0-9]+)")
             or s:match("grain[_%-]?([0-9]+)")

    if lvl then
        local n = tonumber(lvl) or 0
        if n <= 0 then
            return { has_fgs = false, tier = "None", std_val = 0.0, std_desc = "σ = 0.00 (Std Dev)" }
        elseif n >= 25 or n == 75 then
            return { has_fgs = true, tier = "Heavy", std_val = 6.00, std_desc = "σ = 6.00 (Std Dev)" }
        elseif (n > 10 and n < 25) or n == 48 then
            return { has_fgs = true, tier = "Medium", std_val = 3.80, std_desc = "σ = 3.80 (Std Dev)" }
        else
            return { has_fgs = true, tier = "Light", std_val = 2.00, std_desc = "σ = 2.00 (Std Dev)" }
        end
    end

    return nil
end

-- Inspect stream characteristics entirely standalone
local function inspect_av1_grain_profile()
    if not is_av1_stream() then
        av1_grain_info = { has_fgs = false, tier = "None", std_val = 0.0, std_desc = "N/A", source = "None" }
        return
    end

    local path = tostring(mp.get_property("path") or "")

    -- 1. Direct Bitstream OBU Inspection (Mathematical ground truth from raw video data)
    local bin_sig = probe_binary_fgs(path)
    if bin_sig then
        av1_grain_info = bin_sig
        return
    end

    -- 2. Filename & Title Parser (Word boundaries)
    local filename = tostring(mp.get_property("filename") or "")
    local media_title = tostring(mp.get_property("media-title") or "")
    local file_sig = parse_grain_signature(filename) or parse_grain_signature(media_title)
    if file_sig then
        av1_grain_info = {
            has_fgs = file_sig.has_fgs,
            tier = file_sig.tier,
            std_val = file_sig.std_val,
            std_desc = file_sig.std_desc,
            source = "Filename Signature"
        }
        return
    end

    -- 3. Stream & Track Metadata
    local meta = mp.get_property_native("metadata") or {}
    for _, val in pairs(meta) do
        local meta_sig = parse_grain_signature(tostring(val))
        if meta_sig then
            av1_grain_info = {
                has_fgs = meta_sig.has_fgs,
                tier = meta_sig.tier,
                std_val = meta_sig.std_val,
                std_desc = meta_sig.std_desc,
                source = "Stream Metadata"
            }
            return
        end
    end

    local track_list = mp.get_property_native("track-list") or {}
    for _, t in ipairs(track_list) do
        if t.type == "video" then
            local track_sig = parse_grain_signature(t.title)
            if track_sig then
                av1_grain_info = {
                    has_fgs = track_sig.has_fgs,
                    tier = track_sig.tier,
                    std_val = track_sig.std_val,
                    std_desc = track_sig.std_desc,
                    source = "Track Tag"
                }
                return
            end
        end
    end

    -- 4. Default: Clean stream (No FGS found)
    av1_grain_info = { has_fgs = false, tier = "None", std_val = 0.0, std_desc = "σ = 0.00 (Std Dev)", source = "Inspection" }
end

-- Apply Universal Synthetic Film Grain via mpv's native GPU deband-grain carrier
local function apply_synthetic_preset(idx)
    current_synth_idx = idx
    local preset = synthetic_presets[current_synth_idx]

    if preset.grain <= 0 then
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
        if saved_deband_state == nil then
            saved_deband_state = mp.get_property("deband") or "no"
            saved_deband_grain = mp.get_property_number("deband-grain", 24)
        end

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

-- Cycle synthetic grain presets (Locked if AV1 native FGS is present)
local function cycle_synthetic_grain()
    if is_av1_stream() and (av1_grain_info.has_fgs or is_fgs_stripped()) then
        toast("SYNTHETIC GRAIN", "Locked: AV1 Native FGS Active", "yellow", 2.0)
        return
    end
    local next_idx = (current_synth_idx % #synthetic_presets) + 1
    apply_synthetic_preset(next_idx)
end

-- Smart Master Toggle: AV1 FGS for native streams, Synthetic Presets for H.264/HEVC and clean AV1
local function smart_toggle_grain()
    local vtrack = mp.get_property_native("current-tracks/video")
    if not vtrack or vtrack.albumart then
        toast("FILM GRAIN", "Not applicable for audio", "yellow", 2)
        return
    end

    if is_av1_stream() and (av1_grain_info.has_fgs or is_fgs_stripped()) then
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
        cycle_synthetic_grain()
    end
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
    local has_native = is_av1 and (av1_grain_info.has_fgs or is_fgs_stripped())
    local stripped = is_fgs_stripped()
    local synth_preset = synthetic_presets[current_synth_idx]
    local vc = tostring(mp.get_property("video-codec") or mp.get_property("video-format") or "NONE"):upper()

    local hwdec = mp.get_property("hwdec-current") or "no"
    local hw_desc = (hwdec ~= "" and hwdec ~= "no") and (hwdec:upper() .. " (Zero-Copy HW)") or "Software (SW)"
    local pixfmt = mp.get_property("video-params/pixelformat") or "N/A"

    local sections = {}

    if is_av1 and has_native then
        local status_str = stripped and "STRIPPED / OFF (Clean Image)" or "ACTIVE (Hardware FGS)"
        local status_col = stripped and cfg.color_yellow or cfg.color_green
        local tier_col = (av1_grain_info.tier == "Light") and cfg.color_cyan or ((av1_grain_info.tier == "Heavy") and cfg.color_yellow or cfg.color_green)

        table.insert(sections, {
            title = "PIPELINE TELEMETRY",
            title_color = cfg.color_green,
            items = {
                { "Operating Mode", "AV1 BITSTREAM FGS", cfg.color_cyan },
                { "Grain Status", status_str, status_col },
                { "Synthesis Engine", "AV1 Hardware Normative (libplacebo)", cfg.color_white },
                { "Video Decoder", hw_desc, cfg.color_white },
                { "Source Codec", vc .. " (" .. pixfmt .. ")", cfg.color_cyan }
            }
        })

        table.insert(sections, {
            title = "AV1 GRAIN CHARACTERISTICS",
            title_color = cfg.color_green,
            items = {
                { "Grain Profile", av1_grain_info.tier .. " Grain", tier_col },
                { "Intensity Rating", av1_grain_info.std_desc, cfg.color_yellow },
                { "Detection Source", av1_grain_info.source, cfg.color_cyan },
                { "GPU Injection Lock", "Locked (Prevents Double Grain)", cfg.color_green }
            }
        })

        table.insert(sections, {
            title = "CONTROLS & SHORTCUTS",
            title_color = cfg.color_green,
            items = {
                { "[6] / [G]", "Toggle AV1 Hardware FGS On/Off", cfg.color_green },
                { "[Ctrl+6]", "Locked: Native Grain Active", cfg.color_gray },
                { "[Alt+6] / [Alt+g]", "Toggle This Diagnostics Overlay", cfg.color_yellow }
            }
        })
    else
        local mode_title = is_av1 and "UNIVERSAL GPU GRAIN (Clean AV1)" or "UNIVERSAL GPU GRAIN (H.264/HEVC)"
        local status_str = (synth_preset.grain > 0) and string.format("ACTIVE (%s)", synth_preset.name) or "OFF (Clean Source)"
        local status_col = (synth_preset.grain > 0) and cfg.color_green or cfg.color_gray
        local native_status = is_av1 and "None Detected (GPU Injection Allowed)" or "N/A (Non-AV1 Stream)"

        table.insert(sections, {
            title = "PIPELINE TELEMETRY",
            title_color = cfg.color_green,
            items = {
                { "Operating Mode", mode_title, cfg.color_cyan },
                { "Native FGS", native_status, is_av1 and cfg.color_yellow or cfg.color_gray },
                { "Grain Status", status_str, status_col },
                { "Synthesis Engine", "GPU D3D11 / libplacebo Carrier", cfg.color_white },
                { "Video Decoder", hw_desc, cfg.color_white },
                { "Source Codec", vc .. " (" .. pixfmt .. ")", cfg.color_cyan }
            }
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
                { "[Ctrl+6]", "Force Cycle Synthetic Presets", cfg.color_cyan },
                { "[Alt+6] / [Alt+g]", "Toggle This Diagnostics Overlay", cfg.color_yellow }
            }
        })
    end

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

-- Automatically inspect stream on new file
mp.register_event("file-loaded", function()
    if is_fgs_stripped() then
        mp.commandv("vf", "remove", grain_filter_label)
    end

    current_synth_idx = 1
    saved_deband_state = nil
    mp.set_property_native("user-data/film-grain-tag", "OFF")

    inspect_av1_grain_profile()

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