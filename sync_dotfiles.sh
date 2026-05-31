#!/usr/bin/bash
# Resolve script dir so this works whether sourced or executed, from any cwd.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

sudo cp /etc/greetd/config.toml "$HERE/etc/greetd/config.toml"
sudo cp /etc/issue "$HERE/etc/issue"
sudo cp /usr/local/bin/start-greeter.sh "$HERE/usr/local/bin/start-greeter.sh"

cp ~/.zshrc "$HERE/.zshrc"
cp -r ~/.config/hypr/* "$HERE/hypr/"
cp -r ~/.config/waybar/* "$HERE/waybar/"
cp -r ~/.config/rofi/* "$HERE/rofi/"
cp -r ~/.config/nvim/* "$HERE/nvim/"
cp -r ~/.config/kitty/* "$HERE/kitty/"
cp -r ~/.config/tmux/* "$HERE/tmux/"
cp -r ~/.config/btop/* "$HERE/btop/"
cp -r ~/.config/swaync/* "$HERE/swaync/"
cp ~/.local/bin/archmagi "$HERE/bin/archmagi"
mkdir -p "$HERE/bin/archmagi.d" && cp -r ~/.local/bin/archmagi.d/. "$HERE/bin/archmagi.d/"
cp ~/wallpapers/nerv-wallpaper.png "$HERE/wallpapers/"
