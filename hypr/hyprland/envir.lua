-- ENVIRONMENT VARIABLES
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE",              "24")
hl.env("HYPRCURSOR_SIZE",           "24")
hl.env("LIBVA_DRIVER_NAME",         "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("EDITOR",                    "nvim")
hl.env("VISUAL",                    "nvim")

-- PERMISSIONS
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Changes require a Hyprland restart; not applied on-the-fly.

hl.permission({
    binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland",
    type   = "screencopy",
    mode   = "allow",
})
