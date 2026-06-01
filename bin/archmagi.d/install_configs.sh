# Generic config deployment for `archmagi install bootstrap`.

# Copy every shipped config from the repo into its live destination.
# Host-specific files are handled by the template phase.
# Strips `.tmpl` files from live destinations so only rendered files remain.
# @param 1 absolute path to the archmagi repo root
_install_configs() {
    local repo=$1

    sudo cp -r "$repo"/etc/. /etc/
    sudo cp -r "$repo"/usr/. /usr/
    sudo chmod +x /usr/local/bin/start-greeter.sh

    mkdir -p ~/.config/{hypr,waybar,rofi,nvim,kitty,tmux,btop,swaync}
    cp "$repo/.zshrc" ~/.zshrc
    cp -r "$repo"/hypr/. ~/.config/hypr/
    cp -r "$repo"/waybar/. ~/.config/waybar/
    cp -r "$repo"/rofi/. ~/.config/rofi/
    cp -r "$repo"/nvim/. ~/.config/nvim/
    cp -r "$repo"/kitty/. ~/.config/kitty/
    cp -r "$repo"/tmux/. ~/.config/tmux/
    cp -r "$repo"/btop/. ~/.config/btop/
    cp -r "$repo"/swaync/. ~/.config/swaync/

    mkdir -p ~/.local/bin/archmagi.d
    # `install` unlinks the destination first, so the running dispatcher
    # keeps reading from its still-open inode while the path is repointed
    # to a fresh one. Plain cp would truncate-and-rewrite in place, which
    # corrupts an in-flight archmagi mid-execution.
    install -m 755 "$repo/bin/archmagi" ~/.local/bin/archmagi
    cp -r "$repo"/bin/archmagi.d/. ~/.local/bin/archmagi.d/

    mkdir -p ~/wallpapers
    cp "$repo/wallpapers/nerv-wallpaper.png" ~/wallpapers/
    mkdir -p ~/images/screenshots

    sudo find /etc -name '*.tmpl' -delete 2>/dev/null
    find ~/.config -name '*.tmpl' -delete 2>/dev/null
}

# Locate the archmagi repo root by looking for a known template.
# @return absolute repo path on stdout, non-zero on failure
_install_find_repo() {
    if [[ -f "$PWD/etc/hostname.tmpl" ]]; then
        echo "$PWD"
        return 0
    fi
    echo "templates not found; run from the archmagi repo (must contain etc/hostname.tmpl)" >&2
    return 1
}
