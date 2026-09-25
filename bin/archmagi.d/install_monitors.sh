_install_monitors() {
    command -v hyprctl >/dev/null || { echo "  $BAR hyprctl not found; is Hyprland running?" >&2; return 1; }
    command -v jq      >/dev/null || { echo "  $BAR jq not found (in requirements.pacman)"   >&2; return 1; }

    local json
    json=$(hyprctl monitors -j 2>/dev/null) || { echo "  $BAR hyprctl monitors failed" >&2; return 1; }
    local count
    count=$(jq 'length' <<<"$json")
    (( count > 0 )) || { echo "  $BAR no monitors reported by hyprctl" >&2; return 1; }

    printf "  %s ${BOLD}%d live monitor%s detected${RESET}\n" "$BAR" "$count" \
        "$( (( count != 1 )) && echo s)"

    local lines=()
    local name w h scale
    # fd 3 keeps stdin free for the scale prompt inside the loop.
    while IFS=$'\t' read -r -u 3 name w h scale; do
        scale=$(_monitors_clean_scale "$scale")

        echo
        printf "  %s ${AMBER}%s${RESET}  %sx%s\n" "$BAR" "$name" "$w" "$h"
        _monitors_prompt_scale "$scale"
        lines+=("hl.monitor({ output = \"$name\", mode = \"${w}x${h}\", position = \"auto\", scale = $PROMPT_SCALE })")
    done 3< <(jq -r '.[] | [.name, .width, .height, .scale] | @tsv' <<<"$json")

    printf "\n  %s ${BOLD}PREVIEW${RESET}\n" "$BAR"
    local line
    for line in "${lines[@]}"; do
        printf "  %s   %s\n" "$BAR" "$line"
    done

    local dest="$HOME/.config/hypr/hyprland/monit.lua"
    echo
    _ask_yn "write to ${AMBER}${dest}${RESET}?" || { printf "  %s aborted by user\n" "$BAR"; return 0; }

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
    printf "  %s wrote ${AMBER}%s${RESET} (%d monitor line%s)\n" "$BAR" "$dest" "$n" "$plural"
    printf "  %s reload Hyprland: ${AMBER}hyprctl reload${RESET}\n" "$BAR"
}

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

# 1.00 -> 1, 1.50 -> 1.5, 10 -> 10. Only touches digits after the dot.
_monitors_clean_scale() {
    printf '%s' "$1" | sed -E 's/(\..*[1-9])0+$/\1/; s/\.0+$//'
}
