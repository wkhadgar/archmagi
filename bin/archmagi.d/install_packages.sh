# Package installation for `archmagi install bootstrap`.

# Install repo packages (always) and AUR packages (only if paru is present).
# -Syu refreshes the pacman db AND upgrades the system before installing
# missing entries from the list. Without -y, a stale db serves 404s for
# package versions the mirrors have rotated out; without -u, pacman risks a
# partial-upgrade landmine.
# --needed skips already-installed packages.
# --noconfirm avoids prompts mid-bootstrap (the user has already confirmed at
# the bootstrap prompt step).
# @param 1 absolute path to the archmagi repo root
_install_packages() {
    local repo=$1

    sudo pacman -Syu --needed --noconfirm - < "$repo/requirements.pacman" || return 1

    if [[ -f "$repo/requirements.aur" ]]; then
        if command -v paru >/dev/null; then
            paru -Syu --needed --noconfirm - < "$repo/requirements.aur" || return 1
        else
            echo "  ${RED}▌${RESET} paru not installed — skipping $(wc -l < "$repo/requirements.aur") AUR packages" >&2
            echo "  ${RED}▌${RESET} install paru per README to enable AUR support, then re-run bootstrap" >&2
        fi
    fi
}
