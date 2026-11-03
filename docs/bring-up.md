# Bring-up checklist

Each stage ends with something to report back. Don't skip ahead: a stage builds on the one before.

## 1. The image builds

1. Upload the kernel RPM as `kernel-latest` (README, *Building*).
2. Push to `main`; the *Build image* workflow runs.
3. Report: the workflow log if it fails (the *Build* step), otherwise the output of
   `podman run --rm ghcr.io/<owner>/ps5-bazzite-bootc:stable sh -c 'cat /usr/share/ps5-bazzite-bootc/VERSION; ls /usr/lib/modules/*/; bootc container lint'`.

## 2. The disk image builds

1. Run *Build disk image* by hand.
2. Report: the log of the *Prepare the boot partition* step. It lists the FAT partition and
   prints `cmdline.txt`.

## 3. It boots (base PS5 first, then a Pro)

Flash, start the loader, wait up to five minutes on the first boot.

- Comes up in Game Mode or Plasma: report the output of
  `sudo bootc status; id ps5; lsblk -f; findmnt /boot /boot/efi /sysroot; cat /proc/cmdline; systemctl --failed; ps5-report`
  (`id ps5` must say uid 1000: Bazzite's autologin picks that user)
- Black screen: plug a keyboard, Ctrl+Alt+F3, log in as ps5/ps5 and run
  `journalctl -b -p warning --no-pager > /boot/efi/journal.txt`; send that file (readable from a PC).
- Stays in the loader / goes back to the PS5 system: report what the loader's notifications
  said and a listing of the USB drive's FAT partition from a PC.

## 4. Updates and rollback

1. Note `sudo bootc status`, wait for a newer image (or run *Build image* by hand), then
   `sudo bootc upgrade`.
2. Restart. It should go back to the PS5 system; start the loader.
3. Report: `sudo bootc status`, `journalctl -b -1 -u ps5-bootc-sync`, `cat /boot/efi/cmdline.txt`.
4. `sudo bootc rollback`, restart, start the loader. Report `sudo bootc status`.
5. With an option added to `cmdline.txt` beforehand (say `amdgpu.ps5_cu_unlock=3`): check
   it is still there after each step.

## 5. Parity with ps5-bazzite-deck

Wi-Fi, Bluetooth and DualSense pairing, warm reboot (`ps5-warm-reboot on`), CPU boost,
VRR (`vrr-report`), PS5 Pro GPU firmware. Report anything that behaves differently from the
same console on ps5-bazzite-deck.
