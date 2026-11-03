# PS5 Bazzite (bootc)

[ps5-bazzite-deck](https://github.com/VivaLaVent/ps5-bazzite-deck) as a bootc image: the same
kernel and PS5 fixes, but built from a `Containerfile` on top of
`ghcr.io/ublue-os/bazzite-deck:stable` instead of flattened into a disk image. Updates work as on
any Bazzite install: Bazzite's updater (`uupd`) fetches new images in the background, or run
`sudo bootc upgrade` yourself. A bad update is undone with `sudo bootc rollback`.

**Status: experimental.** Not yet booted on a console. Use ps5-bazzite-deck.

Hobby project, not affiliated with Sony, Valve or Universal Blue.

## How it boots

The [PS5 Linux loader](https://github.com/ps5-linux/ps5-linux-loader) knows nothing about bootc.
It loads `bzImage`, `initrd.img` and `cmdline.txt` from the USB drive's FAT partition, as it
always has. bootc writes its boot entries to `/boot/loader/entries`, as it does on any other
Fedora system. `ps5-bootc-sync` copies the current entry's kernel and initramfs to the FAT
partition and rewrites `cmdline.txt` from its options:

- at every boot, so a `bootc rollback` takes effect;
- at shutdown, after ostree has written the entry for an update `bootc upgrade` staged.

Options you add to `cmdline.txt` yourself are kept. The previous deployment stays on the FAT
partition under `ostree/`, and `ROLLBACK.txt` there explains how to start it from a PC if the
new one doesn't come up.

After `bootc upgrade`, a restart goes back to the PS5 system (no warm reboot), and the loader
then starts the new version.

## Differences from ps5-bazzite-deck

The PS5 scripts, units and rules in `ps5/` are copied unchanged from ps5-bazzite-deck
(`ps5/VENDORED` says which commit). `build_files/build.sh` installs them, and does what
ps5-linux-image does for its Bazzite target, with these differences:

- nothing ships in `/usr/local` (it lives in `/var` on bootc, and bootc never updates `/var`):
  scripts go to `/usr/bin`;
- Bazzite's own services stay on, including its updater and its Game Mode autologin, except
  `bazzite-hardware-setup`, `bootloader-update` and greenboot, which assume an x86 PC with GRUB;
- the kernel swap and initramfs follow Bazzite's own build scripts (same packages removed, same
  dracut options), so the image looks to bootc and rpm-ostree like any Bazzite image;
- `ps5-stage-gpu-firmware` (from the kernel package) is off: it writes to `/usr`, which is
  read-only. `ps5-stage-viola-fw` does the same job on the boot partition;
- no repo.etawen.dev: the kernel comes with the image.

## Building

The image needs the `linux-ps5` RPM, which this repo doesn't build (yet). Every run of
ps5-bazzite-deck's `build.sh` leaves it in `~/ps5-build-7.3/linux-bin/`. CI downloads it from a
release tagged `kernel-latest`:

```sh
gh release create kernel-latest ~/ps5-build-7.3/linux-bin/linux-ps5-*.rpm \
  --prerelease --title "PS5 kernel" --notes "From ps5-bazzite-deck build.sh"
```

Locally:

```sh
cp ~/ps5-build-7.3/linux-bin/linux-ps5-*.rpm kernel/
podman build -t ps5-bazzite-bootc .
```

Disk image (or run the *Build disk image* workflow):

```sh
sudo podman run --rm --privileged -v ./bib/config.toml:/config.toml:ro -v ./out:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest --type raw --rootfs ext4 \
  localhost/ps5-bazzite-bootc
sudo tools/finish-disk-image.sh out/image/disk.raw
```

`tests/ps5-bootc-sync.sh` checks the sync logic against fake boot entries; run it after
changing `ps5-bootc-sync`.

## GitHub setup

- Settings → Actions → General → Workflow permissions: *Read and write*.
- Secrets: `DISCORD_RELEASES_WEBHOOK` and `DISCORD_PRERELEASE_WEBHOOK` (the ones
  ps5-bazzite-deck uses) and `DISCORD_TESTING_WEBHOOK` (posts every image push).
- After the first push: make the `ps5-bazzite-bootc` package public in its package settings.

## Credits

Everything PS5-specific comes from ps5-bazzite-deck, ps5-linux-image, rmux's loader and kernel
patches, and their contributors. The bootc layout follows Universal Blue's image template, and
the sync approach Armada's ESP script (thanks JustRadical).
