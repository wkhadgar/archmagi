# Template substitution for `archmagi install bootstrap`.

# Substitute __KEY__ placeholders in a template, write the result atomically.
# Substitution uses bash string replacement so values with special characters
# survive without escaping. Writes go through sudo when dest is under /etc,
# /usr, or /boot.
# @param 1 source template path
# @param 2 destination path
# @param 3+ KEY=value substitution pairs
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

    # Always write a terminating newline (matters for /etc/hostname, /etc/hosts).
    printf '%s\n' "$content" > "$tmp" || return 1

    local dest_dir=${dest%/*}
    if [[ "$dest" == /etc/* || "$dest" == /usr/* || "$dest" == /boot/* ]]; then
        sudo mkdir -p "$dest_dir" || return 1
        sudo mv -f "$tmp" "$dest" || { echo "failed to install $dest" >&2; return 1; }
    else
        mkdir -p "$dest_dir" || return 1
        mv -f "$tmp" "$dest" || { echo "failed to install $dest" >&2; return 1; }
    fi
}
