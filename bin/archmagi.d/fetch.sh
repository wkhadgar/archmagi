# Gatherers return empty when their source is missing; empty rows are skipped
# so the same code runs on laptop, desktop, and server.

shopt -s nullglob

_status_row() {
    printf "  %s %s%-10s%s %s %s\n" "$BAR" "$RED" "$1" "$RESET" "$SEP" "$2"
}

_status_sep() {
    printf "  %s %s─────────────────────────────────%s\n" "$BAR" "$MUTED" "$RESET"
}

# Each line is padded to 38 visible cells so the status column lines up.
_status_logo_lines() {
    local host=${1:-?}
    local n=${host^^}
    printf '%s   ███╗   ███╗ █████╗  ██████╗ ██╗    %s\n' "$BOLD$RED" "$RESET"
    printf '%s   ████╗ ████║██╔══██╗██╔════╝ ██║    %s\n' "$BOLD$RED" "$RESET"
    printf '%s   ██╔████╔██║███████║██║  ███╗██║    %s\n' "$BOLD$RED" "$RESET"
    printf '%s   ██║╚██╔╝██║██╔══██║██║   ██║██║    %s\n' "$BOLD$RED" "$RESET"
    printf '%s   ██║ ╚═╝ ██║██║  ██║╚██████╔╝██║    %s\n' "$BOLD$RED" "$RESET"
    printf '%s   ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝    %s\n' "$BOLD$RED" "$RESET"
    printf '%s   ────────────────────────────────   %s\n' "$MUTED"    "$RESET"
    local node="          NODE: $n"
    local pad=$(( 38 - ${#node} ))
    (( pad < 0 )) && pad=0
    printf '%s%s%*s%s\n' "$AMBER" "$node" "$pad" "" "$RESET"
}

# high_good inverts the thresholds (battery: low is the alarm).
_status_meter_color() {
    local pct=$1 mode=${2:-high_bad}
    if [[ "$mode" == "high_good" ]]; then
        if   (( pct <= 20 )); then echo "$RED"
        elif (( pct <= 50 )); then echo "$AMBER"
        else                       echo "$GREEN"
        fi
    else
        if   (( pct >= 80 )); then echo "$RED"
        elif (( pct >= 50 )); then echo "$AMBER"
        else                       echo "$GREEN"
        fi
    fi
}

_status_bar() {
    local pct=$1 mode=${2:-high_bad} width=8
    (( pct > 100 )) && pct=100
    (( pct < 0 )) && pct=0
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local color
    color=$(_status_meter_color "$pct" "$mode")
    local f="" e=""
    # Box-drawing lines: kitty draws these itself at full cell size, unlike
    # ▰▱ which fall back to a font whose glyphs sit tiny on the baseline.
    while (( filled-- > 0 )); do f+='━'; done
    while (( empty-- > 0 )); do e+='─'; done
    printf '%s%s%s%s%s' "$color" "$f" "$MUTED" "$e" "$RESET"
}

_status_meter() {
    local pct=$1 mode=${2:-high_bad}
    local color
    color=$(_status_meter_color "$pct" "$mode")
    printf '%s %s%3d%%%s' "$(_status_bar "$pct" "$mode")" "$color" "$pct" "$RESET"
}

_status_os() {
    local pretty
    pretty=$(awk -F= '/^PRETTY_NAME=/{gsub(/"/,"",$2); print $2}' /etc/os-release 2>/dev/null)
    [[ -n "$pretty" ]] && echo "$pretty $(uname -m)"
}

_status_kernel() { uname -r; }

_status_hyprland() {
    command -v hyprctl >/dev/null || return
    hyprctl version 2>/dev/null | awk '/^Hyprland/ {print $2; exit}'
}

_status_shell() {
    local shell ver
    shell=${SHELL##*/}
    [[ -z "$shell" ]] && return
    ver=$("$SHELL" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    echo "$shell${ver:+ $ver}"
}

_status_cpu_model() {
    awk -F: '/^model name/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}' /proc/cpuinfo
}

_status_cpu_pct() {
    # Two /proc/stat samples 100ms apart.
    local _ user1 _nice1 sys1 idle1 user2 _nice2 sys2 idle2 u1 t1 u2 t2 du dt
    read -r _ user1 _nice1 sys1 idle1 _ < /proc/stat
    sleep 0.1
    read -r _ user2 _nice2 sys2 idle2 _ < /proc/stat
    u1=$((user1 + sys1)); t1=$((u1 + idle1))
    u2=$((user2 + sys2)); t2=$((u2 + idle2))
    du=$((u2 - u1)); dt=$((t2 - t1))
    (( dt > 0 )) && echo $(( du * 100 / dt )) || echo 0
}

_status_mem_pct() {
    free | awk '/^Mem/{printf "%d", $3*100/$2}'
}

_status_load_pct() {
    local load1 ncpu
    load1=$(awk '{print $1}' /proc/loadavg)
    ncpu=$(nproc 2>/dev/null) || ncpu=1
    awk -v l="$load1" -v c="$ncpu" 'BEGIN{printf "%d", l*100/c}'
}

_status_cpu_temp() {
    local h name input label raw

    # hwmon first: thermal_zone often lists only peripherals (wifi, battery),
    # so it can't be trusted by index.
    for h in /sys/class/hwmon/hwmon*; do
        [[ -r "$h/name" ]] || continue
        name=$(<"$h/name")
        case "$name" in
            k10temp|coretemp|zenpower|cpu_thermal) ;;
            *) continue ;;
        esac

        # temp1_input may be a single core or CCD; prefer the package sensor.
        raw=
        for input in "$h"/temp*_input; do
            [[ -r "$input" ]] || continue
            label=$(<"${input%_input}_label" 2>/dev/null) || label=""
            case "$label" in
                Tctl|Tdie|"Package id 0") raw=$(<"$input"); break ;;
            esac
        done
        [[ -z "$raw" && -r "$h/temp1_input" ]] && raw=$(<"$h/temp1_input")

        [[ -n "$raw" ]] && (( raw > 0 )) && { echo "$((raw/1000))°C"; return; }
    done

    # ARM / embedded fallback.
    local z type
    for z in /sys/class/thermal/thermal_zone*; do
        [[ -r "$z/type" && -r "$z/temp" ]] || continue
        type=$(<"$z/type")
        case "$type" in
            x86_pkg_temp|coretemp|k10temp|cpu_thermal|cpu-thermal) ;;
            *) continue ;;
        esac
        raw=$(<"$z/temp")
        [[ -n "$raw" ]] && (( raw > 0 )) && { echo "$((raw/1000))°C"; return; }
    done
}

