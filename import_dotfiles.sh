#!/usr/bin/bash

sudo cp -r ./etc/* /etc/
sudo cp -r ./usr/* /usr/
sudo chmod +x /usr/local/bin/start-greeter.sh

mkdir -p ~/.config/{hypr,waybar,rofi,nvim,kitty,tmux,fastfetch,btop,swaync}

cp ./.zshrc ~/.zshrc
cp -r ./hypr/* ~/.config/hypr/
cp -r ./waybar/* ~/.config/waybar/
cp -r ./rofi/* ~/.config/rofi/
cp -r ./nvim/* ~/.config/nvim/
cp -r ./kitty/* ~/.config/kitty/
cp -r ./tmux/* ~/.config/tmux/
cp -r ./fastfetch/* ~/.config/fastfetch/
cp -r ./btop/* ~/.config/btop/
cp -r ./swaync/* ~/.config/swaync/

mkdir -p ~/.local/bin/magi.d
cp ./bin/magi ~/.local/bin/magi
cp -r ./bin/magi.d/. ~/.local/bin/magi.d/
mkdir -p ~/wallpapers && cp ./wallpapers/nerv-wallpaper.png ~/wallpapers/
mkdir -p ~/images/screenshots
