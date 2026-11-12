#!/usr/bin/env bash
# Runs ps5-bootc-sync against fake ostree boot entries: install, user edits, upgrades, rollback, --is-current.
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
echo extra >> "$E/initrd.img"; sync
check "user option kept" "$(grep -c ps5_cu_unlock "$E/cmdline.txt")" 1
check "initrd.img not rewritten while the default is unchanged" "$(tail -1 "$E/initrd.img")" extra

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

grep -o 'ostree=[^ ]*' "$B/loader/entries/ostree-b.conf" > "$T/cmdline"
check "warns when booted from an older entry" \
    "$(python3 -I "$SYNC" --boot "$B" --esp "$E" --cmdline "$T/cmdline" | grep -c 'older deployment')" 1
grep -o 'ostree=[^ ]*' "$B/loader/entries/ostree-c.conf" > "$T/cmdline"
check "quiet when booted from the default" \
    "$(python3 -I "$SYNC" --boot "$B" --esp "$E" --cmdline "$T/cmdline" | grep -c 'older deployment' || true)" 0

# --is-current: what the warm-reboot unit asks before loading the boot partition's kernel
cur() { python3 -I "$SYNC" --boot "$B" --esp "$E" --is-current && echo yes || echo no; }
check "boot partition current after a sync" "$(cur)" yes
sed -i 's/^version 1/version 3/' "$B/loader/entries/ostree-b.conf"   # bootc rollback: b is the default again
check "not current after a rollback, until the sync has run" "$(cur)" no
sync
check "rollback boots b" "$(cat "$E/bzImage")" kernel-b
check "current again after the sync" "$(cur)" yes
sed -i 's/^version 3/version 1/' "$B/loader/entries/ostree-b.conf"; sync
check "back on c" "$(cat "$E/bzImage")" kernel-c
sed -i 's/^options \(.*\)$/options \1 quiet/' "$B/loader/entries/ostree-c.conf"   # rpm-ostree kargs
check "not current after new kernel arguments" "$(cur)" no
sync
check "current once they are written" "$(cur)" yes

touch "$E/path-override.txt"; deployment d 3; sync
check "hands off during a manual rollback" "$(cat "$E/bzImage")" kernel-c
check "not current during a manual rollback" "$(cur)" no
