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

_install_bootstrap() {
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
        echo "  $BAR aborted by user." >&2
        return 1
    }

    sudo mkdir -p /etc/archmagi
    {
        printf 'profile=%s\n' "$profile"
        printf 'hostname=%s\n' "$hostname"
        printf 'bootloader=%s\n' "$bootloader"
    } | sudo tee /etc/archmagi/profile >/dev/null
    printf "  %s wrote ${AMBER}/etc/archmagi/profile${RESET}\n" "$BAR"

    # Configs land before packages so a ctrl-C during pacman still leaves a
    # working dotfile install.
    _install_configs "$repo" || {
        echo "  $BAR config deploy failed; bootstrap aborted." >&2
        return 1
    }
    printf "  %s deployed generic configs from ${AMBER}%s${RESET}\n" "$BAR" "$repo"

    { _install_hostname_templates "$repo" "$hostname" &&
      _install_substitute "$repo/hypr/hyprland/monit.lua.tmpl" "$HOME/.config/hypr/hyprland/monit.lua"; } || {
        echo "  $BAR template render failed; bootstrap aborted." >&2
        return 1
    }
    printf "  %s wrote host-specific files from templates\n" "$BAR"

    _install_packages "$repo" || {
        echo "  $BAR package install failed; bootstrap aborted." >&2
        return 1
    }
    printf "  %s pacman -S --needed completed\n" "$BAR"

    # Wallpaper needs imagemagick from packages.
    _install_wallpaper
    _install_boot

    echo
    printf "  %s ${BOLD}MAGI BOOTSTRAP COMPLETE${RESET} %s reboot to see NERV chrome\n" "$BAR" "$SEP"
}

_install_redeploy() {
    local repo
    repo=$(_install_find_repo) || return 1
    [[ -n "$ARCHMAGI_HOSTNAME" ]] || {
        echo "  $BAR /etc/archmagi/profile missing or invalid; run 'archmagi install bootstrap' first" >&2
        return 1
    }

    local drift
    drift=$(_install_drift_scan "$repo")
    if [[ -n "$drift" ]]; then
        local n=$(wc -l <<<"$drift")
        local plural=""; (( n != 1 )) && plural=s
        printf "\n  %s ${BOLD}%d local edit%s would be overwritten:${RESET}\n" "$BAR" "$n" "$plural"
        local f
        while IFS= read -r f; do
            printf "  %s   ${AMBER}%s${RESET}\n" "$BAR" "$f"
        done <<<"$drift"
        echo
        _ask_yn "proceed with redeploy?" || { printf "  %s aborted by user\n" "$BAR"; return 0; }
    fi

    _install_configs "$repo" || return 1
    _install_hostname_templates "$repo" "$ARCHMAGI_HOSTNAME" || return 1
    printf "  %s redeployed configs from ${AMBER}%s${RESET}\n" "$BAR" "$repo"
}

# Prints repo paths whose live copy exists and differs, i.e. what a redeploy
# would overwrite.
_drift_entry() {
    local kind=$1 live=$2 rel=$3 f l
    while IFS= read -r f; do
        _install_sync_excluded "$f" && continue
        case "$kind" in
            file|exe) l=$live ;;
            *)        l="$live/${f#"$rel/"}" ;;
        esac
        [[ -r "$l" ]] || continue
        diff -q "$l" "$repo/$f" >/dev/null 2>&1 || echo "$f"
    done < <(_map_repo_files "$rel")
}

_install_drift_scan() {
    local repo=$1
    _map_each _drift_entry
}

# monit.lua.tmpl is intentionally skipped: the live monit.lua is owned by
# `archmagi install monitors`.
_install_hostname_templates() {
    local repo=$1 hostname=$2 hostname_upper=${2^^}
    _install_substitute "$repo/etc/hostname.tmpl"       /etc/hostname                      HOSTNAME="$hostname" &&
    _install_substitute "$repo/etc/hosts.tmpl"          /etc/hosts                         HOSTNAME="$hostname" &&
    _install_substitute "$repo/etc/issue.tmpl"          /etc/issue                         MAGI_NODES="$(_issue_node_row "$hostname")" &&
    _install_substitute "$repo/hypr/hyprlock.conf.tmpl" "$HOME/.config/hypr/hyprlock.conf" \
        HOSTNAME_UPPER="$hostname_upper" TAILNET_LABELS="$(_hyprlock_tailnet_labels)"
}

# Greeter node row: every MAGI node in 19-column cells, the local host marked.
_issue_node_row() {
    local node mark
    for node in "${MAGI_NODES[@]}"; do
        mark="  "
        [[ "$node" == "$1" ]] && mark=$' '
        printf '%s%-17s' "$mark" "${node^^}"
    done | sed 's/ *$//'
}

# One hyprlock label per MAGI node, stacked 16px apart under the header.
_hyprlock_tailnet_labels() {
    local i
    for i in "${!MAGI_NODES[@]}"; do
        (( i > 0 )) && echo
        cat <<EOF
label {
  monitor =
  text = cmd[update:30000] ~/.local/bin/archmagi tailnet ${MAGI_NODES[i]}
  color = rgba(bb0000aa)
  font_size = 10
  font_family = JetBrainsMono Nerd Font
  position = 48, $(( -68 - 16 * i ))
  halign = left
  valign = top
}
EOF
    done
}
