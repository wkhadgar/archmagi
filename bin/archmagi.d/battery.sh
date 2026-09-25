BATTERY_BAND_LOW=20
BATTERY_BAND_CRITICAL=10
BATTERY_BAND_EMERGENCY=5

# Uptime on wall power isn't bounded by a charge level. Matches the umbilical
# cable freeing an Eva from its activation-time limit.
BATTERY_RUNTIME_UNBOUNDED='∞ // UMBILICAL'

cmd_battery() {
    case "${1:-check}" in
        check)   _battery_check   ;;
        watch)   _battery_watch   ;;
        runtime) _battery_runtime ;;
        summary) _battery_summary ;;
        *)
            echo "archmagi battery: subcommand 'check', 'watch', 'runtime', or 'summary'" >&2
            return 1
            ;;
    esac
}

# Fire notify-send when capacity first drops into a threshold band while
# discharging. Charging clears the state so a later drop notifies again.
_battery_check() {
    local bat
    bat=$(_battery_device) || return 0

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

# start.lua runs this on every host; return early on desktops instead of
# polling a no-op forever.
_battery_watch() {
    _battery_device >/dev/null || return 0

    while true; do
        _battery_check
        sleep 60
    done
}

_battery_runtime() {
    local bat=${1:-} status

    [[ -n "$bat" ]] || bat=$(_battery_device)

    [[ -r "$bat/capacity" ]] || {
        printf '%s\n' "$BATTERY_RUNTIME_UNBOUNDED"
        return 0
    }

    status=Unknown
    [[ -r "$bat/status" ]] && status=$(<"$bat/status")

    case "$status" in
        Charging|Full|"Not charging")
            printf '%s\n' "$BATTERY_RUNTIME_UNBOUNDED"
            return 0
            ;;
    esac

    _battery_eta "$bat"
}

# `BATT // 42% (01h23m)` while draining, `BATT // 80% (∞ // UMBILICAL)` on
# wall power. Empty output on a battery-less host so hyprlock draws nothing.
_battery_summary() {
    local bat=${1:-} cap runtime

    [[ -n "$bat" ]] || bat=$(_battery_device)
    [[ -r "$bat/capacity" ]] || return 0

    cap=$(<"$bat/capacity")
    runtime=$(_battery_runtime "$bat")

    if [[ -n "$runtime" ]]; then
        printf 'BATT // %s%% (%s)\n' "$cap" "$runtime"
    else
        printf 'BATT // %s%%\n' "$cap"
    fi
}
