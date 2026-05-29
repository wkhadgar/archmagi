#!/usr/bin/bash

sudo cp -r ./greetd/* /etc/greetd/
sudo cp ./issue /etc/issue
sudo cp ./start-greeter.sh /usr/local/bin/start-greeter.sh
sudo chmod +x /usr/local/bin/start-greeter.sh

cp ./.zshrc ~/.zshrc
cp -r ./hypr/* ~/.config/hypr/
cp -r ./waybar/* ~/.config/waybar/
cp -r ./rofi/* ~/.config/rofi/
cp -r ./nvim/* ~/.config/nvim/
cp -r ./kitty/* ~/.config/kitty/
mkdir -p ~/.config/tmux && cp -r ./tmux/* ~/.config/tmux/
cp -r ./fastfetch/* ~/.config/fastfetch/
cp -r ./btop/* ~/.config/btop/
cp -r ./swaync/* ~/.config/swaync/

mkdir -p ~/.local/bin && cp ./bin/magi ~/.local/bin/magi
mkdir -p ~/wallpapers && cp ./wallpapers/nerv-wallpaper.png ~/wallpapers/
