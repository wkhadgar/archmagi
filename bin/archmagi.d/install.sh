# archmagi install — bootstrap, boot theme, monitor refresh, sync back.

cmd_install() {
    case "$1" in
        bootstrap) shift; _install_bootstrap "$@" ;;
        boot)      shift; _install_boot      "$@" ;;
        monitors)  shift; _install_monitors  "$@" ;;
        sync)      shift; _install_sync      "$@" ;;
        *) echo "magi install: subcommand 'bootstrap', 'boot', 'monitors', or 'sync'" >&2; return 1 ;;
    esac
}

# ── Detection helpers ──────────────────────────────────────────────

# Echoes: laptop | desktop | server
# laptop = any BAT* in /sys/class/power_supply
# desktop = no battery, any DRM connector marked "connected"
# server = no battery AND no connected display
_install_detect_profile() {
    if compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
        echo laptop
        return
    fi
    if grep -lF connected /sys/class/drm/*/status 2>/dev/null | head -1 >/dev/null; then
        echo desktop
    else
        echo server
    fi
}

_install_detect_bootloader() {
    if [[ -f /etc/default/grub ]] && command -v grub-mkconfig >/dev/null; then
        echo grub
    elif [[ -f /boot/limine.conf || -f /boot/limine.cfg || -f /etc/limine.conf ]]; then
        echo limine
    else
        echo unknown
    fi
}

# Echoes "NAME RESxRES@REFRESH SCALE" per focused/active monitor.
# Empty if hyprctl isn't available (fresh install before first Hyprland session).
_install_detect_monitors() {
    command -v hyprctl >/dev/null || return
    hyprctl monitors 2>/dev/null | awk '
        function flush() {
            if (name != "" && resolution != "") {
                printf "%s %s@%dHz %s\n", name, resolution, refresh, scale
            }
        }
        /^Monitor / {
            flush()
            name = $2; resolution = ""; refresh = 0; scale = "1.0"
        }
        /^[[:space:]]+[0-9]+x[0-9]+@/ && resolution == "" {
            split($1, a, "@"); resolution = a[1]; refresh = int(a[2])
        }
        /^[[:space:]]+scale: / { scale = $2 }
        END { flush() }
    '
}

# ── Prompt helpers ─────────────────────────────────────────────────

# Picklist of MAGI_NODES + custom. Returns chosen hostname on stdout.
_install_prompt_hostname() {
    local current=${1:-} bar="${RED}▌${RESET}"
    local i n=${#MAGI_NODES[@]} choice host
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
        echo "$current"; return
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= n )); then
        echo "${MAGI_NODES[choice-1]}"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice == n+1 )); then
        printf "  %s hostname: " "$bar"
        read -r host
        [[ -z "$host" ]] && { echo "empty hostname" >&2; return 1; }
        echo "$host"
    else
        echo "invalid choice" >&2; return 1
    fi
}

# Pick laptop / desktop / server, defaulting to the detected hint.
_install_prompt_profile_role() {
    local hint=${1:-desktop} bar="${RED}▌${RESET}"
    local choice
    echo
    echo "  $bar ${BOLD}PROFILE${RESET}"
    echo "  $bar   1) laptop"
    echo "  $bar   2) desktop"
    echo "  $bar   3) server"
    printf "  %s pick [1-3, default %s]: " "$bar" "$hint"
    read -r choice
    if [[ -z "$choice" ]]; then echo "$hint"; return; fi
    case "$choice" in
        1) echo laptop ;;
        2) echo desktop ;;
        3) echo server ;;
        *) echo "invalid choice" >&2; return 1 ;;
    esac
}

# Render the detected/decided values and ask for final go-ahead.
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

# ── Bootstrap (phases 1–3: detect, prompt, persist /etc/magi/profile) ──

_install_bootstrap() {
    local bar="${RED}▌${RESET}" sep="${MUTED}//${RESET}"

    # 1. Detect
    local prof_hint bootloader
    prof_hint=$(_install_detect_profile)
    bootloader=$(_install_detect_bootloader)

    # 2. Prompt (with hints)
    local profile hostname current_host
    profile=$(_install_prompt_profile_role "$prof_hint") || return 1

    current_host=$(uname -n); current_host=${current_host%%.*}
    hostname=$(_install_prompt_hostname "$current_host") || return 1

    # 3. Confirm
    _install_prompt_confirm "$profile" "$hostname" "$bootloader" || {
        echo "  $bar aborted by user." >&2
        return 1
    }

    # 4. Persist profile to /etc/magi/profile
    sudo mkdir -p /etc/magi
    {
        printf 'profile=%s\n' "$profile"
        printf 'hostname=%s\n' "$hostname"
        printf 'bootloader=%s\n' "$bootloader"
    } | sudo tee /etc/magi/profile >/dev/null

    echo
    printf "  %s ${BOLD}MAGI BOOTSTRAP${RESET} %s ${AMBER}phase 1-3 complete${RESET}\n" "$bar" "$sep"
    printf "  %s   wrote ${AMBER}/etc/magi/profile${RESET}\n" "$bar"
    printf "  %s   ${MUTED}next: templates, configs, packages, boot — not yet wired${RESET}\n" "$bar"
}

# ── Stubs for not-yet-implemented subcommands ──────────────────────

_install_monitors() {
    echo "magi install monitors: not yet implemented" >&2
    return 1
}

_install_sync() {
    echo "magi install sync: not yet implemented" >&2
    return 1
}

# ── Existing boot theme (unchanged) ────────────────────────────────

_install_boot() {
    # GRUB wins ties since it's more common.
    if [[ -f /etc/default/grub ]] && command -v grub-mkconfig >/dev/null; then
        _boot_grub
    elif [[ -f /boot/limine.conf || -f /boot/limine.cfg || -f /etc/limine.conf ]]; then
        _boot_limine
    else
        echo "no supported bootloader detected (need grub or limine)" >&2
        return 1
    fi
}

_boot_grub() {
    local theme=/usr/share/grub/themes/nerv/theme.txt
    local config=/etc/default/grub
    [[ -f $theme ]] || { echo "theme missing at $theme — run import_dotfiles.sh first" >&2; return 1; }

    local changed=0

    if sudo grep -qF "GRUB_THEME=\"$theme\"" "$config"; then
        :
    elif sudo grep -q '^GRUB_THEME=' "$config"; then
        sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$theme\"|" "$config"
        changed=1
    else
        echo "GRUB_THEME=\"$theme\"" | sudo tee -a "$config" >/dev/null
        changed=1
    fi

    # GRUB needs png.mod preloaded to decode the PNG background
    if ! sudo grep -E '^GRUB_PRELOAD_MODULES=".*\bpng\b' "$config" >/dev/null; then
        if sudo grep -q '^GRUB_PRELOAD_MODULES=' "$config"; then
            sudo sed -i 's/^GRUB_PRELOAD_MODULES="\([^"]*\)"/GRUB_PRELOAD_MODULES="\1 png"/' "$config"
        else
            echo 'GRUB_PRELOAD_MODULES="png"' | sudo tee -a "$config" >/dev/null
        fi
        changed=1
    fi

    if (( changed )); then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        echo "MAGI BOOT theme installed (grub) — reboot to see it."
    else
        echo "MAGI BOOT theme already current (grub) — skipping grub-mkconfig."
    fi
}

_boot_limine() {
    local config
    for candidate in /boot/limine.conf /boot/limine.cfg /etc/limine.conf; do
        [[ -f "$candidate" ]] && { config="$candidate"; break; }
    done
    [[ -n "$config" ]] || { echo "limine config not found" >&2; return 1; }

    local src=/usr/share/nerv/boot-background.png
    [[ -f "$src" ]] || { echo "wallpaper missing at $src — run import_dotfiles.sh first" >&2; return 1; }

    local staged=/boot/nerv-bg.png
    sudo cp "$src" "$staged"

    local block
    block=$(cat <<EOF
# >>> magi boot — NERV theme (do not edit between these markers)
wallpaper: boot():/nerv-bg.png
term_background: 0a0a0a
term_foreground: eeeeee
term_palette: 1a1919;cc0000;7bd88f;ffbf00;948ae3;fc618d;5ad4e6;f7f1ff
term_background_brightness: 0.5
interface_branding: MAGI SYSTEM // NERV HQ
# <<< magi boot
EOF
)
    local tmp
    tmp=$(mktemp)
    sudo sed '/^# >>> magi boot/,/^# <<< magi boot/d' "$config" \
        | awk -v b="$block" '
            !done && /^\// { print b; done = 1 }
            { print }
            END { if (!done) print b }
        ' > "$tmp"
    sudo cp "$tmp" "$config"
    rm -f "$tmp"
    echo "MAGI BOOT theme installed (limine: $config) — reboot to see it."
}
