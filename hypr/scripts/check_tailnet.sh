#!/bin/bash
# usage: check_tailnet.sh <hostname>
host="$1"
if [[ -z "$host" ]]; then
    echo "usage: $0 <hostname>" >&2
    exit 1
fi

label=${host^^}

line=$(tailscale status 2>/dev/null | awk -v h="$host" '$2 == h { print; exit }')
if [[ -z "$line" ]]; then
    state="UNKNOWN"
elif [[ "$line" == *offline* ]]; then
    state="OFFLINE"
else
    state="ONLINE"
fi

printf '%-12s[%s]\n' "$label" "$state"
