# Bootloader theme application for `archmagi install boot`.

# Dispatch to the right bootloader-specific applier.
# GRUB wins ties since it's more common. Bails out if neither is installed.
_install_boot() {
    if [[ -f /etc/default/grub ]] && command -v grub-mkconfig >/dev/null; then
        _boot_grub
    elif [[ -f /boot/limine.conf || -f /boot/limine.cfg || -f /etc/limine.conf ]]; then
        _boot_limine
    else
        echo "no supported bootloader detected (need grub or limine)" >&2
        return 1
    fi
}

# Apply the NERV GRUB theme. Idempotent: only re-runs grub-mkconfig if a key
# actually changed. Requires png.mod preload for the PNG background.
_boot_grub() {
    local theme=/usr/share/grub/themes/nerv/theme.txt
    local config=/etc/default/grub
    [[ -f $theme ]] || { echo "theme missing at $theme — run import_dotfiles.sh first" >&2; return 1; }

    local changed=0

    if sudo grep -qF "GRUB_THEME=\"$theme\"" "$config"; then
        :
    elif sudo grep -q '^GRUB_THEME=' "$config"; then
        sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$theme\"|" "$config"
        changed=1
    else
        echo "GRUB_THEME=\"$theme\"" | sudo tee -a "$config" >/dev/null
        changed=1
    fi

    # GRUB needs png.mod preloaded to decode the PNG background.
    if ! sudo grep -E '^GRUB_PRELOAD_MODULES=".*\bpng\b' "$config" >/dev/null; then
        if sudo grep -q '^GRUB_PRELOAD_MODULES=' "$config"; then
            sudo sed -i 's/^GRUB_PRELOAD_MODULES="\([^"]*\)"/GRUB_PRELOAD_MODULES="\1 png"/' "$config"
        else
            echo 'GRUB_PRELOAD_MODULES="png"' | sudo tee -a "$config" >/dev/null
        fi
        changed=1
    fi

    if (( changed )); then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        echo "MAGI BOOT theme installed (grub) — reboot to see it."
    else
        echo "MAGI BOOT theme already current (grub) — skipping grub-mkconfig."
    fi
}

# Apply the NERV limine theme. Stages the wallpaper to the ESP (boot reads
# only its own partition) and rewrites a sentinel-bounded block at the top of
# limine.conf so general directives sit before the first `/`-entry.
_boot_limine() {
    local config
    for candidate in /boot/limine.conf /boot/limine.cfg /etc/limine.conf; do
        [[ -f "$candidate" ]] && { config="$candidate"; break; }
    done
    [[ -n "$config" ]] || { echo "limine config not found" >&2; return 1; }

    local src=/usr/share/nerv/boot-background.png
    [[ -f "$src" ]] || { echo "wallpaper missing at $src — run import_dotfiles.sh first" >&2; return 1; }

    local staged=/boot/nerv-bg.png
    sudo cp "$src" "$staged"

    local block
    block=$(cat <<EOF
# >>> magi boot — NERV theme (do not edit between these markers)
wallpaper: boot():/nerv-bg.png
term_background: 0a0a0a
term_foreground: eeeeee
term_palette: 1a1919;cc0000;7bd88f;ffbf00;948ae3;fc618d;5ad4e6;f7f1ff
term_background_brightness: 0.5
interface_branding: MAGI SYSTEM // NERV HQ
# <<< magi boot
EOF
)
    local tmp
    tmp=$(mktemp)
    sudo sed '/^# >>> magi boot/,/^# <<< magi boot/d' "$config" \
        | awk -v b="$block" '
            !done && /^\// { print b; done = 1 }
            { print }
            END { if (!done) print b }
        ' > "$tmp"
    sudo cp "$tmp" "$config"
    rm -f "$tmp"
    echo "MAGI BOOT theme installed (limine: $config) — reboot to see it."
}
