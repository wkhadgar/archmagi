#!/bin/bash
# tests/units.sh: behavioral assertions on pure helpers (no system mutations).
#
# Complements tests/smoke.sh:
#   smoke.sh covers syntax + function-defined + end-to-end safe invocations.
#   units.sh covers algorithmic helpers with deterministic input/output:
#     _install_substitute, _install_sync_excluded, _status_meter_color,
#     _monitors_clean_scale, _install_find_repo, _wallpaper_detect_resolution,
#     _status_meter, _ppd_available.

set -u
cd "$(dirname "$(readlink -f "$0")")/.."

source tests/lib.sh

LIB=./bin/archmagi.d
ARCHMAGI_LIB="$LIB"
source "$LIB/lib.sh"
source "$LIB/fetch.sh"
source "$LIB/install_template.sh"
source "$LIB/install_configs.sh"
source "$LIB/install_sync.sh"
source "$LIB/install_monitors.sh"
source "$LIB/install_wallpaper.sh"

test_banner "UNIT TESTS"

# _install_sync_excluded
assert_zero    "sync_excluded: etc/hostname"             _install_sync_excluded etc/hostname
assert_zero    "sync_excluded: etc/hosts"                _install_sync_excluded etc/hosts
assert_zero    "sync_excluded: hypr/hyprlock.conf"       _install_sync_excluded hypr/hyprlock.conf
assert_zero    "sync_excluded: hypr/hyprland/monit.lua"  _install_sync_excluded hypr/hyprland/monit.lua
assert_zero    "sync_excluded: nvim/lazy-lock.json"      _install_sync_excluded nvim/lazy-lock.json
assert_zero    "sync_excluded: any .tmpl"                _install_sync_excluded etc/hostname.tmpl
assert_nonzero "sync_excluded: not bin/archmagi"         _install_sync_excluded bin/archmagi
assert_nonzero "sync_excluded: not waybar/config"        _install_sync_excluded waybar/config

# _status_meter_color: high_bad and high_good have inverted thresholds
assert_eq "meter_color 95 high_bad"   "$(_status_meter_color 95 high_bad)"  "$RED"
assert_eq "meter_color 60 high_bad"   "$(_status_meter_color 60 high_bad)"  "$AMBER"
assert_eq "meter_color 10 high_bad"   "$(_status_meter_color 10 high_bad)"  "$GREEN"
assert_eq "meter_color 10 high_good"  "$(_status_meter_color 10 high_good)" "$RED"
assert_eq "meter_color 40 high_good"  "$(_status_meter_color 40 high_good)" "$AMBER"
assert_eq "meter_color 80 high_good"  "$(_status_meter_color 80 high_good)" "$GREEN"

# _monitors_clean_scale: strip trailing zeros, keep integer part
assert_eq "clean_scale 1.00"    "$(_monitors_clean_scale 1.00)"  "1"
assert_eq "clean_scale 1.50"    "$(_monitors_clean_scale 1.50)"  "1.5"
assert_eq "clean_scale 1.33"    "$(_monitors_clean_scale 1.33)"  "1.33"
assert_eq "clean_scale 1.250"   "$(_monitors_clean_scale 1.250)" "1.25"
assert_eq "clean_scale 2"       "$(_monitors_clean_scale 2)"     "2"

# _install_substitute: __KEY__ replacement, including special-char values
tmp_in=$(mktemp); tmp_out=$(mktemp)
trap 'rm -f "$tmp_in" "$tmp_out"' EXIT
printf '__GREET__ from __WHO__' > "$tmp_in"
_install_substitute "$tmp_in" "$tmp_out" GREET=hello WHO=paulo
assert_eq "substitute: two keys"                "$(<"$tmp_out")" "hello from paulo"
printf 'host=__H__' > "$tmp_in"
_install_substitute "$tmp_in" "$tmp_out" H='balt/has\ar"2'
assert_eq "substitute: special chars in value"  "$(<"$tmp_out")" 'host=balt/has\ar"2'
printf '__HOSTNAME__' > "$tmp_in"
_install_substitute "$tmp_in" "$tmp_out" HOSTNAME=melchior-1
assert_eq "substitute: hyphenated value"        "$(<"$tmp_out")" "melchior-1"

# _install_find_repo: repo root has etc/hostname.tmpl
assert_eq "find_repo: returns PWD from repo root" "$(_install_find_repo 2>&1)" "$PWD"

# _wallpaper_detect_resolution: always emits a sane WxH
assert_match "detect_resolution: WxH shape" "$(_wallpaper_detect_resolution)" '^[0-9]+x[0-9]+$'

# _status_meter: renders %, no crash at boundaries
assert_match "meter 50 high_bad: contains 50%"  "$(_status_meter 50  high_bad)" '50%'
assert_match "meter 0:           contains 0%"   "$(_status_meter 0   high_bad)" '0%'
assert_match "meter 100:         contains 100%" "$(_status_meter 100 high_bad)" '100%'

# _ppd_available: returns deterministic 0/1 based on environment
if command -v powerprofilesctl >/dev/null && powerprofilesctl get >/dev/null 2>&1; then
    assert_zero    "ppd_available: returns 0 when PPD reachable" _ppd_available
else
    assert_nonzero "ppd_available: returns 1 when PPD missing"   _ppd_available
fi

test_summary
