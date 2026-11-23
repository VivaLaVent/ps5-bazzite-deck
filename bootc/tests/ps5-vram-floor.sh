#!/bin/bash
# ps5-vram-floor on a fake cgroup tree laid out like a Game Mode session. The kernel creates dmem.min in a cgroup when
# its parent switches dmem on in cgroup.subtree_control; a fake tree can't, so the files are there from the start and
# the test checks that every parent was switched on, as Max found missing on v3.0.2 at user-UID.slice, user@UID.service
# and the session's slice.
set -uo pipefail
S=$(cd "$(dirname "$0")/.." && pwd)/system_files/usr/bin/ps5-vram-floor
fail=0; check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
U=user.slice/user-1000.slice/user@1000.service
SL="$U/app.slice/app-gamescope\\x2dsession\\x2dplus.slice"
SESS="$SL/gamescope-session-plus@ogui-steam.service"
mk() {
    rm -rf "$T/cg"; mkdir -p "$T/cg"; echo "cpu memory dmem" > "$T/cg/cgroup.controllers"; echo "cpu memory dmem" > "$T/cg/cgroup.subtree_control"
    for d in user.slice user.slice/user-1000.slice $U $U/app.slice "$SL" "$SESS"; do
        mkdir -p "$T/cg/$d"; echo "cpu memory dmem" > "$T/cg/$d/cgroup.controllers"; echo "cpu memory" > "$T/cg/$d/cgroup.subtree_control"
        echo "drm/0000:20:00.0/vram 0" > "$T/cg/$d/dmem.min"
    done
}
v() { cut -d' ' -f2 "$T/cg/$1/dmem.min"; }
on() { grep -qw dmem "$T/cg/$1/cgroup.subtree_control" && echo on || echo off; }
M=$((512 * 1024 * 1024))
mk
PS5_CGROUP_ROOT=$T/cg sh "$S" 1000
check "system: user.slice floor" "$(v user.slice)" "$M"
check "system: user-1000.slice floor" "$(v user.slice/user-1000.slice)" "$M"
check "system: user@1000.service floor" "$(v $U)" "$M"
check "system: dmem on in user.slice for user-1000.slice" "$(on user.slice)" "on"
check "system: dmem on in user-1000.slice for user@1000.service" "$(on user.slice/user-1000.slice)" "on"
check "system: leaves dmem in the user manager to the session (its files would be root's)" "$(on $U)" "off"
check "system: leaves the session's floor alone" "$(v "$SESS")" "0"
chmod a-w "$T/cg/user.slice/dmem.min" "$T/cg/user.slice/user-1000.slice/dmem.min" "$T/cg/$U/dmem.min" "$T/cg/user.slice/cgroup.subtree_control" "$T/cg/user.slice/user-1000.slice/cgroup.subtree_control"
PS5_CGROUP_ROOT=$T/cg PS5_SELF_CGROUP="/$SESS" sh "$S" self
check "session: dmem on in the user manager" "$(on $U)" "on"
check "session: dmem on in app.slice" "$(on $U/app.slice)" "on"
check "session: dmem on in the session's slice (Max's finding)" "$(on "$SL")" "on"
check "session: app.slice floor" "$(v $U/app.slice)" "$M"
check "session: the slice's floor" "$(v "$SL")" "$M"
check "session: its own cgroup's floor" "$(v "$SESS")" "$M"
check "session: the root-owned levels untouched" "$(v $U)" "$M"
mk; chmod a-w "$T/cg/$U/app.slice/dmem.min"
PS5_CGROUP_ROOT=$T/cg PS5_SELF_CGROUP="/$SESS" sh "$S" self
check "app.slice's floor root-owned (v3.0.3): skipped" "$(v $U/app.slice)" "0"
check "app.slice's floor root-owned: the session's slice still gets its floor" "$(v "$SL")" "$M"
check "app.slice's floor root-owned: the session itself still gets its floor" "$(v "$SESS")" "$M"
mk; rm "$T/cg/$SL/dmem.min"
PS5_CGROUP_ROOT=$T/cg PS5_SELF_CGROUP="/$SESS" sh "$S" self
check "a level without dmem.min: the others still get their floor" "$(v "$SESS")/$(v $U/app.slice)" "$M/$M"
mk; for d in user.slice user.slice/user-1000.slice; do echo "cpu memory" > "$T/cg/$d/cgroup.controllers"; done
PS5_CGROUP_ROOT=$T/cg sh "$S" 1000
check "controller not available: not switched on" "$(on user.slice/user-1000.slice)" "off"
if [ "$EUID" -ne 0 ]; then
    mk; mkdir -p "$T/etc"; echo 256 > "$T/etc/vram-floor"
    sed "s#/etc/ps5-bazzite-deck/vram-floor#$T/etc/vram-floor#" "$S" > "$T/floor"
    PS5_CGROUP_ROOT=$T/cg PS5_SELF_CGROUP="/$SESS" sh "$T/floor" self
    check "size from the file (256 MiB)" "$(v "$SESS")" "$((256 * 1024 * 1024))"
    echo 0 > "$T/etc/vram-floor"; PS5_CGROUP_ROOT=$T/cg PS5_SELF_CGROUP="/$SESS" sh "$T/floor" self
    check "0 switches it off" "$(v "$SESS")" "0"
fi
PS5_CGROUP_ROOT=$T/cg PS5_SELF_CGROUP=/system.slice/x.service sh "$S" self; check "a cgroup outside a user manager: nothing, exit 0" "$?" "0"
sh "$S" nonsense > /dev/null; check "bad argument: exit 1" "$?" "1"
exit $fail
