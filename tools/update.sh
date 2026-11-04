#!/bin/bash
# In-place update of a Legacy install to this bundle's version. On the PS5: bash update.sh
set -euo pipefail
[ -e /run/ostree-booted ] && { echo "This is a bootc install: update with  sudo bootc upgrade"; exit 1; }
cd "$(dirname "$0")"
V=$(cat VERSION); K=$(cat KERNEL); OLD=$(uname -r)
echo "PS5 Bazzite Deck: in-place update to $V (kernel $OLD -> $K)"
grep -q "root=LABEL=bazzite-deck" /proc/cmdline || { echo "STOP: this is not a PS5 Bazzite Deck install"; exit 1; }
# /efi on a USB install, often /boot/efi or unmounted on M.2: mount it at /efi if needed
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

# an M.2 install boots from a stick: only write to the boot partition that starts this root
want=$(sudo sed -n 's/.*root=LABEL=\([^ ]*\).*/\1/p' "$EFI/cmdline.txt"); have=$(lsblk -no LABEL "$(findmnt -no SOURCE /)" 2>/dev/null || true)
[ -z "$want" ] || [ -z "$have" ] || [ "$want" = "$have" ] || { echo "STOP: $EFI/cmdline.txt starts root=LABEL=$want, this system runs from LABEL=$have. Mount this install's boot partition at /efi and run the update again."; exit 1; }
BK=/var/lib/ps5-update-backup/$(date +%Y%m%d-%H%M%S)
echo "==> backup of the current kernel and modules to $BK"
sudo mkdir -p "$BK/efi"
for f in efi/*; do n=$(basename "$f"); if sudo test -f "$EFI/$n"; then sudo cp -a "$EFI/$n" "$BK/efi/"; fi; done
sudo cp -a "$EFI/cmdline.txt" "$BK/efi/"
# a kernel of the same name is replaced in place, so its modules need a copy; a new one leaves them where they are
[ "$K" = "$OLD" ] && sudo cp -a "/usr/lib/modules/$K" "$BK/modules"

echo "==> installing kernel and modules"
sudo rm -rf "/usr/lib/modules/$K.new"
sudo cp -a "modules/$K" "/usr/lib/modules/$K.new"
sudo rm -rf "/usr/lib/modules/$K"
sudo mv "/usr/lib/modules/$K.new" "/usr/lib/modules/$K"
for f in efi/*; do sudo cp "$f" "$EFI/"; done
sudo depmod -a "$K"

echo "==> system settings"
while read -r src dst mode; do [ -n "$src" ] && sudo install -Dm"${mode:-644}" "files/$src" "$dst"; done < FILES
[ -f bt-mainconf.sh ] && sudo bash bt-mainconf.sh /etc/bluetooth/main.conf
sudo systemctl daemon-reload
sudo udevadm control --reload 2>/dev/null || true
[ -e /usr/sbin/kexec ] || sudo install -Dm755 files/kexec-shim /usr/sbin/kexec   # systemd runs "kexec -e" for warm reboots
# the first rc3 bundle had a warm-reboot unit that only worked after a boot: replace it
if [ -e /etc/systemd/system/ps5-kexec-load.service ]; then sudo systemctl disable ps5-kexec-load.service 2>/dev/null; sudo rm -f /etc/systemd/system/ps5-kexec-load.service; sudo systemctl daemon-reload; fi
# older installs: the first-start message
sudo systemctl disable ps5-first-start.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/ps5-first-start.service /etc/systemd/system/multi-user.target.wants/ps5-first-start.service /usr/local/sbin/ps5-first-start
# the old opt-in flag
sudo rm -f /etc/ps5-bazzite-deck/bt-address
# Bazzite's ostree-only services fail at every boot here
# Wi-Fi config name and reboot override of the withdrawn test versions
sudo rm -f /etc/NetworkManager/conf.d/99-ps5-wifi.conf /usr/local/share/ps5-bazzite-deck/reboot.target
sudo systemctl mask bootloader-update.service greenboot-healthcheck.service greenboot-success.target >/dev/null 2>&1 || true
# a leftover hdmi.rearm=0 keeps TVs dark after mode changes
sudo sed -i 's/ *hdmi\.rearm=0//' "$EFI/cmdline.txt"
for u in ps5-bt-addr ps5-bt-pro-addr ps5-bt-connectable ps5-bt-revive ps5-wifi-repair ps5-perf ps5-stage-viola-fw ps5-console-defaults; do
  [ -f "/etc/systemd/system/$u.service" ] && sudo systemctl enable "$u.service" 2>/dev/null || true
done
[ -f /etc/systemd/system/ps5-wifi-powersave.timer ] && sudo systemctl enable ps5-wifi-powersave.timer 2>/dev/null || true
sudo sed -i 's/ video=DP-1:1920x1080@60//' "$EFI/cmdline.txt"
# options that became kernel defaults; only the exact strings we added
sudo sed -i -e 's/ lsm=landlock,lockdown,yama,integrity,apparmor,bpf//' -e 's/ usbcore\.autosuspend=-1//' "$EFI/cmdline.txt"
# old VRR test flags (VRR is Steam's setting now)
sudo sed -i -e 's/ *hdmi\.vrr_test=1//' -e 's/ *hdmi\.vrr_chip=[0-9]//' "$EFI/cmdline.txt"
# an old release turned the 40-CU unlock on for everyone (the extra CUs can be faulty): off once, user settings kept after
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
# a new kernel needs a cold start: kexec straight into it skips the PS5's hardware reset (hung in testing)
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
if [ "$K" = "$OLD" ]; then
  echo "Undo: sudo cp -a $BK/efi/* $EFI/ && sudo rm -rf /usr/lib/modules/$K && sudo cp -a $BK/modules /usr/lib/modules/$K && sync"
else
  echo "Undo: sudo cp -a $BK/efi/* $EFI/ && sudo rm -rf /usr/lib/modules/$K && sync   (kernel $OLD's modules were kept)"
fi
