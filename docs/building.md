# Building and how it works

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
- Bazzite's own services stay on, including Steam's update button and the Game Mode autologin, except
  `bazzite-hardware-setup`, `bootloader-update` and greenboot, which assume an x86 PC with GRUB;
- the kernel swap and initramfs follow Bazzite's own build scripts (same packages removed, same
  dracut options), so the image looks to bootc and rpm-ostree like any Bazzite image;
- `ps5-stage-gpu-firmware` (from the kernel package) is off: it writes to `/usr`, which is
  read-only. `ps5-stage-viola-fw` does the same job on the boot partition;
- no repo.etawen.dev: the kernel comes with the image.

## Building the image

The image needs the `linux-ps5` RPM, which this repo doesn't build (yet). CI downloads it from
the release tagged `kernel-latest`. A full ps5-bazzite-deck `build.sh` run leaves it in
`~/ps5-build-7.3/linux-bin/`. After kernel changes made with `tools/quick-kernel.sh`, repackage
the same tree (incremental, a few minutes) and replace it:

```sh
cd ~/ps5-build-7.3
mkdir -p linux-bin/old && sudo mv linux-bin/*.rpm linux-bin/old/   # an RPM there skips the build
./build_image.sh --kernel-only --distro bazzite-deck --kernel "$PWD/work/linux73"
gh release upload kernel-latest linux-bin/linux-ps5-*.rpm --clobber --repo VivaLaVent/ps5-bazzite-bootc
```

The first time, create the release instead: `gh release create kernel-latest
linux-bin/linux-ps5-*.rpm --prerelease --title "PS5 kernel" --notes "linux-ps5 for the image build"`.

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
