# archmagi battery: low-battery notifications via notify-send.
# One-shot `check` reads /sys/class/power_supply/BAT*, decides whether the
# current capacity crossed a warning band, and fires a notification if so.
# `watch` is a background loop for the Hyprland autostart. Both are silent
# no-ops on machines without a battery.

# Warning thresholds (percent, descending). A band re-fires only if capacity
# drops into a stricter band or if the state file was cleared by a charge cycle.
BATTERY_BAND_LOW=20
BATTERY_BAND_CRITICAL=10
BATTERY_BAND_EMERGENCY=5

# Dispatcher.
# @param 1  subcommand: "check" (default), "watch", or "eta"
cmd_battery() {
    case "${1:-check}" in
        check) _battery_check ;;
        watch) _battery_watch ;;
        eta)   _battery_eta   ;;
        *)     echo "archmagi battery: subcommand 'check', 'watch', or 'eta'" >&2; return 1 ;;
    esac
}

# Read the first BAT* device with a readable capacity. If capacity is at or
# below a threshold and Hyprland's notify daemon hasn't seen this band yet,
# fire notify-send and record the band. Charging clears the record so the
# next drop below a threshold notifies again.
_battery_check() {
    local bat
    for bat in /sys/class/power_supply/BAT*; do
        [[ -r "$bat/capacity" ]] && break
    done
    [[ -r "$bat/capacity" ]] || return 0

    local cap status
    cap=$(<"$bat/capacity")
    [[ -r "$bat/status" ]] && status=$(<"$bat/status") || status=Unknown

    local state_file="$HOME/.cache/archmagi/battery-band"
    mkdir -p "$(dirname "$state_file")"
    local last=""
    [[ -f "$state_file" ]] && last=$(<"$state_file")

    if [[ "$status" == "Charging" || "$status" == "Full" ]]; then
        [[ -n "$last" ]] && rm -f "$state_file"
        return 0
    fi

    local band=""
    if   (( cap <= BATTERY_BAND_EMERGENCY )); then band=emergency
    elif (( cap <= BATTERY_BAND_CRITICAL  )); then band=critical
    elif (( cap <= BATTERY_BAND_LOW       )); then band=low
    fi

    [[ -z "$band" || "$band" == "$last" ]] && return 0

    local urgency icon title body
    case "$band" in
        low)
            urgency=normal;   icon=battery-low
            title="BATTERY LOW"
            body="${cap}% remaining. Consider charging."
            ;;
        critical)
            urgency=critical; icon=battery-caution
            title="BATTERY CRITICAL"
            body="${cap}% remaining. Charge now."
            ;;
        emergency)
            urgency=critical; icon=battery-empty
            title="BATTERY CATASTROPHIC"
            body="${cap}% remaining. Suspend imminent."
            ;;
    esac

    notify-send -u "$urgency" -i "$icon" \
        -h string:x-canonical-private-synchronous:archmagi-battery \
        "$title" "$body"

    printf '%s' "$band" > "$state_file"
}

# Poll _battery_check every 60s. Meant to be autostarted from start.lua.
_battery_watch() {
    while true; do
        _battery_check
        sleep 60
    done
}

# _battery_eta lives in lib.sh so fetch, the hyprlock widget, and this
# module all share one implementation.
