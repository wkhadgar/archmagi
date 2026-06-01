# Render /usr/share/nerv/boot-background.png: the shared boot wallpaper for
# the NERV GRUB theme and limine.

# Pick the largest connected monitor's resolution.
# Order: hyprctl (Hyprland up) -> /sys/class/drm/*/modes -> 1920x1080.
# @return WxH on stdout
_wallpaper_detect_resolution() {
    if command -v hyprctl >/dev/null; then
        local res
        res=$(hyprctl monitors -j 2>/dev/null | awk -F'[:,]' '
            /"width":/  { w = $2 + 0 }
            /"height":/ { h = $2 + 0
                          if (w * h > best) { best = w * h; result = w "x" h } }
            END { if (result) print result }')
        if [[ "$res" =~ ^[0-9]+x[0-9]+$ ]]; then
            echo "$res"; return
        fi
    fi

    local best_area=0 best_res="" dir mode w h area
    for dir in /sys/class/drm/card*-*; do
        [[ -d "$dir" && -r "$dir/status" && -r "$dir/modes" ]] || continue
        [[ "$(cat "$dir/status")" == connected ]] || continue
        mode=$(head -1 "$dir/modes")
        [[ "$mode" =~ ^([0-9]+)x([0-9]+) ]] || continue
        w=${BASH_REMATCH[1]}; h=${BASH_REMATCH[2]}
        area=$((w * h))
        if (( area > best_area )); then
            best_area=$area; best_res="${w}x${h}"
        fi
    done
    [[ -n "$best_res" ]] && { echo "$best_res"; return; }

    echo "1920x1080"
}

# Render the boot wallpaper at the given (or auto-detected) resolution.
# Writes /usr/share/nerv/boot-background.png as root.
# @param 1 optional WxH override
_install_wallpaper() {
    local bar="${RED}▌${RESET}"
    local res=${1:-}
    [[ -z "$res" ]] && res=$(_wallpaper_detect_resolution)
    [[ "$res" =~ ^[0-9]+x[0-9]+$ ]] || {
        printf "  %s invalid resolution: %s (expected WxH)\n" "$bar" "$res" >&2; return 1
    }

    command -v magick >/dev/null || {
        printf "  %s imagemagick not installed (add to requirements.pacman or run bootstrap)\n" "$bar" >&2; return 1
    }

    local jbm=/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf
    local jbm_bold=/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf
    local dest=/usr/share/nerv/boot-background.png
    local tmp
    tmp=$(mktemp --suffix=.png)

    magick -size "$res" xc:'#0a0a0a' \
        -gravity north \
          -font "$jbm_bold" -fill '#cc0000' -pointsize 36 -annotate +0+80  'MAGI SYSTEM // NERV HQ' \
          -font "$jbm"      -fill '#666666' -pointsize 18 -annotate +0+135 '─────────────────────────────' \
          -font "$jbm_bold" -fill '#ffbf00' -pointsize 22 -annotate +0+170 'BOOT SEQUENCE INITIATED' \
        -gravity south \
          -font "$jbm_bold" -fill '#cc0000' -pointsize 20 -annotate +0+170 '[PATTERN BLUE]      [STANDBY]' \
          -font "$jbm"      -fill '#666666' -pointsize 16 -annotate +0+135 'CASPER  ·  BALTHASAR  ·  MELCHIOR' \
          -font "$jbm_bold" -fill '#cc0000' -pointsize 16 -annotate +0+90  '⚠  AUTHORIZED PERSONNEL ONLY  ⚠' \
        -alpha off -depth 8 -type TrueColor \
        "$tmp" || { rm -f "$tmp"; printf "  %s magick failed\n" "$bar" >&2; return 1; }

    sudo mkdir -p "$(dirname "$dest")"
    sudo mv -f "$tmp" "$dest"
    printf "  %s wrote ${AMBER}%s${RESET} at ${AMBER}%s${RESET}\n" "$bar" "$dest" "$res"
}
