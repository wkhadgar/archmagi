-- KEYBINDINGS
-- Variables local to this file — expand via string concat in binds.
-- A `desc = ...` field on the bind options table is what `archmagi cheatsheet`
-- reads for the human-facing description; without it, the parser falls back
-- to the raw dispatcher call.

local terminal    = "kitty"
local fileManager = "kitty -e yazi"
local mainMod     = "SUPER"

hl.bind("ALT + C",                     hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + M",     hl.dsp.exit())
hl.bind(mainMod .. " + B",             hl.dsp.exec_cmd("~/.local/bin/archmagi restart waybar"))
hl.bind(mainMod .. " + T",             hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E",             hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SHIFT + E",
    hl.dsp.exec_cmd("kitty -e bash -c 'd=$(ls -td /run/media/$USER/*/ 2>/dev/null | head -1); cd \"${d:-$HOME}\" && yazi'"),
    { desc = "yazi at most-recent USB mount (falls back to $HOME)" })
hl.bind(mainMod .. " + SUPER_L",       hl.dsp.exec_cmd("pkill rofi || rofi -show-icons -show drun"))
hl.bind(mainMod .. " + L",             hl.dsp.exec_cmd("~/.local/bin/archmagi lock"))
hl.bind(mainMod .. " + V",             hl.dsp.exec_cmd("cliphist list | rofi -dmenu -sync | cliphist decode | wl-copy"))
hl.bind(mainMod .. " + N",             hl.dsp.exec_cmd("swaync-client -t"))
hl.bind(mainMod .. " + SHIFT + slash", hl.dsp.exec_cmd("~/.local/bin/archmagi cheatsheet"))
hl.bind(mainMod .. " + F",
    hl.dsp.exec_cmd("~/.local/bin/archmagi hud"),
    { desc = "archmagi hud — live fetch panel" })

-- Screenshot binds
hl.bind("PRINT",                       hl.dsp.exec_cmd("hyprshot -z -m output -o ~/images/screenshots"))
hl.bind(mainMod .. " + PRINT",         hl.dsp.exec_cmd("hyprshot -z -m window -o ~/images/screenshots"))
hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -z -m region -o ~/images/screenshots"))

hl.bind(mainMod .. " + P",             hl.dsp.window.pseudo())   -- dwindle

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",          hl.dsp.focus({ direction = "left"  }))
hl.bind(mainMod .. " + right",         hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",            hl.dsp.focus({ direction = "up"    }))
hl.bind(mainMod .. " + down",          hl.dsp.focus({ direction = "down"  }))

-- Switch workspaces with mainMod + [0-9]; SHIFT to move active window.
for i = 1, 10 do
    local key = i % 10   -- 10 maps to key "0"
    hl.bind(mainMod .. " + "       .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S",             hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S",     hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + CTRL + right",  hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + CTRL + left",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Player controls (requires playerctl)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
