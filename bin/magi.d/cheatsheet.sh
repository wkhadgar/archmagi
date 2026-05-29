# magi cheatsheet — rofi popup of all `bind = ` lines from binds.conf, with
# variable substitution, ~/.local/bin/ stripping, key prettification, and
# workspace-1..9 / shift-1..9 binds filtered out.

cmd_cheatsheet() {
    local binds_file="$HOME/.config/hypr/hyprland/binds.conf"
    [[ -f "$binds_file" ]] || { echo "binds.conf not found at $binds_file" >&2; return 1; }

    awk '
        function trim(s) {
            sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s
        }
        /^[$][a-zA-Z_]+[[:space:]]*=/ {
            eq = index($0, "=")
            name = trim(substr($0, 1, eq - 1))
            value = trim(substr($0, eq + 1))
            sub(/[[:space:]]*#.*$/, "", value)
            vars[name] = trim(value)
            next
        }
        /^bind[[:space:]]*=/ {
            sub(/^bind[[:space:]]*=[[:space:]]*/, "")
            sub(/[[:space:]]*#.*$/, "")
            line = $0
            for (v in vars) {
                while ((pos = index(line, v)) > 0) {
                    line = substr(line, 1, pos - 1) vars[v] substr(line, pos + length(v))
                }
            }
            n = split(line, parts, ",")
            if (n < 3) next
            mod = trim(parts[1]); key = trim(parts[2]); action = trim(parts[3])
            args = ""
            for (i = 4; i <= n; i++) args = args (i > 4 ? "," : "") parts[i]
            args = trim(args)

            if ((action == "workspace" || action == "movetoworkspace") && key ~ /^[0-9]$/) next

            if      (key == "slash")   key = "/"
            else if (key == "left")    key = "←"
            else if (key == "right")   key = "→"
            else if (key == "up")      key = "↑"
            else if (key == "down")    key = "↓"
            else if (key == "PRINT")   key = "PrtSc"
            else if (key == "SUPER_L") key = "Super"

            combo = (mod == "") ? key : mod " + " key

            if (action == "exec") {
                desc = args
            } else {
                desc = action
                if (args != "") desc = desc " " args
            }
            sub("^" ENVIRON["HOME"] "/\\.local/bin/", "", desc)
            sub(/^~\/\.local\/bin\//, "", desc)

            printf "%-25s →  %s\n", combo, desc
        }
    ' "$binds_file" | rofi -dmenu -i -p "MAGI BINDS" \
        -config "$HOME/.config/rofi/config.rasi" \
        -lines 22 -width 70 >/dev/null
}
