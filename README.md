# MAGI SYSTEM // NERV HQ TERMINAL
> GOD'S IN HIS HEAVEN. ALL'S RIGHT WITH THE WORLD.

---

## Requirements

Get the AUR manager (here, paru for compatibility):
```bash
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
```

Then, get the packages:
```bash
sudo pacman -S --needed - < requirements.pacman
```

---

## Install

Each MAGI machine has its own branch (`melchior-1`, `casper-3`, `balthasar-2`) carrying host-specific tweaks (monitors, hostname, fastfetch footer, etc.). Check out the matching branch first, or stay on `main` for a fresh host.

```bash
git clone https://github.com/wkhadgar/dotfiles
cd dotfiles
git checkout <hostname>          # e.g. melchior-1 — or skip for main
source ./import_dotfiles.sh
chsh -s $(which zsh)
```

---

## The `magi` CLI

After install, `magi` lives at `~/.local/bin/magi` and is the entry point for the desktop's helper commands. Run `magi help` for the full list. Highlights:

- `magi status` — NERV-themed system overview (host, uptime, tailnet, updates, CPU/MEM/DISK/NET)
- `magi update` — interactive `paru -Syu` wrapper
- `magi cheatsheet` — rofi popup of all Hyprland keybindings (also bound to `SUPER+/`)
- `magi lock` / `reboot` / `exit` / `shutdown` — power actions, gated by the MAGI consensus dialog
- `magi grub` — install the NERV GRUB theme

---

## Sync back (if anything changed)

```bash
cd dotfiles
source ./sync_dotfiles.sh

git add .
git commit -m "Your changes message"
git push
```

---

## Post-install

- Enable greetd: `sudo systemctl enable greetd`
- Check monitor names and update `hypr/hyprpaper.conf`: `hyprctl monitors | grep Monitor`
- Apply the NERV GRUB theme (optional): `magi grub`
- `atuin` must remain the last line of `.zshrc`
