# Changelog

All notable changes to the images. Exact upstream versions are in each release's `VERSIONS.md`.

## [v2.7.1] – 2026-11-08
> Pre-release. Test fixes on top of v2.7.
- **1440p off-centre** (FLAVA3, under test): the display's own 1440p timings up to 340 MHz no longer go through the manual timing setup, as in rmux's tree; up to there 1440p uses the bridge's own timing (2720 total). Faster ones such as 1440p144 keep the manual setup
- **VRR on FreeSync-only displays** (FLAVA3): the AMD FreeSync range is used when the display announces no HDMI VRR range, with the same 48 Hz floor and follow mode as HDMI VRR (a FreeSync Premium monitor had VRR on v1.8.4)
- **IW620 Wi-Fi and Bluetooth on the first start after an update:** `firmware_class.path=/etc/firmware` on the kernel command line (bootc), so the first load of the Wi-Fi driver already finds the firmware `ps5-stage-firmware` keeps there

## [v2.7] – 2026-11-07
> Stable. Everything since v2.5: the v2.5.1 and v2.6.1 to v2.6.3 pre-releases, plus the changes below.
- **HDMI modes without switches** (`patches/ps5-hdmi-modes.patch`, replaces `ps5-hdmi-100hz.patch`): 1080p100, 1440p100 and 4K100 over FRL always offered where the display takes them, 1440p100/120 on VERDE as well, and on FLAVA3 every other progressive EDID timing up to 600 MHz through the bridge's manual timing setup (from rmux's tree); standard CTA formats outside the bridge's own set stay excluded. VERDE writes its AVI InfoFrame for every mode, with the mode's VIC (1080p120 and the new rates kept the previous mode's)
- **Debug switches and dead code out of the display driver:** `hdmi.icc_trace`, `hdmi.vrr_measure` (and amdgpu's frame-interval logger), `hdmi.rearm`, `hdmi.rearm_trigger` and the re-arm tuning values (now constants), five unused HDCP/sequence functions; `update.sh` drops them from a Legacy `cmdline.txt`
- **No OS updates through Steam:** Bazzite's `os-update` reports none (it ran `uupd` through `runcon`, which needs SELinux); updates are `sudo bootc upgrade`. Steam's channel switch stays (`os-branch-select` without `runcon` when SELinux is off). `bazzite-rollback-helper` refuses (it rebases to ublue-os images)
- **Steam's own videos as overrides** (`ps5-user-defaults`): Steam's files from `steamui/movies` under the override names, so the startup video plays when Game Mode starts, not only on wake
- **Loader patch 0003:** also looks for the boot files in `/data/PS5/Linux/` after the USB drives. `ps5-m2-install --boot` moves `/boot` onto the M.2 (test for starting without a USB drive, `docs/testing.md`)
- **Removed:** `ps5-gamescope-recovery` (the first start is Desktop Mode), `vrr-report`, `tools/quick-kernel.sh` (Legacy only), the parked `patches-next/rmux-display`. Shorter comments throughout; `ps5-perf` reads the fan default once; the kexec shim is only edited when it is installed

## [v2.6.3] – 2026-11-06
> Pre-release. The fix below.
- **bootc updates fail to stage** ("Failed to start ostree-finalize-staged.service") on installs from the v2.5.1, v2.6.1 and v2.6.2 disk images too, not only on v2.5: something still requires greenboot's rollback trigger, and it was masked. The image now ships that trigger as a unit that does nothing, as the v2.5.1 notes' fix does, instead of masking it; `ps5-report` flags a console whose trigger is still masked

## [v2.6.2] – 2026-11-06
> Pre-release. The fixes below; the image still masked greenboot's rollback trigger (fixed in v2.6.3).
- **`ps5-report`:** VRAM in use next to the size in `vram.txt` (top block and SUMMARY), amdgpu's VRAM and GTT lines and the 6 GB default's log on every model; the first start after the 6 GB default still runs with the old size, which this shows
- **`ps5-console-defaults`** is described as the defaults for every model (6 GB VRAM; the 80 °C GPU limit only on a Pro)
- **RADV build stage (bootc):** every -devel package installed with its architecture, and missing `.pc` dependencies resolved per architecture (the first v2.6.1 builds lacked libdrm and others for 64-bit); `sed -n 1p` instead of `head -1`, which could stop the build with SIGPIPE
- **Releases:** the bootc Discord post points at the Beta channel instead of the fixed release tag, which never updates; `release.sh` waits for the run of the commit it tagged, not an older run of a re-pushed tag
- "Warm reboot" instead of "warm restart" in messages and notes

## [v2.6.1] – 2026-11-06
> Pre-release: PS5 Pro GPU hangs fixed, Pro firmware dump on more firmware versions, fan back on the console's own control, 6 GB VRAM, Desktop Mode at start.
- **PS5 Pro: Sony's own GPU command-processor microcode again** (as up to v2.1.1). The cyan_skillfish2 substitute from v2.1.6 on hung vkd3d (D3D12) games such as Dragon's Dogma 2 in a GPU reset that never recovered (black screen, SSH still up). `ps5.viola_cp=cs2` on the command line brings the substitute back for DXVK D3D9 games that hang on Sony's. Existing installs switch at the next start
- **bazzite-bootc-loader from soniciso1's loader:** it dumps the PS5 Pro GPU firmware on 11.00 to 11.60, 12.00, 12.02, 12.40, 12.70 and 13.20 to 13.60 (the official loader only on 11.60, 13.20 and 13.60), so more Pros reach 60 compute units. The dormant boot-entry (BLS) patches are gone; path-override.txt still applies to cmdline.txt and vram.txt
- **Fan: the console's own control by default again, with an 80 °C target** (as in v1.8.9 and v2.1.x; the 7.3.1 kernel had switched to its own quiet curve at boot, and left the firmware's lower target in place during sleep and shutdown). `target_temp` and `ps5-perf`'s FAN_TARGET work again; rmux's kernel curve stays available (`pwm1_enable` 2, or `ps5_fan.curve=1` to start with it), and is what the hwcon plugin and app use
- **100 Hz modes behind `hdmi.modes_100hz=1`** (off by default; FLAVA3): 1080p100, 1440p100 and 4K100 over FRL, as the v2.1.x test. 1440p100 uses a 148.5 kHz timing (2720×1485, 403.92 MHz) when the display's own 1440p100 is slower than the CVT-RB one, which monitors such as the Philips 27E1N1600AE showed as out of range
- **MediaTek Bluetooth (most Slims):** no ISO interface setup (ps5-linux-patches #71); it timed out, and Bluetooth was gone after a warm reboot until a cold boot
- **Own RADV build (bootc):** Mesa 26.2.6 with Terra's patches, as in Bazzite, plus Borchev's Viola patch (int8 matrix instructions for int8 dot products, the compute queue, the GFX1013 async-compute threadgroup workaround), 64- and 32-bit, built in the image build against the base image's libraries (`bootc/mesa`); other GPUs as before. `RADV_VIOLA_ML=0` and `AMD_VIOLA_COMPUTE_QUEUE=0` turn the parts off. Not in the Legacy update bundle
- **`ps5-bt-addr` (MediaTek):** waits up to 10 s for the adapter's address (empty or all zeros until it is set up); when it wasn't readable yet, the script stopped (`16#: invalid integer constant`) and the chip kept its own address, so a DualSense paired under Linux couldn't connect
- **6 GB VRAM on every console:** new disk images ship `vram.txt` with 6 GB; existing installs get it once (`ps5-console-defaults`), later changes are kept
- **Desktop Mode at start, Steam's own videos:** once per install (new and existing), the default session becomes Desktop Mode; Steam's default-session setting in Game Mode turns it off. Bazzite's startup and suspend videos are removed (custom videos stay); new installs keep Steam's own branding
- **Bazzite's deck setup works again:** v2.5.1 renamed the image, and Bazzite then treated it as a desktop image (no `-steamdeck` for Steam in Desktop Mode, no Steam bootstrap, no Return shortcut, no default desktop session). The image is `ps5-bazzite-deck` again; Steam's System page names PS5 Bazzite Deck
- **Update channels:** Stable follows the stable release's kernel, Beta the newest pre-release's; every other channel Steam lists maps to Beta. Pre-release disk images install on Beta
- **`ps5-m2-install`** (moves the running system, bootc and Legacy, to the M.2 partition `m2_init` prepared; `--back` returns to USB): copies through a bind mount (mounting the root device a second time read-only always failed), shows progress (rsync), makes `/boot` writable for the boot entries on bootc, and checks that `cmdline.txt` and every boot entry start the new root before it finishes
- **Legacy update:** `update.sh` recognises installs whose root isn't `LABEL=bazzite-deck` (M.2 copies, other install methods) by the installed version file instead of refusing with "this is not a PS5 Bazzite Deck install"
- The release lists the `.img`'s own SHA-256 next to the volumes', to check the extraction. Pre-releases post to the pre-release Discord channel; flashing instructions name balenaEtcher (drives flashed with Rufus didn't start: emergency shell, root partition not found)

## [v2.5.1] – 2026-11-05
> bootc channels in Steam, Stable for every bootc console, PS5 Pro Bluetooth and temperatures.
- **Steam's OS Update Channel lists Stable and Beta of this image** (`/usr/libexec/os-branch-select`). Bazzite's script rebased to `ghcr.io/ublue-os/bazzite-deck`, which has no PS5 kernel. `:beta` is pushed with every `:stable` build and identical for now; later it carries the newest pre-release kernel and Bazzite's next version. `image-info.json` names this image, so Bazzite's tools and the login banner do too
- **Every bootc console follows `:stable`:** disk images install pointing at `:stable` (content of their release), and `ps5-bootc-channel` moves consoles on an older release tag (`:v2.5`) to `:stable` once; a console on the image's own release tag stays
- **PS5 Pro Bluetooth as in v2.1.x** (`patches/ps5-pro.patch`): HCI on interface 3 with the routing undone before setup and shutdown, the first HCI Reset retried after a cold boot (mfoster978, PR #30), ACL on bulk OUT 0x0d; replaces the early draft in rmux's tree. IW620 and Slim unchanged
- **PS5 Pro: ps5-cpufreq stays off,** as in v2.1.x: the Pro's MP1 never answers P-state requests (0x0b), and the busy mailbox then also blocked ps5-gpufreq's GPU clock requests (hot at idle, loud fan, red `mp1` errors at boot)
- The `:stable` Discord post names its kind (weekly or by hand), the pinned kernel and the PS5 files' commit

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

## [v1.8.9] – 2026-10-30
> Full release (image and update bundle) with the v1.8.8 kernel. Replaces the first v1.8.9 (4K120 as YCbCr 4:2:2), which showed the wrong colour range.
- **One DualSense for the PS5 and Linux, on by default on every console:** Linux has its own Bluetooth address, so the controller keeps a pairing for each (on separate profiles) instead of losing one every time you switch. IW620: while it's on, restarts go through the PS5 system instead of warm ones, because the chip didn't survive a warm reboot with the changed address (Max). `ps5-bt-address off` switches it off
- **MediaTek (Slim): the Linux-only Bluetooth address works on more consoles:** where the kernel's way of setting it didn't stick (hsgodd: the controller lost its PS5-system pairing every time), MediaTek's own command is used as a fallback
- **Steering wheels:** force feedback for Logitech wheels and rumble pads, as in vanilla Bazzite (the kernel config of rmux's 7.3 port has it too; it's in a module, so it needs the full build)
