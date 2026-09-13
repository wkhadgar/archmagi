# archmagi cheatsheet: rofi popup of all hl.bind(...) calls from binds.lua.
# The Lua parser (cheatsheet.lua) stubs the hl.* API, dofiles the binds file,
# and emits one "DISPLAY\tHYPRCTL_ARG" row per bind. rofi shows the DISPLAY
# column; on selection we look up the row by index and fire the paired
# hyprctl dispatch call — Escape/no-selection is a silent no-op. A
# `desc = "..."` on the bind's options table overrides the auto-derived text.

cmd_cheatsheet() {
    local binds_file="$HOME/.config/hypr/hyprland/binds.lua"
    [[ -f "$binds_file" ]] || { echo "binds.lua not found at $binds_file" >&2; return 1; }
    command -v lua >/dev/null || { echo "lua not installed" >&2; return 1; }

    local rows idx dispatch
    rows=$(lua "$ARCHMAGI_LIB/cheatsheet.lua" "$binds_file" --with-dispatch)

    idx=$(cut -f1 <<<"$rows" | rofi -dmenu -i -p "MAGI BINDS" \
            -config "$HOME/.config/rofi/config.rasi" \
            -lines 22 -width 70 -format i)
    [[ -n "$idx" ]] || return 0

    dispatch=$(sed -n "$((idx + 1))p" <<<"$rows" | cut -f2)
    [[ -n "$dispatch" ]] || return 0

    hyprctl dispatch "$dispatch" >/dev/null
}
