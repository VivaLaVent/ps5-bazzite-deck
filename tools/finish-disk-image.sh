#!/usr/bin/env bash
# Make a bootc-image-builder raw disk bootable by the PS5 loader: label its EFI
# partition "boot" and fill it the way ps5-bootc-sync does on the console.
#   sudo tools/finish-disk-image.sh disk.raw
set -euo pipefail
IMG=${1:?usage: finish-disk-image.sh disk.raw}
HERE=$(cd "$(dirname "$0")/.." && pwd)
LOOP=$(losetup -fP --show "$IMG")
M=$(mktemp -d)
mkdir "$M/esp" "$M/boot"
trap 'umount -q "$M/esp" "$M/boot"; losetup -d "$LOOP"; rm -rf "$M"' EXIT

ESP=''
BOOT=''
for p in "$LOOP"p*; do
    case $(blkid -o value -s TYPE "$p" || true) in
        vfat) ESP=$p ;;
        ext4|xfs)
            mount -o ro "$p" "$M/boot"
            if [ -d "$M/boot/loader/entries" ]; then BOOT=$p; break; fi
            umount "$M/boot" ;;
    esac
done
[ -n "$ESP" ] && [ -n "$BOOT" ] || { echo "no EFI or /boot partition in $IMG" >&2; exit 1; }

fatlabel "$ESP" boot
mount "$ESP" "$M/esp"
cp "$HERE/boot/vram.txt" "$M/esp/"
"$HERE/system_files/usr/bin/ps5-bootc-sync" --boot "$M/boot" --esp "$M/esp"
ls -l "$M/esp"
cat "$M/esp/cmdline.txt"