_status_gpu() {
    command -v lspci >/dev/null || return
    lspci 2>/dev/null | awk -F': ' '/VGA|3D|Display/ { print $2 }' \
        | sed -E 's/ \(rev .*\)$//; s/Corporation //; s/Advanced Micro Devices, Inc\. \[AMD\/ATI\]/AMD/' \
        | paste -sd' / '
}

# One nvidia-smi fork shared by _status_gpu_pct and _status_gpu_temp.
_NVIDIA_SMI_CACHE=""
_status_nvidia_query() {
    [[ -n "$_NVIDIA_SMI_CACHE" ]] && return 0
    command -v nvidia-smi >/dev/null || return 1
    _NVIDIA_SMI_CACHE=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
    [[ -n "$_NVIDIA_SMI_CACHE" ]]
}

_status_gpu_pct() {
    if _status_nvidia_query; then
        local v=${_NVIDIA_SMI_CACHE%%,*}
        [[ "$v" =~ ^[0-9]+$ ]] && { echo "$v"; return; }
    fi
    local f v
    for f in /sys/class/drm/card*/device/gpu_busy_percent; do
        [[ -r "$f" ]] || continue
        v=$(<"$f")
        [[ "$v" =~ ^[0-9]+$ ]] && { echo "$v"; return; }
    done
}

