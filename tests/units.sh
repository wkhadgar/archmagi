#!/bin/bash
# Deterministic assertions on pure helpers. No system mutations.

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
source "$LIB/battery.sh"

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

# Fake sysfs device so battery tests pass on laptops and desktops alike.
fake_battery() {
    local dir=$1; shift
    local kv

    mkdir -p "$dir"
    for kv in "$@"; do
        printf '%s' "${kv#*=}" > "$dir/${kv%%=*}"
    done
}

bat_root=$(mktemp -d)
trap 'rm -rf "$bat_root"' EXIT

# 30Wh left of 60Wh at a 15W draw is two hours, either way round.
fake_battery "$bat_root/draining"  capacity=42 status=Discharging \
    energy_now=30000000 energy_full=60000000 power_now=15000000
fake_battery "$bat_root/charging"  capacity=50 status=Charging \
    energy_now=30000000 energy_full=60000000 power_now=15000000
fake_battery "$bat_root/full"      capacity=100 status=Full \
    energy_now=60000000 energy_full=60000000 power_now=0
fake_battery "$bat_root/held"      capacity=80 status="Not charging" \
    energy_now=48000000 energy_full=60000000 power_now=0
fake_battery "$bat_root/unknown"   capacity=55 status=Unknown \
    energy_now=30000000 energy_full=60000000 power_now=15000000
fake_battery "$bat_root/idle"      capacity=42 status=Discharging \
    energy_now=30000000 energy_full=60000000 power_now=0
fake_battery "$bat_root/amps"      capacity=42 status=Discharging \
    charge_now=2000000 charge_full=4000000 current_now=1000000
fake_battery "$bat_root/bare"      capacity=42 status=Discharging
mkdir -p "$bat_root/absent"

# _battery_eta: HHhMMm from either convention, FULL when full, empty otherwise
assert_eq "eta: discharging"          "$(_battery_eta "$bat_root/draining")" "02h00m"
assert_eq "eta: charging to full"     "$(_battery_eta "$bat_root/charging")" "02h00m"
assert_eq "eta: charge_/current_"     "$(_battery_eta "$bat_root/amps")"     "02h00m"
assert_eq "eta: full"                 "$(_battery_eta "$bat_root/full")"     "FULL"
assert_eq "eta: not charging"         "$(_battery_eta "$bat_root/held")"     ""
assert_eq "eta: unknown status"       "$(_battery_eta "$bat_root/unknown")"  ""
assert_eq "eta: zero draw"            "$(_battery_eta "$bat_root/idle")"     ""
assert_eq "eta: no draw attributes"   "$(_battery_eta "$bat_root/bare")"     ""
assert_eq "eta: no battery"           "$(_battery_eta "$bat_root/absent")"   ""

# _battery_runtime: unbounded on wall power, drain ETA while discharging
assert_eq "runtime: no battery is unbounded"  "$(_battery_runtime "$bat_root/absent")"   "$BATTERY_RUNTIME_UNBOUNDED"
assert_eq "runtime: charging is unbounded"    "$(_battery_runtime "$bat_root/charging")" "$BATTERY_RUNTIME_UNBOUNDED"
assert_eq "runtime: full is unbounded"        "$(_battery_runtime "$bat_root/full")"     "$BATTERY_RUNTIME_UNBOUNDED"
assert_eq "runtime: not charging is unbounded"  "$(_battery_runtime "$bat_root/held")"    "$BATTERY_RUNTIME_UNBOUNDED"
assert_eq "runtime: discharging is the ETA"   "$(_battery_runtime "$bat_root/draining")" "02h00m"
assert_eq "runtime: unknown status is blank"  "$(_battery_runtime "$bat_root/unknown")"  ""

# _battery_summary
assert_eq "summary: capacity and ETA"    "$(_battery_summary "$bat_root/draining")" "BATT // 42% (02h00m)"
assert_eq "summary: charging is motto"   "$(_battery_summary "$bat_root/charging")" "BATT // 50% ($BATTERY_RUNTIME_UNBOUNDED)"
assert_eq "summary: full is motto"       "$(_battery_summary "$bat_root/full")"     "BATT // 100% ($BATTERY_RUNTIME_UNBOUNDED)"
assert_eq "summary: capacity only"       "$(_battery_summary "$bat_root/idle")"     "BATT // 42%"
assert_eq "summary: unknown is capacity" "$(_battery_summary "$bat_root/unknown")"  "BATT // 55%"
assert_eq "summary: no battery is empty" "$(_battery_summary "$bat_root/absent")"   ""

# _battery_device: locates a readable BAT* or fails on a battery-less host
if compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
    assert_match "battery_device: returns a BAT path" "$(_battery_device)" '^/sys/class/power_supply/BAT'
else
    assert_nonzero "battery_device: fails without a battery" _battery_device
fi

# _ppd_available: returns deterministic 0/1 based on environment
if command -v powerprofilesctl >/dev/null && powerprofilesctl get >/dev/null 2>&1; then
    assert_zero    "ppd_available: returns 0 when PPD reachable" _ppd_available
else
    assert_nonzero "ppd_available: returns 1 when PPD missing"   _ppd_available
fi

test_summary
