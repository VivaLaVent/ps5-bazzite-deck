#!/usr/bin/env bash
# Put the kernel, initramfs and cmdline.txt on a bootc-image-builder disk's EFI partition,
# where the PS5 loader needs them for the first start (docs/loader-contract.md).
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

fatlabel "$ESP" boot   # LABEL=boot: ps5-kexec, ps5-m2-install and /dev/ps5-boot find it by it
mount "$ESP" "$M/esp"
"$HERE/system_files/usr/bin/ps5-bootc-sync" --boot "$M/boot" --esp "$M/esp"
echo 0x180000000 > "$M/esp/vram.txt"
ls -l "$M/esp"
cat "$M/esp/cmdline.txt"
