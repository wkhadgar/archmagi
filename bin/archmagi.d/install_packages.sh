# Package installation for `archmagi install bootstrap`.

# Install pacman packages, plus AUR via paru when present.
# -Syu (not -S): partial upgrades break Arch, so refresh and upgrade together.
# --noconfirm: the bootstrap prompt already gathered consent.
# @param 1 absolute path to the archmagi repo root
_install_packages() {
    local repo=$1

    sudo pacman -Syu --needed --noconfirm - < "$repo/requirements.pacman" || return 1

    if [[ -f "$repo/requirements.aur" ]]; then
        if command -v paru >/dev/null; then
            paru -Syu --needed --noconfirm - < "$repo/requirements.aur" || return 1
        else
            echo "  ${RED}▌${RESET} paru not installed; skipping $(wc -l < "$repo/requirements.aur") AUR packages" >&2
            echo "  ${RED}▌${RESET} install paru per README to enable AUR support, then re-run bootstrap" >&2
        fi
    fi
}
