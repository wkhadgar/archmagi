_install_sync_excluded() {
    [[ "$1" == nvim/lazy-lock.json ]] || _map_templated "$1"
}

# Returns 2 if the user picked `q` at the prompt so the caller can bail early.
_install_sync_file() {
    local live=$1 repo_rel=$2 abs_repo=$3
    local repo_file="$abs_repo/$repo_rel"
    _install_sync_excluded "$repo_rel" && return 0
    [[ -e "$live" ]] || return 0

    local sudo_cmd=""
    [[ "$live" == /etc/* || "$live" == /usr/* ]] && sudo_cmd=sudo

    if [[ -e "$repo_file" ]] && $sudo_cmd diff -q "$live" "$repo_file" >/dev/null 2>&1; then
        return 0
    fi

    if [[ -e "$repo_file" ]]; then
        printf "\n  ${BAR} ${BOLD}diff${RESET}   %s\n" "$repo_rel"
        $sudo_cmd diff -u "$repo_file" "$live" | head -20
    else
        printf "\n  ${BAR} ${BOLD}new${RESET}    %s\n" "$repo_rel"
    fi
    printf "  ${BAR} pull live → repo? [y/N/q] "
    local ans; read -r ans
    case "$ans" in
        [yY]*)
            mkdir -p "$(dirname "$repo_file")"
            $sudo_cmd cp "$live" "$repo_file"
            [[ -n "$sudo_cmd" ]] && sudo chown "$USER:$USER" "$repo_file"
            ;;
        [qQ]*) return 2 ;;
    esac
    return 0
}

# File lists are read on fd 3 so the prompt's `read` still gets the terminal.
_install_sync_tree() {
    local live_root=$1 repo_rel_root=$2 abs_repo=$3
    [[ -d "$live_root" ]] || return 0
    local f
    while IFS= read -r -u 3 f; do
        _install_sync_file "$f" "$repo_rel_root/${f#"$live_root/"}" "$abs_repo" || return 2
    done 3< <(find "$live_root" -type f 2>/dev/null)
}

_sync_entry() {
    local kind=$1 live=$2 rel=$3 f
    case "$kind" in
        file|exe) _install_sync_file "$live" "$rel" "$repo" ;;
        tree)     _install_sync_tree "$live" "$rel" "$repo" ;;
        root)
            while IFS= read -r -u 3 f; do
                _install_sync_file "$live/${f#"$rel/"}" "$f" "$repo" || return 2
            done 3< <(_map_repo_files "$rel")
            ;;
    esac
}

_install_sync() {
    local repo
    repo=$(_install_find_repo) || return 1
    if _map_each _sync_entry; then
        echo "  ${BAR} sync done"
    else
        echo "  ${BAR} sync aborted"
    fi
}
