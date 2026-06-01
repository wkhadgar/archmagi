# MAGI SYSTEM // NERV HQ TERMINAL
> GOD'S IN HIS HEAVEN. ALL'S RIGHT WITH THE WORLD.

---

## Requirements

`archmagi install bootstrap` installs everything from `requirements.pacman` (repo) and `requirements.aur` (AUR). The AUR list is only attempted when [paru](https://github.com/Morganamilo/paru) is present, so install it first:

```bash
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
```

---

## Install

`archmagi install bootstrap` is the canonical deploy path. It detects host facts (laptop vs. desktop, GRUB vs. limine, attached monitors), prompts for hostname + profile role, persists them to `/etc/archmagi/profile`, then deploys generic configs, substitutes host-specific templates, installs packages, and applies the boot theme.

```bash
git clone https://github.com/wkhadgar/dotfiles
cd dotfiles
./bin/archmagi install bootstrap
chsh -s $(which zsh)
```

---

## The `archmagi` CLI

After install, `archmagi` lives at `~/.local/bin/archmagi` (a thin dispatcher) with its command libraries under `~/.local/bin/archmagi.d/` (sourced on demand). Run `archmagi help` for the full list. Highlights:

- `archmagi fetch` — NERV-themed system overview (host, tailnet, updates, system, compute, power); also the top-level shell greeter
- `archmagi hud` — toggle a floating live `fetch` panel in a kitty popup (bound to `Super+F`)
- `archmagi update [run|check [-j]]` — interactive `paru -Syu` wrapper (`run` is the default); `check` returns pending count from a stale-while-revalidate cache
- `archmagi profile [target]` — power-profiles-daemon picker via rofi (laptop only), or set directly with `power-saver|balanced|performance`
- `archmagi cheatsheet` — rofi popup of all Hyprland keybindings (also bound to `SUPER+?`)
- `archmagi tmux <attach|list|switch|detach|kill>` — tmux session control (default session name `MAGI`); `switch` uses fzf to pick
- `archmagi lock` / `reboot` / `exit` / `shutdown` — power actions, gated by the MAGI consensus dialog. The exit/reboot/shutdown trio chain through `hyprshutdown` (pulled in by `requirements.pacman`) so apps close cleanly before the system command fires.
- `archmagi restart <waybar|xdph>` — kill + relaunch a desktop service
- `archmagi install <bootstrap|boot|wallpaper|monitors|sync>` — bootstrap a fresh host, (re)apply the NERV bootloader theme, (re)render the boot wallpaper, regenerate `monit.conf` from live hyprctl state, or diff-based pull changes from the live system back into the repo

The boot wallpaper at `/usr/share/nerv/boot-background.png` is rendered by `_install_wallpaper` at bootstrap time at the host's auto-detected resolution (hyprctl when up, `/sys/class/drm/*/modes` pre-Hyprland, `1920x1080` fallback). It's read by both GRUB and limine. Re-render at any time:

```bash
archmagi install wallpaper            # auto-detect
archmagi install wallpaper 2560x1440  # explicit
archmagi install boot                 # auto-regens wallpaper if missing
```

---

## Testing

Before deploying changes to `archmagi`, run the smoke test against the in-repo version:

```bash
tests/smoke.sh
```

It bash-syntax-checks every shipped script, sources each `archmagi.d/<group>.sh` to confirm the expected `cmd_*` functions are defined, and end-to-end-invokes the safe-to-call commands (`help`, `fetch`, `tailnet`, `update check`). Destructive commands (`reboot`, `restart waybar`, `install boot`, etc.) are only checked at the function-defined level — never actually invoked. `PATTERN GREEN` on full pass; `PATTERN RED` with details on failure.

To run it automatically before every commit that touches `bin/archmagi*` or the test itself, enable the tracked pre-commit hook **once per clone**:

```bash
git config core.hooksPath .githooks
```

Bypass for a single commit with `git commit --no-verify`.

---

## Sync back (if anything changed)

`archmagi install sync` walks the live → repo file map, shows a unified diff per drift, and prompts `[y/N/q]` per file. Templated files (`etc/hostname`, `etc/hosts`, `hypr/hyprlock.conf`, `hypr/hyprland/monit.conf`, and any `*.tmpl`) are skipped — those flow the other direction.

```bash
cd dotfiles
archmagi install sync

git add .
git commit -m "Your changes message"
git push
```

---

## Post-install

- Enable greetd: `sudo systemctl enable greetd`
- Check monitor names with `hyprctl monitors | grep Monitor`, then update **both** `hypr/hyprland/monit.conf` (resolution/position/scale that Hyprland actually uses) and `hypr/hyprpaper.conf` (wallpaper bindings per monitor)
- The boot wallpaper is rendered at bootstrap from the host's auto-detected resolution; override with `archmagi install wallpaper <WxH>` then `archmagi install boot` if the detected value was wrong
- `atuin` must remain the last line of `.zshrc`
