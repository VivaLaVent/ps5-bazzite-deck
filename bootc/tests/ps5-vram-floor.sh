#!/bin/bash
# ps5-vram-floor on a fake cgroup tree laid out like a Game Mode session (dmem.min files as the kernel has them).
set -uo pipefail
S=$(cd "$(dirname "$0")/.." && pwd)/system_files/usr/bin/ps5-vram-floor
fail=0; check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
U=user.slice/user-1000.slice/user@1000.service
SESS=$U/app.slice/app-gamescope\\x2dsession.slice/gamescope-session-plus@ogui-steam.service
for d in user.slice user.slice/user-1000.slice $U $U/app.slice "$U/app.slice/app-gamescope\\x2dsession.slice" "$SESS"; do
    mkdir -p "$T/$d"; echo "drm/0000:20:00.0/vram 0" > "$T/$d/dmem.min"
done
v() { cut -d' ' -f2 "$T/$1/dmem.min"; }
M=$((512 * 1024 * 1024))
PS5_CGROUP_ROOT=$T sh "$S" 1000
check "system part: user.slice" "$(v user.slice)" "$M"
check "system part: user manager" "$(v $U)" "$M"
check "system part leaves the session alone" "$(v "$SESS")" "0"
chmod a-w "$T/user.slice/dmem.min" "$T/user.slice/user-1000.slice/dmem.min" "$T/$U/dmem.min"
echo "drm/0000:20:00.0/vram 0" > "$T/$U/app.slice/dmem.min"
PS5_CGROUP_ROOT=$T PS5_SELF_CGROUP="/$SESS" sh "$S" self
check "session part: its own cgroup" "$(v "$SESS")" "$M"
check "session part: app.slice" "$(v $U/app.slice)" "$M"
check "session part stops at the root-owned user manager" "$(cut -d' ' -f2 "$T/$U/dmem.min")" "$M"
if [ "$EUID" -ne 0 ]; then
    mkdir -p "$T/etc"; echo 256 > "$T/etc/vram-floor"
    sed "s#/etc/ps5-bazzite-deck/vram-floor#$T/etc/vram-floor#" "$S" > "$T/floor"
    PS5_CGROUP_ROOT=$T PS5_SELF_CGROUP="/$SESS" sh "$T/floor" self
    check "size from the file (256 MiB)" "$(v "$SESS")" "$((256 * 1024 * 1024))"
    echo 0 > "$T/etc/vram-floor"; PS5_CGROUP_ROOT=$T PS5_SELF_CGROUP="/$SESS" sh "$T/floor" self
    check "0 switches it off" "$(v "$SESS")" "0"
fi
mkdir -p "$T/nodmem/a/b"
PS5_CGROUP_ROOT=$T/nodmem PS5_SELF_CGROUP=/a/b sh "$S" self; check "no dmem controller: nothing, exit 0" "$?" "0"
sh "$S" nonsense > /dev/null; check "bad argument: exit 1" "$?" "1"
exit $fail
