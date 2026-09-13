# `archmagi install monitors`: snapshot the live hyprctl monitor topology
# into ~/.config/hypr/hyprland/monit.lua, prompting per monitor for its scale.
# Re-run after attaching or removing displays.

# Detect live monitors, prompt for each scale, preview, confirm, then write.
# Requires Hyprland to be running and jq for JSON parsing.
# @return 0 on success or user-cancel at the final confirm, 1 on hard failure
_install_monitors() {
    local bar="${RED}▌${RESET}"

    command -v hyprctl >/dev/null || { echo "  $bar hyprctl not found; is Hyprland running?" >&2; return 1; }
    command -v jq      >/dev/null || { echo "  $bar jq not found (in requirements.pacman)"   >&2; return 1; }

    local json
    json=$(hyprctl monitors -j 2>/dev/null) || { echo "  $bar hyprctl monitors failed" >&2; return 1; }
    local count
    count=$(jq 'length' <<<"$json")
    (( count > 0 )) || { echo "  $bar no monitors reported by hyprctl" >&2; return 1; }

    printf "  %s ${BOLD}%d live monitor%s detected${RESET}\n" "$bar" "$count" \
        "$( (( count != 1 )) && echo s)"

    local lines=()
    local idx name w h scale
    for ((idx=0; idx<count; idx++)); do
        name=$(jq -r ".[$idx].name"   <<<"$json")
        w=$(jq -r    ".[$idx].width"  <<<"$json")
        h=$(jq -r    ".[$idx].height" <<<"$json")
        scale=$(jq -r ".[$idx].scale" <<<"$json")
        scale=$(_monitors_clean_scale "$scale")

        echo
        printf "  %s ${AMBER}%s${RESET}  %sx%s\n" "$bar" "$name" "$w" "$h"
        _monitors_prompt_scale "$scale"
        lines+=("hl.monitor({ output = \"$name\", mode = \"${w}x${h}\", position = \"auto\", scale = $PROMPT_SCALE })")
    done

    printf "\n  %s ${BOLD}PREVIEW${RESET}\n" "$bar"
    local line
    for line in "${lines[@]}"; do
        printf "  %s   %s\n" "$bar" "$line"
    done

    local dest="$HOME/.config/hypr/hyprland/monit.lua"
    printf "\n  %s write to ${AMBER}%s${RESET}? [y/N] " "$bar" "$dest"
    local ans
    read -r ans
    case "$ans" in
        [yY]*) ;;
        *) printf "  %s aborted by user\n" "$bar"; return 0 ;;
    esac

    mkdir -p "$(dirname "$dest")"
    local tmp
    tmp=$(mktemp)
    {
        printf -- '-- MONITORS\n'
        printf -- '-- See https://wiki.hypr.land/Configuring/Basics/Monitors/\n'
        printf -- '\n'
        for line in "${lines[@]}"; do
            printf '%s\n' "$line"
        done
    } > "$tmp"
    mv -f "$tmp" "$dest"

    local n=${#lines[@]} plural=""
    (( n != 1 )) && plural=s
    printf "  %s wrote ${AMBER}%s${RESET} (%d monitor line%s)\n" "$bar" "$dest" "$n" "$plural"
    printf "  %s reload Hyprland: ${AMBER}hyprctl reload${RESET}\n" "$bar"
}

# Read a scale (number, optionally fractional) with a default; re-prompts on
# invalid input. Empty input keeps the default.
# @param 1 default scale shown in the prompt
# @return chosen scale in PROMPT_SCALE (global)
_monitors_prompt_scale() {
    local default=$1 input
    PROMPT_SCALE=""
    while true; do
        printf "     scale [${AMBER}%s${RESET}] > " "$default"
        read -r input
        input=${input:-$default}
        if [[ "$input" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            PROMPT_SCALE=$(_monitors_clean_scale "$input")
            return 0
        fi
        printf "     ${RED}invalid${RESET}; try a number (e.g. 1, 1.25, 1.33, 1.5, 2)\n"
    done
}

# Strip trailing zeros from a scale string while preserving the integer part:
# 1.00 -> 1, 1.50 -> 1.5, 1.33 -> 1.33, 10 -> 10 (only digits after the dot
# are touched).
# @param 1 raw scale (e.g. from jq)
# @stdout cleaned scale
_monitors_clean_scale() {
    printf '%s' "$1" | sed -E 's/(\..*[1-9])0+$/\1/; s/\.0+$//'
}
