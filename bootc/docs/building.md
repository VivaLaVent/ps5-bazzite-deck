# Building and how it works

## How it boots

The PS5 Linux loader knows nothing about bootc.
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

`build_files/build.sh` installs the same PS5 scripts, units and rules as the Legacy update bundle,
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
- RADV (`libvulkan_radeon.so`, 64- and 32-bit) is built in a first stage of the Containerfile from the Mesa version and
  patches in `mesa/` (Terra's patches as in Bazzite's package, plus Borchev's PS5 Pro patch) against the base image's own
  libraries, then installed over Bazzite's; the build fails if it doesn't load (`ldd -r`). When Bazzite moves to another
  Mesa version, the build warns until `mesa/pins.env` and the patches follow.

## Pinned inputs

Two builds of the same commit should give the same system, so nothing is fetched as "latest": `pins.env` holds the
bootc-image-builder digest, the kernel RPM's name and sha256, and the loader the image was last tested with. CI fails
when the downloaded RPM doesn't match. `KERNEL_REPO`, `KERNEL_TAG`, `KERNEL_RPM` and `KERNEL_SHA256` follow the stable release: promoting a release
(`gh release edit vX.Y --prerelease=false --latest`) runs `pin-kernel.yml`, which pins its kernel RPM. Move the
bootc-image-builder pin on purpose, in its own commit:

```sh
D=$(skopeo inspect docker://quay.io/centos-bootc/bootc-image-builder:latest --format '{{.Digest}}')
sed -i "s|^BIB_IMAGE=.*|BIB_IMAGE=quay.io/centos-bootc/bootc-image-builder@$D|" pins.env
```

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

The image needs the `linux-ps5` RPM. A release builds it from this repo (`build.sh`, in
`.github/workflows/release.yml`) and hands it to the image build; the weekly `:stable` build downloads the RPM named in
`pins.env` and checks its sha256. Each release updates `pins.env` to its own kernel.

Locally, `bash build.sh` produces the same RPM in `~/ps5-build-7.3/linux-bin/`.

## GitHub setup

In the ps5-bazzite-deck repository:

- Settings → Actions → General → Workflow permissions: *Read and write*.
- Secrets: `SIGNING_SECRET` (cosign key) and three Discord webhooks: `DISCORD_RELEASES_WEBHOOK` (stable releases),
  `DISCORD_PRERELEASE_WEBHOOK` (pre-releases) and `DISCORD_BOOTC_WEBHOOK` (bootc releases and image builds).
- The image keeps its name, `ghcr.io/vivalavent/ps5-bazzite-bootc`, so consoles keep updating. Its package
  settings → *Manage Actions access* → add ps5-bazzite-deck with the *Write* role.

## Releases

See [docs/releasing.md](../../docs/releasing.md): one tag builds the kernel, the Legacy update bundle, the bootc
image and disk image, and the loader.
