# archmagi confirm: rofi 3-node consensus dialog. User vote alone gates the action;
# the other two MAGI always vote YES (theater). Do NOT randomize.

cmd_confirm() {
    local msg="${1:?usage: archmagi confirm <MESSAGE>}"

    if [[ -z "$WAYLAND_DISPLAY" && -z "$DISPLAY" ]]; then
        echo "archmagi confirm: no display (WAYLAND_DISPLAY/DISPLAY unset); refusing to invoke rofi" >&2
        return 1
    fi

    local self
    self=$(uname -n)
    self=${self%%.*}      # strip domain if FQDN
    self=${self^^}

    local others=() node
    for node in "${MAGI_NODES[@]}"; do
        [[ "${node^^}" != "$self" ]] && others+=("${node^^}")
    done

    local line1 line2 line3 fmt
    fmt='<span foreground="#666666" font="JetBrains Mono 11">%-12s > </span><span foreground="%s" font="JetBrains Mono Bold 11">%-3s</span>'
    printf -v line1 "$fmt" "${others[0]}" "#ffbf00" "YES"
    printf -v line2 "$fmt" "${others[1]}" "#ffbf00" "YES"
    printf -v line3 "$fmt" "$self"        "#cc0000" "?"

    local mesg
    mesg="<span foreground='#cc0000' font='JetBrains Mono Bold 14'>${msg}</span>
<span foreground='#666666' font='JetBrains Mono 10'>-- MAGI CONSENSUS REQUIRED --</span>

$line1
$line2
$line3"

    local deny=">>  ${self} > NO  (ABORT)"
    local acpt=">>  ${self} > YES (PROCEED)"

    local choice
    choice=$(printf '%s\n%s\n' "$deny" "$acpt" | rofi -sync -dmenu \
        -config ~/.config/rofi/confirm-config.rasi \
        -mesg "$mesg")

    [[ "$choice" == "$acpt" ]]
}
