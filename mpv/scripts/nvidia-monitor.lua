-- =========================================================================
-- MPV NVIDIA Hardware Monitor & RivaTuner-Style Categorized Suite
-- Telemetry: GPU, MEMORY & DISPLAY (with Native HDR & RTX True HDR Detection)
-- =========================================================================

local mp = require("mp")
local utils = require("mp.utils")
-- Shared modules: <config>/script-modules/ (resolved from this script's folder, works in portable_config)
package.path = ((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)[/\\][^/\\]*$") or ".") .. "/../script-modules/?.lua;"
    .. (mp.command_native({ "expand-path", "~~/script-modules/?.lua" }) or "") .. ";" .. package.path
local theme = require("dark-glass")
local glass = require("glass-card")
local util = require("suite-util")

local hud -- monitor controller (created below)
local is_fetching = false
local vrr_os_enabled = false

-- Visual Configuration & Styling (ASS Colors in &HBBGGRR& format)
local cfg = theme.derive({
    poll_interval   = 1.0,         -- Telemetry update rate in seconds
})

-- Telemetry State
local stats = {
    gpu_name   = "Detecting...",
    temp       = "N/A",
    fan        = "N/A",
    pwr_draw   = "N/A",
    pwr_lim    = "N/A",
    load       = "N/A",
    nvdec_load = "0",
    vram_use   = "N/A",
    vram_tot   = "N/A",
    clk_core   = "N/A",
    clk_mem    = "N/A"
}

-- Locate nvidia-smi executable safely using zero-overhead file inspection
local function get_smi_path()
    local default_paths = {
        "C:\\Windows\\System32\\nvidia-smi.exe",
        "C:\\Program Files\\NVIDIA Corporation\\NVSMI\\nvidia-smi.exe"
    }
    for _, path in ipairs(default_paths) do
        local info = utils.file_info(path)
        if info and info.is_file then
            return path
        end
    end
    return "nvidia-smi"
end

local smi_binary = get_smi_path()
local overlay = mp.create_osd_overlay("ass-events")

-- Check Windows OS-level Variable Refresh Rate registry toggle asynchronously
local function check_windows_vrr()
    mp.command_native_async({
        name = "subprocess",
        args = { "reg", "query", "HKCU\\Software\\Microsoft\\DirectX\\UserGpuPreferences", "/v", "DirectXUserGlobalSettings" },
        playback_only = false,
        capture_stdout = true,
        capture_stderr = false
    }, function(success, res)
        if success and res and res.stdout then
            vrr_os_enabled = res.stdout:find("VRROptimizeEnable=1") ~= nil
        end
    end)
end

-- Resolve active dynamic range state (SDR, Native HDR or NVIDIA RTX True HDR)
local DYNAMIC_RANGE = {
    truehdr = { "RTX True HDR (Tensor AI)", "color_green" },
    pq      = { "Native HDR10 (PQ)",        "color_cyan" },
    hlg     = { "Native HDR (HLG)",         "color_cyan" },
    bt2020  = { "Native HDR (BT.2020)",     "color_cyan" },
    sdr     = { "SDR (Standard)",           "color_gray" },
}

local function get_dynamic_range_status()
    local has_video = mp.get_property_native("current-tracks/video")
    if not has_video then
        return "N/A", cfg.color_gray
    end

    local entry = DYNAMIC_RANGE[util.dynamic_range_kind(1.0)]
    return entry[1], cfg[entry[2]]
end

-- Resolve active upscaler engine
local UPSCALERS = {
    vsr  = { "RTX VSR (Tensor AI)", "color_green" },
    nis  = { "NVIDIA NIS",          "color_cyan" },
    fsr  = { "AMD FSR 1.0",         "color_cyan" },
    sgsr = { "Qualcomm SGSR",       "color_cyan" },
    cas  = { "AMD CAS",             "color_cyan" },
    glsl = { "Custom GLSL",         "color_cyan" },
}

local function get_active_upscaler()
    local entry = UPSCALERS[util.upscaler_kind() or ""]
    if entry then return entry[1], cfg[entry[2]] end

    -- Dynamically reflect the active base luma scaler (e.g., Spline36 for images, Lanczos for video)
    local base_scale = mp.get_property("scale") or "lanczos"
    base_scale = base_scale:sub(1,1):upper() .. base_scale:sub(2):lower()
    return string.format("Native (%s)", base_scale), cfg.color_gray
end

-- Extract real-time MPV engine metrics (Native Video FPS, Display Hz, Latency & Drops)
local function get_mpv_perf_stats()
    local is_paused = mp.get_property_bool("pause", false)

    -- 1. Native Video Framerate (Container / Stream FPS)
    local v_fps = mp.get_property_number("container-fps", 0)
    if v_fps <= 0 then
        v_fps = mp.get_property_number("estimated-vf-fps", 0)
    end

    -- 2. Physical Display Refresh Rate
    local d_fps = mp.get_property_number("display-fps", 0)
    if d_fps <= 0 then
        d_fps = mp.get_property_number("estimated-display-fps", 0)
    end

    -- 3. GPU Render Latency via vo-passes (nanoseconds -> milliseconds)
    local render_ms = 0
    local vo_p = mp.get_property_native("vo-passes")
    if vo_p and vo_p["fresh"] then
        local total_ns = 0
        for _, pass in ipairs(vo_p["fresh"]) do
            total_ns = total_ns + (pass["last"] or pass["avg"] or 0)
        end
        if total_ns > 0 then
            render_ms = total_ns / 1000000
        end
    end

    -- 4. Target Frametime interval (1000 / Display Hz)
    local frametime_ms = (d_fps > 0) and (1000 / d_fps) or 0

    -- 5. Dropped and Mistimed frames
    local drops = mp.get_property_number("drop-frame-count", 0)
    local mistimed = mp.get_property_number("mistimed-frame-count", 0)

    -- 6. G-Sync / VRR status detection
    local vsync_mode = mp.get_property("video-sync") or "audio"
    local interpolation = mp.get_property_bool("interpolation", false)
    local vrr_text = "OFF"
    local vrr_color = cfg.color_gray

    if vrr_os_enabled then
        if vsync_mode == "audio" and not interpolation then
            vrr_text = "ACTIVE (VRR Mode)"
            vrr_color = cfg.color_green
        else
            vrr_text = "STANDBY (VSync Lock)"
            vrr_color = cfg.color_yellow
        end
    else
        vrr_text = "DISABLED (Windows)"
        vrr_color = cfg.color_gray
    end

    local video_fps_str = "N/A"
    if v_fps > 0 then
        if is_paused then
            video_fps_str = string.format("%.3f FPS (Paused)", v_fps)
        else
            video_fps_str = string.format("%.3f FPS", v_fps)
        end
    end

    local display_hz_str = "N/A"
    if d_fps > 0 then
        display_hz_str = string.format("%.2f Hz (%.1f ms)", d_fps, frametime_ms)
    end

    local lat_str = (render_ms > 0) and string.format("%.2f ms", render_ms) or "0.00 ms"
    local drops_str = string.format("%d (Mistimed: %d)", drops, mistimed)
    local drops_color = (drops == 0 and mistimed == 0) and cfg.color_green or cfg.color_yellow
    if drops > 5 then drops_color = cfg.color_red end

    return video_fps_str, display_hz_str, lat_str, vrr_text, vrr_color, drops_str, drops_color
end

-- Parse raw CSV output from nvidia-smi (includes GPU Name, Clocks & Video Decoder load)
local function parse_smi_csv(csv_line)
    if not csv_line or csv_line == "" then return end
    -- Isolate only the first line in case of multiple GPUs or trailing newlines
    local first_line = csv_line:match("[^\r\n]+") or ""
    local fields = {}
    for val in first_line:gmatch("([^,]+)") do
        table.insert(fields, val:match("^%s*(.-)%s*$"))
    end

    if #fields >= 11 then
        stats.gpu_name   = fields[1]
        stats.temp       = fields[2]
        stats.fan        = fields[3]
        stats.pwr_draw   = fields[4]
        stats.pwr_lim    = fields[5]
        stats.load       = fields[6]

        local nvdec_raw  = fields[7]
        local nvdec_clean = nvdec_raw:match("(%d+)")
        stats.nvdec_load = nvdec_clean or "0"

        stats.clk_core   = fields[10]
        stats.clk_mem    = fields[11]

        local mem_u = tonumber(fields[8])
        local mem_t = tonumber(fields[9])
        stats.vram_use = mem_u and string.format("%.2f", mem_u / 1024) or "N/A"
        stats.vram_tot = mem_t and string.format("%.0f", mem_t / 1024) or "N/A"
    end
end

-- Render ASS HUD Overlay with Dynamic Range and Unified Vector Diamond Headers
local function draw_hud()
    if not hud.enabled then
        overlay:remove()
        return
    end

    local d, scale = glass.begin_frame(overlay, cfg)
    if not d then return end

    -- Temperature dynamic coloring
    local temp_num = tonumber(stats.temp) or 0
    local temp_color = cfg.color_green
    if temp_num >= 82 then
        temp_color = cfg.color_red
    elseif temp_num >= 72 then
        temp_color = cfg.color_yellow
    end

    -- Fan string formatting
    local fan_str = stats.fan ~= "N/A" and (stats.fan .. " %") or "N/A"
    if stats.fan == "0" then
        fan_str = "0 % (Fan Stop)"
    end

    -- Retrieve real-time MPV engine metrics
    local v_fps_val, d_hz_val, lat_val, vrr_val, vrr_col, drops_val, drops_col = get_mpv_perf_stats()
    local upscaler_name, upscaler_col = get_active_upscaler()
    local hdr_name, hdr_col = get_dynamic_range_status()

    -- =========================================================================
    -- Sectioned Telemetry Data Structure
    -- =========================================================================
    local sections = {
        {
            title = "GPU",
            title_color = cfg.color_green,
            items = {
                { "Core Clock", stats.clk_core .. " MHz", cfg.color_cyan },
                { "GPU Load", stats.load .. " % (NVDEC: " .. stats.nvdec_load .. " %)", cfg.color_white },
                { "Temperature", stats.temp .. " °C", temp_color },
                { "Power Draw", stats.pwr_draw .. " W / " .. stats.pwr_lim .. " W", cfg.color_yellow },
                { "Fan Speed", fan_str, cfg.color_white }
            }
        },
        {
            title = "MEMORY",
            title_color = cfg.color_green,
            items = {
                { "VRAM Clock", stats.clk_mem .. " MHz", cfg.color_cyan },
                { "VRAM Usage", stats.vram_use .. " GB / " .. stats.vram_tot .. " GB", cfg.color_white }
            }
        },
        {
            title = "DISPLAY",
            title_color = cfg.color_green,
            items = {
                { "Video FPS", v_fps_val, cfg.color_cyan },
                { "Display Rate", d_hz_val, cfg.color_white },
                { "Dynamic Range", hdr_name, hdr_col },
                { "Upscaler", upscaler_name, upscaler_col },
                { "G-Sync / VRR", vrr_val, vrr_col },
                { "Render Time", lat_val, cfg.color_yellow },
                { "Dropped Frames", drops_val, drops_col }
            }
        }
    }

    glass.draw(overlay, cfg, {
        d = d, scale = scale,
        title = "NVIDIA HARDWARE MONITOR",
        subtitle = stats.gpu_name,
        sections = sections,
        anchor = "top-right",
    })
end

-- Asynchronous polling routine (Non-blocking)
local function poll_nvidia_smi()
    if not hud.enabled or is_fetching then return end
    is_fetching = true

    mp.command_native_async({
        name = "subprocess",
        args = {
            smi_binary,
            "--query-gpu=name,temperature.gpu,fan.speed,power.draw,power.limit,utilization.gpu,utilization.decoder,memory.used,memory.total,clocks.gr,clocks.mem",
            "--format=csv,noheader,nounits"
        },
        playback_only = false,
        capture_stdout = true,
        capture_stderr = false
    }, function(success, res, err)
        is_fetching = false
        if success and res and res.status == 0 and res.stdout then
            parse_smi_csv(res.stdout)
            draw_hud()
        end
    end)
end

-- Enable/disable state, user-data flag, refresh timer and coalesced redraws
hud = util.monitor({
    overlay     = overlay,
    draw        = draw_hud,
    interval    = cfg.poll_interval,
    user_data   = { "user-data/gpu-monitor-active" },
    before_draw = check_windows_vrr,
    after_draw  = poll_nvidia_smi,
    tick        = poll_nvidia_smi,
})
local toggle_overlay = hud.toggle

-- Keybindings and script messages
mp.add_forced_key_binding("g", "toggle-gpu-monitor-forced", toggle_overlay)
mp.register_script_message("toggle-gpu-monitor", toggle_overlay)

mp.register_script_message("set-gpu-monitor", hud.switch)

mp.observe_property("osd-dimensions", "native", hud.request_redraw)
mp.observe_property("pause", "bool", hud.request_redraw)
mp.observe_property("vf", "native", hud.request_redraw)
mp.observe_property("glsl-shaders", "native", hud.request_redraw)
mp.observe_property("scale", "string", hud.request_redraw)