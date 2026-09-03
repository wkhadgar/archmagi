-- Direct dofile() instead of require() because Hyprland does not seed
-- package.path with ~/.config/hypr/. HOME expands at load time.
local base = os.getenv("HOME") .. "/.config/hypr/hyprland/"

dofile(base .. "monit.lua")
dofile(base .. "start.lua")
dofile(base .. "envir.lua")
dofile(base .. "looks.lua")
dofile(base .. "input.lua")
dofile(base .. "binds.lua")
dofile(base .. "winwo.lua")
