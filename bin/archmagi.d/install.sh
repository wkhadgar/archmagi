# archmagi install — bootstrap, boot theme, monitor refresh, sync back.

source "$ARCHMAGI_LIB/install_detect.sh"
source "$ARCHMAGI_LIB/install_prompt.sh"
source "$ARCHMAGI_LIB/install_template.sh"
source "$ARCHMAGI_LIB/install_boot.sh"

cmd_install() {
    case "$1" in
        bootstrap) shift; _install_bootstrap "$@" ;;
        boot)      shift; _install_boot      "$@" ;;
        monitors)  shift; _install_monitors  "$@" ;;
        sync)      shift; _install_sync      "$@" ;;
        *) echo "archmagi install: subcommand 'bootstrap', 'boot', 'monitors', or 'sync'" >&2; return 1 ;;
    esac
}

# Phases 1-3 of bootstrap: detect host facts, prompt for the ones we can't
# infer (hostname, role override), persist the result to /etc/archmagi/profile.
# Phases 4-10 (templates / configs / packages / boot chain) are next.
_install_bootstrap() {
    local bar="${RED}▌${RESET}" sep="${MUTED}//${RESET}"

    local prof_hint bootloader
    prof_hint=$(_install_detect_profile)
    bootloader=$(_install_detect_bootloader)

    local profile hostname current_host
    profile=$(_install_prompt_profile_role "$prof_hint") || return 1

    current_host=$(uname -n); current_host=${current_host%%.*}
    hostname=$(_install_prompt_hostname "$current_host") || return 1

    _install_prompt_confirm "$profile" "$hostname" "$bootloader" || {
        echo "  $bar aborted by user." >&2
        return 1
    }

    sudo mkdir -p /etc/archmagi
    {
        printf 'profile=%s\n' "$profile"
        printf 'hostname=%s\n' "$hostname"
        printf 'bootloader=%s\n' "$bootloader"
    } | sudo tee /etc/archmagi/profile >/dev/null

    echo
    printf "  %s ${BOLD}MAGI BOOTSTRAP${RESET} %s ${AMBER}phase 1-3 complete${RESET}\n" "$bar" "$sep"
    printf "  %s   wrote ${AMBER}/etc/archmagi/profile${RESET}\n" "$bar"
    printf "  %s   ${MUTED}next: templates, configs, packages, boot — not yet wired${RESET}\n" "$bar"
}

_install_monitors() {
    echo "archmagi install monitors: not yet implemented" >&2
    return 1
}

_install_sync() {
    echo "archmagi install sync: not yet implemented" >&2
    return 1
}
