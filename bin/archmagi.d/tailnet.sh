# archmagi tailnet: uppercased "<HOST> [STATE]" line for hyprlock cmd labels.

cmd_tailnet() {
    local host="${1:?usage: archmagi tailnet <hostname>}"
    printf '%-12s[%s]\n' "${host^^}" "$(_tailnet_state "$host")"
}
