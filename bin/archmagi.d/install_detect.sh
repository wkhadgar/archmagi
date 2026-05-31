# Hardware/state detection helpers used by `archmagi install bootstrap`.

# Detect host profile by hardware features.
# @return laptop | desktop | server  (server = no battery AND no connected display)
_install_detect_profile() {
    if compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
        echo laptop
        return
    fi
    if grep -lF connected /sys/class/drm/*/status 2>/dev/null | head -1 >/dev/null; then
        echo desktop
    else
        echo server
    fi
}

# Detect installed bootloader by config file presence.
# @return grub | limine | unknown
_install_detect_bootloader() {
    if [[ -f /etc/default/grub ]] && command -v grub-mkconfig >/dev/null; then
        echo grub
    elif [[ -f /boot/limine.conf || -f /boot/limine.cfg || -f /etc/limine.conf ]]; then
        echo limine
    else
        echo unknown
    fi
}

# Detect connected monitors via hyprctl.
# @return one line per monitor: "NAME RESxRES@REFRESH SCALE"
#         empty when hyprctl isn't available (pre-first-Hyprland install)
_install_detect_monitors() {
    command -v hyprctl >/dev/null || return
    hyprctl monitors 2>/dev/null | awk '
        function flush() {
            if (name != "" && resolution != "") {
                printf "%s %s@%dHz %s\n", name, resolution, refresh, scale
            }
        }
        /^Monitor / {
            flush()
            name = $2; resolution = ""; refresh = 0; scale = "1.0"
        }
        /^[[:space:]]+[0-9]+x[0-9]+@/ && resolution == "" {
            split($1, a, "@"); resolution = a[1]; refresh = int(a[2])
        }
        /^[[:space:]]+scale: / { scale = $2 }
        END { flush() }
    '
}
