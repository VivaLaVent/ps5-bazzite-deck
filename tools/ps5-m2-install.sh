#!/bin/bash
# Moves the running PS5 Bazzite Deck system, bootc or Legacy, onto the M.2; the USB drive keeps the boot partition
# (and on bootc /boot), which the loader always starts from. The M.2 must be prepared with m2_init first.
#   sudo ps5-m2-install          copy the system to the M.2 (erases the M.2's Linux partition)
#   sudo ps5-m2-install --back   start from the USB system again (the M.2 copy stays)
#   sudo ps5-m2-install --boot   bootc on the M.2: /boot moves onto the M.2 too (test for starting without a USB drive)
set -euo pipefail
NVME=${NVME:-/dev/nvme0n1p1}
SRC=/mnt/ps5-m2-src DST=/mnt/ps5-m2-dst

bls_set_root() {   # <entries dir> <old uuid> <new uuid>
    sed -i "s/\broot=UUID=$2\b/root=UUID=$3/" "$1"/*.conf
}
deploy_etc_set_root() {   # <sysroot> <old uuid> <new uuid>: fstab and mount units of every deployment
    grep -rlZ --include=fstab --include='*.mount' "$2" "$1"/ostree/deploy/*/deploy/*/etc 2>/dev/null |
        xargs -0r sed -i "s/$2/$3/g"
}
legacy_fstab() {   # <fstab> <root label>
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
STATE=$E/ps5-m2-usb-root.txt
if [ -e /run/ostree-booted ]; then MODE=bootc; ROOTMP=/sysroot; else MODE=legacy; ROOTMP=/; fi
ROOTDEV=$(findmnt -no SOURCE "$ROOTMP")
BOOT_RO=0

boot_rw() {   # bootc keeps /boot read-only; the boot entries live there
    [ "$MODE" = bootc ] || return 0
    if findmnt -no OPTIONS /boot | tr ',' '\n' | grep -qx ro; then mount -o remount,rw /boot; BOOT_RO=1; fi
}
cleanup() {
    umount -q "$SRC" "$DST" 2>/dev/null || true
    [ "$BOOT_RO" = 0 ] || mount -o remount,ro /boot 2>/dev/null || true
}
trap cleanup EXIT

boot_files_point_at() {   # <root=...>: cmdline.txt (and on bootc every boot entry) start that root
    local want=$1
    [ "$MODE" = bootc ] && /usr/bin/ps5-bootc-sync >/dev/null
    grep -qw "$want" "$E/cmdline.txt" || { echo "STOP: $E/cmdline.txt doesn't start $want"; return 1; }
    [ "$MODE" = legacy ] && return 0
    local f; for f in /boot/loader/entries/*.conf; do
        grep -qw "$want" "$f" || { echo "STOP: $f doesn't start $want"; return 1; }
    done
}

if [ "${1-}" = --back ]; then
    [ -s "$STATE" ] || { echo "STOP: no record of the USB system ($STATE)"; exit 1; }
    read -r usb < "$STATE"
    if [ "$MODE" = bootc ]; then
        boot_rw
        bls_set_root /boot/loader/entries "$(blkid -s UUID -o value "$ROOTDEV")" "${usb#UUID=}"
    fi
    cmdline_set_root "$E/cmdline.txt" "root=$usb"
    boot_files_point_at "root=$usb"; sync
    echo "Back to the USB system ($usb) from the next start: power off and start with the loader."
    exit 0
fi

if [ "${1-}" = --boot ]; then
    [ "$MODE" = bootc ] || { echo "STOP: --boot is for bootc installs"; exit 1; }
    [ "$(readlink -f "$ROOTDEV")" = "$(readlink -f "$NVME")" ] || { echo "STOP: the system doesn't run from $NVME; run sudo ps5-m2-install first"; exit 1; }
    BOOTDEV=$(findmnt -no SOURCE /boot)
    [ "$(findmnt -no MAJ:MIN /boot)" != "$(findmnt -no MAJ:MIN /sysroot)" ] || { echo "STOP: /boot is already on $NVME"; exit 1; }
    mkdir -p "$DST"
    # without what is mounted on top: the M.2's own, empty /boot folder
    mount --bind /sysroot "$DST"
    mount -o remount,bind,rw "$DST"
    [ -d "$DST/boot" ] && [ -z "$(ls -A "$DST/boot")" ] || { echo "STOP: /boot on $NVME isn't an empty folder"; exit 1; }
    cp -ax /boot/. "$DST/boot/"
    mkdir -p "$DST/boot/efi"
    [ -L "$DST/boot/loader" ] || { echo "STOP: the copy of /boot has no loader link"; exit 1; }
    # ostree bind-mounts the M.2's /boot once fstab no longer names the USB one; the boot partition becomes optional
    for f in "$DST"/ostree/deploy/*/deploy/*/etc/fstab; do
        awk '$2 != "/boot"' "$f" > "$f.new"; cat "$f.new" > "$f"; rm -f "$f.new"
        grep -q '[[:space:]]/boot/efi[[:space:]]' "$f" ||
            echo "/dev/ps5-boot /boot/efi vfat umask=0077,shortname=winnt,nofail,x-systemd.device-timeout=5s 0 0" >> "$f"
    done
    sync
    echo "Done: /boot is on the M.2 from the next start ($BOOTDEV is no longer used)."
    echo "Power off and start with the loader; the USB drive still holds the boot partition the loader reads."
    exit 0
fi

[ -b "$NVME" ] || { echo "STOP: $NVME not found. Prepare the M.2 with m2_init from ps5-linux-tools first."; exit 1; }
[ "$(readlink -f "$ROOTDEV")" != "$(readlink -f "$NVME")" ] || { echo "STOP: the system already runs from $NVME"; exit 1; }
! findmnt -rno TARGET -S "$NVME" >/dev/null || { echo "STOP: $NVME is mounted ($(findmnt -rno TARGET -S "$NVME" | head -1)); unmount it first"; exit 1; }
used=$(df -B1 --output=used "$ROOTMP" | tail -1)
size=$(blockdev --getsize64 "$NVME")
[ "$used" -lt "$size" ] || { echo "STOP: the system ($((used >> 30)) GiB) doesn't fit on $NVME ($((size >> 30)) GiB)"; exit 1; }

echo "Copies this $MODE system ($ROOTDEV, $((used >> 30)) GiB) to $NVME ($((size >> 30)) GiB). Everything on $NVME is erased."
read -rp "Type yes to continue: " a; [ "$a" = yes ] || exit 1

if [ "$MODE" = bootc ]; then LABEL=bazzite-bootc-m2; else LABEL="$(blkid -s LABEL -o value "$ROOTDEV")-m2"; fi
mkfs.ext4 -q -F -L "$LABEL" "$NVME"
mkdir -p "$SRC" "$DST"
# a second mount of the root device would have to match its read-write state; a bind mount shows the partition
# without what is mounted on top of it
mount --bind "$ROOTMP" "$SRC"
mount -o remount,bind,ro "$SRC"
mount "$NVME" "$DST"
echo "Copying, 10 to 30 minutes..."
if command -v rsync >/dev/null; then
    rsync -aHAX --numeric-ids --info=progress2 "$SRC/" "$DST/"
else
    cp -a "$SRC/." "$DST/"
fi
sync

if [ "$MODE" = bootc ]; then
    old=$(blkid -s UUID -o value "$ROOTDEV"); new=$(blkid -s UUID -o value "$NVME")
    [ -d "$DST/ostree/deploy" ] || { echo "STOP: the copy has no ostree deployments"; exit 1; }
    echo "UUID=$old" > "$STATE"
    deploy_etc_set_root "$DST" "$old" "$new"
    boot_rw
    bls_set_root /boot/loader/entries "$old" "$new"
    cmdline_set_root "$E/cmdline.txt" "root=UUID=$new"
    boot_files_point_at "root=UUID=$new"
else
    [ -f "$DST/etc/fstab" ] || { echo "STOP: the copy has no /etc/fstab"; exit 1; }
    echo "LABEL=$(blkid -s LABEL -o value "$ROOTDEV")" > "$STATE"
    legacy_fstab "$DST/etc/fstab" "$LABEL"
    cmdline_set_root "$E/cmdline.txt" "root=LABEL=$LABEL"
    boot_files_point_at "root=LABEL=$LABEL"
fi
sync
echo "Done. Power off and start with the loader: the system now starts from the M.2."
echo "Keep the USB drive plugged in. To go back: sudo ps5-m2-install --back"
