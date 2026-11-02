-- =========================================================================
-- NVIDIA Dark Glass Theme (dark-glass.lua)
-- Single source of truth for the suite palette, typography and glass opacity.
-- Loaded by every HUD script via: local theme = require("dark-glass")
-- Location: ~~/script-modules/dark-glass.lua (not loaded as a script itself)
-- =========================================================================

local M = {
    ui_scale        = 1.35,        -- User size multiplier (1.0 = normal, 1.35 = 4K recommended, 1.6 = TV)
    font_face       = "Segoe UI",
    color_green     = "00E676",    -- NVIDIA Green (Headers, Titles & Active items)
    color_cyan      = "00E5FF",    -- RivaTuner Cyan (Values, Clocks & Badges)
    color_yellow    = "00C8FF",    -- Amber Warning / Toggles
    color_red       = "3B3BFF",    -- Critical Red / Mute / Abort
    color_white     = "FFFFFF",
    color_gray      = "9E9E9E",    -- Inactive labels & descriptions
    color_dark_box  = "1C1C1C",    -- Tracks, selections & inactive slots
    bg_alpha        = "35",        -- Glass box transparency (Hex: 00-FF, 35 = ~80% dark)
}

-- Returns a private copy of the theme merged with script-specific fields.
-- Fields passed in `overrides` take precedence over the shared theme.
function M.derive(overrides)
    local cfg = {}
    for k, v in pairs(M) do
        if type(v) ~= "function" then cfg[k] = v end
    end
    for k, v in pairs(overrides or {}) do
        cfg[k] = v
    end
    return cfg
end

return M
