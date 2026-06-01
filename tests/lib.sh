# tests/lib.sh: shared test harness for smoke.sh and units.sh.
# Defines color palette, pass/fail printers + counter, assertion helpers,
# and the PATTERN GREEN/RED banner + summary blocks.

RED=$'\033[38;2;204;0;0m'
AMBER=$'\033[38;2;255;191;0m'
GREEN=$'\033[38;2;123;216;143m'
MUTED=$'\033[38;2;102;102;102m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

pass=0; fail=0
pass() { printf "  ${GREEN}[✓]${RESET} %s\n" "$1"; pass=$((pass+1)); }
fail() { printf "  ${RED}[✗]${RESET} %s\n" "$1"   >&2; fail=$((fail+1)); }

assert_eq() {
    local desc=$1 got=$2 want=$3
    [[ "$got" == "$want" ]] && pass "$desc" || fail "$desc: got '$got', want '$want'"
}
assert_match() {
    local desc=$1 got=$2 pattern=$3
    [[ "$got" =~ $pattern ]] && pass "$desc" || fail "$desc: '$got' !~ /$pattern/"
}
assert_zero() {
    local desc=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$desc"
    else fail "$desc: exit code $?"
    fi
}
assert_nonzero() {
    local desc=$1; shift
    if ! "$@" >/dev/null 2>&1; then pass "$desc"
    else fail "$desc: expected non-zero exit"
    fi
}

test_banner() {
    local title=$1
    echo
    printf "  ${RED}▌${RESET} ${BOLD}MAGI SYSTEM${RESET} ${MUTED}// %s${RESET}\n" "$title"
    printf "  ${RED}▌${RESET} ${MUTED}─────────────────────────────────${RESET}\n"
}

test_summary() {
    local total=$((pass + fail))
    echo
    if (( fail == 0 )); then
        printf "  ${RED}▌${RESET} ${BOLD}PATTERN GREEN${RESET} ${MUTED}//${RESET} %d/%d passed\n\n" "$pass" "$total"
        exit 0
    else
        printf "  ${RED}▌${RESET} ${BOLD}${RED}PATTERN RED${RESET} ${MUTED}//${RESET} %d/%d passed, ${RED}%d failed${RESET}\n\n" "$pass" "$total" "$fail" >&2
        exit 1
    fi
}
