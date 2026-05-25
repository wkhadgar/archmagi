#!/usr/bin/bash
# Regenerate the NERV MAGI BOOT background PNG.
# Used as the wallpaper by both the GRUB theme (via `magi boot`) and limine.
#
# Usage:  regenerate-bg.sh [WIDTHxHEIGHT]   (default 1920x1080)
# Run on each host at its native screen resolution before `magi boot` so the
# baked-in chrome lands cleanly without scaling. Requires imagemagick and
# JetBrainsMono Nerd Font; falls back to default fonts if JBM isn't installed.

set -e
res="${1:-1920x1080}"
dir="$(dirname "$(readlink -f "$0")")"
out="$dir/boot-background.png"

JBM_BOLD=/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf
JBM=/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf

magick -size "$res" xc:'#0a0a0a' \
  -gravity north \
    -font "$JBM_BOLD" -fill '#cc0000' -pointsize 36 -annotate +0+80  'MAGI SYSTEM // NERV HQ' \
    -font "$JBM"      -fill '#666666' -pointsize 18 -annotate +0+135 '─────────────────────────────' \
    -font "$JBM_BOLD" -fill '#ffbf00' -pointsize 22 -annotate +0+170 'BOOT SEQUENCE INITIATED' \
  -gravity south \
    -font "$JBM_BOLD" -fill '#cc0000' -pointsize 20 -annotate +0+170 '[PATTERN BLUE]      [STANDBY]' \
    -font "$JBM"      -fill '#666666' -pointsize 16 -annotate +0+135 'CASPER  ·  BALTHASAR  ·  MELCHIOR' \
    -font "$JBM_BOLD" -fill '#cc0000' -pointsize 16 -annotate +0+90  '⚠  AUTHORIZED PERSONNEL ONLY  ⚠' \
  -alpha off -depth 8 -type TrueColor \
  "$out"

echo "wrote $out at $res"
