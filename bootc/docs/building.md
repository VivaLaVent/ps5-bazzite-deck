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

`build_files/build.sh` installs the same PS5 scripts, units and rules as the classic update bundle,
straight from `files/` and the FILES list in `tools/make-update-bundle.sh`, and does what
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

## Pinned inputs

Two builds of the same commit should give the same system, so nothing is fetched as "latest": `pins.env` holds the
bootc-image-builder digest, the kernel RPM's name and sha256, and the loader the image was last tested with. CI fails
when the downloaded RPM doesn't match. Update a pin on purpose, in its own commit:

```sh
cd ~/ps5-bazzite-deck/bootc
command -v skopeo >/dev/null || sudo apt install -y skopeo
D=$(skopeo inspect docker://quay.io/centos-bootc/bootc-image-builder:latest --format '{{.Digest}}')
R=$(basename ~/ps5-build-7.3/linux-bin/linux-ps5-*.rpm)
S=$(sha256sum ~/ps5-build-7.3/linux-bin/"$R" | cut -d' ' -f1)
L=$(git ls-remote https://github.com/VivaLaVent/ps5-linux-loader HEAD | cut -c1-12)
printf 'BIB_IMAGE=quay.io/centos-bootc/bootc-image-builder@%s\nKERNEL_REPO=VivaLaVent/ps5-bazzite-bootc\nKERNEL_TAG=kernel-latest\nKERNEL_RPM=%s\nKERNEL_SHA256=%s\nLOADER=VivaLaVent/ps5-linux-loader@%s\n' "$D" "$R" "$S" "$L" > pins.env
cat pins.env
```

`LOADER` is a record, not a download: set it to the loader commit you actually booted the image with.

## Signing

CI signs every pushed image with cosign when the `SIGNING_SECRET` secret is set. Once
`system_files/etc/pki/containers/ps5-bazzite-bootc.pub` exists, the image also carries a containers policy that only
accepts signed images from this repository, and CI refuses to push unsigned. A console checks signatures once it
switches with `sudo bootc switch --enforce-container-sigpolicy ghcr.io/vivalavent/ps5-bazzite-bootc:stable`.

```sh
cosign generate-key-pair      # empty password; keep cosign.key private and out of git
gh secret set SIGNING_SECRET --repo VivaLaVent/ps5-bazzite-deck < cosign.key
install -Dm644 cosign.pub system_files/etc/pki/containers/ps5-bazzite-bootc.pub
```

Push the signing secret first and the public key in a later commit, so the image that starts enforcing is already
signed.

## Building the image

The image needs the `linux-ps5` RPM, which this repo doesn't build (yet). CI downloads the file named in
`pins.env` from the release tagged `kernel-latest` and checks its sha256. A full ps5-bazzite-deck `build.sh` run leaves it in
`~/ps5-build-7.3/linux-bin/`. After kernel changes made with `tools/quick-kernel.sh`, repackage
the same tree (incremental, a few minutes) and replace it:

```sh
cd ~/ps5-build-7.3
mkdir -p linux-bin/old && sudo mv linux-bin/*.rpm linux-bin/old/   # an RPM there skips the build
./build_image.sh --kernel-only --distro bazzite-deck --kernel "$PWD/work/linux73"
gh release upload kernel-latest linux-bin/linux-ps5-*.rpm --clobber --repo VivaLaVent/ps5-bazzite-bootc
```

Then update `KERNEL_RPM` and `KERNEL_SHA256` in `pins.env` (above) and push.

The first time, create the release instead: `gh release create kernel-latest
linux-bin/linux-ps5-*.rpm --prerelease --title "PS5 kernel" --notes "linux-ps5 for the image build"`.

Locally:

```sh
cp ~/ps5-build-7.3/linux-bin/linux-ps5-*.rpm bootc/kernel/     # from the repository root
podman build -f bootc/Containerfile -t ps5-bazzite-bootc .
```

Disk image, from `bootc/` (or run the *Build bootc disk image* workflow):

```sh
sudo podman run --rm --privileged -v ./bib/config.toml:/config.toml:ro -v ./out:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  "$(. ./pins.env; echo "$BIB_IMAGE")" --type raw --rootfs ext4 \
  localhost/ps5-bazzite-bootc
sudo tools/finish-disk-image.sh out/image/disk.raw
```

`tests/ps5-bootc-sync.sh` checks the sync logic against fake boot entries; run it after
changing `ps5-bootc-sync`.

## GitHub setup

In the ps5-bazzite-deck repository:

- Settings → Actions → General → Workflow permissions: *Read and write*.
- Secrets: `SIGNING_SECRET` (cosign key) and `DISCORD_TESTING_WEBHOOK` (posts every image push), next to the
  release webhooks ps5-bazzite-deck already has.
- The image keeps its name, `ghcr.io/vivalavent/ps5-bazzite-bootc`, so consoles keep updating. Its package
  settings → *Manage Actions access* → add ps5-bazzite-deck with the *Write* role.

## Releases

- **vX.Y.Z**: the quick kernel package for classic installs, as before. bootc consoles get the change through
  their next update, since every push to `main` builds the image.
- **vX.Y**: the same, plus the bootc disk image for new installs. Create the release, then run
  *Build bootc disk image* with that tag: `gh workflow run bootc-build-disk-image.yml -f release=vX.Y`. It
  attaches `ps5-bazzite-deck-bootc-vX.Y.img.7z.*` and its `.sha256` to the release.
