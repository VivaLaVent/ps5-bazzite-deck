#!/usr/bin/env bash
# ps5-ostree-path (initramfs) against fake roots: it links a missing boot.N only to the same deployment.
set -uo pipefail
S=$(cd "$(dirname "$0")/.." && pwd)/system_files/usr/lib/dracut/modules.d/90ps5-ostree-path/ps5-ostree-path.sh
D=$(mktemp -d); trap 'chmod -R u+w "$D"; rm -rf "$D"' EXIT; R=$D/root
NEW=7b61e90c0bab3465614a6eed644a56e16748e929acfe6839a2b4b7d5823a25bf; OLD=e50295915c05e29ccf81bb366966d1122e6b570af1d853f684e1da85fa5ec70b
mk() { chmod -R u+w "$D"; rm -rf "$R"; mkdir -p "$R"/ostree/deploy/default/deploy/{aaa.0,bbb.0}; }
bootdir() { mkdir -p "$R/ostree/$1/default/$NEW" "$R/ostree/$1/default/$OLD"
    ln -s ../../../deploy/default/deploy/aaa.0 "$R/ostree/$1/default/$NEW/0"; ln -s ../../../deploy/default/deploy/bbb.0 "$R/ostree/$1/default/$OLD/0"; }
run() { echo "$1" > "$D/cmdline"; PS5_SYSROOT=$R PS5_CMDLINE=$D/cmdline PS5_LOG=$D/log sh "$S"; }
linked() { [ -L "$R/ostree/$1" ] && readlink "$R/ostree/$1" || echo none; }
fail=0; check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi; }
C="root=UUID=535d rw boot=UUID=70ed rootwait ostree=/ostree/boot.1/default/$NEW/0 amdgpu.ps5_cu_unlock=3"

mk; bootdir boot.0.1; ln -s boot.0.1 "$R/ostree/boot.0"; run "$C"
check "root has the deployment under boot.0 only: boot.1 linked to its folder" "$(linked boot.1)" boot.0.1
check "the path from cmdline.txt resolves to the deployment" "$(basename "$(readlink -f "$R/ostree/boot.1/default/$NEW/0")")" aaa.0
run "$C"; check "a second run changes nothing" "$(ls "$R/ostree" | tr '\n' ' ')" "boot.0 boot.0.1 boot.1 deploy "
mk; bootdir boot.1.0; ln -s boot.1.0 "$R/ostree/boot.1"; run "$C"
check "path already there: nothing added" "$(ls "$R/ostree" | tr '\n' ' ')" "boot.1 boot.1.0 deploy "
mk; bootdir boot.1.1; ln -s boot.1.1 "$R/ostree/boot.1"; run "${C/boot.1/boot.0}"
check "the other direction" "$(linked boot.0)" boot.1.1
mk; bootdir boot.0.1; ln -s boot.0.1 "$R/ostree/boot.0"; run "${C/$NEW/$(printf 'f%.0s' {1..64})}"
check "a deployment the root doesn't have: nothing" "$(linked boot.1)" none
mk; bootdir boot.0.1; ln -s boot.0.1 "$R/ostree/boot.0"; run "${C/\/0 amdgpu/\/1 amdgpu}"
check "same checksum, another index: nothing" "$(linked boot.1)" none
mk; bootdir boot.0.1; ln -s boot.0.1 "$R/ostree/boot.0"; mkdir -p "$R/ostree/boot.1.0/default"; ln -s boot.1.0 "$R/ostree/boot.1"; run "$C"
check "boot.1 exists without that deployment: left alone" "$(linked boot.1)" boot.1.0
mk; bootdir boot.0.1; ln -s boot.0.1 "$R/ostree/boot.0"; run "root=LABEL=x rw quiet"
check "no ostree= (a Legacy start): nothing" "$(linked boot.1)" none
mk; bootdir boot.0.1; ln -s boot.0.1 "$R/ostree/boot.0"; chmod a-w "$R/ostree"
if [ "$(id -u)" = 0 ]; then echo "$C" > "$D/cmdline"; chmod -R a+rX "$D"; PS5_SYSROOT=$R PS5_CMDLINE=$D/cmdline PS5_LOG=/dev/null setpriv --reuid 65534 --regid 65534 --clear-groups sh "$S"; rc=$?; else run "$C"; rc=$?; fi
check "a root it can't write to: exits 0, no link" "$rc $(linked boot.1)" "0 none"
exit $fail
