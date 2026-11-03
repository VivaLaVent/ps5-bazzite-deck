#!/bin/bash
# Builds the in-place update bundle from a finished image (run on the build PC):
#   bash tools/make-update-bundle.sh v1.0.6
# Output: ~/ps5-build-7.3/output/ps5-bazzite-deck-<version>-update.tar.xz (+ .sha256)
set -euo pipefail
SRC=$(cd "$(dirname "$0")/.." && pwd)
REL=${1:?usage: make-update-bundle.sh v1.0.6}
B=~/ps5-build-7.3; IMG=${IMG:-$B/output/ps5-bazzite-deck.img}
NAME=ps5-bazzite-deck-$REL-update; OUT=$B/output/$NAME
rm -rf "$OUT" "$OUT.tar.xz" "$OUT.tar.xz.sha256"; mkdir -p "$OUT/efi" "$OUT/modules" "$OUT/files"
if [ -n "${FROM_BUNDLE:-}" ]; then
  # kernel, initrd and modules from an existing bundle (same kernel, new files/ and scripts)
  T=$(mktemp -d); tar -C "$T" -xJf "$FROM_BUNDLE"; S=$(ls -d "$T"/*/ | head -1)
  cp -a "$S/efi/." "$OUT/efi/"; cp -a "$S/modules/." "$OUT/modules/"
  [ -f "$S/files/ps5-iw620-modprobe.conf" ] && cp "$S/files/ps5-iw620-modprobe.conf" "$OUT/files/"
  K=$(cat "$S/KERNEL"); rm -rf "$T"
  echo "kernel parts from $(basename "$FROM_BUNDLE"): $K"
else
[ -f "$IMG" ] || { echo "STOP: $IMG not found"; exit 1; }
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
fi
cp "$SRC/files/99-ps5-wifi.conf" "$SRC/files/99-ps5-bt-phantom.rules" "$SRC/files/50-ps5-pro-bt-power.rules" "$SRC/files/btusb-ps5.conf" "$SRC/files/ps5-stage-firmware-no-default-deps.conf" "$SRC/files/ps5-bt-addr" "$SRC/files/ps5-bt-addr.service" "$SRC/files/ps5-bt-pro-addr" "$SRC/files/ps5-bt-pro-addr.service" "$SRC/files/ps5-bt-connectable.service" "$SRC/files/99-ps5-bt-services.rules" "$SRC/files/ps5-bt-revive" "$SRC/files/ps5-bt-revive.service" "$SRC/files/ps5-hidp.conf" "$SRC/files/99-ps5-usb-power.rules" "$SRC/files/ps5-warm-reboot" "$SRC/files/ps5-bt-address" "$SRC/tools/ps5-report.sh" "$SRC/tools/vrr-report.sh" "$SRC/files/ps5-perf" "$SRC/files/ps5-perf.service" "$SRC/files/ps5-stage-viola-fw" "$SRC/files/ps5-stage-viola-fw.service" "$SRC/files/ps5-wifi-powersave.service" "$SRC/files/ps5-wifi-powersave.timer" "$SRC/files/ps5-wifi-repair" "$SRC/files/ps5-wifi-repair.service" "$SRC/files/90-ps5-wifi-powersave" "$SRC/files/ps5-kexec" "$SRC/files/kexec-shim" "$SRC/files/ps5-kexec-prepare.service" "$SRC/files/ps5-reboot.service" "$SRC/files/reboot.target" "$SRC/files/ps5-reboot-to-ps5" "$OUT/files/"
# FILES: source, destination, optional mode (default 644)
cat > "$OUT/FILES" << 'L'
99-ps5-wifi.conf /etc/NetworkManager/conf.d/99-ps5-wifi.conf
99-ps5-bt-phantom.rules /etc/udev/rules.d/99-ps5-bt-phantom.rules
50-ps5-pro-bt-power.rules /etc/udev/rules.d/50-ps5-pro-bt-power.rules
btusb-ps5.conf /etc/modprobe.d/btusb-ps5.conf
ps5-stage-firmware-no-default-deps.conf /etc/systemd/system/ps5-stage-firmware.service.d/10-no-default-deps.conf
ps5-iw620-modprobe.conf /etc/modprobe.d/ps5-iw620.conf
ps5-bt-addr /usr/local/sbin/ps5-bt-addr 755
ps5-bt-addr.service /etc/systemd/system/ps5-bt-addr.service
ps5-bt-pro-addr /usr/local/sbin/ps5-bt-pro-addr 755
ps5-bt-pro-addr.service /etc/systemd/system/ps5-bt-pro-addr.service
ps5-bt-connectable.service /etc/systemd/system/ps5-bt-connectable.service
99-ps5-bt-services.rules /etc/udev/rules.d/99-ps5-bt-services.rules
ps5-bt-revive /usr/local/sbin/ps5-bt-revive 755
ps5-bt-revive.service /etc/systemd/system/ps5-bt-revive.service
ps5-hidp.conf /etc/modules-load.d/ps5-hidp.conf
99-ps5-usb-power.rules /etc/udev/rules.d/99-ps5-usb-power.rules
ps5-warm-reboot /usr/local/sbin/ps5-warm-reboot 755
ps5-bt-address /usr/local/sbin/ps5-bt-address 755
ps5-report.sh /usr/local/bin/ps5-report 755
vrr-report.sh /usr/local/bin/vrr-report 755
ps5-perf /usr/local/sbin/ps5-perf 755
ps5-perf.service /etc/systemd/system/ps5-perf.service
ps5-stage-viola-fw /usr/local/sbin/ps5-stage-viola-fw 755
ps5-stage-viola-fw.service /etc/systemd/system/ps5-stage-viola-fw.service
ps5-wifi-powersave.service /etc/systemd/system/ps5-wifi-powersave.service
ps5-wifi-powersave.timer /etc/systemd/system/ps5-wifi-powersave.timer
ps5-wifi-repair /usr/local/sbin/ps5-wifi-repair 755
ps5-wifi-repair.service /etc/systemd/system/ps5-wifi-repair.service
90-ps5-wifi-powersave /etc/NetworkManager/dispatcher.d/90-ps5-wifi-powersave 755
ps5-kexec /usr/local/sbin/ps5-kexec 755
ps5-reboot-to-ps5 /usr/local/sbin/ps5-reboot-to-ps5 755
ps5-kexec-prepare.service /etc/systemd/system/ps5-kexec-prepare.service
ps5-reboot.service /etc/systemd/system/ps5-reboot.service
reboot.target /usr/local/share/ps5-bazzite-deck/reboot.target
L
echo "$REL" > "$OUT/VERSION"; echo "$K" > "$OUT/KERNEL"
cp "$SRC/tools/update.sh" "$OUT/update.sh"
cp "$SRC/tools/bt-mainconf.sh" "$OUT/bt-mainconf.sh"
(cd "$OUT" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
echo "efi files: $(ls "$OUT/efi" | tr '\n' ' ')  kernel: $K  modules: $(du -sh "$OUT/modules" | cut -f1)"
tar -C "$B/output" -cJf "$OUT.tar.xz" "$NAME"
(cd "$B/output" && sha256sum "$NAME.tar.xz" > "$NAME.tar.xz.sha256" && ls -lh "$NAME.tar.xz" && cat "$NAME.tar.xz.sha256")
