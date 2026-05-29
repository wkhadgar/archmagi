# magi — shared palette, constants, and cross-group helpers.
# Sourced unconditionally by bin/magi before any command-group library.

RED=$'\033[38;2;204;0;0m'
AMBER=$'\033[38;2;255;191;0m'
BLUE=$'\033[38;2;90;212;230m'
GREEN=$'\033[38;2;123;216;143m'
MUTED=$'\033[38;2;102;102;102m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

MAGI_NODES=(casper-3 balthasar-2 melchior-1)

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

_pending_counts() {
    local pacman aur
    pacman=$(checkupdates 2>/dev/null | wc -l)
    aur=$(paru -Qua 2>/dev/null | wc -l)
    echo "$pacman $aur"
}
