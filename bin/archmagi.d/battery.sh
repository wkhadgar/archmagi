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

# Print "H:MM" for battery time remaining (discharge) or time to full (charge),
# or "--:--" when the battery is Full, or empty when no battery / draw is
# unavailable. Supports both energy_/power_ (uWh, uW) and charge_/current_
# (uAh, uA) sysfs conventions. Meant to be invoked from the hyprlock ACTIVE
# TIME REMAINING widget on a 60s update.
_battery_eta() {
    local bat
    for bat in /sys/class/power_supply/BAT*; do
        [[ -r "$bat/capacity" ]] && break
    done
    [[ -r "$bat/capacity" ]] || return 0

    local status
    [[ -r "$bat/status" ]] && status=$(<"$bat/status") || return 0

    local now full draw
    if [[ -r "$bat/energy_now" && -r "$bat/power_now" && -r "$bat/energy_full" ]]; then
        now=$(<"$bat/energy_now"); full=$(<"$bat/energy_full"); draw=$(<"$bat/power_now")
    elif [[ -r "$bat/charge_now" && -r "$bat/current_now" && -r "$bat/charge_full" ]]; then
        now=$(<"$bat/charge_now"); full=$(<"$bat/charge_full"); draw=$(<"$bat/current_now")
    else
        return 0
    fi

    local remaining
    case "$status" in
        Discharging) remaining=$now ;;
        Charging)    remaining=$(( full - now )) ;;
        Full)        echo "--:--"; return 0 ;;
        *)           return 0 ;;
    esac

    (( draw > 0 )) || return 0

    local total_minutes=$(( remaining * 60 / draw ))
    printf '%d:%02d\n' $(( total_minutes / 60 )) $(( total_minutes % 60 ))
}
