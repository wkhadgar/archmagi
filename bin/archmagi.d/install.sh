# archmagi install — bootstrap, boot theme, monitor refresh, sync back.

source "$ARCHMAGI_LIB/install_detect.sh"
source "$ARCHMAGI_LIB/install_prompt.sh"
source "$ARCHMAGI_LIB/install_template.sh"
source "$ARCHMAGI_LIB/install_configs.sh"
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

# Run the full bootstrap chain on a fresh host.
# Order: detect -> prompt -> persist profile -> templates -> configs.
# Packages and boot theme are wired in a later iteration.
_install_bootstrap() {
    local bar="${RED}▌${RESET}" sep="${MUTED}//${RESET}"

    local repo
    repo=$(_install_find_repo) || return 1

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

    printf "  %s wrote ${AMBER}/etc/archmagi/profile${RESET}\n" "$bar"

    _install_configs "$repo"
    printf "  %s deployed generic configs from ${AMBER}%s${RESET}\n" "$bar" "$repo"

    local hostname_upper=${hostname^^}
    _install_substitute "$repo/etc/hostname.tmpl"           /etc/hostname                          HOSTNAME="$hostname"
    _install_substitute "$repo/etc/hosts.tmpl"              /etc/hosts                             HOSTNAME="$hostname"
    _install_substitute "$repo/hypr/hyprlock.conf.tmpl"     "$HOME/.config/hypr/hyprlock.conf"     HOSTNAME_UPPER="$hostname_upper"
    _install_substitute "$repo/hypr/hyprland/monit.conf.tmpl" "$HOME/.config/hypr/hyprland/monit.conf"
    printf "  %s wrote ${AMBER}hostname / hosts / hyprlock label / monit.conf${RESET} from templates\n" "$bar"

    echo
    printf "  %s ${BOLD}MAGI BOOTSTRAP${RESET} %s ${AMBER}configs + templates done${RESET}\n" "$bar" "$sep"
    printf "  %s   ${MUTED}next: packages, boot theme — not yet wired${RESET}\n" "$bar"
}

_install_monitors() {
    echo "archmagi install monitors: not yet implemented" >&2
    return 1
}

_install_sync() {
    echo "archmagi install sync: not yet implemented" >&2
    return 1
}
