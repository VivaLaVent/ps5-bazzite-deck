# Changelog

All notable changes to the images. Exact upstream versions are in each release's `VERSIONS.md`.

## [v2.5] – 2026-11-04
> Stable. Everything since v1.8.9; the v2.0 to v2.4.2 releases in between were test versions and are removed.
- **Two install forms:** Legacy (full image + update bundle, as before) and bootc (experimental): `ghcr.io/vivalavent/ps5-bazzite-bootc`, flashed from the release's disk image, updated with `sudo bootc upgrade`, rolled back with `sudo bootc rollback`, started by **bazzite-bootc-loader** (rmux's ps5-linux-loader @ 940bce3 + BLS patches, built for every release; starts Legacy installs as the standard loader does)
- **Kernel:** Linux 7.3.1 + rmux's shitshow (8de2aff), named `7.3.1-viva`. Display: the v1.8.9 display stack replayed onto 7.3.1 (FLAVA3 and Verde setup, 4K120 over FRL by Lawson, standard 1080p/1440p/2160p modes with the FLAVA3 1440p timings, VRR, re-arm, EDID keep and fallback, SCDC, sleep mute, RGB range). Everything else from rmux's tree: IW620 and MediaTek Bluetooth fixes, PS5 Pro CPU/GPU clocks, fan hwmon driver. Plus suspend-to-idle (Dasloh, PR #4), the thermal GPU governor (Borchev, #66; 85 °C), no fan spike at shutdown. 100 Hz modes removed (artifacts on Verde)
- **Bluetooth:** the Linux-only address is saved on first use (no re-pairing after a cold boot); PS5 Pro Bluetooth from a cold boot and its Linux-only address (mfoster978, PR #30/#31); IW620 scanning fixed; Bluetooth, Wi-Fi and restart scripts as in v2.1.1
- **PS5 Pro:** GPU firmware appended on a 4-byte boundary (it mostly never loaded before); D3D9 games (CP microcode from Bazzite's compressed linux-firmware); 1 GB VRAM and 80 °C by default (`ps5-console-defaults`); GPU busy reporting and `gpu_metrics` unsupported (MangoHud); fan driver starts
- **Fan and power:** firmware fan control by default, kernel curve opt-in; fan target restored after sleep; CPU boost off caps at 3.2 GHz
- **Updates:** a new kernel name installs next to the running kernel (kept as the backup); the update refuses bootc installs and a boot partition that starts another root; the two newest backups are kept
- **`ps5-report`:** fastfetch-style summary (console, HDMI chip, wireless chip, install type, kernel, display, Bluetooth, Wi-Fi), then Bluetooth, Wi-Fi, USB, display, GPU, bootc and system sections; kernel log from dmesg; runs with stdin closed
- **Build and release:** everything built by GitHub Actions from this repo (`release.yml`): kernel on a self-hosted runner (`tools/release.sh` starts and stops it), update bundle, bootc image and disk image, loader; releases public from the start; a release's kernel reaches the nightly `:stable` bootc image when promoted (`pin-kernel.yml`); weekly upstream audit; Discord posts carry "What's new"
- **Parked:** rmux's display rework adapted (`patches-next/rmux-display/`, v2.4.2's kernel), for 4K120 and VRR on his path
- **bootc is the standard form.** Release notes, README and wiki lead with it (why, switching by reflash); Legacy installs keep in-place updates and are advised to switch

## [v1.8.9] – 2026-10-<DD>
> Full release (image and update bundle) with the v1.8.8 kernel. Replaces the first v1.8.9 (4K120 as YCbCr 4:2:2), which showed the wrong colour range.
- **One DualSense for the PS5 and Linux, on by default on every console:** Linux has its own Bluetooth address, so the controller keeps a pairing for each (on separate profiles) instead of losing one every time you switch. IW620: while it's on, restarts go through the PS5 system instead of warm ones, because the chip didn't survive a warm restart with the changed address (Max). `ps5-bt-address off` switches it off
- **MediaTek (Slim): the Linux-only Bluetooth address works on more consoles:** where the kernel's way of setting it didn't stick (hsgodd: the controller lost its PS5-system pairing every time), MediaTek's own command is used as a fallback
- **Steering wheels:** force feedback for Logitech wheels and rumble pads, as in vanilla Bazzite (the kernel config of rmux's 7.3 port has it too; it's in a module, so it needs the full build)
