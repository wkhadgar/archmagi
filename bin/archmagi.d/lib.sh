RED=$'\033[38;2;204;0;0m'
AMBER=$'\033[38;2;255;191;0m'
BLUE=$'\033[38;2;90;212;230m'
GREEN=$'\033[38;2;123;216;143m'
MUTED=$'\033[38;2;102;102;102m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

MAGI_NODES=(casper-3 balthasar-2 melchior-1)

# Facts persisted by `archmagi install bootstrap`.
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

# Priority order matters: DHCP can set the kernel hostname to an IP, so
# `uname -n` is the last resort.
_archmagi_hostname() {
    local h=""
    [[ -n "$ARCHMAGI_HOSTNAME" ]] && h=$ARCHMAGI_HOSTNAME
    [[ -z "$h" && -r /etc/hostname ]] && h=$(</etc/hostname)
    [[ -z "$h" ]] && h=$(uname -n)
    printf '%s' "${h%%.*}"
}

# Non-zero exit on a battery-less host so callers can gate a whole surface
# on it instead of repeating the glob.
_battery_device() {
    local bat
    for bat in /sys/class/power_supply/BAT*; do
        [[ -r "$bat/capacity" ]] || continue
        printf '%s' "$bat"
        return 0
    done
    return 1
}

# HHhMMm when discharging or charging, `FULL` when full, empty otherwise.
# Accepts either energy_/power_ (uWh, uW) or charge_/current_ (uAh, uA)
# so it works across firmware variants.
_battery_eta() {
    local bat=${1:-}

    [[ -n "$bat" ]] || bat=$(_battery_device)
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

_ppd_available() {
    command -v powerprofilesctl >/dev/null && powerprofilesctl get >/dev/null 2>&1
}

# UNKNOWN means the host isn't in `tailscale status` output at all (vs offline).
# The cache holds `tailscale status` for the process lifetime; one fork per
# archmagi invocation regardless of how many MAGI nodes are queried.
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

_pending_counts_cache() {
    local dir="${XDG_CACHE_HOME:-$HOME/.cache}/archmagi"
    mkdir -p "$dir" 2>/dev/null
    echo "$dir/updates"
}

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

# Stale-while-revalidate: cached read is instant, a fresh fetch runs in the
# background whenever the cache is older than TTL. First-ever call per host
# pays the full fetch cost. Output is always "INT INT\n" (fallback "0 0").
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
