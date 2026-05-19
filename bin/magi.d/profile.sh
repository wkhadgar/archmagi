# magi profile — power-profiles-daemon wrapper with a NERV-themed rofi picker.
# Host-specific to laptops with PPD installed; balthasar's flavor commit adds
# this and the matching waybar battery `on-click` binding.

_profile_center() {
    local text="$1" width="$2"
    local len=${#text}
    local lpad=$(( (width - len) / 2 ))
    local rpad=$(( width - len - lpad ))
    printf '%*s%s%*s' "$lpad" "" "$text" "$rpad" ""
}

PROFILES=(power-saver balanced performance)

declare -A PROFILE_ICONS=(
    [power-saver]="󰒲"
    [balanced]="󰗑"
    [performance]="󱐋"
)

declare -A PROFILE_DISPLAY=(
    [power-saver]="POWER SAVE"
    [balanced]="BALANCED"
    [performance]="PERFORMANCE"
)

declare -A PROFILE_NERV=(
    [power-saver]="SYNAPSE LOW"
    [balanced]="SYNAPSE NORM"
    [performance]="SYNAPSE MAX"
)

_profile_pick() {
    local current="$1"

    local opts=() profile marker desc label
    for profile in "${PROFILES[@]}"; do
        marker=" "
        [[ "$profile" == "$current" ]] && marker="✓"
        desc=$(_profile_center "${PROFILE_NERV[$profile]}" 14)
        printf -v label "%s   %-12s ⟨ %s ⟩ %s" "${PROFILE_ICONS[$profile]}" "${PROFILE_DISPLAY[$profile]}" "$desc" "$marker"
        opts+=("$label")
    done

    local mesg
    mesg="<span foreground='#cc0000' font='JetBrains Mono Bold 14'>POWER REGULATION</span>
<span foreground='#666666' font='JetBrains Mono 10'>-- TACTICAL DESIGNATION REQUIRED --</span>

<span foreground='#666666' font='JetBrains Mono 11'>ACTIVE PROTOCOL ▸ </span><span foreground='#ffbf00' font='JetBrains Mono Bold 11'>${PROFILE_DISPLAY[$current]:-${current^^}}</span><span foreground='#444444' font='JetBrains Mono 10'>  · ${PROFILE_NERV[$current]:-}</span>"

    local choice
    choice=$(printf '%s\n' "${opts[@]}" | rofi -sync -dmenu \
        -config ~/.config/rofi/power-profile-config.rasi \
        -mesg "$mesg")

    [[ -z "$choice" ]] && return 1

    for profile in "${PROFILES[@]}"; do
        if [[ "$choice" == *"${PROFILE_DISPLAY[$profile]}"* ]]; then
            echo "$profile"
            return 0
        fi
    done
    return 1
}

cmd_profile() {
    command -v powerprofilesctl >/dev/null || {
        echo "powerprofilesctl not installed — run: sudo pacman -S power-profiles-daemon python-gobject" >&2
        return 1
    }

    local current target
    current=$(powerprofilesctl get 2>/dev/null) || {
        echo "power-profiles-daemon not reachable — check: systemctl status power-profiles-daemon" >&2
        return 1
    }
    target="$1"

    if [[ -z "$target" ]]; then
        if [[ -n "$WAYLAND_DISPLAY" || -n "$DISPLAY" ]]; then
            target=$(_profile_pick "$current") || return 0
        else
            local sep="${MUTED}//${RESET}"
            echo
            printf "  %sACTIVE PROTOCOL%s   %s %s%s%s\n" "$RED" "$RESET" "$sep" "$AMBER" "$current" "$RESET"
            printf "  %sAVAILABLE%s         %s %s\n"     "$RED" "$RESET" "$sep" "${PROFILES[*]}"
            echo
            return 0
        fi
    fi

    if ! powerprofilesctl set "$target" 2>/dev/null; then
        echo "INVALID PROTOCOL '$target' — choices: ${PROFILES[*]}" >&2
        return 1
    fi

    printf "PROTOCOL SET ▸ %s → %s\n" "$current" "$target"
}
