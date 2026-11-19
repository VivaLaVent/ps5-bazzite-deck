#!/bin/bash
# ps5-m2-install: the functions that point the boot files at the new root, and the refusal without root.
set -uo pipefail
S=$(cd "$(dirname "$0")/../.." && pwd)/tools/ps5-m2-install.sh
fail=0; check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
# shellcheck source=/dev/null
. "$S" --functions-only
set +e   # the script sets -e; this test checks failures itself
OLD=184d9bc7-1d63-4d97-b2b3-50240542dda1; NEW=0f1e2d3c-4b5a-6978-8796-a5b4c3d2e1f0; OTHER=184d9bc7-1d63-4d97-b2b3-50240542dda2
LINE="root=UUID=$OLD rw boot=UUID=db95cf33-333b-4487-bdb7-ce5c9e0e9ae9 rootwait console=tty0 ostree=/ostree/boot.1/default/a1e0/0 quiet"

printf '%s\n# second line root=UUID=%s\n' "$LINE" "$OLD" > "$T/cmdline.txt"
cmdline_set_root "$T/cmdline.txt" "root=UUID=$NEW"
check "cmdline: root= replaced" "$(head -1 "$T/cmdline.txt")" "${LINE/root=UUID=$OLD/root=UUID=$NEW}"
check "cmdline: only the first line" "$(sed -n 2p "$T/cmdline.txt")" "# second line root=UUID=$OLD"

mkdir -p "$T/entries"
echo "options root=UUID=$OLD rw ostree=/ostree/boot.1/default/a/0" > "$T/entries/a.conf"
echo "options root=UUID=$OTHER rw ostree=/ostree/boot.1/default/b/0" > "$T/entries/b.conf"
bls_set_root "$T/entries" "$OLD" "$NEW"
check "BLS: the old root's entry" "$(cat "$T/entries/a.conf")" "options root=UUID=$NEW rw ostree=/ostree/boot.1/default/a/0"
check "BLS: another root's entry untouched" "$(cat "$T/entries/b.conf")" "options root=UUID=$OTHER rw ostree=/ostree/boot.1/default/b/0"

for d in d1 d2; do
    E="$T/sys/ostree/deploy/default/deploy/$d/etc"; mkdir -p "$E/systemd/system"
    echo "UUID=$OLD / ext4 defaults 0 1" > "$E/fstab"
    printf '[Mount]\nWhat=/dev/disk/by-uuid/%s\n' "$OLD" > "$E/systemd/system/sysroot.mount"
    echo "id=$OLD" > "$E/other.conf"
done
deploy_etc_set_root "$T/sys" "$OLD" "$NEW"
E2="$T/sys/ostree/deploy/default/deploy/d2/etc"
check "deployments: fstab" "$(cat "$E2/fstab")" "UUID=$NEW / ext4 defaults 0 1"
check "deployments: mount unit" "$(sed -n 2p "$E2/systemd/system/sysroot.mount")" "What=/dev/disk/by-uuid/$NEW"
check "deployments: other files untouched" "$(cat "$E2/other.conf")" "id=$OLD"

if [ "$EUID" -ne 0 ]; then
    out=$(bash "$S" 2>&1); rc=$?
    check "without root: refuses" "$rc:$out" "1:Run with sudo"
fi
exit $fail
