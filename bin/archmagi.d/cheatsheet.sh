# archmagi cheatsheet: rofi popup of all hl.bind(...) calls from binds.lua.
# The Lua parser (cheatsheet.lua) stubs the hl.* API, dofiles the binds file,
# and emits one "KEYS -> DESC" row per bind. Workspace-1..10 loop binds are
# filtered; keys are prettified; ~/.local/bin/ prefixes are stripped. Pass a
# `desc = "..."` on the bind's options table to override the auto-derived text.

cmd_cheatsheet() {
    local binds_file="$HOME/.config/hypr/hyprland/binds.lua"
    [[ -f "$binds_file" ]] || { echo "binds.lua not found at $binds_file" >&2; return 1; }
    command -v lua >/dev/null || { echo "lua not installed" >&2; return 1; }

    lua "$ARCHMAGI_LIB/cheatsheet.lua" "$binds_file" \
        | rofi -dmenu -i -p "MAGI BINDS" \
            -config "$HOME/.config/rofi/config.rasi" \
            -lines 22 -width 70 >/dev/null
}
