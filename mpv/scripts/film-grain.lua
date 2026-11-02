-- =========================================================================
-- MPV Dual-Engine Film Grain Controller
-- Mode A: AV1 Bitstream Normative FGS Hardware Stripping (Key 'g')
-- Mode B: Universal Semi-Monochromatic GLSL Shader Grain (Key '6')
-- =========================================================================

local mp = require("mp")
local utils = require("mp.utils")
package.path = ((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)[/\\][^/\\]*$") or ".") .. "/../script-modules/?.lua;"
    .. (mp.command_native({ "expand-path", "~~/script-modules/?.lua" }) or "") .. ";" .. package.path
local util = require("suite-util")

local grain_filter_label = "@filmgrain"
local grain_filter_def = "@filmgrain:format=film-grain=no"
local grain_shader_path = "~~/scalers/FilmGrain.glsl"

-- GLSL Semi-Monochromatic Grain Presets (Key '6')
local synthetic_presets = {
    { id = "off",    name = "Off (Clean / Direct)", short = "OFF",    strength = 0.000 },
    { id = "light",  name = "Light Grain",          short = "Light",  strength = 0.025 },
    { id = "medium", name = "Medium Grain",         short = "Medium", strength = 0.045 },
    { id = "heavy",  name = "Heavy Grain",          short = "Heavy",  strength = 0.075 }
}

local current_synth_idx = 1
local toast = util.toast

local av1_grain_info = {
    has_fgs = false,
    tier = "None",
    std_val = 0.0
}

local function is_fgs_stripped()
    local vf_str = mp.get_property("vf") or ""
    return vf_str:find(grain_filter_label, 1, true) ~= nil
end

local function is_av1_stream()
    local vc = tostring(mp.get_property("video-codec") or mp.get_property("video-format") or ""):lower()
    return vc:find("av1") ~= nil
end

local function is_grain_shader_active()
    local shaders = mp.get_property_native("glsl-shaders") or {}
    for _, s in ipairs(shaders) do
        if type(s) == "string" and s:find("FilmGrain") then
            return true
        end
    end
    return false
end

-- =========================================================================
-- Standalone AV1 OBU Bitstream Inspection
-- =========================================================================

local function generate_bit_needles(pattern_32)
    local needles = {}
    for s = 0, 7 do
        local b1 = math.floor(pattern_32 / (2 ^ (16 + s))) % 256
        local b2 = math.floor(pattern_32 / (2 ^ (8 + s))) % 256
        local b3 = math.floor(pattern_32 / (2 ^ s)) % 256
        table.insert(needles, { shift = s, str = string.char(b1, b2, b3) })
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
            local x2_val = (math.floor(byte_pre * (2 ^ s)) % 256) + math.floor(byte_cur / (2 ^ (8 - s)))
            if x2_val == 0x30 then return true end
        end
    end
    return false
end

local function inspect_av1_grain_profile()
    if not is_av1_stream() then
        av1_grain_info = { has_fgs = false, tier = "None", std_val = 0.0 }
        return
    end

    local path = tostring(mp.get_property("path") or "")
    if path ~= "" and not path:find("^%a+://") then
        local f = io.open(path, "rb")
        if f then
            local data = f:read(2097152)
            f:close()
            if data and #data >= 128 then
                if scan_needles_in_data(data, NEEDLES_HEAVY) then
                    av1_grain_info = { has_fgs = true, tier = "Heavy", std_val = 6.00 }
                    return
                elseif scan_needles_in_data(data, NEEDLES_MEDIUM) then
                    av1_grain_info = { has_fgs = true, tier = "Medium", std_val = 3.80 }
                    return
                elseif scan_needles_in_data(data, NEEDLES_LIGHT) then
                    av1_grain_info = { has_fgs = true, tier = "Light", std_val = 2.00 }
                    return
                end
            end
        end
    end

    av1_grain_info = { has_fgs = false, tier = "None", std_val = 0.0 }
end

-- =========================================================================
-- Action 1: GLSL Synthetic Grain Presets (Key '6')
-- =========================================================================

local function apply_synthetic_preset(idx)
    current_synth_idx = idx
    local preset = synthetic_presets[current_synth_idx]

    if preset.id == "off" then
        if is_grain_shader_active() then
            mp.commandv("change-list", "glsl-shaders", "remove", grain_shader_path)
        end
        mp.set_property_native("user-data/film-grain-tag", "OFF")
        toast("GLSL GRAIN", "Disabled (Clean Video)", "yellow", 1.8)
    else
        if not is_grain_shader_active() then
            mp.commandv("change-list", "glsl-shaders", "append", grain_shader_path)
        end
        mp.set_property("glsl-shader-opts", string.format("FilmGrain/GrainStrength=%.4f", preset.strength))
        mp.set_property_native("user-data/film-grain-tag", "GRAIN: " .. preset.short)
        toast("GLSL GRAIN", preset.name, "green", 2.0)
    end
end

local function cycle_synthetic_grain()
    local next_idx = (current_synth_idx % #synthetic_presets) + 1
    apply_synthetic_preset(next_idx)
end

-- =========================================================================
-- Action 2: AV1 Native Hardware Grain Toggle (Key 'g')
-- =========================================================================

local function toggle_av1_grain()
    local vtrack = mp.get_property_native("current-tracks/video")
    if not vtrack or vtrack.albumart then
        toast("AV1 GRAIN", "Not applicable for audio tracks", "yellow", 2)
        return
    end

    if not is_av1_stream() then
        toast("AV1 GRAIN", "Active stream is not AV1", "yellow", 2)
        return
    end

    if is_fgs_stripped() then
        mp.commandv("vf", "remove", grain_filter_label)
        mp.set_property_native("user-data/film-grain-tag", "FGS: ON")
        toast("AV1 GRAIN", "ENABLED (Hardware Synthesis)", "green", 2)
    else
        mp.commandv("vf", "append", grain_filter_def)
        mp.set_property_native("user-data/film-grain-tag", "FGS: OFF")
        toast("AV1 GRAIN", "DISABLED (Metadata Stripped)", "yellow", 2)
    end
end

-- =========================================================================
-- Events & Registrations
-- =========================================================================

mp.register_event("file-loaded", function()
    if is_fgs_stripped() then
        mp.commandv("vf", "remove", grain_filter_label)
    end
    if is_grain_shader_active() then
        mp.commandv("change-list", "glsl-shaders", "remove", grain_shader_path)
    end
    current_synth_idx = 1
    mp.set_property_native("user-data/film-grain-tag", "OFF")
    inspect_av1_grain_profile()
end)

mp.register_script_message("toggle-av1-grain", toggle_av1_grain)
mp.register_script_message("cycle-synthetic-grain", cycle_synthetic_grain)