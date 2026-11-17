# Changelog

Changes per release. Upstream versions are in each release's `VERSIONS.md`.

## [v2.16.1] – 2026-11-17
Pre-release.
- Bluetooth as in v2.15: the original PS5 and the Pro use the Linux-only address again by default; the Slim keeps shared pairing. On a Pro the imported PS5 pairing didn't connect (#73); shared pairing had only been tested on the Slim
- Removed: the VRAM scanout test (`amdgpu.ps5_scanout_gtt`, `patches/ps5-scanout-fallback.patch`); the `amdgpu.sg_display=1` it needs stops the PS5 from starting (doopz93). The v2.15 and v2.16 notes no longer suggest it

## [v2.16] – 2026-11-15
Pre-release.
- No full GPU reset on the PS5: a hang stops after the per-queue reset, so the display survives (official #81)
- The display's own resolution at 60 Hz is preferred at first start, instead of 1080p60; `amdgpu.force_1080p=1` goes back
- PS5 Pro: GPU firmware on system software 13.00, 60 compute units (official loader #104)
- PS5 Pro: GPU limit 85 °C as on the other models; the old 80 °C equalled the fan target and throttled the GPU
- One DualSense pairing on every console: the Linux-only Bluetooth address is removed (withdrawn in v2.16.1)
- Wi-Fi (IW620): the driver's own regulatory defaults again (no country following)
- Built for our kernel: xone (Xbox Wireless Adapter), xpadneo, new-lg4ff, hid-tmff2, t150, hid-fanatecff, gcadapter-oc, v4l2loopback, openrazer (`bootc/kmods/`)
- Logitech wheels: Bazzite's `hid_logitech` blacklist is kept only together with new-lg4ff
- The VRAM scanout test needs `amdgpu.sg_display=1` as well (removed in v2.16.1)
- `ps5-report`: Bazzite's package versions; skips files tuned and Steam rewrite
- The image builds without DirectMesh or a driver when its source is gone
- Removed: the dead `ps5-stage-viola-fw` drop-in, `ps5-stage-gpu-firmware`, duplicate Bluetooth links and a duplicate USB power rule, obsolete `patches/upstream`
- Release notes claim each fix only where it last happened

## [v2.15] – 2026-11-15
Pre-release. v2.14.1 and v2.14.2 were withdrawn; their changes are here.
- IW620: a remain-on-channel request times out after 20 s instead of hanging the console (#60)
- FLAVA3: 1440p at 100 and 120 Hz uses the mode's own timing; the picture was shifted up (VERDE unchanged)
- Test switch `amdgpu.ps5_scanout_gtt` for games dropping out of Game Mode when VRAM is full (removed in v2.16.1)
- DirectMesh also on GPUs reporting `1002:13db` (#62)
- A root shell in emergency and rescue mode instead of "root account is locked"
- `ps5-report`: a "Changed on this console" section; `/run/ps5` read with sudo; the display line reads the active CRTC
- `legacy-to-bootc.sh`: stops on an earlier `/ostree`; puts the Legacy kernel back on any failure
- `ps5-m2-install`: names the `--boot` step and how to prepare the M.2

## [v2.14] – 2026-11-13
Pre-release.
- Mesh shaders per game on the original PS5 and Slim (DirectMesh, experimental): `ps5-directmesh %command%`
- Legacy installs are no longer supported; `tools/legacy-to-bootc.sh` converts one to bootc in place
- The kernel source comes from our mirror of rmux's repository, which was removed from GitHub
- The image's file list is `bootc/build_files/files.list`

## [v2.13] – 2026-11-12
Stable.
- The loader appends what it dumps to the initrd: a PS5 Pro has 60 compute units from the first start; starts without a USB drive get Wi-Fi firmware and pairings
- `ps5-dumps` (dracut) copies them to `/run/ps5`
- Warm reboots keep the PS5 Pro GPU firmware
- `ps5-stage-viola-fw` and `ps5.viola_cp=cs2` are gone

## [v2.12.1] – 2026-11-11
Pre-release.
- 4K120 is no longer withdrawn by a link check still running after a modeset

## [v2.12] – 2026-11-11
Pre-release.
- M.2 installs: no emergency shell after an update (`ps5-ostree-path`)
- Steam's About page: OS Variant `ps5-bazzite-deck`, OS Build with channel and release

## [v2.11] – 2026-11-11
Pre-release.
- Starts on PS5 system software 4.x (GPT first usable LBA fixed; found by fitamix)
- Cooler at idle: CPU clock rate limit, GPU clock after CPU boost
- IW620: no TDLS (a phone opening a direct link killed Wi-Fi)
- Salina xHCI kept out of runtime suspend (Bluetooth was lost)
- Wi-Fi (IW620) follows the access point's country (reverted in v2.16)
- Kernel patches: one per feature
- Fresh installs of a stable release follow Stable

## [v2.10] – 2026-11-10
Stable.
- Display test switches: `hdmi.rearm`, `edid_keep`, `scdc_writes`, `sleep_mute`
- VERDE: HDR no longer offered (it came out washed out)

## [v2.9] – 2026-11-10
Pre-release.
- Controllers paired in the PS5 system connect in Linux: the loader exports the pairings, `ps5-bt-import` imports them (loader #97)
- Compute through KFD (ROCm/HIP, OpenCL): TLB flush fixed (#57, #77)
- Warm reboots after `bootc rollback` start the right deployment

## [v2.8.1] – 2026-11-09
Pre-release.
- Fan: 80 °C target in firmware mode (`ps5_fan.target=`, 0 = Sony's)

## [v2.8] – 2026-11-09
Pre-release.
- Fan: firmware mode no longer forces full speed at 90 °C (the fan cycled)
- Firewall starts again
- Linux 7.3.3
- IW620: Wi-Fi after a warm reboot, hidden networks; Bluetooth pairing and private addresses (#75)
- Display: triple-buffer fix (#72)
- `:stable` is built from the stable release, not from `main`

## [v2.7.3] – 2026-11-08
Pre-release.
- Async compute on the original PS5 and Slim

## [v2.7.2] – 2026-11-08
Pre-release.
- VRR range also read from the HDMI Forum SCDB
- `ps5-report` names the GPU on consoles reporting `1002:13db`

## [v2.7.1] – 2026-11-08
Pre-release.
- FLAVA3: 1440p up to 340 MHz uses the bridge's own timing (it was off-centre)
- VRR on FreeSync-only displays
- IW620 Wi-Fi and Bluetooth on the first start after an update (`firmware_class.path`)

## [v2.7] – 2026-11-07
Stable.
- 100 Hz modes always offered; other EDID timings up to 600 MHz on FLAVA3
- Debug switches and dead code removed from the display driver
- Updates only with `sudo bootc upgrade`; Steam's update check finds none
- Steam's own startup and suspend videos
- The loader also looks in `/data/PS5/Linux/`; `ps5-m2-install --boot`

## [v2.6.3] – 2026-11-06
Pre-release.
- bootc updates stage again (greenboot's rollback trigger shipped as a no-op)

## [v2.6.2] – 2026-11-06
Pre-release.
- `ps5-report`: VRAM in use next to `vram.txt`
- RADV build fixes

## [v2.6.1] – 2026-11-06
Pre-release.
- PS5 Pro: Sony's own GPU microcode again (the substitute hung D3D12 games)
- Loader from soniciso1's fork: PS5 Pro GPU firmware on more system software versions
- Own RADV build: Bazzite's Mesa patches plus the Pro's int8 matrix instructions and compute queue
- 6 GB VRAM on every console
- Desktop Mode at start
- MediaTek Bluetooth: no ISO interface setup (#71)
- `ps5-m2-install` moves the system to the M.2

## [v2.5.1] – 2026-11-05
- Steam's OS Update Channel lists Stable and Beta of this image
- Every bootc console follows `:stable`
- PS5 Pro Bluetooth as in v2.1.x (mfoster978)
- PS5 Pro: `ps5-cpufreq` stays off (the Pro's MP1 doesn't answer P-state requests)

## [v2.5] – 2026-11-04
Stable.
- bootc image next to Legacy; started by bazzite-bootc-loader
- Linux 7.3.1 with rmux's patches; the v1.8.9 display stack on top (4K120 over FRL, VRR, standard modes)
- PS5 Pro: GPU firmware on a 4-byte boundary (it mostly never loaded)
- Builds and releases from GitHub Actions

## [v1.8.9] – 2026-10-30
- Linux-only Bluetooth address on every console (removed in v2.16)
- Force feedback for Logitech wheels
