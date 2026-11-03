# Changelog

## Unreleased

- composefs off in prepare-root.conf: the PS5 kernel has no EROFS, so the first real boot stopped in
  ostree-prepare-root ("Failed to mount composefs: No such device"). Back on once the kernel has EROFS.

## Increment 6

- docs/loader-contract.md: every file the loader reads from the USB drive, and who writes it.
- pins.env pins bootc-image-builder by digest and the kernel RPM by sha256, and records the loader
  the image was tested with (`loader=` in VERSION and in the release notes).
- Images are cosign-signed when SIGNING_SECRET is set; with the public key in system_files the image
  ships a containers policy for this repository.
- The boot partition is found as an EFI partition or by the label `boot` (/dev/ps5-boot); vram.txt is
  no longer copied (the loader's default is the same 512 MB).
- ps5-bootc-sync warns at boot when an older deployment than the default was started (a cut-off
  shutdown after an update); the README says what to do.
- README: kernel options on the console with `rpm-ostree kargs`; links the VivaLaVent loader fork.

## Increment 5

- README for users (install, updating, rollback, boot options), in PS5 Bazzite Deck's style;
  how it works and building moved to docs/building.md.

## Increment 4

- Comments trimmed to the ones that explain a reason the code can't show.

## Increment 3

- PS5 files updated to ps5-bazzite-deck v2.1.3: Wi-Fi config renamed to 99-ps5-wifi.conf, one
  Bluetooth-connectable mechanism (the bluetooth.service drop-in is gone), warm reboot opt-in
  through /usr/share/ps5-bazzite-deck/reboot.target, newer Bluetooth address scripts.
- The image records which deck release it matches (`deck=` in its VERSION, and in
  /etc/ps5-bazzite-deck-version for ps5-report).
- README: how to repackage the kernel RPM after quick-kernel.sh changes.
- CI: plain podman build and push instead of the deprecated buildah and push actions.
- README: updates go through Steam's update button, as on Bazzite Deck (the uupd timer is off there).

## First CI build

- Create /var/usrlocal before installing the kernel RPM.
- Keep kmod-libs (libkmod) when removing Bazzite's kmods.
- Only patch the kernel RPM's units that exist.
- Decompress the Oberon firmware with xz -dc: unxz skips hard-linked files.

## Increment 2

- Kernel swap, initramfs and cleanup now follow Bazzite's own build scripts (ublue-os/bazzite
  at 59f518b): devel packages removed with the kernel, dracut with zstd and fido2, the
  rpm-ostree base database relinked after our rpm transactions.
- Game Mode autologin left to Bazzite (`bazzite-autologin`) instead of our own SDDM config.
- `bootc container lint` runs offline with a tmpfs /run, as in Bazzite.

## Increment 1

- First image: bazzite-deck:stable with the linux-ps5 kernel and the ps5-bazzite-deck files.
- `ps5-bootc-sync` keeps the PS5 loader's boot partition in step with bootc.
