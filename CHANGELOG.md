# Changelog

All notable changes to the images. Exact upstream versions are in each release's `VERSIONS.md`.

## [Unreleased]
- **One DualSense for the PS5 and Linux, without a USB cable.** The new service `ps5-bt-addr.service` gives the Marvell IW620 Bluetooth chip a Linux-only address at boot (`80:..` becomes `82:..`). The DualSense keeps the PS5 pairing on one profile and the Linux pairing on a different profile. The chip keeps the address in RAM. The PS5 system gets its initial address when it starts. The service does not change consoles with a MediaTek chip. Refer to `docs/dualsense-profiles.md`
- In-place update: installs and enables `ps5-bt-addr.service`. A line in `FILES` can have a third column, the file mode. The default mode is 644

## [v1.2.0] – 2026-10-23
- **Fix: rainbow / "disco" colours** (posterized contours in gradients, seen on Verde consoles with TVs that offer deep colour): the output is capped at 8 bits per colour in the DRM core on the PS5. The graphics driver defaulted "max bpc" to 16 and compositors may ask for 10; the HDMI bridges show deeper colour as contours. Also stops the TV re-announcing itself every few seconds on such setups
- **Fix: "timing issue" / no picture after switching displays**: the wake-up re-arm (#46) now only runs when the same display re-announces itself (EDID checksum); a different display is set up by the hotplug path and the desktop with its own mode
- **Fix: link training errors at boot** (FLAVA3): the chip's "picture up" notification now cancels a pending re-arm, as Verde's already did, so it no longer fires during the first picture setup
- **Fix: 1440p picture shifted 32 px to the left** with displays whose 1440p timing uses negative hsync (e.g. Elgato 4K X): the bridge places the picture relative to the rising edge of hsync, so 1440p timings now get the standard sync shape and positive polarity
- Same drivers (modules) as v1.1.1; the kernel changes are all built in

## [v1.1.1] – 2026-10-23
- **40-CU unlock opt-in again** (`amdgpu.ps5_cu_unlock=3` no longer in the image's `cmdline.txt`): on some consoles the 4 extra compute units cause artifacts (green dots), a purple tint or crashes (silicon lottery). The in-place update switches it off once for installs coming from v1.1.0; after that, a setting you add yourself is kept across updates. README: section "40 GPU compute units (optional)" with on/off commands
- Same kernel and drivers as v1.1.0

## [v1.1.0] – 2026-10-23
- Based on rmux's latest PS5 patches (`meower` @ 34bcc15): HDMI audio (#42) and HDMI hotplug (#43) now come from upstream; our own ports of both are dropped
- Kernel patches consolidated by purpose into four files: `ps5-bluetooth`, `ps5-hdmi-rearm-pr46` (kept separate until it is merged upstream), `ps5-hdmi-output-fixes`, `ps5-hdmi-modes` (plus the Wi-Fi driver's `ps5-iw620-kernel73-compat`)
- **1440p120 always available** when the TV/monitor offers it; the `hdmi.allow_1440p120` option is removed
- **1440p60 offered** when a TV/monitor lists 1440p only at other refresh rates, using the standard VESA 1440p60 timing (241.5 MHz)
- **Fix: squeezed, discoloured picture on some 4K TVs** (whole picture in the left half): modes the TV only accepts as YCbCr 4:2:0 are skipped; the next mode (usually 1080p) is used. Turning on the TV's enhanced HDMI mode for that port gives 4K60
- **All 40 GPU compute units enabled by default** (`amdgpu.ps5_cu_unlock=3` in `cmdline.txt`, also added by the in-place update unless a `ps5_cu_unlock` setting is already there); set it to `=0` to go back to 36
- Hotplug detection runs on the kernel's general work queue (removes a "hogged CPU" warning); the 1440p timing adjustment is logged only when it changes
- Build: the in-place update bundle is made before the 7-Zip volumes; `SKIP_7Z=1` for test builds
- In-place update: finds the USB drive's boot partition by itself (`/efi`, `/boot/efi` on M.2 installs, or mounts it by its label)
- README: troubleshooting steps (PS5 settings, loader, `cmdline.txt` options), USB port speeds per model, simpler M.2 installation, loader links to rmuxwashere/ps5-linux-loader

## [v1.0.7] – 2026-10-22
- **Fix: black screen at boot on some TVs.** The two event sequences that v1.0.6 enabled (from ps5-linux-patches #43) are off again: on some TVs they made the chip re-announce the TV during the first picture setup, link training failed and the screen stayed black.
- **Fix: 1440p picture shifted.** The chip places a 1440p picture as if the signal had the back porches of the standard 1440p60 reduced-blanking timing (80 px / 33 lines); other 1440p timings (the desktop's generated 1440p60, a TV's 1440p120) were shifted right or down. The sync pulses are now moved so the back porches match; resolution, totals and refresh rate are unchanged
- SSH is enabled by default (user `ps5`, password `ps5`; change it with `passwd`)
- Kernel: `CONFIG_MODULE_ALLOW_BTF_MISMATCH=y`, so kernel-only hotfixes keep loading the release's modules

## [v1.0.6] – 2026-10-22
- **HDMI: picture comes back when the display wakes up** (display already on at boot, woken from standby, power-cycled): the HDMI bridge is set up again after the display re-announces itself. ps5-linux-patches #46 (rdmrocha), merged by hand onto #43. Off switch: add `hdmi.rearm=0` to `cmdline.txt`
- **HDMI hotplug**: switching to a different display or re-plugging the cable is detected, and the picture and HDMI audio are set up again. ps5-linux-patches #43, ported to the 7.3 display code
- **Fix: no signal after switching down from 4K** (e.g. to 1080p or 1080p120): 4K60 turns HDMI 2.0 scrambling on in the TV, and it was never turned off again for lower modes. Now it is. 1080p120 works
- **1440p120, experimental and opt-in**: add `hdmi.allow_1440p120=1` to `cmdline.txt`. Uses the 4K60 high-bandwidth setup
- **In-place updates**: an update bundle (`tools/update.sh`) brings earlier installs to the new version without reflashing; kernel, modules and settings, with a backup

## [v1.0.5] – 2026-10-22
- **Fix: services randomly missing after the first reboot** (no Wi-Fi/Ethernet because NetworkManager never started, Switch to Desktop dropping back to Game Mode). Cause: the image builder's `ps5-stage-firmware.service` creates a systemd ordering cycle (`Before=systemd-modules-load` with default dependencies, i.e. also after `basic.target`); systemd breaks it by deleting a different job each boot. Fixed with a drop-in setting `DefaultDependencies=no`. Affected v1.0.3 and v1.0.4 on all models
- MediaTek Wi-Fi (PS5 Slim) confirmed working by a tester; MediaTek Bluetooth still unconfirmed

## [v1.0.4] – 2026-10-21
- Rebuilt on current Bazzite Deck stable and rmux's latest 7.3 PS5 patches (`meower` HEAD): fan autoservo fix, boot fan target set by the kernel
- HDMI audio stability fix (upstream ps5-linux-patches #42, ported to 7.3)
- Wi-Fi (NXP IW620): driver rebuilt with the upstream HE capability + TX fixes; built with objtool metadata (removes the kernel warning at boot)
- Wi-Fi: NetworkManager keeps the permanent MAC during scans (fixes GUI Wi-Fi joins and the first-boot "connect to the internet" failure)
- **MediaTek MT7921 (PS5 Slim / newer) support, untested:** Wi-Fi driver enabled (`CONFIG_MT7921E=m`); Bluetooth: WizGery's btusb bulk-OUT fix (ported to 7.3) and L2CAP defer-security patch, plus udev/modprobe rules. One image for all models; drivers bind by hardware ID
- Boot: dropped the ignored `video=DP-1:1920x1080@60` from `cmdline.txt` (was logging "User-defined mode not supported" on every boot)

## [v1.0.3] – 2026-10-20
- **Bluetooth works**: the 7.3 PS5 patch registered the IW620 Bluetooth device (`1286:2059`) in the wrong `btusb` table, so its quirks never applied (two `hci` devices, `Opcode 0x2031 failed`). The fix (now part of `patches/ps5-bluetooth.patch`) moves the entry to `quirks_table` and the interface-0 check after the quirks lookup. Only `btusb.ko` changed; a hotfix module for v1.0.2 is attached to the release.

## [v1.0.2] – 2026-10-20
First working public release.
- Linux 7.3 with rmuxnet 7.3 PS5 patches (`meower` @ 36f173f): VCN video decode/encode, Bluetooth re-enabled
- **Game Mode works**: `bpf` added to `CONFIG_LSM`, `CONFIG_DEBUG_INFO_BTF=y` (fixes `cardwired`), `lsm=…,bpf` also in `cmdline.txt`
- Wi-Fi: PS5 IW620 driver with kernel 7.2/RTNL patches + new kernel 7.3 compat patch, `ps_mode=0` (firmware is staged at boot from the loader by the builder's ps5-stage-firmware service, not shipped in the image)
- Builder: ps5-linux-image @ 52db0a4 + fixes (VCN firmware mount, Wi-Fi patch order)

## [v1.0.0] – 2026-10-20 (withdrawn)
Same image plus a first-boot service running external Wi-Fi/Bluetooth fix scripts; the Wi-Fi script reloads the driver and can hang the first boot. Do not use.

## [v0.1.0] – 2026-10-19 (not published)
- Kernel 7.2.3 (ps5-linux-patches `main` @ 753c793) build; first image with working Game Mode (cmdline `lsm=` fix only)
