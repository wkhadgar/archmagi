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

    current_host=$(_archmagi_hostname)
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
    _install_substitute "$repo/hypr/hyprland/monit.lua.tmpl" "$HOME/.config/hypr/hyprland/monit.lua"
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
# path for an already-bootstrapped host. Warns first when handmade live edits
# would be clobbered; user picks whether to proceed.
# Skips monit.lua.tmpl because the live monit.lua is owned by `install monitors`.
_install_redeploy() {
    local bar="${RED}▌${RESET}"
    local repo
    repo=$(_install_find_repo) || return 1
    [[ -n "$ARCHMAGI_HOSTNAME" ]] || {
        echo "  $bar /etc/archmagi/profile missing or invalid; run 'archmagi install bootstrap' first" >&2
        return 1
    }

    local drift
    drift=$(_install_drift_scan "$repo")
    if [[ -n "$drift" ]]; then
        local n=$(wc -l <<<"$drift")
        local plural=""; (( n != 1 )) && plural=s
        printf "\n  %s ${BOLD}%d local edit%s would be overwritten:${RESET}\n" "$bar" "$n" "$plural"
        local f
        while IFS= read -r f; do
            printf "  %s   ${AMBER}%s${RESET}\n" "$bar" "$f"
        done <<<"$drift"
        printf "\n  %s proceed with redeploy? [y/N] " "$bar"
        local ans
        read -r ans
        case "$ans" in
            [yY]*) ;;
            *) printf "  %s aborted by user\n" "$bar"; return 0 ;;
        esac
    fi

    _install_configs "$repo" || return 1
    _install_hostname_templates "$repo" "$ARCHMAGI_HOSTNAME" || return 1
    printf "  %s redeployed configs from ${AMBER}%s${RESET}\n" "$bar" "$repo"
}

# Walk the managed live<->repo trees and echo the repo-relative path of every
# live file whose content differs from its repo counterpart. Files that appear
# only live (not yet added to repo) are ignored; the redeploy would preserve
# them anyway. Templated files (per _install_sync_excluded) are skipped
# because they flow only outward.
# @param 1 absolute repo root
_install_drift_scan() {
    local repo=$1
    local trees=(
        "$HOME/.config/hypr::hypr"
        "$HOME/.config/waybar::waybar"
        "$HOME/.config/rofi::rofi"
        "$HOME/.config/nvim::nvim"
        "$HOME/.config/kitty::kitty"
        "$HOME/.config/tmux::tmux"
        "$HOME/.config/btop::btop"
        "$HOME/.config/swaync::swaync"
    )
    local pair live_root repo_rel_root live_file rel repo_file
    for pair in "${trees[@]}"; do
        live_root=${pair%%::*}; repo_rel_root=${pair##*::}
        [[ -d "$live_root" ]] || continue
        while IFS= read -r live_file; do
            rel=${live_file#"$live_root/"}
            _install_sync_excluded "$repo_rel_root/$rel" && continue
            repo_file="$repo/$repo_rel_root/$rel"
            [[ -f "$repo_file" ]] || continue
            diff -q "$live_file" "$repo_file" >/dev/null 2>&1 || echo "$repo_rel_root/$rel"
        done < <(find "$live_root" -type f 2>/dev/null)
    done
}

# Render the three hostname-bound templates (hostname, hosts, hyprlock identity).
# Shared by bootstrap and redeploy; monit.lua.tmpl is intentionally excluded
# because the live monit.lua is owned by `archmagi install monitors`.
_install_hostname_templates() {
    local repo=$1 hostname=$2 hostname_upper=${2^^}
    _install_substitute "$repo/etc/hostname.tmpl"       /etc/hostname                      HOSTNAME="$hostname"
    _install_substitute "$repo/etc/hosts.tmpl"          /etc/hosts                         HOSTNAME="$hostname"
    _install_substitute "$repo/hypr/hyprlock.conf.tmpl" "$HOME/.config/hypr/hyprlock.conf" HOSTNAME_UPPER="$hostname_upper"
}
