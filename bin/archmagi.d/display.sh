DISPLAY_MODES=(mirror extend external internal)

cmd_display() {
    _display_outputs || return 1
    if [[ -z "$1" ]]; then
        _display_pick
    else
        _display_apply "$1"
    fi
}

# Sets OUT_INT (the laptop panel, or the first output on a desktop) and OUT_EXT
# (the first other output). `monitors all` includes disabled outputs, so one
# turned off by an earlier mode is still found.
_display_outputs() {
    local names
    names=$(hyprctl monitors all -j 2>/dev/null | jq -r '.[].name') || {
        _display_fail "hyprctl unavailable; is Hyprland running?"; return 1
    }
    OUT_INT=$(grep -m1 -E '^(eDP|LVDS|DSI)-' <<<"$names")
    [[ -n "$OUT_INT" ]] || OUT_INT=$(head -1 <<<"$names")
    OUT_EXT=$(grep -m1 -vxF "$OUT_INT" <<<"$names")
    [[ -n "$OUT_EXT" ]] || { _display_fail "ONLY ONE DISPLAY CONNECTED"; return 1; }
}

# Each mode first re-applies monit.lua, so a mirror or disabled rule from an
# earlier mode never sticks. Outputs monit.lua doesn't name get a preferred
# mode at scale 1.
_display_apply() {
    local mode=$1 extra
    case "$mode" in
        mirror)   extra="m({ output = ext, mode = 'preferred', position = 'auto', scale = 1, mirror = int })" ;;
        extend)   extra="" ;;
        external) extra="m({ output = int, disabled = true })" ;;
        internal) extra="m({ output = ext, disabled = true })" ;;
        *) echo "archmagi display: mode ${DISPLAY_MODES[*]}" >&2; return 1 ;;
    esac

    local out
    out=$(hyprctl eval "
local int, ext = '$OUT_INT', '$OUT_EXT'
local m, seen = hl.monitor, {}
hl.monitor = function(s) seen[s.output] = true; return m(s) end
dofile(os.getenv('HOME') .. '/.config/hypr/hyprland/monit.lua')
hl.monitor = m
for _, o in ipairs({ int, ext }) do
    if not seen[o] then m({ output = o, mode = 'preferred', position = 'auto', scale = 1 }) end
end
$extra" 2>&1)
    [[ "$out" == ok ]] || { _display_fail "${mode^^} FAILED: $out"; return 1; }
}

_display_pick() {
    local choice
    choice=$(printf '%s\n' \
        "MIRROR     // $OUT_EXT shows $OUT_INT" \
        "EXTEND     // separate desktops" \
        "EXTERNAL   // $OUT_EXT only" \
        "INTERNAL   // $OUT_INT only" \
        | rofi -dmenu -i -p "PROJECTION" -config "$HOME/.config/rofi/config.rasi") || return 0
    [[ -n "$choice" ]] || return 0
    choice=${choice%% *}
    _display_apply "${choice,,}"
}

# Errors also go to a notification: from Super+P there is no terminal.
_display_fail() {
    echo "archmagi display: $1" >&2
    notify-send -u normal "PROJECTION" "$1" 2>/dev/null
}
