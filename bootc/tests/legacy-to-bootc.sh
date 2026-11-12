#!/usr/bin/env bash
# The parts of tools/legacy-to-bootc.sh that run without a console: accounts, kernel arguments, the first-start move.
set -uo pipefail
SRC=$(cd "$(dirname "$0")/../.." && pwd)/tools/legacy-to-bootc.sh
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail=0; check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1"; echo "     got:  $2"; echo "     want: $3"; fail=1; fi; }
# the three functions, without running the script
sed -n '/^carry_accounts() {$/,/^}$/p; /^append_kargs() {$/,/^}$/p; /^write_firstboot() {$/,/^}$/p' "$SRC" > "$T/fn.sh"
# shellcheck disable=SC1091
. "$T/fn.sh"

O=$T/old; N=$T/new; mkdir -p "$O/etc" "$N/etc/systemd/system" "$N/usr/lib/bootc/kargs.d"
printf 'root:x:0:0:root:/root:/bin/bash\nps5:x:1000:1000:PS5:/home/ps5:/bin/bash\nsddm:x:971:971::/var/lib/sddm:/sbin/nologin\nnobody:x:65534:65534::/:/sbin/nologin\n' > "$O/etc/passwd"
printf 'root:!::0:99999:7:::\nps5:$6$hash:19000:0:99999:7:::\nsddm:!!:19000::::::\n' > "$O/etc/shadow"
printf 'root:x:0:\nwheel:x:10:ps5\nps5:x:1000:\nsddm:x:971:\ninput:x:104:ps5\n' > "$O/etc/group"
printf 'ps5:524288:65536\n' > "$O/etc/subuid"; cp "$O/etc/subuid" "$O/etc/subgid"
printf 'root:x:0:0:root:/root:/bin/bash\n' > "$N/etc/passwd"; printf 'root:!::0:99999:7:::\n' > "$N/etc/shadow"; chmod 000 "$N/etc/shadow"
printf 'root:x:0:\n' > "$N/etc/group"; printf 'wheel:x:10:\ninput:x:104:\nvideo:x:39:\n' > "$N/usr/lib/group"
out=$(carry_accounts "$O" "$N")
check "the login user is found, system users are not" "$out" "  users: ps5"
check "passwd: ps5 added, sddm and nobody not" "$(cut -d: -f1 "$N/etc/passwd" | tr '\n' ' ')" "root ps5 "
check "shadow: ps5's password hash carried over" "$(grep -c '^ps5:\$6\$hash:' "$N/etc/shadow")" 1
check "shadow keeps its mode" "$(stat -c %a "$N/etc/shadow")" 0
check "group: own group added; wheel and input taken from /usr/lib/group with ps5 in them" "$(sort "$N/etc/group" | tr '\n' ' ')" "input:x:104:ps5 ps5:x:1000: root:x:0: wheel:x:10:ps5 "
check "subuid and subgid carried over" "$(cat "$N/etc/subuid" "$N/etc/subgid" | tr '\n' ' ')" "ps5:524288:65536 ps5:524288:65536 "
carry_accounts "$O" "$N" >/dev/null
check "a second run adds nothing" "$(wc -l < "$N/etc/passwd") $(wc -l < "$N/etc/group") $(grep -c ps5 "$N/etc/shadow")" "2 4 1"

E=$T/entries; mkdir -p "$E"
printf 'kargs = ["rootwait", "console=tty0", "idle=halt"]\n' > "$N/usr/lib/bootc/kargs.d/10-ps5.toml"
printf 'title x\nversion 1\noptions root=UUID=abcd rw ostree=/ostree/boot.1/default/ff/0\nlinux /ostree/x/vmlinuz\ninitrd /ostree/x/initramfs.img\n' > "$E/ostree-1.conf"
append_kargs "$N" "$E"
check "the image's kargs.d arguments follow ostree's own" "$(grep ^options "$E/ostree-1.conf")" "options root=UUID=abcd rw ostree=/ostree/boot.1/default/ff/0 rootwait console=tty0 idle=halt"
append_kargs "$N" "$E"
check "a second run adds nothing; other lines untouched" "$(grep -c . "$E/ostree-1.conf") $(grep -o 'rootwait' "$E/ostree-1.conf" | wc -l)" "5 1"

write_firstboot "$N"
check "first-start unit, script and its sysinit link are written" "$([ -x "$N/etc/ps5-legacy-migrate" ] && readlink "$N/etc/systemd/system/sysinit.target.wants/ps5-legacy-migrate.service")" "../ps5-legacy-migrate.service"
S=$T/sys; mkdir -p "$S/var/home/ps5/.steam" "$S/var/lib/flatpak/app" "$S/var/lib/bluetooth" "$S/usr" "$S/ostree/deploy/default/var"
echo game > "$S/var/home/ps5/.steam/game"; ln -s var/home "$S/home"
PS5_SYSROOT=$S sh "$N/etc/ps5-legacy-migrate" >/dev/null
V=$S/ostree/deploy/default/var
check "home, Flatpaks and Bluetooth pairings moved into the bootc system" "$(cat "$V/home/ps5/.steam/game") $([ -d "$V/lib/flatpak/app" ] && [ -d "$V/lib/bluetooth" ] && echo moved)" "game moved"
check "nothing left behind in the Legacy home; the rest of Legacy untouched" "$(ls -A "$S/var/home" | wc -l) $([ -d "$S/usr" ] && echo usr)" "0 usr"
check "done marker written" "$([ -e "$V/lib/ps5-bazzite-bootc/legacy-migrated" ] && echo yes)" yes
mkdir -p "$S/var/home/ps5"; echo new > "$S/var/home/ps5/later"
PS5_SYSROOT=$S sh "$N/etc/ps5-legacy-migrate" >/dev/null
check "an existing home in the bootc system is never overwritten" "$(ls "$V/home/ps5" -A | tr '\n' ' ')$(cat "$S/var/home/ps5/later")" ".steam new"
S2=$T/sys2; mkdir -p "$S2/home/ps5" "$S2/ostree/deploy/default/var"; echo a > "$S2/home/ps5/a"
PS5_SYSROOT=$S2 sh "$N/etc/ps5-legacy-migrate" >/dev/null
check "a Legacy system with a real /home folder: moved too" "$(cat "$S2/ostree/deploy/default/var/home/ps5/a")" a
exit $fail