_status_gpu_temp() {
    if _status_nvidia_query; then
        local v=${_NVIDIA_SMI_CACHE##*,}
        [[ "$v" =~ ^[0-9]+$ ]] && { echo "${v}°C"; return; }
    fi
    local f raw
    for f in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do
        [[ -r "$f" ]] || continue
        raw=$(<"$f")
        [[ -n "$raw" ]] && (( raw > 0 )) && { echo "$((raw/1000))°C"; return; }
    done
}

_status_mem() { free -h | awk '/^Mem/{print $3" / "$2}'; }

_status_load() { awk '{print $1", "$2", "$3}' /proc/loadavg; }

# vfat is excluded so the ESP never shows up. Mountpoint only when >1 disk.
_status_body_disks() {
    command -v findmnt >/dev/null || {
        local pct size avail
        pct=$(df / | awk 'NR==2{printf "%d", $3*100/$2}')
        read -r size avail < <(df -h / | awk 'NR==2{print $2" "$4}')
        _status_row "DISK" "$(_status_meter "${pct:-0}")  $avail free of $size"
        return
    }

    local -a rows=()
    local target size avail pct
    while read -r target size avail pct; do
        pct=${pct%\%}
        [[ "$pct" =~ ^[0-9]+$ ]] || continue
        rows+=("$target|$size|$avail|$pct")
    done < <(findmnt -l --real -t ext4,btrfs,xfs,f2fs,ext3,ext2,ntfs,exfat \
                     --output=TARGET,SIZE,AVAIL,USE% --noheadings 2>/dev/null)

    (( ${#rows[@]} == 0 )) && return

    local row value multi=$(( ${#rows[@]} > 1 ))
    for row in "${rows[@]}"; do
        IFS='|' read -r target size avail pct <<<"$row"
        value="$(_status_meter "$pct")  $avail free of $size"
        (( multi )) && value+=" · $target"
        _status_row "DISK" "$value"
    done
}

_status_lan() {
    ip route get 1 2>/dev/null | awk '{print $7; exit}'
}

_status_tailscale() {
    command -v tailscale >/dev/null || return
    tailscale ip --4 2>/dev/null | head -1
}

_status_protocol() {
    local p nerv=""
    p=$(powerprofilesctl get 2>/dev/null) || return
    [[ -z "$p" ]] && return
    case "$p" in
        power-saver) nerv="SYNAPSE LOW" ;;
        balanced)    nerv="SYNAPSE NORM" ;;
        performance) nerv="SYNAPSE MAX" ;;
    esac
    if [[ -n "$nerv" ]]; then
        printf '%s · %s%s%s' "${p^^}" "$AMBER" "$nerv" "$RESET"
    else
        echo "${p^^}"
    fi
}

_status_battery() {
    local bat
    bat=$(_battery_device) || return

    local cap status pow_uw arrow=""
    cap=$(<"$bat/capacity")
    [[ -r "$bat/status" ]] && status=$(<"$bat/status")
    case "$status" in
        Charging)    arrow="${GREEN}↑${RESET}" ;;
        Discharging) arrow="${AMBER}↓${RESET}" ;;
    esac
    [[ -r "$bat/power_now" ]] && pow_uw=$(<"$bat/power_now")
    local meter eta
    meter=$(_status_meter "$cap" high_good)
    eta=$(_battery_eta "$bat")
    if [[ -n "${pow_uw:-}" && "$pow_uw" -gt 0 ]]; then
        local watts
        watts=$(awk "BEGIN{printf \"%.1f\", $pow_uw/1000000}")
        printf '%s  %s %sW' "$meter" "$arrow" "$watts"
    else
        printf '%s' "$meter"
    fi
    [[ -n "$eta" ]] && printf '  %s' "$eta"
}

_status_display() {
    command -v hyprctl >/dev/null || return
    hyprctl monitors 2>/dev/null | awk '
        function flush() {
            if (focused == "yes" && resolution != "") {
                printf "%s · %s@%dHz x%s\n", name, resolution, refresh, scale
            }
        }
        /^Monitor / {
            flush()
            name = $2; resolution = ""; refresh = 0; scale = ""; focused = ""
        }
        /^[[:space:]]+[0-9]+x[0-9]+@/ && resolution == "" {
            split($1, parts, "@")
            resolution = parts[1]
            refresh = int(parts[2])
        }
        /^[[:space:]]+scale: / { scale = $2 }
        /^[[:space:]]+focused: yes/ { focused = "yes" }
        END { flush() }
    '
}

# One-line readouts for the hyprlock bottom-left labels.
_fetch_lock() {
    local v
    case "$1" in
        cpu)  echo "CPU  // $(_status_cpu_pct)%" ;;
        mem)  echo "MEM  // $(_status_mem)" ;;
        disk) echo "DISK // $(df -h / | awk 'NR==2{print $4}') free" ;;
        net)  v=$(_status_lan); echo "NET  // ${v:-offline}" ;;
        *)    echo "archmagi fetch lock: field 'cpu', 'mem', 'disk', or 'net'" >&2; return 1 ;;
    esac
}

