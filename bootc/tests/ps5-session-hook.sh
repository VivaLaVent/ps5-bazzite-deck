#!/bin/bash
# The Game Mode session hook: gamescope starts without DirectMesh, Steam and the games get it (#78).
# Runs the hook in the order gamescope-session-plus uses: source it, start gamescope, post_gamescope_start, start the client.
set -uo pipefail
H=$(cd "$(dirname "$0")/.." && pwd)/system_files/etc/gamescope-session-plus/sessions.d/steam
fail=0; check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
sed 's#^/usr/bin/ps5-vram-floor self$#:#' "$H" > "$T/hook"
cat > "$T/session" << 'S'
#!/bin/bash
post_gamescope_start() { echo "bazzite's own hook ran" > "$OUT/own"; }
set -a; . "$HOOK"; set +a
sh -c 'echo "${VK_DRIVER_FILES:-unset}" > "$OUT/gamescope"' &
gamescope_pid=$!
wait "$gamescope_pid"
post_gamescope_start
sh -c 'echo "${VK_DRIVER_FILES:-unset}" > "$OUT/client"'
S
DM=/usr/share/directmesh/icd.d/radeon_icd.x86_64.json:/usr/share/vulkan/icd.d/radeon_icd.i686.json
run() { rm -rf "$T/out"; mkdir "$T/out"; ( [ "$1" = unset ] && unset VK_DRIVER_FILES || export VK_DRIVER_FILES=$1; HOOK=$T/hook OUT=$T/out timeout 20 bash "$T/session" ) 2>/dev/null; }
run "$DM"
check "DirectMesh set: gamescope starts without it" "$(cat "$T/out/gamescope")" "unset"
check "DirectMesh set: the client gets it" "$(cat "$T/out/client")" "$DM"
check "Bazzite's own post_gamescope_start still runs" "$(cat "$T/out/own")" "bazzite's own hook ran"
run unset
check "nothing set: gamescope" "$(cat "$T/out/gamescope")" "unset"
check "nothing set: the client" "$(cat "$T/out/client")" "unset"
run /home/me/my_icd.json
check "a user's own driver setting reaches gamescope" "$(cat "$T/out/gamescope")" "/home/me/my_icd.json"
check "a user's own driver setting reaches the client" "$(cat "$T/out/client")" "/home/me/my_icd.json"
exit $fail
