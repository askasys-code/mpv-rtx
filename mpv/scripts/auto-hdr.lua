-- =========================================================================
-- NVIDIA RTX Video True HDR Controller for MPV
-- Prevents double tone-mapping on native HDR and handles SDR-to-HDR cleanly
-- Universal Support: Moving Videos & High-Resolution Still Images
-- =========================================================================

-- Shared modules: <config>/script-modules/ (resolved from this script's folder, works in portable_config)
package.path = ((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)[/\\][^/\\]*$") or ".") .. "/../script-modules/?.lua;"
    .. (mp.command_native({ "expand-path", "~~/script-modules/?.lua" }) or "") .. ";" .. package.path
local util = require("suite-util")

local hdr_label = "@truehdr"
local fmt_label = "@truehdr_fmt"

local toast = util.toast

-- Inspect video filter pipeline to determine if True HDR is currently active
local function is_hdr_active()
    return util.vf_has(hdr_label)
end

-- Safely remove existing True HDR filter instance and format converter
local function remove_hdr_filter()
    util.vf_remove(hdr_label, fmt_label)
end

-- Check if pixel format is directly accepted by D3D11VPP True HDR
local function is_format_supported(pixfmt)
    return util.is_rtx_pixfmt(pixfmt)
end

-- Inspect video metadata to determine if content is already native HDR
local function is_native_hdr()
    local gamma = tostring(mp.get_property("video-params/gamma") or ""):lower()
    local colormatrix = tostring(mp.get_property("video-params/colormatrix") or ""):lower()
    local primaries = tostring(mp.get_property("video-params/primaries") or ""):lower()
    local sig_peak = mp.get_property_number("video-params/sig-peak", 1.0)

    -- Detect PQ (HDR10 / Dolby Vision), HLG, or Wide Color Gamut with high luminance
    if gamma:find("pq") or gamma:find("smpte2084") or gamma:find("hlg") or gamma:find("arib") then
        return true
    end

    if colormatrix:find("2020") or primaries:find("2020") or primaries:find("dci-p3") then
        if sig_peak > 1.05 or gamma:find("pq") or gamma:find("hlg") then
            return true
        end
    end

    if sig_peak > 1.05 then
        return true
    end

    return false
end

-- Main toggle and hardware filter dispatcher
local function toggle_hdr()
    -- Guard: Prevent running on pure audio tracks or album art
    local vtrack = mp.get_property_native("current-tracks/video")
    if not vtrack or vtrack.albumart then
        toast("NVIDIA TRUE HDR", "Not applicable for audio tracks", "yellow", 2)
        return
    end

    local video_w = mp.get_property_native("width")
    if not video_w or video_w <= 0 then
        toast("NVIDIA TRUE HDR", "No media stream loaded", "red", 2)
        return
    end

    -- 1. If True HDR is currently active, turn it OFF
    if is_hdr_active() then
        remove_hdr_filter()
        toast("NVIDIA TRUE HDR", "OFF (Native SDR)", "yellow", 2)
        return
    end

    -- 2. Abort if the media already contains native HDR mastering
    if is_native_hdr() then
        toast("NVIDIA TRUE HDR", "Skipped (Already Native HDR)", "cyan", 2.5)
        return
    end

    -- 3. Format adaptation for software-decoded RGB
    local pixfmt = mp.get_property_native("video-params/hw-pixelformat")
                or mp.get_property_native("video-params/pixelformat")

    if not is_format_supported(pixfmt) then
        mp.commandv("vf", "append", string.format("%s:format=nv12", fmt_label))
    end

    -- 4. Append filter using isolated instance label
    local filter_cmd = string.format("%s:d3d11vpp=nvidia-true-hdr", hdr_label)
    mp.commandv("vf", "append", filter_cmd)

    local target_type = vtrack.image and "Image" or "Video"
    toast("NVIDIA TRUE HDR", string.format("Active (%s SDR -> HDR)", target_type), "green", 2.2)
end

-- Automatically clean filter when loading a new file
local function on_file_loaded()
    remove_hdr_filter()
end

mp.register_event("file-loaded", on_file_loaded)

-- Script Message API Handlers
mp.register_script_message("autohdr-toggle", toggle_hdr)
mp.register_script_message("autohdr-enable", function()
    if not is_hdr_active() and not is_native_hdr() then
        toggle_hdr()
    end
end)
mp.register_script_message("autohdr-disable", remove_hdr_filter)