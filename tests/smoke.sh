#!/bin/bash
# tests/smoke.sh — sanity check for magi.
#
# Runs against the in-repo bin/magi + bin/magi.d/ (does not require deployment
# to ~/.local/bin). Three test classes:
#   1. bash syntax-check every shipped script
#   2. source each magi.d/<group>.sh and assert its cmd_<group> is defined
#   3. invoke the safe-to-call commands end-to-end and check output shape
#
# Destructive commands (reboot/shutdown/install/restart/confirm) are only
# checked at the "is the function defined?" level — never invoked.
#
# Exit code: 0 if all tests pass, 1 otherwise.

set -u
cd "$(dirname "$(readlink -f "$0")")/.."

MAGI=./bin/magi
LIB=./bin/magi.d

# Colors — mirror bin/magi.d/lib.sh so the report fits the aesthetic.
RED=$'\033[38;2;204;0;0m'
AMBER=$'\033[38;2;255;191;0m'
GREEN=$'\033[38;2;123;216;143m'
MUTED=$'\033[38;2;102;102;102m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

pass=0; fail=0
pass() { printf "  ${GREEN}[✓]${RESET} %s\n" "$1"; pass=$((pass+1)); }
fail() { printf "  ${RED}[✗]${RESET} %s\n" "$1"   >&2; fail=$((fail+1)); }

# ── 1. syntax ────────────────────────────────────────
echo
printf "  ${RED}▌${RESET} ${BOLD}MAGI SYSTEM${RESET} ${MUTED}// SMOKE TEST${RESET}\n"
printf "  ${RED}▌${RESET} ${MUTED}─────────────────────────────────${RESET}\n"

for f in "$MAGI" "$LIB"/*.sh; do
    if bash -n "$f" 2>/dev/null; then pass "syntax: $f"
    else                              fail "syntax: $f"
    fi
done

# ── 2. source-and-defined ────────────────────────────
# group.sh → expected function names (space-separated)
declare -A expected=(
    [status]="cmd_status"
    [tailnet]="cmd_tailnet"
    [update]="cmd_update _update_run _update_check"
    [confirm]="cmd_confirm"
    [power]="cmd_lock cmd_reboot cmd_exit cmd_shutdown _graceful_close"
    [restart]="cmd_restart _restart_waybar _restart_xdph"
    [install]="cmd_install _install_boot _boot_grub _boot_limine"
    [cheatsheet]="cmd_cheatsheet"
    [tmux]="cmd_tmux _tmux_attach"
    [help]="cmd_help"
)

for group in "${!expected[@]}"; do
    (
        MAGI_LIB="$LIB"
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

# ── 3. end-to-end (safe stdout-only commands) ────────

# magi help — banner present
if [[ "$($MAGI help 2>&1)" == *"MAGI SYSTEM"* ]]; then
    pass "help renders banner"
else fail "help missing banner"
fi

# magi update check — numeric integer
out=$($MAGI update check 2>&1)
if [[ "$out" =~ ^[0-9]+$ ]]; then pass "update check → numeric ($out)"
else                              fail "update check → '$out' (not numeric)"
fi

# magi update check -j — JSON keys present
out=$($MAGI update check -j 2>&1)
if [[ "$out" == *'"text":'* && "$out" == *'"alt":'* && "$out" == *'"tooltip":'* && "$out" == *'"class":'* && "$out" == *'"percentage":'* ]]; then
    pass "update check -j → JSON with all 5 keys"
else
    fail "update check -j → '$out'"
fi

# magi tailnet — `HOST  [STATE]` for one of the three MAGI
out=$($MAGI tailnet melchior-1 2>&1)
if [[ "$out" =~ ^MELCHIOR-1[[:space:]]+\[(ONLINE|OFFLINE|UNKNOWN)\]$ ]]; then
    pass "tailnet melchior-1 → '$out'"
else fail "tailnet melchior-1 → '$out' (wrong format)"
fi

# magi status — banner + at least one expected line
out=$($MAGI status 2>&1)
if [[ "$out" == *"MAGI SYSTEM"* && "$out" == *"TAILNET"* && "$out" == *"UPDATES"* ]]; then
    pass "status banner + sections"
else fail "status missing sections: $out"
fi

# unknown top-level — non-zero exit
if ! $MAGI bogus-cmd-xyz </dev/null >/dev/null 2>&1; then
    pass "unknown top-level command exits non-zero"
else fail "unknown top-level should have failed"
fi

# unknown subcommand — non-zero exit
if ! $MAGI update bogus-sub </dev/null >/dev/null 2>&1; then
    pass "unknown update subcommand exits non-zero"
else fail "update bogus-sub should have failed"
fi
if ! $MAGI restart bogus-sub </dev/null >/dev/null 2>&1; then
    pass "unknown restart subcommand exits non-zero"
else fail "restart bogus-sub should have failed"
fi
if ! $MAGI install bogus-sub </dev/null >/dev/null 2>&1; then
    pass "unknown install subcommand exits non-zero"
else fail "install bogus-sub should have failed"
fi

# ── summary ──────────────────────────────────────────
total=$((pass + fail))
echo
if (( fail == 0 )); then
    printf "  ${RED}▌${RESET} ${BOLD}PATTERN GREEN${RESET} ${MUTED}//${RESET} %d/%d passed\n\n" "$pass" "$total"
    exit 0
else
    printf "  ${RED}▌${RESET} ${BOLD}${RED}PATTERN RED${RESET} ${MUTED}//${RESET} %d/%d passed, ${RED}%d failed${RESET}\n\n" "$pass" "$total" "$fail" >&2
    exit 1
fi
