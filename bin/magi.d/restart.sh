# magi restart <waybar|xdph> — kill + relaunch a desktop service detached.

_restart_waybar() {
    killall waybar 2>/dev/null
    setsid waybar >/dev/null 2>&1 < /dev/null &
}

_restart_xdph() {
    sleep 1
    killall -e xdg-desktop-portal-hyprland 2>/dev/null
    killall xdg-desktop-portal 2>/dev/null
    setsid /usr/lib/xdg-desktop-portal-hyprland >/dev/null 2>&1 < /dev/null &
    sleep 2
    setsid /usr/lib/xdg-desktop-portal >/dev/null 2>&1 < /dev/null &
}

cmd_restart() {
    case "$1" in
        waybar) shift; _restart_waybar "$@" ;;
        xdph)   shift; _restart_xdph   "$@" ;;
        *)      echo "magi restart: subcommand 'waybar' or 'xdph'" >&2; return 1 ;;
    esac
}
