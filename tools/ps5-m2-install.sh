#!/bin/bash
# Moves the running PS5 Bazzite Deck system, bootc or Legacy, onto the M.2 and starts it from there from now on.
# The USB drive keeps its boot partition (and on bootc its /boot): the loader always starts Linux from there.
#   sudo ps5-m2-install          copy the system to the M.2 (erases the M.2's Linux partition)
#   sudo ps5-m2-install --back   start from the USB system again (the M.2 copy stays)
# The M.2 must be prepared with m2_init from ps5-linux-tools first (it creates /dev/nvme0n1p1).
set -euo pipefail
NVME=${NVME:-/dev/nvme0n1p1}
SRC=/mnt/ps5-m2-src DST=/mnt/ps5-m2-dst

# --- rewrites, kept apart so they can be tested on plain files
bls_set_root() {   # <entries dir> <old uuid> <new uuid>: the root of every bootc boot entry
    sed -i "s/\broot=UUID=$2\b/root=UUID=$3/" "$1"/*.conf
}
deploy_etc_set_root() {   # <sysroot> <old uuid> <new uuid>: fstab and mount units of every deployment
    grep -rlZ --include=fstab --include='*.mount' "$2" "$1"/ostree/deploy/*/deploy/*/etc 2>/dev/null |
        xargs -0r sed -i "s/$2/$3/g"
}
legacy_fstab() {   # <fstab> <new root label>: root by label, boot partition by label and optional
    local f=$1 tmp; tmp=$(mktemp)
    awk -v lbl="$2" '$2 == "/" { next } $2 == "/efi" || $2 == "/boot/efi" { next } { print }
        END { print "LABEL=" lbl " / ext4 defaults 0 1"; print "LABEL=boot /efi vfat defaults,nofail 0 2" }' "$f" > "$tmp"
    cat "$tmp" > "$f"; rm -f "$tmp"
}
cmdline_set_root() {   # <cmdline.txt> <root=...>
    sed -i "1s/\broot=[^ ]*/$2/" "$1"
}

[ "${1-}" = --functions-only ] && return 0 2>/dev/null
[ "$EUID" -eq 0 ] || { echo "Run with sudo"; exit 1; }
E=; for d in /efi /boot/efi; do [ -f "$d/cmdline.txt" ] && { E=$d; break; }; done
[ -n "$E" ] || { echo "STOP: no boot partition with cmdline.txt mounted at /efi or /boot/efi"; exit 1; }
STATE=$E/ps5-m2-usb-root.txt   # the USB root, for --back; on the boot partition, which both systems share
if [ -e /run/ostree-booted ]; then MODE=bootc; ROOTDEV=$(findmnt -no SOURCE /sysroot); else MODE=legacy; ROOTDEV=$(findmnt -no SOURCE /); fi

if [ "${1-}" = --back ]; then
    [ -s "$STATE" ] || { echo "STOP: no record of the USB system ($STATE)"; exit 1; }
    read -r usb < "$STATE"
    if [ "$MODE" = bootc ]; then
        cur=$(blkid -s UUID -o value "$ROOTDEV")
        bls_set_root /boot/loader/entries "$cur" "${usb#UUID=}"
    fi
    cmdline_set_root "$E/cmdline.txt" "root=$usb"; sync
    echo "Back to the USB system ($usb) from the next start: power off and start with the loader."
    exit 0
fi

[ -b "$NVME" ] || { echo "STOP: $NVME not found. Prepare the M.2 with m2_init from ps5-linux-tools first."; exit 1; }
[ "$(readlink -f "$ROOTDEV")" != "$(readlink -f "$NVME")" ] || { echo "STOP: the system already runs from $NVME"; exit 1; }
! findmnt -rno TARGET -S "$NVME" >/dev/null || { echo "STOP: $NVME is mounted ($(findmnt -rno TARGET -S "$NVME" | head -1)); unmount it first"; exit 1; }
used=$(df -B1 --output=used "$([ "$MODE" = bootc ] && echo /sysroot || echo /)" | tail -1)
size=$(blockdev --getsize64 "$NVME")
[ "$used" -lt "$size" ] || { echo "STOP: the system ($((used >> 30)) GiB) doesn't fit on $NVME ($((size >> 30)) GiB)"; exit 1; }

echo "Copies this $MODE system ($ROOTDEV, $((used >> 30)) GiB) to $NVME ($((size >> 30)) GiB). Everything on $NVME is erased."
read -rp "Type yes to continue: " a; [ "$a" = yes ] || exit 1

if [ "$MODE" = bootc ]; then LABEL=bazzite-bootc-m2; else LABEL="$(blkid -s LABEL -o value "$ROOTDEV")-m2"; fi
mkfs.ext4 -q -F -L "$LABEL" "$NVME"
mkdir -p "$SRC" "$DST"
trap 'umount -q "$SRC" "$DST" 2>/dev/null || true' EXIT
mount -o ro "$ROOTDEV" "$SRC"   # the partition itself, without anything mounted on top of it
mount "$NVME" "$DST"
echo "Copying, 10 to 30 minutes without progress output..."
cp -a "$SRC/." "$DST/"   # keeps hardlinks (the ostree repository relies on them), xattrs and SELinux labels
sync

if [ "$MODE" = bootc ]; then
    old=$(blkid -s UUID -o value "$ROOTDEV"); new=$(blkid -s UUID -o value "$NVME")
    echo "UUID=$old" > "$STATE"
    deploy_etc_set_root "$DST" "$old" "$new"
    bls_set_root /boot/loader/entries "$old" "$new"   # ostree takes later versions' arguments from these
    cmdline_set_root "$E/cmdline.txt" "root=UUID=$new"   # ps5-bootc-sync keeps it current from now on
else
    echo "LABEL=$(blkid -s LABEL -o value "$ROOTDEV")" > "$STATE"
    legacy_fstab "$DST/etc/fstab" "$LABEL"
    cmdline_set_root "$E/cmdline.txt" "root=LABEL=$LABEL"
fi
sync
echo "Done. Power off and start with the loader: the system now starts from the M.2."
echo "Keep the USB drive plugged in. To go back: sudo ps5-m2-install --back"
