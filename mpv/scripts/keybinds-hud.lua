-- =========================================================================
-- MPV-RTX Dynamic Keybindings HUD (keybinds-hud.lua)
-- Real-Time Dynamic input.conf & input-bindings Parser
-- Zero-Maintenance: Auto-updates on input.conf edits with clean layout math
-- =========================================================================

local mp = require("mp")

-- Shared modules: <config>/script-modules/
package.path = ((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)[/\\][^/\\]*$") or ".") .. "/../script-modules/?.lua;"
    .. (mp.command_native({ "expand-path", "~~/script-modules/?.lua" }) or "") .. ";" .. package.path
local theme = require("dark-glass")
local glass = require("glass-card")

local is_visible = false
local cfg = theme.derive({})
local overlay = mp.create_osd_overlay("ass-events")

local col1_sections = {}
local col2_sections = {}

-- =========================================================================
-- Helper: Format Key Labels Cleanly
-- =========================================================================

local function format_key(k)
    local parts = {}
    for part in k:gmatch("[^+]+") do
        local p = part
        if p == "MBTN_RIGHT"   then p = "R-Click"
        elseif p == "MBTN_LEFT"then p = "L-Click"
        elseif p == "MBTN_MID" then p = "Mid-Click"
        elseif p == "SPACE"    then p = "Space"
        elseif p == "BS"       then p = "BS"
        elseif p == "WHEEL_UP" then p = "Wheel-Up"
        elseif p == "WHEEL_DOWN" then p = "Wheel-Dn"
        elseif p == "PGUP"     then p = "PgUp"
        elseif p == "PGDWN"    then p = "PgDn"
        elseif p == "LEFT"     then p = "Left"
        elseif p == "RIGHT"    then p = "Right"
        elseif p == "UP"       then p = "Up"
        elseif p == "DOWN"     then p = "Down"
        end
        table.insert(parts, p)
    end
    return "[" .. table.concat(parts, "+") .. "]"
end

-- =========================================================================
-- Dynamic input.conf Resolution & Parser
-- =========================================================================

local function get_input_conf_path()
    local p = mp.find_config_file("input.conf")
    if p and p ~= "" then return p end

    p = mp.command_native({ "expand-path", "~~/input.conf" })
    if p and p ~= "" then
        local f = io.open(p, "r")
        if f then f:close(); return p end
    end

    local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
    if home ~= "" then
        local win_p = home .. "\\AppData\\Roaming\\mpv\\input.conf"
        local f = io.open(win_p, "r")
        if f then f:close(); return win_p end
    end

    return nil
end

local function parse_keybindings()
    local path = get_input_conf_path()
    local lines = {}

    if path then
        local f = io.open(path, "r")
        if f then
            for line in f:lines() do
                table.insert(lines, line)
            end
            f:close()
        end
    end

    if #lines == 0 then
        local raw = mp.get_property_native("input-bindings") or {}
        for _, b in ipairs(raw) do
            if b.key and b.cmd and b.cmd ~= "ignore" then
                table.insert(lines, b.key .. " " .. b.cmd)
            end
        end
    end

    local categories = {
        scalers   = { title = "SCALERS & NEURAL AI",  items = {}, map = {} },
        grain     = { title = "FILM GRAIN SUITE",     items = {}, map = {} },
        audio     = { title = "AUDIO DSP & CHANNELS", items = {}, map = {} },
        telemetry = { title = "TELEMETRY & MONITORS", items = {}, map = {} },
        geometry  = { title = "VIEWPORT & GEOMETRY",  items = {}, map = {} },
        playback  = { title = "PLAYBACK & TOOLS",     items = {}, map = {} },
        custom    = { title = "CUSTOM SHORTCUTS",     items = {}, map = {} }
    }

    local function add_item(cat_name, item_id, key_str, desc, col)
        local cat = categories[cat_name]
        if not cat.map[item_id] then
            local entry = { key_str = key_str, desc = desc, col = col }
            cat.map[item_id] = entry
            table.insert(cat.items, entry)
        else
            -- If already present and key is different, append only if short
            local existing = cat.map[item_id]
            if not existing.key_str:find(key_str, 1, true) and #existing.key_str < 16 then
                existing.key_str = existing.key_str .. " / " .. key_str
            end
        end
    end

    for _, raw_line in ipairs(lines) do
        local line = raw_line:match("^%s*(.-)%s*$")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local key, rest = line:match("^(%S+)%s+(.+)$")
            if key and rest then
                local cmd, comment = rest:match("^(.-)%s*#%s*(.+)$")
                cmd = (cmd or rest):match("^%s*(.-)%s*$")

                if cmd ~= "ignore" then
                    local matched = false

                    -- =========================================================
                    -- 1. SCALERS & NEURAL AI (Individual non-merging entries)
                    -- =========================================================
                    if cmd:find("autovsr%-toggle") then
                        add_item("scalers", "vsr", format_key(key), comment or "RTX Video Super Resolution (VSR)", cfg.color_cyan)
                        matched = true
                    elseif cmd:find("autovsr%-update") then
                        add_item("scalers", "vsr_up", format_key(key), comment or "Force VSR Rescale", cfg.color_white)
                        matched = true
                    elseif cmd:find("custom%-notify%-scaler") then
                        local scaler_name = cmd:match("custom%-notify%-scaler%s+\"([^\"]+)\"") or "Shader"
                        add_item("scalers", "scaler_" .. scaler_name, format_key(key), comment or (scaler_name .. " Scaler"), cfg.color_cyan)
                        matched = true
                    elseif cmd:find("autohdr%-toggle") then
                        add_item("scalers", "hdr", format_key(key), comment or "RTX Video True HDR", cfg.color_green)
                        matched = true
                    elseif cmd:find("cycle%-values%s+scale") then
                        add_item("scalers", "scale_base", format_key(key), comment or "Cycle Scaler (Lanczos/Nearest)", cfg.color_yellow)
                        matched = true
                    elseif cmd:find("MASTER RESET") or cmd:find("set scale \"lanczos\"") then
                        add_item("scalers", "reset", format_key(key), comment or "Master Reset (Reference State)", cfg.color_yellow)
                        matched = true

                    -- =========================================================
                    -- 2. FILM GRAIN SUITE
                    -- =========================================================
                    elseif cmd:find("toggle%-film%-grain%-hud") then
                        add_item("grain", "grain_hud", format_key(key), comment or "Film Grain Diagnostics HUD", cfg.color_yellow)
                        matched = true
                    elseif cmd:find("toggle%-film%-grain") then
                        add_item("grain", "grain_tgl", format_key(key), comment or "Toggle AV1 Native FGS", cfg.color_green)
                        matched = true
                    elseif cmd:find("cycle%-synthetic%-grain") then
                        add_item("grain", "grain_cyc", format_key(key), comment or "Cycle Synthetic Presets", cfg.color_cyan)
                        matched = true

                    -- =========================================================
                    -- 3. AUDIO DSP & CHANNELS (Compact solo grouping)
                    -- =========================================================
                    elseif cmd:find("cycle%-audio%-dsp") then
                        add_item("audio", "dsp", format_key(key), comment or "Cycle Headphone DSP Presets", cfg.color_cyan)
                        matched = true
                    elseif cmd:find("cycle%-bass%-boost") then
                        add_item("audio", "bass", format_key(key), comment or "Bass Boost", cfg.color_yellow)
                        matched = true
                    elseif cmd:find("cycle%-channel%-solo") then
                        add_item("audio", "solo_cyc", format_key(key), comment or "Cycle Channel Solo Modes", cfg.color_yellow)
                        matched = true
                    elseif cmd:find("set%-channel%-solo%s+all") then
                        add_item("audio", "solo_all", format_key(key), comment or "Reset Solo (All Channels)", cfg.color_green)
                        matched = true
                    elseif cmd:find("set%-channel%-solo") then
                        add_item("audio", "solo_grp", "[Ctrl+1..5]", comment or "Solo (Front/C/Surr/Rear/LFE)", cfg.color_white)
                        matched = true
                    elseif cmd:find("custom%-notify%-volume") then
                        add_item("audio", "vol", "[Up] / [Down]", comment or "Volume Up / Down", cfg.color_white)
                        matched = true
                    elseif cmd:find("cycle%s+mute") then
                        add_item("audio", "mute", format_key(key), comment or "Mute / Unmute Audio", cfg.color_red)
                        matched = true
                    elseif cmd:find("cycle%s+audio") then
                        add_item("audio", "aud_track", format_key(key), comment or "Cycle Audio Track", cfg.color_cyan)
                        matched = true

                    -- =========================================================
                    -- 4. TELEMETRY & MONITORS
                    -- =========================================================
                    elseif cmd:find("toggle%-both%-monitors") then
                        add_item("telemetry", "sync_hud", format_key(key), comment or "Video + GPU HUD", cfg.color_green)
                        matched = true
                    elseif cmd:find("toggle%-media%-monitor") then
                        add_item("telemetry", "vid_mon", format_key(key), comment or "Video Diagnostics Monitor", cfg.color_cyan)
                        matched = true
                    elseif cmd:find("toggle%-gpu%-monitor") then
                        add_item("telemetry", "gpu_mon", format_key(key), comment or "NVIDIA Hardware Monitor", cfg.color_cyan)
                        matched = true
                    elseif cmd:find("toggle%-audio%-hud") then
                        add_item("telemetry", "aud_mon", format_key(key), comment or "Studio Audio Monitor", cfg.color_cyan)
                        matched = true
                    elseif cmd:find("video%-sync") then
                        add_item("telemetry", "pacing", format_key(key), comment or "Toggle Frame Pacing (Sync)", cfg.color_yellow)
                        matched = true

                    -- =========================================================
                    -- 5. VIEWPORT & GEOMETRY (Compact compound grouping)
                    -- =========================================================
                    elseif cmd:find("custom%-notify%-zoom") then
                        add_item("geometry", "zoom", "[Wheel] / [Ctrl + / -]", comment or "Smooth Zoom In / Out", cfg.color_cyan)
                        matched = true
                    elseif cmd:find("custom%-notify%-reset%-geo") then
                        add_item("geometry", "geo_rst", "[Mid-Click] / [BS]", comment or "Reset Geometry (100% Center)", cfg.color_yellow)
                        matched = true
                    elseif cmd:find("video%-pan") then
                        add_item("geometry", "pan", "[Alt + Arrows]", comment or "Pan Viewport (X / Y)", cfg.color_white)
                        matched = true
                    elseif cmd:find("video%-rotate") then
                        add_item("geometry", "rot", format_key(key), comment or "Rotate Video (90° / 270°)", cfg.color_white)
                        matched = true
                    elseif cmd:find("video%-hflip") then
                        add_item("geometry", "hflip", format_key(key), comment or "Horizontal Mirror (Flip)", cfg.color_white)
                        matched = true

                    -- =========================================================
                    -- 6. PLAYBACK & TOOLS (Clean merged navigation)
                    -- =========================================================
                    elseif cmd:find("cycle%s+pause") then
                        add_item("playback", "pause", format_key(key), comment or "Play / Pause", cfg.color_green)
                        matched = true
                    elseif cmd:find("seek%s+%-?5") then
                        add_item("playback", "seek5", "[Left] / [Right]", comment or "Seek ±5s (Exact)", cfg.color_white)
                        matched = true
                    elseif cmd:find("seek%s+%-?1") then
                        add_item("playback", "seek1", "[Shift + Left/Right]", comment or "Seek ±1s (Exact)", cfg.color_white)
                        matched = true
                    elseif cmd:find("frame%-back%-step") or cmd:find("frame%-step") then
                        add_item("playback", "fstep", "[.] / [,]", comment or "Frame Step (Forward / Back)", cfg.color_white)
                        matched = true
                    elseif cmd:find("playlist%-prev") or cmd:find("playlist%-next") then
                        add_item("playback", "plist", "[PgUp/Dn] / [Ctrl+Arrows]", comment or "Previous / Next File", cfg.color_white)
                        matched = true
                    elseif cmd:find("display%-clip%-maker") then
                        add_item("playback", "clip", format_key(key), comment or "Hardware Clip Maker (NVENC)", cfg.color_green)
                        matched = true
                    elseif cmd:find("screenshot%s+video") then
                        add_item("playback", "scr_vid", format_key(key), comment or "Clean Screenshot (No Subs)", cfg.color_white)
                        matched = true
                    elseif cmd:find("screenshot") then
                        add_item("playback", "scr_norm", format_key(key), comment or "Screenshot (To Desktop)", cfg.color_white)
                        matched = true
                    elseif cmd:find("cycle%s+sub%-visibility") then
                        add_item("playback", "sub_vis", format_key(key), comment or "Toggle Subtitles On / Off", cfg.color_cyan)
                        matched = true
                    elseif cmd:find("cycle%s+sub") then
                        add_item("playback", "sub_trk", format_key(key), comment or "Cycle Subtitle Track", cfg.color_cyan)
                        matched = true
                    elseif cmd:find("loop%-file") or cmd:find("cycle%s+deband") then
                        add_item("playback", "loop_deb", format_key(key), comment or (cmd:find("deband") and "Toggle Deband Filter" or "Toggle File Loop Mode"), cfg.color_white)
                        matched = true
                    elseif cmd:find("cycle%s+fullscreen") then
                        add_item("playback", "fs", format_key(key), comment or "Toggle Fullscreen", cfg.color_cyan)
                        matched = true
                    elseif cmd:find("^quit$") then
                        add_item("playback", "quit", format_key(key), comment or "Quit Player", cfg.color_red)
                        matched = true
                    end

                    -- Custom / Unrecognized key fallback
                    if not matched then
                        local custom_desc = comment or cmd:match("^%S+") or cmd
                        add_item("custom", "c_" .. key, format_key(key), custom_desc, cfg.color_white)
                    end
                end
            end
        end
    end

    -- =========================================================================
    -- Perfectly Balanced Two-Column Distribution
    -- Column 1: Scalers (9) + Grain (3) + Audio (8)       = ~20 items
    -- Column 2: Telemetry (5) + Geometry (5) + Playback (11) = ~21 items
    -- =========================================================================
    col1_sections = {}
    col2_sections = {}

    local function push_sec(dest_col, cat_id)
        local cat = categories[cat_id]
        if cat and #cat.items > 0 then
            local clean = {}
            for _, it in ipairs(cat.items) do
                table.insert(clean, { it.key_str, it.desc, it.col })
            end
            table.insert(dest_col, {
                title = cat.title,
                title_color = cfg.color_green,
                items = clean
            })
        end
    end

    -- Left Column
    push_sec(col1_sections, "scalers")
    push_sec(col1_sections, "grain")
    push_sec(col1_sections, "audio")

    -- Right Column
    push_sec(col2_sections, "telemetry")
    push_sec(col2_sections, "geometry")
    push_sec(col2_sections, "playback")
    push_sec(col2_sections, "custom")
end

-- =========================================================================
-- Render Column Engine
-- =========================================================================

local function get_column_height(g, sections)
    local total_rows = 0
    for _, sec in ipairs(sections) do
        total_rows = total_rows + #sec.items
    end
    if #sections == 0 then return 0 end
    return (#sections * g.section_step) + (math.max(0, #sections - 1) * g.section_gap) + (total_rows * g.row_step)
end

local function draw_column(ass, cfg_theme, g, col_x1, col_x2, start_y, sections)
    local cur_y = start_y
    for s_idx, sec in ipairs(sections) do
        glass.section_header(ass, cfg_theme, g, col_x1, cur_y, sec.title, sec.title_color or cfg_theme.color_green)
        cur_y = cur_y + g.section_step

        for _, item in ipairs(sec.items) do
            local key_lbl, desc_lbl, key_col = item[1], item[2], item[3] or cfg_theme.color_white

            ass:new_event()
            ass:append(string.format("{\\an7\\pos(%d,%d)\\fn%s\\b1\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}%s",
                col_x1 + g.indent_x, cur_y, cfg_theme.font_face, g.row_size, key_col, key_lbl))

            ass:new_event()
            ass:append(string.format("{\\an9\\pos(%d,%d)\\fn%s\\b0\\fs%d\\c&H%s&\\bord1\\3c&H000000&\\shad1}%s",
                col_x2, cur_y, cfg_theme.font_face, g.row_size, cfg_theme.color_white, desc_lbl))

            cur_y = cur_y + g.row_step
        end

        if s_idx < #sections then
            cur_y = cur_y + g.section_gap
        end
    end
end

-- =========================================================================
-- Render HUD
-- =========================================================================

local function draw_hud()
    if not is_visible then
        overlay:remove()
        return
    end

    local d, scale = glass.begin_frame(overlay, cfg)
    if not d then return end

    local g = glass.metrics(scale, { header_gap = 12, bottom_pad = 22, pad_x = 22 })
    local h1 = get_column_height(g, col1_sections)
    local h2 = get_column_height(g, col2_sections)
    local max_block_h = math.max(h1, h2)

    glass.draw(overlay, cfg, {
        d = d, scale = scale,
        title = "KEYBINDINGS CHEATSHEET",
        subtitle = "NVIDIA Dark Glass Suite • Press [F1], [?], or [ESC] to Close",
        sections = {},
        width = 860,
        anchor = "top-center",
        header_gap = 12, bottom_pad = 22, pad_x = 22,
        block = {
            height = function() return max_block_h end,
            draw = function(ass, _, x1, x2, cur_y)
                local avail_w = (x2 - g.pad_x) - (x1 + g.pad_x)
                local col_gap = math.floor(30 * scale)
                local col_w = math.floor((avail_w - col_gap) / 2)

                local c1_x1 = x1 + g.pad_x
                local c1_x2 = c1_x1 + col_w
                local c2_x1 = c1_x2 + col_gap
                local c2_x2 = c2_x1 + col_w

                draw_column(ass, cfg, g, c1_x1, c1_x2, cur_y, col1_sections)
                draw_column(ass, cfg, g, c2_x1, c2_x2, cur_y, col2_sections)
            end
        }
    })
end

-- =========================================================================
-- Toggle & Key Interception Lifecycle
-- =========================================================================

local function hide_hud()
    if not is_visible then return end
    is_visible = false
    mp.remove_key_binding("keybinds_esc_close")
    mp.set_property_native("user-data/keybinds-active", false)
    overlay:remove()
end

local function show_hud()
    if is_visible then return end
    is_visible = true
    mp.set_property_native("user-data/keybinds-active", true)

    mp.add_forced_key_binding("ESC", "keybinds_esc_close", hide_hud)

    parse_keybindings()
    draw_hud()
end

local function toggle_hud()
    if is_visible then
        hide_hud()
    else
        show_hud()
    end
end

-- Script Messages and Direct Bindings
mp.register_script_message("toggle-keybinds-hud", toggle_hud)
mp.register_script_message("show-keybinds-hud", show_hud)
mp.register_script_message("hide-keybinds-hud", hide_hud)

mp.add_forced_key_binding("F1", "toggle-keybinds-f1", toggle_hud)
mp.add_forced_key_binding("?", "toggle-keybinds-question", toggle_hud)

mp.observe_property("osd-dimensions", "native", function()
    if is_visible then draw_hud() end
end)