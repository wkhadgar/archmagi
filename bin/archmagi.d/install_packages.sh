# Repo packages are required: -Syu (not -S) because partial upgrades break
# Arch, and any failure aborts bootstrap. AUR packages are optional extras:
# installed one by one without -u, so an unrelated AUR package that fails to
# upgrade can't block bootstrap, and failures only warn.
_install_packages() {
    local repo=$1

    sudo pacman -Syu --needed --noconfirm - < "$repo/requirements.pacman" || return 1

    [[ -f "$repo/requirements.aur" ]] || return 0
    if ! command -v paru >/dev/null; then
        echo "  ${BAR} paru not installed; skipping $(wc -l < "$repo/requirements.aur") AUR packages" >&2
        echo "  ${BAR} install paru per README to enable AUR support, then re-run bootstrap" >&2
        return 0
    fi

    local pkg failed=()
    # fd 3 keeps paru's stdin on the terminal.
    while IFS= read -r -u 3 pkg; do
        [[ -n "$pkg" ]] || continue
        paru -S --needed --noconfirm "$pkg" || failed+=("$pkg")
    done 3< "$repo/requirements.aur"

    (( ${#failed[@]} == 0 )) || echo "  ${BAR} AUR packages failed, continuing without them: ${failed[*]}" >&2
    return 0
}
