# archmagi battery: low-battery notifications via notify-send, plus the two
# text widgets the lockscreen draws.
# One-shot `check` reads the battery sysfs device, decides whether the current
# capacity crossed a warning band, and fires a notification if so. `watch` is a
# background loop for the Hyprland autostart. `runtime` and `summary` render the
# lockscreen widgets. Every subcommand is a silent no-op on a machine without a
# battery, except `runtime`, which reports unbounded runtime there.

# Warning thresholds (percent, descending). A band re-fires only if capacity
# drops into a stricter band or if the state file was cleared by a charge cycle.
BATTERY_BAND_LOW=20
BATTERY_BAND_CRITICAL=10
BATTERY_BAND_EMERGENCY=5

# Rendered whenever the host draws from wall power and its uptime is therefore
# not bounded by a charge level, the way an Evangelion on the umbilical cable
# has no activation time limit.
BATTERY_RUNTIME_UNBOUNDED='∞ // UMBILICAL'

# Dispatcher.
# @param 1  subcommand: "check" (default), "watch", "runtime", or "summary"
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

# Read the first BAT* device with a readable capacity. If capacity is at or
# below a threshold and Hyprland's notify daemon hasn't seen this band yet,
# fire notify-send and record the band. Charging clears the record so the
# next drop below a threshold notifies again.
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

# Poll _battery_check every 60s. Meant to be autostarted from start.lua, which
# runs on every host, so a battery-less one returns instead of polling a no-op
# forever.
_battery_watch() {
    _battery_device >/dev/null || return 0

    while true; do
        _battery_check
        sleep 60
    done
}

# Lockscreen top-right value: how long the host can keep running unattended.
# Wall power imposes no bound, so print BATTERY_RUNTIME_UNBOUNDED for a host
# with no battery at all and for a laptop that is charging, full, or holding at
# a charge threshold. A discharging laptop prints its drain ETA.
# @param 1  battery sysfs dir; defaults to the first device _battery_device finds
_battery_runtime() {
    local bat=${1:-} status

    [[ -n "$bat" ]] || bat=$(_battery_device)

    # No battery: the host runs on wall power, so its uptime is not bounded by
    # a charge level. An absent device leaves $bat empty and fails this check.
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

# Lockscreen bottom-left row: `BATT // 42% (01h23m)` while draining and
# `BATT // 80% (∞ // UMBILICAL)` on wall power, so it reads the same as the
# top-right widget. Drops the parenthesised half to `BATT // 42%` when the
# firmware exposes no usable figure, and prints nothing on a host with no
# battery, which leaves the hyprlock label empty so it is never drawn.
# @param 1  battery sysfs dir; defaults to the first device _battery_device finds
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

# _battery_device and _battery_eta live in lib.sh so fetch and this module
# share one device lookup and one ETA implementation. fetch calls _battery_eta
# directly, so its BATTERY row keeps the raw time-to-full while charging.
