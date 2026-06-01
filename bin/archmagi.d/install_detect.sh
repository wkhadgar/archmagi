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

