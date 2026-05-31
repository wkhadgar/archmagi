# Interactive TTY prompts used by `archmagi install bootstrap`.
#
# Prompts write their UI directly to stdout and store the chosen value in a
# well-known global variable. The bootstrap reads the global. This avoids
# wrapping prompts in $() — which silently swallows their output into a pipe
# and leaves `read` blocking on input the user can't see.

# Pick a hostname from a MAGI_NODES picklist or enter a custom one.
# @param 1 current hostname (used as the empty-input default; optional)
# @return chosen hostname in PROMPT_HOSTNAME (global)
_install_prompt_hostname() {
    local current=${1:-} bar="${RED}▌${RESET}"
    local i n=${#MAGI_NODES[@]} choice host
    PROMPT_HOSTNAME=""
    echo
    echo "  $bar ${BOLD}MAGI NODE${RESET}"
    for ((i=0; i<n; i++)); do
        printf "  %s   %d) %s\n" "$bar" "$((i+1))" "${MAGI_NODES[i]}"
    done
    printf "  %s   %d) custom\n" "$bar" "$((n+1))"
    if [[ -n "$current" ]]; then
        printf "  %s pick [1-%d, default %s]: " "$bar" "$((n+1))" "$current"
    else
        printf "  %s pick [1-%d]: " "$bar" "$((n+1))"
    fi
    read -r choice
    if [[ -z "$choice" && -n "$current" ]]; then
        PROMPT_HOSTNAME=$current
        return
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= n )); then
        PROMPT_HOSTNAME=${MAGI_NODES[choice-1]}
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice == n+1 )); then
        printf "  %s hostname: " "$bar"
        read -r host
        [[ -z "$host" ]] && { echo "empty hostname" >&2; return 1; }
        PROMPT_HOSTNAME=$host
    else
        echo "invalid choice" >&2; return 1
    fi
}

# Pick laptop / desktop / server, defaulting to the detected hint.
# @param 1 default hint (laptop|desktop|server)
# @return chosen role in PROMPT_PROFILE (global)
_install_prompt_profile_role() {
    local hint=${1:-desktop} bar="${RED}▌${RESET}"
    local choice
    PROMPT_PROFILE=""
    echo
    echo "  $bar ${BOLD}PROFILE${RESET}"
    echo "  $bar   1) laptop"
    echo "  $bar   2) desktop"
    echo "  $bar   3) server"
    printf "  %s pick [1-3, default %s]: " "$bar" "$hint"
    read -r choice
    if [[ -z "$choice" ]]; then PROMPT_PROFILE=$hint; return; fi
    case "$choice" in
        1) PROMPT_PROFILE=laptop ;;
        2) PROMPT_PROFILE=desktop ;;
        3) PROMPT_PROFILE=server ;;
        *) echo "invalid choice" >&2; return 1 ;;
    esac
}

# Show a review table of the detected/decided values; ask for final go-ahead.
# @param 1 profile
# @param 2 hostname
# @param 3 bootloader
# @return 0 if user confirms with Y/empty, 1 if N
_install_prompt_confirm() {
    local profile=$1 hostname=$2 bootloader=$3
    local bar="${RED}▌${RESET}" sep="${MUTED}//${RESET}"
    echo
    echo "  $bar ${BOLD}REVIEW${RESET}"
    printf "  %s   %sprofile%s    %s %s\n"    "$bar" "$RED" "$RESET" "$sep" "$profile"
    printf "  %s   %shostname%s   %s %s\n"    "$bar" "$RED" "$RESET" "$sep" "$hostname"
    printf "  %s   %sbootloader%s %s %s\n"    "$bar" "$RED" "$RESET" "$sep" "$bootloader"
    printf "  %s ${AMBER}proceed?${RESET} [Y/n]: " "$bar"
    local answer
    read -r answer
    case "$answer" in
        [nN]*) return 1 ;;
        *)     return 0 ;;
    esac
}
