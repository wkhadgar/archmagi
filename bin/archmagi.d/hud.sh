# archmagi hud: toggle a floating live status panel.
# Spawns a kitty window of class `archmagi-hud` running an `archmagi fetch`
# loop. Hypr window rules (winwo.lua) pin it floating/centered/borderless.
# A second invocation closes it by address; class-based selectors on the
# Hyprland 0.56 Lua dispatcher API are ignored (they close the focused
# window), so we query hl.get_windows via hyprctl clients first.

cmd_hud() {
    local addrs addr
    addrs=$(hyprctl clients -j 2>/dev/null \
        | jq -r '.[] | select(.class == "archmagi-hud") | .address')

    if [[ -n "$addrs" ]]; then
        while IFS= read -r addr; do
            [[ -n "$addr" ]] || continue
            hyprctl dispatch "hl.dsp.window.close({window=\"$addr\"})" >/dev/null
        done <<< "$addrs"
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
