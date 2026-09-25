cmd_update() {
    case "${1:-run}" in
        run)   shift 2>/dev/null; _update_run "$@" ;;
        check) shift; _update_check "$@" ;;
        *)     echo "archmagi update: subcommand 'run' or 'check'" >&2; return 1 ;;
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

    local pacman aur
    read -r pacman aur < <(_pending_counts)
    local total=$((pacman + aur))

    echo
    printf "  %s %s%sMAGI SYSTEM%s %s ${AMBER}PROTOCOL SYNC${RESET}\n" "$BAR" "$BOLD" "$RED" "$RESET" "$SEP"
    printf "  %s ${MUTED}---------------------------------${RESET}\n" "$BAR"

    if ((total == 0)); then
        printf "  %s network up to date: ${GREEN}PATTERN GREEN${RESET}\n\n" "$BAR"
        notify-send "MAGI SYSTEM UPDATE STATUS" $'\nMAGI NETWORK IS UP TO DATE'
        return 0
    fi

    local threat threat_color
    if   ((total >= 45)); then threat="PATTERN RED";   threat_color="$RED"
    elif ((total >= 16)); then threat="PATTERN BLUE";  threat_color="$BLUE"
    else                       threat="PATTERN AMBER"; threat_color="$AMBER"
    fi

    printf "  %s ${RED}PACMAN${RESET}       %s ${AMBER}%s${RESET} pending\n" "$BAR" "$SEP" "$pacman"
    printf "  %s ${RED}AUR${RESET}          %s ${AMBER}%s${RESET} pending\n" "$BAR" "$SEP" "$aur"
    printf "  %s ${RED}THREAT LEVEL${RESET} %s ${threat_color}${threat}${RESET}\n" "$BAR" "$SEP"
    echo

    if ((pacman > 0)); then
        printf "  %s ${MUTED}pacman protocols:${RESET}\n" "$BAR"
        checkupdates 2>/dev/null | sed "s/^/        /"
        echo
    fi
    if ((aur > 0)); then
        printf "  %s ${MUTED}AUR protocols:${RESET}\n" "$BAR"
        paru -Qua 2>/dev/null | sed "s/^/        /"
        echo
    fi

    printf "  %s ${BOLD}${AMBER}ACCEPT MAGI UPDATES?${RESET} [${AMBER}Y${RESET}/n] " "$BAR"
    local answer; read -r answer

    local notif
    case "$answer" in
        [nN]*)
            printf "  %s ${RED}SYNC ABORTED${RESET}\n\n" "$BAR"
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
                printf "  %s ${BOLD}SYNC COMPLETE${RESET}: ${GREEN}PATTERN GREEN${RESET}\n\n" "$BAR"
                notif="MAGI PROTOCOLS UPDATED"
            else
                printf "  %s ${BOLD}${RED}SYNC FAILED${RESET} (rc=$rc)\n\n" "$BAR"
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
