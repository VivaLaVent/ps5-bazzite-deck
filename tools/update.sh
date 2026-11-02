#!/bin/bash
# In-place update of a PS5 Bazzite Deck install (v1.0.3 or newer, kernel 7.3.0) to the
# version this bundle was built from. Run on the PS5:   bash update.sh
set -euo pipefail
cd "$(dirname "$0")"
V=$(cat VERSION); K=$(cat KERNEL)
echo "PS5 Bazzite Deck: in-place update to $V"
[ "$(uname -r)" = "$K" ] || { echo "STOP: running kernel $(uname -r), this bundle is for $K"; exit 1; }
grep -q "root=LABEL=bazzite-deck" /proc/cmdline || { echo "STOP: this is not a PS5 Bazzite Deck install"; exit 1; }
# the USB drive's FAT32 boot partition: /efi on the USB system, often /boot/efi on an M.2 install,
# or not mounted at all; mount it at /efi for the update if needed
EFI=""; MOUNTED=0
for d in /efi /boot/efi; do if sudo test -f "$d/cmdline.txt"; then EFI=$d; break; fi; done
if [ -z "$EFI" ]; then
  sudo mkdir -p /efi
  sudo mount LABEL=boot /efi 2>/dev/null && sudo test -f /efi/cmdline.txt && { EFI=/efi; MOUNTED=1; } \
    || { echo "STOP: boot partition (label 'boot') not found - is the USB drive plugged in?"; exit 1; }
fi
echo "boot partition: $EFI"
echo "==> checking the bundle"
sha256sum -c --quiet SHA256SUMS || { echo "STOP: bundle files are damaged, download it again"; exit 1; }

