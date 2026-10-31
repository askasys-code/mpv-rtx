-- =========================================================================
-- Suite Utilities (suite-util.lua)
-- Small helpers that were previously copy-pasted across the HUD scripts.
-- Usage: local util = require("suite-util")
-- =========================================================================

local M = {}

-- Dispatches a Dark Glass toast to custom-notify.lua
function M.toast(title, msg, color, duration)
    mp.commandv("script-message", "notify", title, msg, color or "green", tostring(duration or 2))
end

-- Clamps a string to max_len characters, ending with "..." when cut
function M.truncate_string(str, max_len)
    if not str then return "" end
    if #str > max_len then return str:sub(1, max_len - 3) .. "..." end
    return str
end

-- Human readable bitrate ("N/A", "640 kbps", "45.00 Mbps")
function M.format_bitrate(bps)
    if not bps or bps <= 0 then return "N/A" end
    if bps >= 1000000 then
        return string.format("%.2f Mbps", bps / 1000000)
    else
        return string.format("%d kbps", math.floor(bps / 1000 + 0.5))
    end
end

-- Parses the value of a "set-*" script-message: true / false / nil (= toggle)
function M.parse_switch(val)
    if val == "yes" or val == "true" or val == "on" or val == "1" then
        return true
    elseif val == "no" or val == "false" or val == "off" or val == "0" then
        return false
    end
    return nil
end

-- Is a labelled filter (e.g. "@vsr") present in the current video filter chain?
function M.vf_has(label)
    local vf_str = mp.get_property("vf") or ""
    return vf_str:find(label, 1, true) ~= nil
end

-- Removes a labelled filter and its optional format helper from the chain
function M.vf_remove(label, helper_label)
    local vf_str = mp.get_property("vf") or ""
    if vf_str:find(label, 1, true) ~= nil then
        mp.commandv("vf", "remove", label)
    end
    if vf_str:find(helper_label, 1, true) ~= nil then
        mp.commandv("vf", "remove", helper_label)
    end
end

-- Pixel formats accepted directly by D3D11VPP (RTX True HDR / RTX VSR)
local RTX_FORMATS = {
    ["nv12"]        = true,
    ["yuv420p"]     = true,
    ["p010"]        = true,
    ["p010le"]      = true,
    ["yuv420p10le"] = true,
}

-- extra_d3d11 = true additionally accepts hardware "d3d11" frames (used by VSR)
function M.is_rtx_pixfmt(pixfmt, extra_d3d11)
    if not pixfmt then return false end
    local clean_fmt = tostring(pixfmt):lower():match("^%s*(.-)%s*$")
    if extra_d3d11 and clean_fmt == "d3d11" then return true end
    return RTX_FORMATS[clean_fmt] or false
end

-- =========================================================================
-- Time formatters (one per on-screen style, outputs are script-specific)
--   mmss    -> MM:SS with unbounded minutes          (sound-monitor)
--   auto    -> MM:SS, or H:MM:SS when >= 1 hour      (custom-osc)
--   hms     -> always HH:MM:SS                       (video-monitor)
--   precise -> (seconds, no_ms, full) optional .mmm  (clip-maker)
-- =========================================================================
M.format_time = {
    mmss = function(seconds)
        if not seconds or seconds < 0 then return "00:00" end
        local m = math.floor(seconds / 60)
        local s = math.floor(seconds % 60)
        return string.format("%02d:%02d", m, s)
    end,

    auto = function(seconds)
        if not seconds or seconds < 0 then return "00:00" end
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        local s = math.floor(seconds % 60)
        if h > 0 then
            return string.format("%d:%02d:%02d", h, m, s)
        end
        return string.format("%02d:%02d", m, s)
    end,

    hms = function(seconds)
        if not seconds or seconds < 0 then return "00:00:00" end
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        local s = math.floor(seconds % 60)
        return string.format("%02d:%02d:%02d", h, m, s)
    end,

    precise = function(seconds, no_ms, full)
        if not seconds or seconds < 0 then return "00:00" end
        local ms = no_ms and "" or string.format(".%03d", math.floor((seconds % 1) * 1000))
        local s = math.floor(seconds) % 60
        local m = math.floor(seconds / 60) % 60
        local h = math.floor(seconds / 3600)
        if full or h > 0 then
            return string.format("%d:%02d:%02d%s", h, m, s, ms)
        end
        return string.format("%02d:%02d%s", m, s, ms)
    end,
}

