#!/bin/bash
# Update bundle for existing installs:   FROM_BUNDLE=<kernel parts .tar.xz> bash tools/make-update-bundle.sh vX.Y
set -euo pipefail
SRC=$(cd "$(dirname "$0")/.." && pwd)
bash "$SRC/tools/fetch-bt-sync.sh"   # files/ps5-bt-sync, upstream's pairing importer
REL=${1:?usage: make-update-bundle.sh vX.Y}
B=${B:-$HOME/ps5-build-7.3}
NAME=ps5-bazzite-deck-$REL-update; OUT=$B/output/$NAME
rm -rf "$OUT" "$OUT.tar.xz" "$OUT.tar.xz.sha256"; mkdir -p "$OUT/efi" "$OUT/modules" "$OUT/files"
[ -f "${FROM_BUNDLE:-}" ] || { echo "STOP: FROM_BUNDLE=<kernel parts .tar.xz> is required"; exit 1; }
T=$(mktemp -d); tar -C "$T" -xJf "$FROM_BUNDLE"; S=$(ls -d "$T"/*/ | sed -n 1p)
cp -a "$S/efi/." "$OUT/efi/"; cp -a "$S/modules/." "$OUT/modules/"
[ -f "$S/files/ps5-iw620-modprobe.conf" ] && cp "$S/files/ps5-iw620-modprobe.conf" "$OUT/files/"
K=$(cat "$S/KERNEL"); rm -rf "$T"
echo "kernel parts from $(basename "$FROM_BUNDLE"): $K"
# FILES: source, destination, optional mode (default 644)
cat > "$OUT/FILES" << 'L'
99-ps5-iw620.conf /etc/NetworkManager/conf.d/99-ps5-iw620.conf
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
bluetooth-ps5-connectable.conf /etc/systemd/system/bluetooth.service.d/10-ps5-connectable.conf
99-ps5-bt-services.rules /etc/udev/rules.d/99-ps5-bt-services.rules
ps5-bt-revive /usr/local/sbin/ps5-bt-revive 755
ps5-bt-revive.service /etc/systemd/system/ps5-bt-revive.service
ps5-hidp.conf /etc/modules-load.d/ps5-hidp.conf
99-ps5-usb-power.rules /etc/udev/rules.d/99-ps5-usb-power.rules
ps5-warm-reboot /usr/local/sbin/ps5-warm-reboot 755
ps5-bt-address /usr/local/sbin/ps5-bt-address 755
ps5-bt-sync /usr/local/sbin/ps5-bt-sync 755
ps5-bt-import /usr/local/sbin/ps5-bt-import 755
ps5-bt-import.service /etc/systemd/system/ps5-bt-import.service
ps5-report.sh /usr/local/bin/ps5-report 755
ps5-m2-install.sh /usr/local/bin/ps5-m2-install 755
ps5-fastfetch-logo.txt /usr/local/share/ps5-bazzite-deck/fastfetch-logo.txt
ps5-fastfetch.sh /etc/profile.d/zz-ps5-fastfetch.sh
ps5-perf /usr/local/sbin/ps5-perf 755
ps5-perf.service /etc/systemd/system/ps5-perf.service
ps5-stage-viola-fw /usr/local/sbin/ps5-stage-viola-fw 755
ps5-stage-viola-fw.service /etc/systemd/system/ps5-stage-viola-fw.service
ps5-console-defaults /usr/local/sbin/ps5-console-defaults 755
ps5-console-defaults.service /etc/systemd/system/ps5-console-defaults.service
ps5-session-defaults /usr/local/sbin/ps5-session-defaults 755
ps5-session-defaults.service /etc/systemd/system/ps5-session-defaults.service
ps5-user-defaults /usr/local/bin/ps5-user-defaults 755
ps5-user-defaults.service /etc/systemd/user/ps5-user-defaults.service
ps5-wifi-powersave.service /etc/systemd/system/ps5-wifi-powersave.service
ps5-wifi-powersave.timer /etc/systemd/system/ps5-wifi-powersave.timer
ps5-wifi-repair /usr/local/sbin/ps5-wifi-repair 755
ps5-wifi-repair.service /etc/systemd/system/ps5-wifi-repair.service
90-ps5-wifi-powersave /etc/NetworkManager/dispatcher.d/90-ps5-wifi-powersave 755
ps5-kexec /usr/local/sbin/ps5-kexec 755
ps5-reboot-to-ps5 /usr/local/sbin/ps5-reboot-to-ps5 755
ps5-kexec-prepare.service /etc/systemd/system/ps5-kexec-prepare.service
ps5-reboot.service /etc/systemd/system/ps5-reboot.service
reboot.target /etc/systemd/system/reboot.target
L
# every file in FILES, so a new entry can't be listed without being shipped
while read -r src _; do
  [ "$src" = ps5-iw620-modprobe.conf ] && continue   # taken from the image or bundle above
  f=$SRC/files/$src; [ -f "$f" ] || f=$SRC/tools/$src
  cp "$f" "$OUT/files/"
done < "$OUT/FILES"
cp "$SRC/files/kexec-shim" "$OUT/files/"
echo "$REL" > "$OUT/VERSION"; echo "$K" > "$OUT/KERNEL"
cp "$SRC/tools/update.sh" "$OUT/update.sh"
cp "$SRC/tools/bt-mainconf.sh" "$OUT/bt-mainconf.sh"
(cd "$OUT" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
echo "efi files: $(ls "$OUT/efi" | tr '\n' ' ')  kernel: $K  modules: $(du -sh "$OUT/modules" | cut -f1)"
tar -C "$B/output" -cJf "$OUT.tar.xz" "$NAME"
(cd "$B/output" && sha256sum "$NAME.tar.xz" > "$NAME.tar.xz.sha256" && ls -lh "$NAME.tar.xz" && cat "$NAME.tar.xz.sha256")
