# Changelog

## Unreleased

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
