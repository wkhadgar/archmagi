# _install_substitute TEMPLATE DEST KEY=value ...
# Bash string replacement (so values with special characters survive without
# escaping). Written 0644; root-owned when dest is under /etc, /usr, or /boot.
_install_substitute() {
    local tmpl=$1 dest=$2; shift 2
    [[ -r "$tmpl" ]] || { echo "template missing: $tmpl" >&2; return 1; }

    local content
    content=$(<"$tmpl")
    local kv key val
    for kv in "$@"; do
        key=${kv%%=*}
        val=${kv#*=}
        content=${content//__${key}__/$val}
    done

    local tmp
    tmp=$(mktemp) || return 1
    trap 'rm -f "$tmp"' RETURN

    # Terminating newline matters for /etc/hostname, /etc/hosts.
    printf '%s\n' "$content" > "$tmp" || return 1

    if [[ "$dest" == /etc/* || "$dest" == /usr/* || "$dest" == /boot/* ]]; then
        sudo install -D -m 644 -o root -g root "$tmp" "$dest"
    else
        install -D -m 644 "$tmp" "$dest"
    fi || { echo "failed to install $dest" >&2; return 1; }
}
