#!/bin/bash
# BlueZ options a DualSense needs (found by ps5-cachyos-setup): JustWorksRepairing = always (it re-pairs
# to upgrade its link key), PairableTimeout = 0 (else BlueZ answers "No Bonding" and drops the bond).
set -eu
f=${1:-/etc/bluetooth/main.conf}
[ -f "$f" ] || { printf '[General]\n' > "$f"; }
grep -q '^\[General\]' "$f" || printf '\n[General]\n' >> "$f"
set_key() {
    local key=$1 val=$2
    if grep -qE "^[#[:space:]]*${key}[[:space:]]*=" "$f"; then
        sed -i -E "0,/^[#[:space:]]*${key}[[:space:]]*=.*/s//$key = $val/" "$f"
    else
        sed -i "/^\[General\]/a $key = $val" "$f"
    fi
}
set_key JustWorksRepairing always
set_key PairableTimeout 0
echo "main.conf: JustWorksRepairing = always, PairableTimeout = 0"
