#!/bin/bash
# Destructive commands are only checked for definition, never invoked.

set -u
cd "$(dirname "$(readlink -f "$0")")/.."

source tests/lib.sh

ARCHMAGI=./bin/archmagi
LIB=./bin/archmagi.d

test_banner "SMOKE TEST"

for f in "$ARCHMAGI" "$LIB"/*.sh; do
    if bash -n "$f" 2>/dev/null; then pass "syntax: $f"
    else                              fail "syntax: $f"
    fi
done

for f in "$LIB"/*.lua hypr/hyprland.lua hypr/hyprland/*.lua hypr/hyprland/*.lua.tmpl; do
    [[ -f "$f" ]] || continue
    if luac -p "$f" 2>/dev/null; then pass "syntax: $f"
    else                              fail "syntax: $f"
    fi
done

# group.sh -> expected function names (space-separated)
declare -A expected=(
    [fetch]="cmd_fetch _status_body _status_logo_lines"
    [tailnet]="cmd_tailnet"
    [update]="cmd_update _update_run _update_check"
    [confirm]="cmd_confirm"
    [power]="cmd_lock cmd_reboot cmd_exit cmd_shutdown _graceful_close"
    [restart]="cmd_restart _restart_waybar _restart_xdph"
    [install]="cmd_install _map_each _map_repo_files _configs_entry _sync_entry _drift_entry _install_boot _install_bootstrap _install_redeploy _install_drift_scan _install_hostname_templates _install_monitors _install_sync _install_sync_file _install_sync_tree _install_sync_excluded _install_detect_profile _install_detect_bootloader _install_prompt_hostname _install_prompt_profile_role _install_prompt_confirm _install_substitute _install_configs _install_find_repo _install_packages _install_wallpaper _wallpaper_detect_resolution _boot_grub _boot_limine _monitors_prompt_scale _monitors_clean_scale"
    [cheatsheet]="cmd_cheatsheet"
    [tmux]="cmd_tmux _tmux_attach"
    [profile]="cmd_profile _profile_pick _profile_center"
    [hud]="cmd_hud"
    [help]="cmd_help"
    [battery]="cmd_battery _battery_check _battery_watch _battery_eta _battery_device _battery_runtime _battery_summary"
)

for group in "${!expected[@]}"; do
    (
        ARCHMAGI_LIB="$LIB"
        source "$LIB/lib.sh"
        source "$LIB/$group.sh"
        for fn in ${expected[$group]}; do
            if declare -F "$fn" >/dev/null; then
                printf "  ${GREEN}[✓]${RESET} %s.sh defines %s\n" "$group" "$fn"
            else
                printf "  ${RED}[✗]${RESET} %s.sh missing %s\n" "$group" "$fn" >&2
                exit 1
            fi
        done
    )
    if (( $? == 0 )); then pass=$((pass + $(echo ${expected[$group]} | wc -w)))
    else                   fail=$((fail+1))
    fi
done

# archmagi help: banner present
if [[ "$($ARCHMAGI help 2>&1)" == *"MAGI SYSTEM"* ]]; then
    pass "help renders banner"
else fail "help missing banner"
fi

# archmagi update check: numeric integer
out=$($ARCHMAGI update check 2>&1)
if [[ "$out" =~ ^[0-9]+$ ]]; then pass "update check → numeric ($out)"
else                              fail "update check → '$out' (not numeric)"
fi

# archmagi update check -j: JSON keys present
out=$($ARCHMAGI update check -j 2>&1)
if [[ "$out" == *'"text":'* && "$out" == *'"alt":'* && "$out" == *'"tooltip":'* && "$out" == *'"class":'* && "$out" == *'"percentage":'* ]]; then
    pass "update check -j → JSON with all 5 keys"
else
    fail "update check -j → '$out'"
fi

# archmagi tailnet: `HOST  [STATE]` for one of the three MAGI
out=$($ARCHMAGI tailnet melchior-1 2>&1)
if [[ "$out" =~ ^MELCHIOR-1[[:space:]]+\[(ONLINE|OFFLINE|UNKNOWN)\]$ ]]; then
    pass "tailnet melchior-1 → '$out'"
else fail "tailnet melchior-1 → '$out' (wrong format)"
fi

# archmagi fetch: banner + at least one expected line
out=$($ARCHMAGI fetch 2>&1)
if [[ "$out" == *"NODE:"* && "$out" == *"TAILNET"* && "$out" == *"UPDATES"* ]]; then
    pass "fetch banner + sections"
else fail "fetch missing sections: $out"
fi

# unknown top-level: non-zero exit
if ! $ARCHMAGI bogus-cmd-xyz </dev/null >/dev/null 2>&1; then
    pass "unknown top-level command exits non-zero"
else fail "unknown top-level should have failed"
fi

# unknown subcommand: non-zero exit
for sub in update restart install; do
    if ! $ARCHMAGI "$sub" bogus-sub </dev/null >/dev/null 2>&1; then
        pass "unknown $sub subcommand exits non-zero"
    else fail "$sub bogus-sub should have failed"
    fi
done

test_summary
