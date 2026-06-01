# archmagi hud: toggle a floating live status panel.
# Spawns a kitty window of class `archmagi-hud` running an `archmagi fetch` loop.
# Hypr window rules (winwo.conf) pin it floating/centered/borderless.

cmd_hud() {
    if hyprctl clients -j 2>/dev/null | grep -q '"class": "archmagi-hud"'; then
        hyprctl dispatch closewindow class:^archmagi-hud$ >/dev/null
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
