#!/bin/sh
# The loader's cmdline.txt names the deployment as /ostree/boot.N/default/<checksum>/<n>. ostree keeps that N in two
# places, /boot and the root, and they can be on different drives (root on the M.2, /boot on the USB drive). When
# the root has the same deployment under the other boot.N only, ostree-prepare-root finds nothing and the start
# ends in the emergency shell. Link the missing boot.N to the other one's folder; ps5-bootc-sync then puts the
# boot partition right, and ostree's next cleanup removes the link.
R=${PS5_SYSROOT:-/sysroot}
t=
for a in $(cat "${PS5_CMDLINE:-/proc/cmdline}"); do case "$a" in ostree=*) t=${a#ostree=} ;; esac; done
case "$t" in
    /ostree/boot.0/*) want=boot.0; other=boot.1 ;;
    /ostree/boot.1/*) want=boot.1; other=boot.0 ;;
    *) exit 0 ;;
esac
[ ! -e "$R$t" ] || exit 0
[ ! -e "$R/ostree/$want" ] && [ ! -L "$R/ostree/$want" ] || exit 0
[ -e "$R/ostree/$other${t#/ostree/"$want"}" ] || exit 0
dir=$(readlink "$R/ostree/$other") || exit 0
ln -s "$dir" "$R/ostree/$want" 2>/dev/null || exit 0
echo "ps5-ostree-path: the root has this deployment under $other, not $want: linked $want to $dir" > "${PS5_LOG:-/dev/kmsg}"
exit 0
