#!/bin/bash
# Sets the BlueZ options a DualSense needs in /etc/bluetooth/main.conf ([General]), idempotently:
#   JustWorksRepairing = always : the DualSense re-pairs ~1.5 s after pairing to upgrade its link
#                                 key; BlueZ's default rejects that round and the bond is deleted
#   PairableTimeout = 0         : stay pairable; with pairable off at pair time BlueZ answers the
#                                 pad's request with "No Bonding" and the bond is thrown away
# (both found and packet-verified by the ps5-cachyos-setup project)
set -eu
f=${1:-/etc/bluetooth/main.conf}
[ -f "$f" ] || { printf '[General]\n' > "$f"; }
grep -q '^\[General\]' "$f" || printf '\n[General]\n' >> "$f"
set_key() {
    local key=$1 val=$2
    if grep -qE "^[#[:space:]]*$key[[:space:]]*=" "$f"; then
        sed -i -E "0,/^[#[:space:]]*$key[[:space:]]*=.*/s//$key = $val/" "$f"
    else
        sed -i "/^\[General\]/a $key = $val" "$f"
    fi
}
set_key JustWorksRepairing always
set_key PairableTimeout 0
echo "main.conf: JustWorksRepairing = always, PairableTimeout = 0"
