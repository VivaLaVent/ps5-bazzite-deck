#!/usr/bin/env bash
# Runs ps5-bootc-sync against fake ostree boot entries: install, user edits, upgrades, rollback.
#   tests/ps5-bootc-sync.sh
set -euo pipefail
SYNC=$(cd "$(dirname "$0")/.." && pwd)/system_files/usr/bin/ps5-bootc-sync
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
B=$T/boot E=$T/esp
mkdir -p "$B/loader/entries" "$E"

# deployment <letter> <ostree version> [extra kargs]
deployment() {
    local h; h=$(printf "$1%.0s" {1..64})
    mkdir -p "$B/ostree/default-$h"
    echo "kernel-$1" > "$B/ostree/default-$h/vmlinuz-7.3"
    echo "initrd-$1" > "$B/ostree/default-$h/initramfs-7.3.img"
    cat > "$B/loader/entries/ostree-$1.conf" <<E
title Bazzite $1
version $2
options root=UUID=r rw ostree=/ostree/boot.0/default/$h/0 ${3:-}
linux /ostree/default-$h/vmlinuz-7.3
initrd /ostree/default-$h/initramfs-7.3.img
E
}
sync() { python3 -I "$SYNC" --boot "$B" --esp "$E" >/dev/null; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$3', got '$2'"; exit 1; fi; }

deployment a 1; sync
check "fresh install boots a" "$(cat "$E/bzImage")" kernel-a
check "no rollback target yet" "$(ls "$E/ostree" 2>/dev/null | wc -l)" 0

echo " amdgpu.ps5_cu_unlock=3" >> "$E/cmdline.txt"; sed -i ':a;N;s/\n//;ba' "$E/cmdline.txt"
echo viola >> "$E/initrd.img"; sync
check "user option kept" "$(grep -c ps5_cu_unlock "$E/cmdline.txt")" 1
check "PS5 Pro firmware in initrd.img kept" "$(tail -1 "$E/initrd.img")" viola

deployment b 2 newkarg=1; sync
check "upgrade boots b" "$(cat "$E/bzImage")" kernel-b
check "upgrade replaces initrd" "$(cat "$E/initrd.img")" initrd-b
check "new karg added" "$(grep -c newkarg=1 "$E/cmdline.txt")" 1
check "user option survives upgrade" "$(grep -c ps5_cu_unlock "$E/cmdline.txt")" 1
check "a kept for rollback" "$(cat "$E"/ostree/aaaa*/vmlinuz)" kernel-a

rm "$B/loader/entries/ostree-a.conf"; sed -i 's/^version 2/version 1/' "$B/loader/entries/ostree-b.conf"
deployment c 2; sync
check "second upgrade boots c" "$(cat "$E/bzImage")" kernel-c
check "karg dropped by the image is gone" "$(grep -c newkarg "$E/cmdline.txt" || true)" 0
check "a pruned, b kept" "$(ls "$E/ostree")" bbbbbbbbbbbb

touch "$E/path-override.txt"; deployment d 3; sync
check "hands off during a manual rollback" "$(cat "$E/bzImage")" kernel-c
