# archmagi update — interactive paru -Syu (run) + waybar update count (check).
# Subcommands: run (default), check [-j]

cmd_update() {
    case "${1:-run}" in
        run)   shift 2>/dev/null; _update_run "$@" ;;
        check) shift; _update_check "$@" ;;
        *)     echo "magi update: subcommand 'run' or 'check'" >&2; return 1 ;;
    esac
}

_update_check() {
    local critical=45
    local pacman aur
    read -r pacman aur < <(_pending_counts)
    local total=$((pacman + aur))
    local percentage=$((100 * total / critical))
    ((percentage > 100)) && percentage=100

    local tooltip class alt text
    if ((total > 0)); then
        tooltip="$pacman + $aur AUR"
        class="updates"
        alt="$total"
        text="$total"
    else
        tooltip="MAGI NETWORK IS UP TO DATE"
        class="no-updates"
        alt=""
        text=""
    fi

    if [[ "$1" == "-j" ]]; then
        printf '{"text": "%s", "alt": "%s", "tooltip": "%s", "class": "%s", "percentage": %s}\n' \
            "$text" "$alt" "$tooltip" "$class" "$percentage"
    else
        echo "$total"
    fi
}

_update_run() {
    local bar="${RED}▌${RESET}"
    local sep="${MUTED}//${RESET}"

    local pacman aur
    read -r pacman aur < <(_pending_counts)
    local total=$((pacman + aur))

    echo
    printf "  %s %s%sMAGI SYSTEM%s %s ${AMBER}PROTOCOL SYNC${RESET}\n" "$bar" "$BOLD" "$RED" "$RESET" "$sep"
    printf "  %s ${MUTED}─────────────────────────────────${RESET}\n" "$bar"

    if ((total == 0)); then
        printf "  %s network up to date — ${GREEN}PATTERN GREEN${RESET}\n\n" "$bar"
        notify-send "MAGI SYSTEM UPDATE STATUS" $'\nMAGI NETWORK IS UP TO DATE'
        return 0
    fi

    # Threat level scales with batch size; CRITICAL_UPDATE_AMOUNT (45) is the red line.
    local threat threat_color
    if   ((total >= 45)); then threat="PATTERN RED";   threat_color="$RED"
    elif ((total >= 16)); then threat="PATTERN BLUE";  threat_color="$BLUE"
    else                       threat="PATTERN AMBER"; threat_color="$AMBER"
    fi

    printf "  %s ${RED}PACMAN${RESET}       %s ${AMBER}%s${RESET} pending\n" "$bar" "$sep" "$pacman"
    printf "  %s ${RED}AUR${RESET}          %s ${AMBER}%s${RESET} pending\n" "$bar" "$sep" "$aur"
    printf "  %s ${RED}THREAT LEVEL${RESET} %s ${threat_color}${threat}${RESET}\n" "$bar" "$sep"
    echo

    if ((pacman > 0)); then
        printf "  %s ${MUTED}pacman protocols:${RESET}\n" "$bar"
        checkupdates 2>/dev/null | sed "s/^/        /"
        echo
    fi
    if ((aur > 0)); then
        printf "  %s ${MUTED}AUR protocols:${RESET}\n" "$bar"
        paru -Qua 2>/dev/null | sed "s/^/        /"
        echo
    fi

    printf "  %s ${BOLD}${AMBER}ACCEPT MAGI UPDATES?${RESET} [${AMBER}Y${RESET}/n] " "$bar"
    local answer; read -r answer

    local notif
    case "$answer" in
        [nN]*)
            printf "  %s ${RED}SYNC ABORTED${RESET}\n\n" "$bar"
            notif="ABORTED UPDATES"
            sleep 1
            ;;
        [yY]*|"")
            echo
            local rc=0
            paru -Syu --noconfirm || rc=$?
            echo
            if ((rc == 0)); then
                rm -f "$(_pending_counts_cache)" 2>/dev/null
                printf "  %s ${BOLD}SYNC COMPLETE${RESET} — ${GREEN}PATTERN GREEN${RESET}\n\n" "$bar"
                notif="MAGI PROTOCOLS UPDATED"
            else
                printf "  %s ${BOLD}${RED}SYNC FAILED${RESET} (rc=$rc)\n\n" "$bar"
                notif="ERROR $rc"
            fi
            sleep 3
            ;;
        *)
            return 1
            ;;
    esac

    notify-send "MAGI SYSTEM UPDATE STATUS" $'\n -- '"$notif"' --'
}
