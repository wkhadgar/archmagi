# archmagi: shared palette, constants, and cross-group helpers.
# Sourced unconditionally by bin/archmagi before any command-group library.

RED=$'\033[38;2;204;0;0m'
AMBER=$'\033[38;2;255;191;0m'
BLUE=$'\033[38;2;90;212;230m'
GREEN=$'\033[38;2;123;216;143m'
MUTED=$'\033[38;2;102;102;102m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

MAGI_NODES=(casper-3 balthasar-2 melchior-1)

# Persisted host facts from `archmagi install bootstrap`. Empty when the host
# hasn't been bootstrapped yet.
ARCHMAGI_PROFILE=""
ARCHMAGI_HOSTNAME=""
ARCHMAGI_BOOTLOADER=""
if [[ -r /etc/archmagi/profile ]]; then
    while IFS='=' read -r _k _v; do
        case "$_k" in
            profile)    ARCHMAGI_PROFILE="$_v"    ;;
            hostname)   ARCHMAGI_HOSTNAME="$_v"   ;;
            bootloader) ARCHMAGI_BOOTLOADER="$_v" ;;
        esac
    done < /etc/archmagi/profile
    unset _k _v
fi

# Short hostname. Prefers `/etc/archmagi/profile` when bootstrap has run,
# then `/etc/hostname` (canonical on Arch), and finally falls back to
# `uname -n`. Truncates FQDN to the short label so callers get `balthasar-2`
# rather than `balthasar-2.localdomain`. On hosts where DHCP or similar has
# set the kernel hostname to an IP, this still yields the right name.
_archmagi_hostname() {
    local h=""
    [[ -n "$ARCHMAGI_HOSTNAME" ]] && h=$ARCHMAGI_HOSTNAME
    [[ -z "$h" && -r /etc/hostname ]] && h=$(</etc/hostname)
    [[ -z "$h" ]] && h=$(uname -n)
    printf '%s' "${h%%.*}"
}

# Format battery time-remaining as `HHhMMm`. Prints:
#   `HHhMMm` when discharging (time to empty) or charging (time to full)
#   `FULL`   when the battery is Full
#   nothing  when no battery, unknown status, or draw is unavailable
# Supports both energy_/power_ (uWh, uW) and charge_/current_ (uAh, uA)
# sysfs conventions so it works across laptop firmware variants.
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
        Full)        echo "FULL"; return 0 ;;
        *)           return 0 ;;
    esac

    (( draw > 0 )) || return 0

    local total_minutes=$(( remaining * 60 / draw ))
    printf '%02dh%02dm\n' $(( total_minutes / 60 )) $(( total_minutes % 60 ))
}

# True when power-profiles-daemon is installed AND its daemon is reachable
# (the D-Bus call succeeds). Used to gate the profile UI surface so it appears
# on any host running PPD, regardless of laptop/desktop profile.
_ppd_available() {
    command -v powerprofilesctl >/dev/null && powerprofilesctl get >/dev/null 2>&1
}

# UNKNOWN means the host isn't in `tailscale status` output at all (vs offline).
# $_TAILNET_STATUS_CACHE holds the full `tailscale status` output for the
# duration of this process; one fork per archmagi invocation regardless of
# how many MAGI nodes are queried.
_TAILNET_STATUS_CACHE=""
_tailnet_state() {
    local host="$1"
    [[ -z "$_TAILNET_STATUS_CACHE" ]] && _TAILNET_STATUS_CACHE=$(tailscale status 2>/dev/null)
    local line
    line=$(awk -v h="$host" '$2 == h { print; exit }' <<<"$_TAILNET_STATUS_CACHE")
    if   [[ -z "$line"      ]]; then echo UNKNOWN
    elif [[ "$line" == *offline* ]]; then echo OFFLINE
    else                                  echo ONLINE
    fi
}

# Cache path for the (slow) pacman + AUR update counts.
_pending_counts_cache() {
    local dir="${XDG_CACHE_HOME:-$HOME/.cache}/archmagi"
    mkdir -p "$dir" 2>/dev/null
    echo "$dir/updates"
}

# Synchronously fetch fresh counts and atomically replace the cache file.
# Returns 0 on success, non-zero (with $tmp removed) if the write/move failed.
_pending_counts_fetch() {
    local out=$1 p a tmp
    p=$(checkupdates 2>/dev/null | wc -l)
    a=$(paru -Qua 2>/dev/null | wc -l)
    tmp="$out.$$.tmp"
    if printf '%s %s\n' "$p" "$a" > "$tmp" 2>/dev/null && mv -f "$tmp" "$out" 2>/dev/null; then
        return 0
    fi
    rm -f "$tmp" 2>/dev/null
    return 1
}

# Stale-while-revalidate: callers always get an instant answer once the cache
# exists. The first-ever call per host pays the full fetch cost. Output is
# always "INT INT\n" — falls back to "0 0" when the fetch fails.
_pending_counts() {
    local cache ttl=300 age
    cache=$(_pending_counts_cache)
    if [[ -r "$cache" ]]; then
        age=$(( $(date +%s) - $(stat -c %Y "$cache") ))
        cat "$cache"
        if (( age >= ttl )); then
            ( _pending_counts_fetch "$cache" ) & disown 2>/dev/null
        fi
        return
    fi
    if _pending_counts_fetch "$cache" && [[ -r "$cache" ]]; then
        cat "$cache"
    else
        echo "0 0"
    fi
}
