# archmagi lock/reboot/exit/shutdown: power actions. The latter three each open
# the consensus confirm dialog, then route through _graceful_close which calls
# hyprshutdown (clean IPC-driven app close) followed by an optional systemctl
# command. The chain is nohup'd + disowned so Hyprland tearing down doesn't
# kill it before systemctl runs.

source "$ARCHMAGI_LIB/confirm.sh"

cmd_lock() {
    pidof hyprlock >/dev/null || hyprlock
}

_graceful_close() {
    if ! command -v hyprshutdown >/dev/null; then
        echo "hyprshutdown not installed; run: sudo pacman -S hyprshutdown" >&2
        return 1
    fi
    local then_cmd="${1:-true}"
    nohup bash -c "hyprshutdown && $then_cmd" >/dev/null 2>&1 &
    disown
}

cmd_reboot()   { cmd_confirm REBOOT   && _graceful_close "systemctl reboot";   }
cmd_exit()     { cmd_confirm EXIT     && _graceful_close; }
cmd_shutdown() { cmd_confirm SHUTDOWN && _graceful_close "systemctl poweroff"; }
