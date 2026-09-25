
hl.env("XCURSOR_SIZE",              "24")
hl.env("HYPRCURSOR_SIZE",           "24")
hl.env("LIBVA_DRIVER_NAME",         "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("EDITOR",                    "nvim")
hl.env("VISUAL",                    "nvim")

-- Permission changes need a Hyprland restart.

hl.permission({
    binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland",
    type   = "screencopy",
    mode   = "allow",
})