cmd_fetch() {
    [[ "$1" == lock ]] && { _fetch_lock "$2"; return; }

    # Buffered and flushed at once so the HUD loop never paints a half frame
    # while tailscale or lspci are slow.
    local hostname
    hostname=$(_archmagi_hostname)

    local out
    out=$({
        local logo body i n_logo n_body empty offset logo_idx
        mapfile -t logo < <(_status_logo_lines "$hostname")
        mapfile -t body < <(_status_body)
        n_logo=${#logo[@]}
        n_body=${#body[@]}
        printf -v empty '%*s' 38 ''
        offset=$(( (n_body - n_logo) / 2 ))
        (( offset < 0 )) && offset=0
        echo
        for ((i=0; i<n_body; i++)); do
            logo_idx=$(( i - offset ))
            if (( logo_idx >= 0 && logo_idx < n_logo )); then
                printf '%s%s\n' "${logo[logo_idx]}" "${body[i]}"
            else
                printf '%s%s\n' "$empty" "${body[i]}"
            fi
        done
        echo
    })
    printf '%s\n' "$out"
}

_status_body_system() {
    local v
    v=$(_status_os);       [[ -n "$v" ]] && _status_row "OS"       "$v"
    v=$(_status_kernel);   [[ -n "$v" ]] && _status_row "KERNEL"   "$v"
    v=$(_status_hyprland); [[ -n "$v" ]] && _status_row "HYPRLAND" "$v"
    v=$(_status_shell);    [[ -n "$v" ]] && _status_row "SHELL"    "$v"
    v=$(uptime -p | sed 's/^up //')
    _status_row "UPTIME" "$v"
}

_status_body_network() {
    local v node state color
    printf "  %s %sTAILNET%s    %s\n" "$BAR" "$RED" "$RESET" "$SEP"
    for node in "${MAGI_NODES[@]}"; do
        state=$(_tailnet_state "$node")
        case "$state" in
            ONLINE)  color="$AMBER" ;;
            OFFLINE) color="$RED" ;;
            *)       color="$MUTED" ;;
        esac
        printf "  %s    %-14s %s[%s]%s\n" "$BAR" "${node^^}" "$color" "$state" "$RESET"
    done
    v=$(_status_lan);       [[ -n "$v" ]] && _status_row "LAN"       "$v"
    v=$(_status_tailscale); [[ -n "$v" ]] && _status_row "TAILSCALE" "$v"

    local pacman aur total updates
    read -r pacman aur < <(_pending_counts)
    total=$((pacman + aur))
    if (( total > 0 )); then
        updates="${AMBER}${total}${RESET} ${MUTED}(${pacman} pacman + ${aur} AUR)${RESET}"
    else
        updates="${MUTED}network up to date${RESET}"
    fi
    _status_row "UPDATES" "$updates"
}

_status_body_compute() {
    local cpu_pct cpu_temp cpu_model cpu_line
    cpu_pct=$(_status_cpu_pct)
    cpu_temp=$(_status_cpu_temp)
    cpu_model=$(_status_cpu_model)
    cpu_line="$(_status_meter "${cpu_pct:-0}")"
    [[ -n "$cpu_model" ]] && cpu_line+="  $cpu_model"
    [[ -n "$cpu_temp"  ]] && cpu_line+=" · $cpu_temp"
    _status_row "CPU" "$cpu_line"

    local gpu_pct gpu_temp gpu_model gpu_line
    gpu_pct=$(_status_gpu_pct)
    gpu_temp=$(_status_gpu_temp)
    gpu_model=$(_status_gpu)
    if [[ -n "$gpu_pct" ]]; then
        gpu_line="$(_status_meter "$gpu_pct")"
        [[ -n "$gpu_model" ]] && gpu_line+="  $gpu_model"
        [[ -n "$gpu_temp"  ]] && gpu_line+=" · $gpu_temp"
        _status_row "GPU" "$gpu_line"
    elif [[ -n "$gpu_model" ]]; then
        gpu_line="$gpu_model"
        [[ -n "$gpu_temp" ]] && gpu_line+=" · $gpu_temp"
        _status_row "GPU" "$gpu_line"
    fi

    local mem_pct mem_h
    mem_pct=$(_status_mem_pct); mem_h=$(_status_mem)
    _status_row "MEM" "$(_status_meter "${mem_pct:-0}")  $mem_h"

    _status_body_disks

    local load_pct load_raw
    load_pct=$(_status_load_pct); load_raw=$(_status_load)
    _status_row "LOAD" "$(_status_meter "${load_pct:-0}")  $load_raw"
}

# Separator only when a field exists, so servers don't get a dangling rule.
_status_body_power() {
    local proto batt disp
    proto=$(_status_protocol)
    batt=$(_status_battery)
    disp=$(_status_display)
    [[ -z "$proto" && -z "$batt" && -z "$disp" ]] && return
    _status_sep
    [[ -n "$proto" ]] && _status_row "PROTOCOL" "$proto"
    [[ -n "$batt"  ]] && _status_row "BATTERY"  "$batt"
    [[ -n "$disp"  ]] && _status_row "DISPLAY"  "$disp"
}

_status_body() {
    local hostname
    hostname=$(_archmagi_hostname)
    printf "  %s %s%sMAGI SYSTEM%s %s %s%s%s\n" \
        "$BAR" "$BOLD" "$RED" "$RESET" "$SEP" "$AMBER" "${hostname^^}" "$RESET"
    _status_sep
    _status_body_system
    _status_sep
    _status_body_network
    _status_sep
    _status_body_compute
    _status_body_power
}
