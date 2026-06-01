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

# True when power-profiles-daemon is installed AND its daemon is reachable
# (the D-Bus call succeeds). Used to gate the profile UI surface so it appears
# on any host running PPD, regardless of laptop/desktop profile.
_ppd_available() {
    command -v powerprofilesctl >/dev/null && powerprofilesctl get >/dev/null 2>&1
}

# UNKNOWN means the host isn't in `tailscale status` output at all (vs offline).
_tailnet_state() {
    local host="$1"
    local line
    line=$(tailscale status 2>/dev/null | awk -v h="$host" '$2 == h { print; exit }')
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
_pending_counts_fetch() {
    local out=$1 p a tmp
    p=$(checkupdates 2>/dev/null | wc -l)
    a=$(paru -Qua 2>/dev/null | wc -l)
    tmp="$out.$$.tmp"
    printf '%s %s\n' "$p" "$a" > "$tmp" && mv -f "$tmp" "$out"
}

# Stale-while-revalidate: callers always get an instant answer once the cache
# exists. The first-ever call per host pays the full fetch cost.
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
    _pending_counts_fetch "$cache"
    cat "$cache" 2>/dev/null
}
