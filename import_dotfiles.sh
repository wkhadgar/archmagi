#!/usr/bin/bash
# Resolve script dir so this works whether sourced or executed, from any cwd.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

sudo cp -r "$HERE"/etc/* /etc/
sudo cp -r "$HERE"/usr/* /usr/
sudo chmod +x /usr/local/bin/start-greeter.sh

mkdir -p ~/.config/{hypr,waybar,rofi,nvim,kitty,tmux,btop,swaync}

cp "$HERE/.zshrc" ~/.zshrc
cp -r "$HERE"/hypr/* ~/.config/hypr/
cp -r "$HERE"/waybar/* ~/.config/waybar/
cp -r "$HERE"/rofi/* ~/.config/rofi/
cp -r "$HERE"/nvim/* ~/.config/nvim/
cp -r "$HERE"/kitty/* ~/.config/kitty/
cp -r "$HERE"/tmux/* ~/.config/tmux/
cp -r "$HERE"/btop/* ~/.config/btop/
cp -r "$HERE"/swaync/* ~/.config/swaync/

mkdir -p ~/.local/bin/archmagi.d
cp "$HERE/bin/archmagi" ~/.local/bin/archmagi
cp -r "$HERE"/bin/archmagi.d/. ~/.local/bin/archmagi.d/
mkdir -p ~/wallpapers && cp "$HERE/wallpapers/nerv-wallpaper.png" ~/wallpapers/
mkdir -p ~/images/screenshots
