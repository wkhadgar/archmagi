# Prompts write UI to stdout and store the chosen value in a PROMPT_* global,
# so `$()` capture never swallows the UI into a captured pipe.

_install_prompt_hostname() {
    local current=${1:-}
    local i n=${#MAGI_NODES[@]} choice host
    PROMPT_HOSTNAME=""
    echo
    echo "  $BAR ${BOLD}MAGI NODE${RESET}"
    for ((i=0; i<n; i++)); do
        printf "  %s   %d) %s\n" "$BAR" "$((i+1))" "${MAGI_NODES[i]}"
    done
    printf "  %s   %d) custom\n" "$BAR" "$((n+1))"
    if [[ -n "$current" ]]; then
        printf "  %s pick [1-%d, default %s]: " "$BAR" "$((n+1))" "$current"
    else
        printf "  %s pick [1-%d]: " "$BAR" "$((n+1))"
    fi
    read -r choice
    if [[ -z "$choice" && -n "$current" ]]; then
        PROMPT_HOSTNAME=$current
        return
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= n )); then
        PROMPT_HOSTNAME=${MAGI_NODES[choice-1]}
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice == n+1 )); then
        printf "  %s hostname: " "$BAR"
        read -r host
        [[ -z "$host" ]] && { echo "empty hostname" >&2; return 1; }
        PROMPT_HOSTNAME=$host
    else
        echo "invalid choice" >&2; return 1
    fi
}

_install_prompt_profile_role() {
    local hint=${1:-desktop}
    local choice
    PROMPT_PROFILE=""
    echo
    echo "  $BAR ${BOLD}PROFILE${RESET}"
    echo "  $BAR   1) laptop"
    echo "  $BAR   2) desktop"
    echo "  $BAR   3) server"
    printf "  %s pick [1-3, default %s]: " "$BAR" "$hint"
    read -r choice
    if [[ -z "$choice" ]]; then PROMPT_PROFILE=$hint; return; fi
    case "$choice" in
        1) PROMPT_PROFILE=laptop ;;
        2) PROMPT_PROFILE=desktop ;;
        3) PROMPT_PROFILE=server ;;
        *) echo "invalid choice" >&2; return 1 ;;
    esac
}

_install_prompt_confirm() {
    local profile=$1 hostname=$2 bootloader=$3
    echo
    echo "  $BAR ${BOLD}REVIEW${RESET}"
    printf "  %s   %sprofile%s    %s %s\n"    "$BAR" "$RED" "$RESET" "$SEP" "$profile"
    printf "  %s   %shostname%s   %s %s\n"    "$BAR" "$RED" "$RESET" "$SEP" "$hostname"
    printf "  %s   %sbootloader%s %s %s\n"    "$BAR" "$RED" "$RESET" "$SEP" "$bootloader"
    printf "  %s ${AMBER}proceed?${RESET} [Y/n]: " "$BAR"
    local answer
    read -r answer
    case "$answer" in
        [nN]*) return 1 ;;
        *)     return 0 ;;
    esac
}
