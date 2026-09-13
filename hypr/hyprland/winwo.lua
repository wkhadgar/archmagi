-- WINDOWS AND WORKSPACES
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

hl.window_rule({
    name  = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- archmagi hud — floating live fetch panel (Super+F)
hl.window_rule({
    name  = "archmagi-hud",
    match = { class = "^(archmagi-hud)$" },
    float    = true,
    size     = "1150 540",
    center   = true,
    pin      = true,
    no_focus = true,
})

hl.layer_rule({ match = { namespace = "^waybar$" },                    blur = true })
hl.layer_rule({ match = { namespace = "^swaync-control-center$" },     blur = true })
hl.layer_rule({ match = { namespace = "^swaync-notification-window$" }, blur = false })
hl.layer_rule({ match = { namespace = "^rofi$" },                      dim_around = true })
