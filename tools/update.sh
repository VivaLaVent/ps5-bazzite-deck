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
# Linux-only Bluetooth address (DualSense keeps a PS5 profile and a Linux profile); takes effect at the next boot
if [ -f /etc/systemd/system/ps5-bt-addr.service ]; then
  sudo systemctl daemon-reload
  sudo systemctl enable ps5-bt-addr.service 2>/dev/null
fi
sudo sed -i 's/ video=DP-1:1920x1080@60//' "$EFI/cmdline.txt"
sudo grep -q "lsm=" "$EFI/cmdline.txt" || sudo sed -i 's/[[:space:]]*$/ lsm=landlock,lockdown,yama,integrity,apparmor,bpf/' "$EFI/cmdline.txt"
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
echo "DONE: updated to $V. Reboot (sudo reboot) and run the loader as usual."
[ "$MOUNTED" = 1 ] && echo "(for the undo, mount the boot partition first: sudo mount LABEL=boot /efi)"
echo "Undo: sudo cp -a $BK/efi/* $EFI/ && sudo rm -rf /usr/lib/modules/$K && sudo cp -a $BK/modules /usr/lib/modules/$K && sync"