BK=/var/lib/ps5-update-backup/$(date +%Y%m%d-%H%M%S)
echo "==> backup of the current kernel and modules to $BK"
sudo mkdir -p "$BK/efi"
for f in efi/*; do n=$(basename "$f"); if sudo test -f "$EFI/$n"; then sudo cp -a "$EFI/$n" "$BK/efi/"; fi; done
sudo cp -a "$EFI/cmdline.txt" "$BK/efi/"
sudo cp -a "/usr/lib/modules/$K" "$BK/modules"

echo "==> installing kernel and modules"
sudo rm -rf "/usr/lib/modules/$K.new"
sudo cp -a "modules/$K" "/usr/lib/modules/$K.new"
sudo rm -rf "/usr/lib/modules/$K"
sudo mv "/usr/lib/modules/$K.new" "/usr/lib/modules/$K"
for f in efi/*; do sudo cp "$f" "$EFI/"; done
sudo depmod -a "$K"

echo "==> system settings"
while read -r src dst mode; do [ -n "$src" ] && sudo install -Dm"${mode:-644}" "files/$src" "$dst"; done < FILES
# Bluetooth services (Linux-only address, connectable, revive) and BlueZ pairing options;
# take effect at the next boot
[ -f bt-mainconf.sh ] && sudo bash bt-mainconf.sh /etc/bluetooth/main.conf
sudo systemctl daemon-reload
sudo udevadm control --reload 2>/dev/null || true
[ -e /usr/sbin/kexec ] || sudo install -Dm755 files/kexec-shim /usr/sbin/kexec   # systemd runs "kexec -e" for warm reboots
# the first rc3 bundle had a warm-reboot unit that only worked after a boot: replace it
if [ -e /etc/systemd/system/ps5-kexec-load.service ]; then sudo systemctl disable ps5-kexec-load.service 2>/dev/null; sudo rm -f /etc/systemd/system/ps5-kexec-load.service; sudo systemctl daemon-reload; fi
# v1.6: the first-start message is gone (it didn't show, or only for a moment): remove it from existing installs
sudo systemctl disable ps5-first-start.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/ps5-first-start.service /etc/systemd/system/multi-user.target.wants/ps5-first-start.service /usr/local/sbin/ps5-first-start
# v1.8.9: the Linux-only Bluetooth address is on by default; the old opt-in flag isn't used any more
sudo rm -f /etc/ps5-bazzite-deck/bt-address
# v1.8.9: Bazzite's ostree-only services fail at every boot on this image: masked
sudo systemctl mask bootloader-update.service greenboot-healthcheck.service greenboot-success.target >/dev/null 2>&1 || true
# v1.8.9: hdmi.rearm=0 is gone (the re-arm has its own back-off now); a leftover kept TVs dark after mode changes
sudo sed -i 's/ *hdmi\.rearm=0//' "$EFI/cmdline.txt"
for u in ps5-bt-addr ps5-bt-connectable ps5-bt-revive ps5-wifi-repair ps5-perf ps5-stage-viola-fw; do
  [ -f "/etc/systemd/system/$u.service" ] && sudo systemctl enable "$u.service" 2>/dev/null || true
done
[ -f /etc/systemd/system/ps5-wifi-powersave.timer ] && sudo systemctl enable ps5-wifi-powersave.timer 2>/dev/null || true
sudo sed -i 's/ video=DP-1:1920x1080@60//' "$EFI/cmdline.txt"
# v1.5.1: options that are kernel defaults now (CONFIG_LSM, CONFIG_USB_AUTOSUSPEND_DELAY=-1) leave cmdline.txt;
# only the exact strings we added, anything a user changed stays
sudo sed -i -e 's/ lsm=landlock,lockdown,yama,integrity,apparmor,bpf//' -e 's/ usbcore\.autosuspend=-1//' "$EFI/cmdline.txt"
# v1.7.1: VRR is no longer a test behind a flag (Steam's VRR setting switches it): the old test flags go
sudo sed -i -e 's/ *hdmi\.vrr_test=1//' -e 's/ *hdmi\.vrr_chip=[0-9]//' "$EFI/cmdline.txt"
# GPU compute units: 40 (amdgpu.ps5_cu_unlock=3) is opt-in again from v1.1.1 (silicon lottery: the extra 4
# can be faulty). v1.1.0 switched it on for everyone, so switch it off once for installs coming from v1.1.0.
# From then on a setting the user adds is never touched.
case "$(cat /etc/ps5-bazzite-deck-version 2>/dev/null)" in
  v1.1.0|v1.1.0-*)
    if sudo grep -q "amdgpu.ps5_cu_unlock=3" "$EFI/cmdline.txt"; then
      sudo sed -i 's/ *amdgpu\.ps5_cu_unlock=3//' "$EFI/cmdline.txt"
      echo "    40-CU unlock switched off (opt-in from v1.1.1; see the README to switch it on again)"
    fi ;;
esac
echo "$V" | sudo tee /etc/ps5-bazzite-deck-version >/dev/null
sync
[ "$MOUNTED" = 1 ] && sudo umount "$EFI"

echo
# A new kernel needs a cold start: with warm reboot on, the next restart would kexec straight into it
# without the PS5 resetting its hardware (an untested combination; the v1.5.0 test install hung that way).
[ -e /etc/ps5-bazzite-deck/warm-reboot ] && sudo touch /run/ps5-reboot-to-ps5 && echo "note: warm reboot is on; this one restart goes through the PS5 system (cold), as a new kernel needs"
B=/var/lib/ps5-update-backup
if [ -d "$B" ]; then
  old=$(ls -1dt "$B"/*/ 2>/dev/null | tail -n +3)
  if [ -n "$old" ]; then
    freed=$(sudo du -shc $old 2>/dev/null | tail -1 | cut -f1)
    sudo rm -rf $old
    echo "old backups removed, kept the newest 2 ($freed freed)"
  fi
fi
echo "DONE: updated to $V. Reboot (sudo reboot) and run the loader as usual."
[ "$MOUNTED" = 1 ] && echo "(for the undo, mount the boot partition first: sudo mount LABEL=boot /efi)"
echo "Undo: sudo cp -a $BK/efi/* $EFI/ && sudo rm -rf /usr/lib/modules/$K && sudo cp -a $BK/modules /usr/lib/modules/$K && sync"
