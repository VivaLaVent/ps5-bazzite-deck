# Changelog

## Unreleased

- Kernel swap, initramfs and cleanup now follow Bazzite's own build scripts (ublue-os/bazzite
  at 59f518b): devel packages removed with the kernel, dracut with zstd and fido2, the
  rpm-ostree base database relinked after our rpm transactions.
- Game Mode autologin left to Bazzite (`bazzite-autologin`) instead of our own SDDM config.
- `bootc container lint` runs offline with a tmpfs /run, as in Bazzite.

## Increment 1

- First image: bazzite-deck:stable with the linux-ps5 kernel and the ps5-bazzite-deck files.
- `ps5-bootc-sync` keeps the PS5 loader's boot partition in step with bootc.