-- =========================================================================
-- NVIDIA pipeline detection (shared by nvidia-monitor, video-monitor, custom-osc)
-- Scripts keep their own labels/colours and map the returned "kind" to them.
-- =========================================================================

-- RTX VSR filter active? (@vsr label or d3d11vpp nvidia scaling mode)
function M.has_vsr()
    local vf_str = mp.get_property("vf") or ""
    return (vf_str:find("@vsr") or vf_str:find("scaling%-mode=nvidia")) ~= nil
end

-- RTX True HDR filter active?
function M.has_truehdr()
    local vf_str = mp.get_property("vf") or ""
    return (vf_str:find("@truehdr") or vf_str:find("nvidia%-true%-hdr")) ~= nil
end

-- Returns "truehdr" | "pq" | "hlg" | "bt2020" | "sdr".
-- peak_threshold: sig-peak above which the stream counts as HDR (scripts differ: 1.0 / 1.05)
function M.dynamic_range_kind(peak_threshold)
    if M.has_truehdr() then return "truehdr" end

    local gamma = mp.get_property("video-params/gamma") or ""
    local sig_peak = mp.get_property_number("video-params/sig-peak", 1.0)
    local colormatrix = mp.get_property("video-params/colormatrix") or ""

    if gamma == "pq" then
        return "pq"
    elseif gamma == "hlg" then
        return "hlg"
    elseif sig_peak > peak_threshold or colormatrix:find("bt.2020") then
        return "bt2020"
    end
    return "sdr"
end

-- Returns "vsr" | "nis" | "fsr" | "sgsr" | "cas" | "glsl" | nil (nil = native scaler)
function M.upscaler_kind()
    if M.has_vsr() then return "vsr" end

    -- Filter out empty string tokens (e.g. when glsl-shaders="" is set on image opening)
    local raw_shaders = mp.get_property_native("glsl-shaders") or {}
    local shaders = {}
    for _, s in ipairs(raw_shaders) do
        if type(s) == "string" and s:match("%S") then
            table.insert(shaders, s)
        end
    end

    if #shaders > 0 then
        for _, s in ipairs(shaders) do
            if s:find("NVScaler") then return "nis" end
            if s:find("FSR") then return "fsr" end
            if s:find("SGSR") then return "sgsr" end
            if s:find("CAS") then return "cas" end
        end
        return "glsl"
    end
    return nil
end

-- =========================================================================
-- Redraw coalescing: many property observers firing in the same tick
-- (e.g. on file load) trigger a single redraw instead of one each.
-- =========================================================================
function M.coalesce(fn)
    local pending = false
    return function()
        if pending then return end
        pending = true
        mp.add_timeout(0, function()
            pending = false
            fn()
        end)
    end
end

-- =========================================================================
-- Monitor controller: enable/disable state, inter-script user-data flags,
-- periodic refresh timer and coalesced redraw requests.
--   o.overlay      osd overlay owned by the script
--   o.draw         function that renders the HUD
--   o.interval     refresh period in seconds
--   o.user_data    list of user-data properties mirroring the enabled state
--   o.before_draw  (optional) called when enabling, before the first draw
--   o.after_draw   (optional) called when enabling, after the first draw
--   o.tick         (optional) timer callback (default: redraw while enabled)
-- Returns { enabled, set(state), toggle(), switch(val), request_redraw() }
-- =========================================================================
function M.monitor(o)
    local hud = { enabled = false }
    local timer = nil

    local function default_tick()
        if hud.enabled then o.draw() end
    end

    function hud.set(state)
        hud.enabled = state
        for _, key in ipairs(o.user_data) do
            mp.set_property_native(key, state)
        end
        if state then
            if o.before_draw then o.before_draw() end
            o.draw()
            if o.after_draw then o.after_draw() end
            if not timer then
                timer = mp.add_periodic_timer(o.interval, o.tick or default_tick)
            end
        else
            if timer then
                timer:kill()
                timer = nil
            end
            o.overlay:remove()
        end
    end

    function hud.toggle()
        hud.set(not hud.enabled)
    end

    -- Handler for "set-*" script-messages: yes/no/on/off/1/0, anything else toggles
    function hud.switch(val)
        local state = M.parse_switch(val)
        if state == nil then
            hud.toggle()
        else
            hud.set(state)
        end
    end

    -- Property observers call this: redraws once per tick, never while hidden
    hud.request_redraw = M.coalesce(function()
        if hud.enabled then o.draw() end
    end)

    return hud
end

return M
