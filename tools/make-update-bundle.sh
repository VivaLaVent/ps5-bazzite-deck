#!/bin/bash
# Builds the in-place update bundle from a finished image (run on the build PC):
#   bash tools/make-update-bundle.sh v1.0.6
# Output: ~/ps5-build-7.3/output/ps5-bazzite-deck-<version>-update.tar.xz (+ .sha256)
set -euo pipefail
SRC=$(cd "$(dirname "$0")/.." && pwd)
REL=${1:?usage: make-update-bundle.sh v1.0.6}
B=~/ps5-build-7.3; IMG=$B/output/ps5-bazzite-deck.img
NAME=ps5-bazzite-deck-$REL-update; OUT=$B/output/$NAME
[ -f "$IMG" ] || { echo "STOP: $IMG not found"; exit 1; }
rm -rf "$OUT" "$OUT.tar.xz" "$OUT.tar.xz.sha256"; mkdir -p "$OUT/efi" "$OUT/modules" "$OUT/files"
LOOP=$(sudo losetup -fP -r --show "$IMG")
cleanup() { sudo umount /mnt/ps5boot /mnt/ps5root 2>/dev/null || true; sudo losetup -d "$LOOP" 2>/dev/null || true; }
trap cleanup EXIT
sudo mkdir -p /mnt/ps5boot /mnt/ps5root
sudo mount -o ro "${LOOP}p2" /mnt/ps5boot
sudo mount -o ro,noload "${LOOP}p1" /mnt/ps5root
echo "boot partition:"; sudo ls -la /mnt/ps5boot
K=$(sudo ls /mnt/ps5root/usr/lib/modules); [ "$(echo "$K" | wc -l)" = 1 ] || { echo "STOP: expected one kernel, found: $K"; exit 1; }
sudo test -f /mnt/ps5boot/bzImage || { echo "STOP: no bzImage on the boot partition"; exit 1; }
for f in $(sudo ls /mnt/ps5boot); do case "$f" in bzImage|initrd*) sudo cp "/mnt/ps5boot/$f" "$OUT/efi/";; esac; done
sudo cp -a "/mnt/ps5root/usr/lib/modules/$K" "$OUT/modules/"
sudo test -f /mnt/ps5root/etc/modprobe.d/ps5-iw620.conf && sudo cp /mnt/ps5root/etc/modprobe.d/ps5-iw620.conf "$OUT/files/ps5-iw620-modprobe.conf"
sudo chown -R "$(id -u):$(id -g)" "$OUT"
cp "$SRC/files/99-ps5-iw620.conf" "$SRC/files/99-ps5-bt-phantom.rules" "$SRC/files/btusb-ps5.conf" "$SRC/files/ps5-stage-firmware-no-default-deps.conf" "$SRC/files/ps5-bt-addr" "$SRC/files/ps5-bt-addr.service" "$OUT/files/"
# FILES: source, destination, optional mode (default 644)
cat > "$OUT/FILES" << 'L'
99-ps5-iw620.conf /etc/NetworkManager/conf.d/99-ps5-iw620.conf
99-ps5-bt-phantom.rules /etc/udev/rules.d/99-ps5-bt-phantom.rules
btusb-ps5.conf /etc/modprobe.d/btusb-ps5.conf
ps5-stage-firmware-no-default-deps.conf /etc/systemd/system/ps5-stage-firmware.service.d/10-no-default-deps.conf
ps5-iw620-modprobe.conf /etc/modprobe.d/ps5-iw620.conf
ps5-bt-addr /usr/local/sbin/ps5-bt-addr 755
ps5-bt-addr.service /etc/systemd/system/ps5-bt-addr.service
L
echo "$REL" > "$OUT/VERSION"; echo "$K" > "$OUT/KERNEL"
cp "$SRC/tools/update.sh" "$OUT/update.sh"
(cd "$OUT" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
echo "efi files: $(ls "$OUT/efi" | tr '\n' ' ')  kernel: $K  modules: $(du -sh "$OUT/modules" | cut -f1)"
tar -C "$B/output" -cJf "$OUT.tar.xz" "$NAME"
(cd "$B/output" && sha256sum "$NAME.tar.xz" > "$NAME.tar.xz.sha256" && ls -lh "$NAME.tar.xz" && cat "$NAME.tar.xz.sha256")
