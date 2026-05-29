# magi status — NERV-themed terminal overview.

cmd_status() {
    local hostname uptime
    hostname=$(uname -n)
    hostname=${hostname%%.*}
    uptime=$(uptime -p | sed 's/^up //')

    local pacman aur updates_str total
    read -r pacman aur < <(_pending_counts)
    total=$((pacman + aur))
    if ((total > 0)); then
        updates_str="${AMBER}${total}${RESET} ${MUTED}(${pacman} pacman + ${aur} AUR)${RESET}"
    else
        updates_str="${MUTED}network up to date${RESET}"
    fi

    local cpu mem disk ip
    cpu=$(grep 'cpu ' /proc/stat | awk '{u=$2+$4; t=$2+$4+$5; print int((u-pu)/(t-pt)*100)"%"}' pu=0 pt=0)
    mem=$(free -h | awk '/^Mem/{print $3"/"$2}')
    disk=$(df -h / | awk 'NR==2{print $4" free"}')
    ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
    [[ -z "$ip" ]] && ip="offline"

    local bar="${RED}▌${RESET}"
    local sep="${MUTED}//${RESET}"

    echo
    printf "  %s %s%sMAGI SYSTEM%s %s %s%s%s\n" "$bar" "$BOLD" "$RED" "$RESET" "$sep" "$AMBER" "${hostname^^}" "$RESET"
    printf "  %s %s─────────────────────────────────%s\n" "$bar" "$MUTED" "$RESET"
    printf "  %s %sUPTIME%s      %s %s\n" "$bar" "$RED" "$RESET" "$sep" "$uptime"
    printf "  %s %sTAILNET%s     %s\n" "$bar" "$RED" "$RESET" "$sep"
    for node in "${MAGI_NODES[@]}"; do
        local state color
        state=$(_tailnet_state "$node")
        case "$state" in
            ONLINE)  color="$AMBER" ;;
            OFFLINE) color="$RED" ;;
            *)       color="$MUTED" ;;
        esac
        printf "  %s    %-12s %s[%s]%s\n" "$bar" "${node^^}" "$color" "$state" "$RESET"
    done
    printf "  %s %sUPDATES%s     %s %b\n" "$bar" "$RED" "$RESET" "$sep" "$updates_str"
    printf "  %s %sCPU%s         %s %s\n" "$bar" "$RED" "$RESET" "$sep" "$cpu"
    printf "  %s %sMEM%s         %s %s\n" "$bar" "$RED" "$RESET" "$sep" "$mem"
    printf "  %s %sDISK%s        %s %s\n" "$bar" "$RED" "$RESET" "$sep" "$disk"
    printf "  %s %sNET%s         %s %s\n" "$bar" "$RED" "$RESET" "$sep" "$ip"
    echo
}
