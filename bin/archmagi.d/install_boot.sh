_install_boot() {
    [[ -f /usr/share/nerv/boot-background.png ]] || _install_wallpaper || return 1

    case $(_install_detect_bootloader) in
        grub)   _boot_grub ;;
        limine) _boot_limine ;;
        *)      echo "no supported bootloader detected (need grub or limine)" >&2; return 1 ;;
    esac
}

# Idempotent: only re-runs grub-mkconfig if a key actually changed.
# The png preload is required to render the PNG theme background.
_boot_grub() {
    local theme=/usr/share/grub/themes/nerv/theme.txt
    local config=/etc/default/grub
    [[ -f $theme ]] || { echo "theme missing at $theme; run archmagi install bootstrap first" >&2; return 1; }

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

    if ! sudo grep -E '^GRUB_PRELOAD_MODULES=".*\bpng\b' "$config" >/dev/null; then
        if sudo grep -q '^GRUB_PRELOAD_MODULES=' "$config"; then
            sudo sed -i 's/^GRUB_PRELOAD_MODULES="\([^"]*\)"/GRUB_PRELOAD_MODULES="\1 png"/' "$config"
        else
            echo 'GRUB_PRELOAD_MODULES="png"' | sudo tee -a "$config" >/dev/null
        fi
        changed=1
    fi

    if (( changed )); then
        sudo grub-mkconfig -o /boot/grub/grub.cfg || {
            echo "grub-mkconfig failed; /etc/default/grub was updated but grub.cfg is stale" >&2
            return 1
        }
        echo "MAGI BOOT theme installed (grub); reboot to see it."
    else
        echo "MAGI BOOT theme already current (grub); skipping grub-mkconfig."
    fi
}

# Wallpaper must go on the ESP: limine only reads its own partition.
# The sentinel block goes before the first `/`-entry so directives are in scope.
_boot_limine() {
    local config
    for candidate in /boot/limine.conf /boot/limine.cfg /etc/limine.conf; do
        [[ -f "$candidate" ]] && { config="$candidate"; break; }
    done
    [[ -n "$config" ]] || { echo "limine config not found" >&2; return 1; }

    local src=/usr/share/nerv/boot-background.png
    local staged=/boot/nerv-bg.png
    sudo cp "$src" "$staged" || { echo "failed to stage wallpaper to $staged" >&2; return 1; }

    local block
    block=$(cat <<EOF
# >>> magi boot: NERV theme (do not edit between these markers)
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
    trap 'rm -f "$tmp"' RETURN

    ( set -o pipefail
      sudo sed '/^# >>> magi boot/,/^# <<< magi boot/d' "$config" \
          | awk -v b="$block" '
              !done && /^\// { print b; done = 1 }
              { print }
              END { if (!done) print b }
          ' > "$tmp"
    ) || { echo "limine.conf rewrite failed; original left intact" >&2; return 1; }

    sudo cp "$tmp" "$config" || { echo "failed to write $config" >&2; return 1; }
    echo "MAGI BOOT theme installed (limine: $config); reboot to see it."
}
