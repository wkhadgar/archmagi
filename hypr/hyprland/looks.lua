-- LOOK AND FEEL
-- See https://wiki.hypr.land/Configuring/Basics/Variables/

hl.config({
    general = {
        gaps_in     = 3,
        gaps_out    = 10,
        border_size = 1,

        col = {
            active_border   = { colors = { "rgba(cc0000ee)", "rgba(ffbf00ee)" }, angle = 45 },
            inactive_border = "rgba(1a0000aa)",
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 0,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 0.97,

        shadow = {
            enabled      = true,
            range        = 8,
            render_power = 2,
            color        = "rgba(cc000033)",
        },

        blur = {
            enabled           = true,
            size              = 4,
            passes            = 2,
            vibrancy          = 0.2,
            new_optimizations = true,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
        smart_split    = true,
        smart_resizing = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        font_family                = "JetBrains Mono",
        force_default_wallpaper    = 0,
        disable_hyprland_logo      = true,
        allow_session_lock_restore = true,
        mouse_move_enables_dpms    = true,
        key_press_enables_dpms     = true,
    },
})

-- HUD SNAP: sharp, fast, computational. Matches the rofi/consensus aesthetic.
hl.curve("snap",  { type = "bezier", points = { { 0.19, 1   }, { 0.22, 1 } } })
hl.curve("slam",  { type = "bezier", points = { { 0.5,  0   }, { 0.5,  1 } } })
hl.curve("flash", { type = "bezier", points = { { 0,    0   }, { 0.2,  1 } } })
hl.curve("decel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1,  1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 5,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 1.5, bezier = "flash" })
hl.animation({ leaf = "borderangle",   enabled = true, speed = 30,  bezier = "default", style = "loop" })
hl.animation({ leaf = "windows",       enabled = true, speed = 2,   bezier = "slam" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 1.5, bezier = "decel", style = "popin 90%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1,   bezier = "slam",  style = "popin 90%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1,   bezier = "flash" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1,   bezier = "flash" })
hl.animation({ leaf = "fade",          enabled = true, speed = 1.5, bezier = "decel" })
hl.animation({ leaf = "layers",        enabled = true, speed = 2,   bezier = "snap" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 1.5, bezier = "decel", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1,   bezier = "flash", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1,   bezier = "flash" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1,   bezier = "flash" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 2,   bezier = "slam",  style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 2,   bezier = "slam",  style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.5, bezier = "flash", style = "slide" })
