# archmagi install: bootstrap, boot theme, monitor refresh, sync back.

source "$ARCHMAGI_LIB/install_detect.sh"
source "$ARCHMAGI_LIB/install_prompt.sh"
source "$ARCHMAGI_LIB/install_template.sh"
source "$ARCHMAGI_LIB/install_configs.sh"
source "$ARCHMAGI_LIB/install_packages.sh"
source "$ARCHMAGI_LIB/install_wallpaper.sh"
source "$ARCHMAGI_LIB/install_boot.sh"
source "$ARCHMAGI_LIB/install_monitors.sh"
source "$ARCHMAGI_LIB/install_sync.sh"

cmd_install() {
    case "$1" in
        bootstrap) shift; _install_bootstrap "$@" ;;
        redeploy)  shift; _install_redeploy  "$@" ;;
        boot)      shift; _install_boot      "$@" ;;
        wallpaper) shift; _install_wallpaper "$@" ;;
        monitors)  shift; _install_monitors  "$@" ;;
        sync)      shift; _install_sync      "$@" ;;
        *) echo "archmagi install: subcommand 'bootstrap', 'redeploy', 'boot', 'wallpaper', 'monitors', or 'sync'" >&2; return 1 ;;
    esac
}

# Run the full bootstrap chain on a fresh host.
# Order: detect -> prompt -> persist -> configs -> templates -> packages -> wallpaper -> boot.
# Configs land before packages so a ctrl-C during pacman still leaves a
# working dotfile install; wallpaper waits for imagemagick from packages.
_install_bootstrap() {
    local bar="${RED}▌${RESET}" sep="${MUTED}//${RESET}"

    local repo
    repo=$(_install_find_repo) || return 1

    local prof_hint bootloader
    prof_hint=$(_install_detect_profile)
    bootloader=$(_install_detect_bootloader)

    local profile hostname current_host
    _install_prompt_profile_role "$prof_hint" || return 1
    profile=$PROMPT_PROFILE

    current_host=$(uname -n); current_host=${current_host%%.*}
    _install_prompt_hostname "$current_host" || return 1
    hostname=$PROMPT_HOSTNAME

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

    _install_hostname_templates "$repo" "$hostname"
    _install_substitute "$repo/hypr/hyprland/monit.conf.tmpl" "$HOME/.config/hypr/hyprland/monit.conf"
    printf "  %s wrote host-specific files from templates\n" "$bar"

    _install_packages "$repo" || {
        echo "  $bar package install failed; bootstrap aborted." >&2
        return 1
    }
    printf "  %s pacman -S --needed completed\n" "$bar"

    _install_wallpaper
    _install_boot

    echo
    printf "  %s ${BOLD}MAGI BOOTSTRAP COMPLETE${RESET} %s reboot to see NERV chrome\n" "$bar" "$sep"
}

# Re-deploy configs + re-render hostname-bound templates from the persisted
# /etc/archmagi/profile. No prompts, no packages, no boot theme. The post-pull
# path for an already-bootstrapped host.
# Skips monit.conf.tmpl because the live monit.conf is owned by `install monitors`.
_install_redeploy() {
    local bar="${RED}▌${RESET}"
    local repo profile hostname bootloader
    repo=$(_install_find_repo) || return 1
    [[ -r /etc/archmagi/profile ]] || {
        echo "  $bar /etc/archmagi/profile missing; run 'archmagi install bootstrap' first" >&2
        return 1
    }
    source /etc/archmagi/profile

    _install_configs "$repo"
    _install_hostname_templates "$repo" "$hostname"
    printf "  %s redeployed configs from ${AMBER}%s${RESET}\n" "$bar" "$repo"
}

# Render the three hostname-bound templates (hostname, hosts, hyprlock identity).
# Shared by bootstrap and redeploy; monit.conf.tmpl is intentionally excluded
# because the live monit.conf is owned by `archmagi install monitors`.
_install_hostname_templates() {
    local repo=$1 hostname=$2 hostname_upper=${2^^}
    _install_substitute "$repo/etc/hostname.tmpl"       /etc/hostname                      HOSTNAME="$hostname"
    _install_substitute "$repo/etc/hosts.tmpl"          /etc/hosts                         HOSTNAME="$hostname"
    _install_substitute "$repo/hypr/hyprlock.conf.tmpl" "$HOME/.config/hypr/hyprlock.conf" HOSTNAME_UPPER="$hostname_upper"
}
