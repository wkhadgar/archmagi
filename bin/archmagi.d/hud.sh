# archmagi hud: toggle a floating live status panel.
# Spawns a kitty window of class `archmagi-hud` running an `archmagi fetch`
# loop. Hypr window rules (winwo.lua) pin it floating/centered/borderless.
# Toggle-close by killing the kitty PID reported by `hyprctl clients`;
# Hyprland's 0.56 Lua dispatcher API doesn't accept an address selector
# from outside its own Lua context, so `hyprctl dispatch` can't target
# a specific window reliably.

cmd_hud() {
    local pids pid
    pids=$(hyprctl clients -j 2>/dev/null \
        | jq -r '.[] | select(.class == "archmagi-hud") | .pid')

    if [[ -n "$pids" ]]; then
        while IFS= read -r pid; do
            [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 0 )) && kill "$pid" 2>/dev/null
        done <<< "$pids"
        return 0
    fi

    command -v kitty >/dev/null || { echo "archmagi hud: kitty is not installed" >&2; return 1; }

    setsid -f kitty \
        --class=archmagi-hud --title=ARCHMAGI_HUD \
        --override hide_window_decorations=yes \
        --override cursor_blink_interval=0 \
        --override enable_audio_bell=no \
        --override confirm_os_window_close=0 \
        bash -c \
        'stty -echo 2>/dev/null; printf "\033[?25l"; while :; do out=$(~/.local/bin/archmagi fetch); printf "\033[H%s\033[J" "$out"; sleep 1; done' \
        >/dev/null 2>&1
}
