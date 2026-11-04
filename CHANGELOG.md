# Changelog

All notable changes to the images. Exact upstream versions are in each release's `VERSIONS.md`.

## [Unreleased]
- **The kernel is named `<version>-viva`** (`7.3.1-viva`)
- **Releases are public from the start:** notes first, then files as they're built: update bundle for existing installs, bootc disk image, loader; the notes list each file as it arrives
- **`ps5-report` starts with a fastfetch-style block:** console (original, Slim, Pro), HDMI chip, wireless chip, install type, kernel, display, Bluetooth and Wi-Fi state; then Bluetooth, Wi-Fi, USB, display, GPU and system sections with their logs. Kernel log counts are no longer doubled
- Discord: the post carries the notes' "What's new" cut at a line (a byte cut could break a character and the post), plus a link to the full notes; the bootc post gives the `bootc switch` command for pre-releases
- Weekly upstream audit (`upstream-audit.yml`, `tools/audit-upstream.sh`): do our patches apply to rmux's newest kernel branch and the newest loader. Every X.Y release starts from it (`docs/releasing.md`)
- Fixed: the update bundle step (`podman rm` has no `-q`)

## [v2.4] – 2026-11-04
> First release built entirely by GitHub Actions from this repo: kernel, update bundle for existing installs, bazzite-bootc-loader, bootc image and disk image. Kernel: Linux 7.3.1 + rmux's shitshow (8de2aff) with our own work ported on top; 40 patch files became 5. Releases v2.1.2 to v2.3 are withdrawn.
- **Wi-Fi and Bluetooth back to v2.1.1.** Every Bluetooth, Wi-Fi and restart script, service and rule from v2.1.2 to v2.2 is reverted to its v2.1.1 version (the scripts, services and rules; the kernel's Bluetooth is rmux's newer code, below)
- **bootc image (experimental):** `ghcr.io/vivalavent/ps5-bazzite-bootc`, flashed from the release's disk image, updated with `sudo bootc upgrade`, rolled back with `sudo bootc rollback`
- **bazzite-bootc-loader:** rmux's ps5-linux-loader @ 940bce3 + BLS patches 0001-0006, built from source for every release. Starts existing installs exactly as the standard loader does
- **PS5 Pro: D3D9 games work.** AMD's command-processor microcode is now read from Bazzite's compressed linux-firmware; before, the swap silently kept Sony's
- **PS5 Pro: 1 GB VRAM and an 80 °C GPU limit by default** (`ps5-console-defaults`, once; later changes are kept)
- **Fan: no spike to full speed at shutdown or reboot**
- The update refuses to run on a bootc install, and refuses a boot partition that starts a different root (M.2 installs booting from a stick)
- Removed: the ICC debugfs test patch (issue #36)
- **rmux's newer kernel work comes in:** IW620 and MediaTek Bluetooth fixes (including the IW620 fix for `0x2039` timeouts), native FRL with 4:2:0 fallback, ALLM and bounded recovery, RGB range from DRM ("Broadcast RGB"), his mode policy, the PS5 Pro frequency drivers with Pro clock limits
- **Ported from ours, which his tree doesn't have:** VRR on FLAVA3, HDMI re-arm and session-switch fixes, EDID keep and fallback, SCDC Source Version and TMDS_Config, sleep mute, full-rate DP link, Verde game content, the thermal GPU governor (85 °C limit), overlay GPU load and temperature, the fan shutdown fix, suspend-to-idle
- Dropped where rmux has his own: our mode list (no more "1080p60 preferred" default), `hdmi.rgb_range`, the HDMI debug log, the 100 Hz test modes
- Wi-Fi driver unchanged
- `ps5-report` and `vrr-report`: count the new kernel's "got real HDMI EDID" lines; `ps5-report` recognizes both PS5 Pro GPU IDs (13da, 13dc)
- A release's kernel reaches the nightly `:stable` bootc image only when the release is promoted to stable (`pin-kernel.yml`), so a test kernel never does
- Comments in our kernel patches and scripts cut to the reason, one or two lines
- The release kernel builds on a self-hosted runner (label `ps5-kernel`); `gh workflow run release.yml -f tag=vX.Y -f hosted=true` uses GitHub's runner instead

## [v2.1.1] – 2026-11-02
> v2.1.0's image with the new kernel installed into it, checked file by file.
- **Fix: Bluetooth on original PS5s (IW620) found no new devices** ("Busy"; the DualSense still worked): v2.0's reconnect quirk made the kernel scan with the old command family while it advertised with the new one, and this chip refuses to mix them ("Command Disallowed" on every scan). The quirk is taken out again, back to v1.8.x behaviour; consistent with rmux reporting Bluetooth trouble on his branch, which has the same quirk
- **Fix: fan target back to 50 °C after sleep** (and the fan loud again): on waking up the fan driver re-sends its parameter table to the console, which resets the fan target. The current target (80 °C, or what you set with `ps5-perf`/hwcon) is put back now

## [v2.1.0] – 2026-11-02
> Stable release: v2.0.0's image with the v2.0.1 and v2.1.0 kernel, Bluetooth driver and scripts installed into it (no full image build), checked file by file. Everything since v1.8.4 is in the v2.0.0, v2.0.1 and v2.1.0 entries.
- **CPU boost off is really off:** with boost switched off (`ps5-perf`, or the CPU boost toggle in tools), the CPU could still reach the boost clocks; the ceiling now drops to 3.2 GHz. The CPU starts in a defined state, so the current clock and the cpufreq statistics are right from boot (rmux's fix, ported to our driver)
- Checked against rmux's 7.3.1 branch: its fan commit adds diagnostics and drops one temperature channel; nothing there fixes a problem we have, so it isn't taken. A move to Linux 7.3.1 comes as its own release later

## [v2.0.1] – 2026-11-<DD> (pre-release)
> Kernel, Bluetooth module and the changed scripts, as a quick package on top of v2.0.0.
- **Fix: fan louder than before** (Shahine, Phat): v2.0.0's new fan driver no longer set the console's fan target to 80 °C at boot, as the old driver did, so the firmware used its own lower target. It's set again. And the fan modes now match upstream's, so fan tools work as intended: `pwm1_enable` 2 is the kernel curve (as hwcon and CoolerControl expect), 3 the console's firmware control (the default); writing `target_temp` returns to firmware control
- **PS5 Pro: Bluetooth works from a cold boot** (mfoster978, PR #30): the first HCI Reset raced the controller becoming ready, which left a dead `hci0` until btusb was reloaded; it's retried a few times now (Pro chip only)
- **PS5 Pro: GPU load in overlays** (after mfoster978's PR #29): with the Viola firmware, amdgpu's own `gpu_busy_percent` is no longer removed by a duplicate, and `gpu_metrics` is marked unsupported, so MangoHud stops replacing load and temperature with zeros
- **PS5 Pro: one DualSense for the PS5 and Linux** (mfoster978, PR #31): the Linux-only Bluetooth address on the Pro, set once Bluetooth is up (`ps5-bt-pro-addr`)
- **Fix: "not VRR capable" on TVs that had VRR before v1.8.6** (Verrek's Panasonic OLED): the TV announces HDMI VRR with a minimum (48 Hz) and no maximum, which the HDMI spec means as "up to the highest refresh rate"; it was read as "no HDMI VRR", so the TV looked FreeSync-only and was refused since v1.8.6. FreeSync-only monitors are still refused. The VRR range is also read from the newer EDID block (HF-SCDB) some TVs use
- **PS5 Pro firmware:** the staging service says so when the loader didn't dump the Viola firmware (it was silently skipped). The README names the loaders that dump it: the official ps5-linux-loader built from its main branch (2 November or later) on 13.20, 13.60 or 11.60
- `ps5-report`: counts the Pro's firmware files correctly (it read the root-only boot partition without root and always said 0)

## [v2.0.0] – 2026-11-02 (pre-release)
> Full build (image and update bundle). Everything since v1.8.4, the current Latest: the v1.8.5–v1.8.9 test kernels, today's upstream updates, and fixes for the reported Bluetooth and PS5 Pro problems. Untested parts are marked as such.

**Controller / Bluetooth**
- **One DualSense for the PS5 system and Linux, on by default on every console:** Linux keeps its own Bluetooth address, so the controller keeps one pairing per system (on separate profiles). `ps5-bt-address off` switches it off
- **Fix: controller needed pairing again after every cold boot** (several consoles): the Linux address was derived afresh from the chip's power-on default at every boot, and that default isn't fixed on every unit. The chosen address is now saved on first use and reused on every boot. Not yet confirmed on the affected consoles
- **MediaTek (Slim):** where the kernel's way of setting the address didn't stick (the controller lost its PS5-system pairing every time), MediaTek's own command is used as a fallback. Untested so far
- **IW620: better reconnects of keyboards and controllers** (legacy LE command family, rmux's meower `cf37af5` by Daniel Walker). Untested on this image; rmux's newer 7.3.1 branch has the same quirk and he reports Bluetooth problems there, so if Bluetooth is worse than on v1.8.9 on an IW620 console, this is the first suspect
- **IW620: no warm restart while the Linux-only address is on** (restarts go through the PS5 system instead), because the chip didn't survive a warm restart with the changed address (Max). The real "both together" fix stays open
- The PS5 Pro's Bluetooth chip is recognised; the Linux-only address isn't supported on it yet (stated instead of silently skipped)

**PS5 Pro**
- **Fix: the Pro's GPU firmware mostly never loaded (v1.8.0–v1.8.9).** The firmware is appended to the initrd, and the kernel needs each appended archive to start on a 4-byte boundary; our script didn't pad, so on most installs the kernel stopped reading at the join and **the Pro ran as a base PS5 (36 compute units)**. That's behind most Pro game crashes and HDMI losses reported (007 First Light, Persona 3, No Man's Sky, GTA V). Found, measured and fixed by mfoster978 (issue #27, PR #32); his retest at 60 CUs no longer crashed. The Pro also needs a loader that dumps the firmware (loader PR #91 for 11.60)
- **Upstream #66 (Borchev) ported in full:** a GPU clock governor with a thermal limit (85 °C by default, `ps5_gpufreq.temp_limit`), 500–2350 MHz on the Pro and 500–2230 MHz on the base PS5; GPU busy reporting on the Pro (`gpu_busy_percent`); the compute-unit enable check moved to GPU init (it ran too early) and repeated after resume and GPU resets; `0x13dc` treated as a Pro; the gfx clock read from the SMU and the GPU temperature from Tctl. The separate thermal driver is gone, its sensor is `temp5` of the fan's hwmon device. This governor replaces rmux's GPU clock driver, which is no longer built; the GPU-load and temperature overlay values keep working (they use the same accounting and the same Tctl reading). #66's power-controller locking for sleep entry (messages sent with interrupts off) is applied to the lock the CPU frequency driver shares. All of it untested on this image so far
- **Fan driver starts on the Pro:** the Pro hands the fan zone over in manual mode, which made the driver fail; it's returned to firmware control (upstream #66)
- The PS5 CPU frequency driver still doesn't start on a Pro (its requests came back "busy")
- `ps5-report` has a PS5 Pro section: compute units, whether the Pro's GPU firmware was found and loaded, fan board id, and whether the unsupported `cu_unlock` option is set

**Fan**
- **New fan driver** (rmux's meower hwmon driver): a standard hwmon device (`ps5_fan`: temperatures, fan speed, `pwm1`, a curve via `pwm1_auto_point*`). **The console's own firmware fan control stays the default** (`pwm1_enable` 2); the kernel's curve is opt-in (3). `target_temp` (what `ps5-perf` and the hwcon plugin use) is kept. `ps5-perf status` shows the fan mode and speed

**Display**
- 4K120 only where the TV can take it, and back to 4K by itself when the link doesn't come up (v1.8.5, after Slip's work)
- VRR only for displays with HDMI VRR, as on the PS5 system; FreeSync-only monitors blanked (v1.8.6, Storm)
- 100 Hz modes (1080p100, 1440p100, 4K100) offered where the display goes to 100 Hz; 1080p100 is the uncertain one (v1.8.7, test)
- HDMI 2.x link settings told to the TV at every mode change, for TVs that dropped to HDMI 1.4 modes after boot (v1.8.8, Beyond TV, #11/#21). Not yet confirmed by the reporter, and a suspect for one monitor (ASUS MS27UC behind an HDMI switch) that lost 4K60 on v1.8.9; a display log from that setup is wanted
- Tried and taken out again (kept in the `archive/research-2026-11` tag): ALLM, instant VRR switching, a one-step switch-over, 4K120 as YCbCr 4:2:2 (wrong colour range), a re-arm change

**Cleanups and tooling**
- **Patch cleanup:** release numbers and people's names moved out of code comments into the patch descriptions and this changelog; no code change
- **Reproducible builds:** rmux's meower branch is pinned to the commit our patches are made against (`36b9828`); newer meower commits are carried as our own patches. A `FRESH=1` release mode builds from fresh clones with every patch applied in order
- Steering wheels: force feedback for Logitech wheels and rumble pads, as in vanilla Bazzite
- No failed services at boot (Bazzite's ostree-only `bootloader-update` and `greenboot` are masked); the update removes a leftover `hdmi.rearm=0`
- The updater keeps the two newest backups and removes older ones
- 1 MiB kernel log buffer, so early boot lines (HDMI chip, Pro firmware) stay in reports; `ps5-report` also reads the persistent journal and tells the Pro's Bluetooth chip apart
- Deprecated workqueue use fixed (the `vrr_follow_fn enqueued on deprecated workqueue` warning)
- README: features described without version history (that's this file), VRAM/GTT section, `steamos-session-select`, the official wiki (wiki.ps5-linux.eu)
- Upstream: MT7921 Wi-Fi config (#40) was already in; #63 (Slip) partly borrowed in v1.8.5; #66 partly, see above

## [v1.8.9] – 2026-10-<DD>
> Full release (image and update bundle) with the v1.8.8 kernel. Replaces the first v1.8.9 (4K120 as YCbCr 4:2:2), which showed the wrong colour range.
- **One DualSense for the PS5 and Linux, on by default on every console:** Linux has its own Bluetooth address, so the controller keeps a pairing for each (on separate profiles) instead of losing one every time you switch. IW620: while it's on, restarts go through the PS5 system instead of warm ones, because the chip didn't survive a warm restart with the changed address (Max). `ps5-bt-address off` switches it off
- **MediaTek (Slim): the Linux-only Bluetooth address works on more consoles:** where the kernel's way of setting it didn't stick (hsgodd: the controller lost its PS5-system pairing every time), MediaTek's own command is used as a fallback
- **Steering wheels:** force feedback for Logitech wheels and rumble pads, as in vanilla Bazzite (the kernel config of rmux's 7.3 port has it too; it's in a module, so it needs the full build)

## [v1.8.8] – 2026-10-<DD>
> Test build: kernel only, as a quick kernel package, on top of v1.8.6 or v1.8.7.
- **Fix attempt: TVs that drop to HDMI 1.4 modes a few seconds after boot** (Beyond TV, issues #11 and #21: only 1080p60 and 1440p60 left, no 4K, no 120 Hz, no VRR). The console now tells HDMI 2.x TVs its link settings at every mode change, as a PC does, not only at 4K and 120 Hz

## [v1.8.7] – 2026-10-<DD>
> Test build: kernel only, as a quick kernel package, on top of v1.8.6.
- **100 Hz modes, for testing** (FLAVA3 consoles, only when the display goes to 100 Hz or more): **1440p100** (most likely to work: the HDMI chip already handles 1440p60 and 1440p120 the same way), **1080p100** (unknown: whether the chip knows this mode is what the test finds out) and **4K100** (when the display lists it; same link as 4K120, with its fallback to 4K). Modes that give no picture are taken out again before a release

## [v1.8.6] – 2026-10-<DD>
> Kernel only, as a quick kernel package, on top of v1.8.5.
- **VRR only for displays with HDMI VRR,** as on the PS5 system: monitors that announce only FreeSync blanked on every refresh change with VRR on (Storm, AOC Q27G2G3R4B); they aren't offered VRR any more. TVs with HDMI VRR (LG, Samsung, Sony…) are unaffected

## [v1.8.5] – 2026-10-<DD>
> Kernel only, as a quick kernel package, on top of v1.8.4.
- **No more black screen from 4K120** (hsgodd, kishy, pukason): 4K120 is only offered when the display announces the HDMI 2.1 link speed it needs (FRL at 4 lanes × 8 Gbps or more) and YCbCr 4:2:2, and the HDMI chip doesn't report a slower link. If the 4K120 link still doesn't come up, the console notices it (the chip's FRL status), stops offering 4K120 for that display, and switches to 4K at the highest refresh that works by itself. After Slip's work in his `hdmi-usbc-test` branch
- The log says why 4K120 is or isn't offered (`sudo dmesg | grep 4K120`)

## [v1.8.4] – 2026-10-<DD>
> Stable release: everything since v1.7.2 for every model. Image and update bundle: the v1.8.0 build with the v1.8.4 kernel.
- **VRR never below 48 Hz** (from v1.7.3): less flicker on OLEDs
- **PS5 Pro support:** GPU (upstream #58 by Borchev, ported to 7.3), its GPU firmware added to the initrd at boot, internal Bluetooth (QuartConz), Wi-Fi; the PS5 CPU and GPU frequency drivers don't start on a Pro (they flooded the log with "mp1fw_sendmsg: busy" and frequency errors), its firmware keeps the clocks
- **Display as in v1.7.3:** the v1.8.1–v1.8.3 display changes and ALLM are undone (kept in the `archive/research-2026-11` tag)
- Bazzite's ostree-only `bootloader-update` and `greenboot` services, which failed at every boot, are masked
- The update removes a leftover `hdmi.rearm=0` from `cmdline.txt` (it kept a TV dark after mode changes) and, on IW620 consoles, switches the Linux-only Bluetooth address off (it left Wi-Fi and Bluetooth hung after warm restarts)

## [v1.8.3] – 2026-10-<DD> (PRO ONLY)
> Kernel only, as a quick kernel package, on top of v1.8.0/v1.8.1. Test build for 4K120.
- **4K120 hardening** (no picture on hsgodd's LG with VRR on): with VRR, the HDMI chip switches to follow mode only once the 4K120 link has had time to come up (1.5 s instead of 0.1 s); 4K120 is offered only at 120.00 Hz (the HDMI chip's setup is made for exactly that); the log shows the picture format at 4K120

## [v1.8.1] – 2026-10-<DD> (PRO ONLY)
> Kernel only, as a quick kernel package.
- **VRR switches like on a PC:** switching VRR on or off no longer re-runs the whole HDMI setup; the HDMI chip switches in one go, without the black screen of about 2 seconds (which Steam's menus triggered often). Changing the resolution still goes through the setup
- **Fix: 4K120 without picture on some TVs since v1.8.0** (hsgodd): ALLM is gone again. Its InfoFrame writes landed while the HDMI chip trained the 4K120 link, and Linux on a PC doesn't send ALLM at all

## [v1.8.0] – 2026-10-<DD> (PRO ONLY)
> Pre-release: ALLM and PS5 Pro support need testing on more TVs and on a Pro.
- **ALLM:** on FLAVA3 consoles the TV switches to its game mode by itself, when it supports ALLM (the same HDMI Forum signal the PS5 system sends). ` hdmi.allm=0` switches it off
- **PS5 Pro (untested):** GPU support from upstream's PR #58 by Borchev, ported to our 7.3 kernel (Viola golden settings, 64 compute units, GPU clock and temperature), and the Pro's GPU firmware put into the initrd at boot from what the loader dumps, without rebuilding the initrd on the console. Nothing changes on other consoles
- **PS5 Pro Wi-Fi and Bluetooth (untested):** the Pro's MediaTek MT7925 Wi-Fi driver is in the kernel; its internal Bluetooth (0e8d:3605) from QuartConz's patch (interface 3, WMT activation, ACL on the second bulk endpoint, an idea from WizGery), plus his rule that keeps it out of USB autosuspend
- **`ps5-bt-address`:** warns that IW620 consoles may not apply the address after a cold boot, and `status` shows the controller's current address

## [v1.7.3] – 2026-10-<DD>
> Kernel only, as a quick kernel package.
- **VRR never goes below 48 Hz,** the PS5 system's own floor. Many TVs allow 40 Hz, where OLEDs flicker visibly when the refresh rate swings (suggested by hsgodd). Below 48 fps, frames are doubled at 120 Hz modes; 60 Hz modes keep a fixed 60 Hz. The FreeSync InfoFrame now sends the range actually used

## [v1.7.2] – 2026-10-<DD>
- **4K at 120 Hz** over HDMI 2.1 FRL on FLAVA3 consoles with an HDMI 2.1 TV that supports it, in Game Mode's display settings like any other mode. Ported from Lawson's kernel, which follows Sony's own setup for this mode; between GPU and HDMI chip it runs as YCbCr 4:2:2, the TV gets real 4K120. VRR works there too
- **VRR:** switching VRR again or changing the mode while the HDMI chip is still switching over no longer mixes the two setups

## [v1.7.1] – 2026-10-<DD>
> v1.7.0 was built but not released: its cleanup had dropped two setup steps VRR needs (Sony's full PHY settings and the VSync block in every setup), and with VRR switched on the console could hang completely. v1.7.1 is v1.7.0 with those steps back and without the wait that could hang it.
- **VRR on FLAVA3 consoles,** switched with Steam's VRR setting (Settings → Display), no boot option needed. Works at 4K60, 1080p120, 1440p60 and 1440p120 with TVs that support VRR or FreeSync (tested on an LG C4). The fix is Lawson's: a timing packet the GPU sends the HDMI chip every frame, the chip's MSA bit left clear, and the chip's follow mode switched on after the packet flows (with thanks to hsgodd for the stock-system captures). Switching takes about 2 seconds of black screen. `hdmi.vrr=0` never offers VRR
- **USB-C DisplayPort off by default** (from v1.6.1): add ` usbc_dp.enable=1` for a USB-C display or the PSVR2
- **VRR only where it works:** on consoles with the VERDE HDMI chip VRR is never offered, so Steam's setting can't switch on a mode that doesn't work there
- **README:** the PS5 Pro isn't supported yet; etaHEN and kstuff have to be off; `RADV_DEBUG=nohiz` for graphics glitches in a game; the Wi-Fi chips by ID in the hardware matrix
- **Cleanup:** the VRR test code and switches of v1.5.1–v1.6.3 are gone (kept in the `archive/research-2026-11` tag); the update removes ` hdmi.vrr_test=1` from `cmdline.txt`. For debugging: `hdmi.icc_trace=1`, `hdmi.vrr_measure=1`

## [v1.6.3] – 2026-10-<DD>
> Kernel only, as a quick kernel package.
- **VRR at every mode:** 1440p60 and 1440p120 work too (Gilles, LG C4), with the timing packet sent whatever the sync polarity
- **Cleaner, faster switching:** the HDMI chip switches over in under 2 seconds (was about 6), and the picture stays dark meanwhile instead of drifting and flickering
- The frame-timing log every 2 seconds only with `hdmi.vrr_measure=1`

## [v1.6.2] – 2026-10-<DD>
> Kernel only, as a quick kernel package.
- **VRR works at 4K60 and 1080p120** (FLAVA3, with ` hdmi.vrr_test=1`): test 28's follow mode (Lawson) gave real VRR on an LG C4, the TV's FreeSync following the game. It's now the default with `hdmi.vrr_test=1`, so VRR is switched on and off with Steam's normal VRR setting
- **No black screen in modes it can't carry yet:** at 1440p (custom timing; 1440p60 also has a negative sync, so no timing packet) VRR isn't offered and the refresh stays fixed. `hdmi.vrr_any_mode=1` tries those modes anyway
- The timing packet the GPU sends, or why it isn't sent, is logged once per mode

## [v1.6.1] – 2026-10-<DD>
> Kernel only, as a quick kernel package.
- **USB-C DisplayPort off by default:** programming the front USB-C port's DisplayPort policy can reset a device on that port, such as a boot drive there (Slip makes it opt-in in his hdmi-usbc-test branch for the same reason). USB-C displays and PSVR2: add ` usbc_dp.enable=1` to `cmdline.txt`
- **VRR test 28, from Lawson's work** (only with `hdmi.vrr_test=1`, follow mode with `hdmi.vrr_chip=2`): the GPU sends Sony's timing SDP (`39 04`, the source timing) every frame, the HDMI chip's MSA-ignore bit stays clear (it drops its input lock otherwise), and the chip is switched to follow mode only after the SDP flows, plus a FreeSync SPD for the TV. Lawson reports real VRR with this on his setup (TV FreeSync following the game at 40–60 Hz)

## [v1.6.0] – 2026-10-<DD>
- **Fix: colours too dark on TVs set to "Auto"** (FLAVA3 consoles, since v1.5.0): the RGB range flag went out as "limited" instead of "full" (first fixed in the v1.5.3 pre-release)
- **The first-start message is gone:** it didn't show, or only for a moment. The update removes it from existing installs
- Everything from the v1.5.2–v1.5.6 pre-releases: the VRR experiment's tests 21–26 (inert unless `hdmi.vrr_test=1`), `hdmi.icc_trace`

## [v1.5.6] – 2026-10-<DD>
> Kernel only, as a quick kernel package.
- **VRR test 25b:** `hdmi.vrr_prep_keep=1` sends our own pre-block as well, right after the replayed stock message, in case the chip needs both
- **VRR test 26:** `hdmi.icc_send` sends any HDMI ICC message to the EMC right away (hex, root only, only with `hdmi.vrr_test=1`). Test 25 showed the EMC accepts stock's VRR arming sequence (id `0x30`) but nothing runs it: stored sequences need a trigger binding (4/2), and ours binds `0x31`–`0x37` only. With this, registering `0x30` and binding it to trigger bits can be tried without a rebuild
- Build: a duplicate `ps5-vrr-prep-raw.patch` line in `build.sh` removed (hsgodd)

## [v1.5.5] – 2026-10-<DD>
> Kernel only, as a quick kernel package.
- **VRR test 25** (only with `hdmi.vrr_test=1` and the chip's own VRR mode): test 24 ruled out the InfoFrames, which leaves the pre-block as the one message where stock and our port still differ. `hdmi.vrr_prep_raw` replaces it at runtime with pasted register writes (e.g. from a stock capture), so each captured value can be tried without a new build

## [v1.5.5] – 2026-10-<DD>
> Kernel only, as a quick kernel package.
- **VRR test 25:** with test 24 every visible message of Sony's VRR switch is replicated except one, the pre-block, whose constants came from a 4K capture. `hdmi.vrr_prep_raw` (runtime) sends a captured pre-block 1:1 instead of ours, so stock's own bytes for a mode can be replayed and bisected without a rebuild. hsgodd's capture of that message (id 0x0186) shows it arms the chip's VTEM/EMP generator (`0x7110` preamble, `0x7011`/`0x7204` strobes, `0x7225`–`0x7231`), which our pre-block never did The UPDCTRL latch after the pre-block is now off by default (stock's capture has none)

## [v1.5.4] – 2026-10-<DD>
> Kernel only, as a quick kernel package.
- **VRR test 24** (only with `hdmi.vrr_test=1` and the chip's own VRR mode): hsgodd captured stock's complete VRR-on sequence; its VRR block matches ours, but stock sends two messages ours didn't, right before the pre-block: a DRM InfoFrame in the `0x7e40` slot and an SPD InfoFrame (vendor "SCEI", product "PS5", source type game). Both now go out in VRR mode (`hdmi.vrr_spd`, `hdmi.vrr_drm`); `hdmi.vrr_vsif=0` keeps our FreeSync packet from overwriting the DRM InfoFrame in the shared slot

## [v1.5.3] – 2026-10-<DD>
> Kernel only, as a quick kernel package (no image, no update bundle).
- **Fix: colours too dark on TVs set to "Auto"** (FLAVA3 consoles, since v1.5.0): the full-range fix wrote the `hdmi.rgb_range` value straight into the AVI InfoFrame's quantization field, but CTA-861 codes it as 0 default, 1 limited, 2 full, so the default "1 = full" went out as **limited**. TVs that follow the flag (VCDB QS=1, most current TVs) on "Auto" treated the GPU's full-range RGB as limited: too dark, crushed shadows, at every resolution (Gilles, LG). The parameter keeps its meaning (1 full, 2 limited, 0 no flag)
- **VRR test 22: full ICC trace** (`hdmi.icc_trace=1`, runtime, off by default): every HDMI ICC message and reply logged in full as numbered hex, the Linux side of the stock-vs-Linux comparison. Test 21 showed the GPU does variable timing and the stock system gets real VRR through the same chip, so the gap is in how the chip is programmed

## [v1.5.2] – 2026-10-<DD>
- **VRR test 21 in the kernel** (inert unless `hdmi.vrr_test=1`): measures whether the GPU really sends a variable frame length. Every 2 s the kernel logs the measured frame intervals from the vblank interrupt (`PS5 VRR DRR: … frame length VARIES` or `FIXED`), and at each VRR switch the frame-length range amdgpu programs. Answers hsgodd's question (B): fixed timing from the GPU would explain both the FreeSync drift and the chip's VRR mode refusing
- Update bundle only (fresh installs: flash the v1.5.1 image, then update)

## [v1.5.1] – 2026-10-<DD>
- **Updates always end in a cold start:** with warm reboot on, the restart after an update kexec'd straight into the new kernel without the PS5 resetting its hardware (the v1.5.0 test install hung that way). The updater and the quick-kernel installer now make that one restart go through the PS5 system
- **Fan left at the console's own target:** v1.5.0 set 85 °C, but the console's own target is 80 °C (ObsessiveRug's report), so the fan ran later and the console warmer. `FAN_TARGET=` in `/etc/ps5-bazzite-deck/perf.conf` still sets one; CPU boost stays on
- **Shorter `cmdline.txt`:** the two options we had added are kernel defaults now: the security modules (`CONFIG_LSM`, Game Mode needs them) and USB never sleeping (`CONFIG_USB_AUTOSUSPEND_DELAY=-1`). The updater removes exactly `lsm=landlock,lockdown,yama,integrity,apparmor,bpf` and `usbcore.autosuspend=-1`; anything else in the line stays
- **`ps5-report` and `vrr-report` built in:** the bug-report and VRR-result scripts are commands now (they need no network)
- **Experimental VRR in the kernel, off by default:** the VRR test series (tests 6–20) is in the release kernel but inert unless `hdmi.vrr_test=1` is in `cmdline.txt`; without it the HDMI setup is exactly v1.5.0's. One build instead of separate quick kernels; switches under `/sys/module/hdmi/parameters/vrr_*`

## [v1.5.0] – 2026-10-<DD>
- **USB-C DisplayPort output** (ps5-linux-patches #57 by tertiumndatur, ported to 7.3): displays and the PSVR2 on the console's front USB-C port, no adapter. The HDMI EDID is now bound to the one HDMI connector, and all HDMI-bridge-specific paths (HDR, mute, link lock, 1440p fixup, the standard mode set) stay off the USB-C link. PSVR2 also needs userspace that isn't in the image yet (a patched Mesa for reprojection, PSVR2Toolkit)
- **Colours at 1080p:** the AVI InfoFrame now says full-range RGB (what the GPU sends; *it went out coded as limited by mistake, fixed in v1.5.3*); TVs read the old "default" as limited range for TV timings like 1080p and 4K60, which crushed blacks and oversaturated colours at those resolutions only (`hdmi.rgb_range=0` for the old behaviour)
- **Wi-Fi power saving stays off:** Steam's developer toggle switched it back on; a timer turns it off again within two minutes, and the NetworkManager hook now uses the same code (it ignored the setting and missed the IW620's `mlan` interface name) (`WIFI_POWERSAVE=1` in `/etc/ps5-bazzite-deck/perf.conf` leaves it alone)
- **First-start message:** while Steam sets itself up behind the blank screen with the blinking cursor, the console now says so and asks not to power off (idea: ObsessiveRug, kishy)
- **"Generic display, 1080p only" after leaving the desktop:** a short or invalid EDID announcement from the HDMI chip (around display power changes) no longer replaces the stored EDID; the previous one is kept and the event is logged (NikySantoro)
- **Fewer hangs on the blinking cursor when switching between Game Mode and the desktop** (the HDMI side; the GPU side is the GFX1013 fix below): the console re-arm no longer blanks the screen (under the console lock, for seconds) while a session switch is still settling, and the same TV re-announcing itself no longer fires a hotplug that made the starting session reprobe and modeset in a loop (`hdmi.rearm_quiet_ms`)
- **Verde consoles:** IT content and content type "game" in the AVI InfoFrame, as FLAVA3 already sends, so TVs choose their game/low-latency mode (the full-RGB-range fix isn't needed there: Verde already declares full range, which also confirms the FLAVA3 fix)
- **Warm reboot, IW620 consoles:** Bluetooth now survives a warm reboot as well (two of two in testing on v1.4.1, Wi-Fi too). Most likely because the Linux-only Bluetooth address, which sent a vendor command to the combo chip at every boot, is off there since v1.4.1; the warm-reboot note no longer says Bluetooth stays off
- Safety net for the EDID binding: if amdgpu can't tell which connector is the HDMI bridge (PR #57 was tested on fat consoles only), every DisplayPort connector gets the bridge's EDID as before, instead of none ("generic display")
- GFX1013 fixes from the same PR (GFXOFF around compute idle, MMIO PASID TLB flushes instead of the KIQ): aimed at the GPU page faults + `ring gfx_0.0.0 timeout` when a session starts or closes; they did not fix it (still there on v1.5.0, gamescope-xwm, ObsessiveRug's report), being investigated, Salina xHCI 1 ms poll (needed for Sense controllers), threaded NAPI on the Ethernet, Bluetooth HIDP frames sent non-blocking, ICC teardown hardening
- **CPU boost and a fan target by default** (`ps5-perf`; requested by moonman7299, values after NotHavocc's ps5-hwcon-plugin): the CPU's boost clocks are allowed (up to 3.5 GHz under load, the governor still idles down; nothing is locked at max), and the fan aims for 85 °C (the console's own target is saved the first time and shown by `ps5-perf status`). `ps5-perf off` restores both, `/etc/ps5-bazzite-deck/perf.conf` changes the values

## [v1.4.1] – 2026-10-<DD>
- **IW620 (Marvell) consoles: the Linux-only Bluetooth address is off by default** (`ps5-bt-address on` enables it). It sends a vendor command to the Wi-Fi/Bluetooth combo chip at every boot and is the suspect for v1.4.0's "Wi-Fi sees networks but won't connect" on those consoles (three reports; MediaTek consoles, which use the kernel's own path, were fine). Back on by default once the cause is confirmed
- **USB never sleeps by default** (`usbcore.autosuspend=-1` in `cmdline.txt`, added by the image build and the updater): the USB drive, controllers and dongles no longer get suspended; it was the most-recommended fix for disconnects and freezes
- **Wi-Fi power saving off** whenever a Wi-Fi interface comes up (NetworkManager dispatcher): Steam's developer setting can switch it on per connection, and with it on the IW620 throttles to ~100 Mbit/s instead of ~700 (thelonlybud)
- **Wi-Fi repaired automatically after a warm reboot** (IW620 consoles): the chip's firmware keeps running across a warm reboot and the Wi-Fi driver failed to start ("WLAN FW already running" → "Firmware Init Failed"). `ps5-wifi-repair` runs after warm reboots only, and only when that happened: unload `moal`, reset the Wi-Fi PCI function, load `moal` (fresh firmware). Bluetooth on the same chip drops off USB in a warm reboot and can't be brought back that way (port re-enumeration times out); it needs a cold start, and `ps5-warm-reboot on` says so on IW620 consoles
- Warm reboot: the final step is now systemd's own kexec action (`SuccessAction=kexec-force`) instead of `systemctl --force kexec`, which failed at that point ("Transport endpoint is not connected") and only worked through the fallback; documented as experimental (garbled picture after it on some consoles, IW620 Wi-Fi/Bluetooth sometimes off until a cold start)

## [v1.4.0] – 2026-10-<DD>
> Pulled after release and removed from the releases page: on IW620 consoles Wi-Fi saw networks but wouldn't connect. Everything below is in v1.4.1.
- **One DualSense for the PS5 and Linux** (PR #9 by Dasloh): `ps5-bt-addr.service` gives the IW620 Bluetooth chip a Linux-only address at boot (`80:..` becomes `82:..`), so a DualSense keeps its PS5 pairing on one profile and the Linux pairing on another. Original PS5 (IW620) only. Existing Linux pairings must be paired once again after the update. See `docs/dualsense-profiles.md`
- **Controllers reconnect by themselves**: `ps5-bt-connectable.service` makes the Bluetooth adapter accept incoming connections (it started as non-connectable); it runs every time the adapter appears and after every bluetoothd start
- The Linux-only address also reaches the kernel and bluetoothd (the adapter is re-initialised with bluetoothd stopped), and is set again whenever the adapter re-appears, so pairings are always stored under the same address
- **DualSense pairing that sticks** (lessons from the ps5-cachyos-setup project): BlueZ `JustWorksRepairing = always` (the pad re-pairs ~1.5 s after pairing; the default rejects that and deletes the bond) and `PairableTimeout = 0` (with pairable off at pair time the bond is thrown away); `hidp` is loaded at boot (the first connection after a boot could drop); `ps5-bt-revive.service` reloads `btusb` if the Bluetooth adapter hangs after a warm reboot (missing, or unpowered with command timeouts; a user who switched Bluetooth off is left alone)
- **Full-rate DP link**: the link from the GPU to the HDMI chip runs at full rate for every resolution; no black screens at any resolution in rc1 testing; if training at full rate ever fails, the fixed rate is released for the session and amdgpu chooses by itself again
- **VRR: not yet.** rc1/rc2 drove VRR from the GPU alone: the HDMI chip locks the frame timing. hsgodd then found the chip's own VRR mode in the stock system (Sony's VSync block with VRR values, written after link training, plus 6224=40,0f); with it the picture comes up, but TVs drop the signal ~3.5 s after the chip enters VRR mode, even at a fixed refresh rate, with every combination of ignore-MSA, VTEM metadata guess and FreeSync InfoFrame (vrr-test8). Most likely the VTEM packet's contents are still missing. Parked in the `archive/research-2026-11` tag (test 8 and hsgodd's test 7)
- No new boot options: the HDMI debug log (rc1's `hdmi.log_notify=1`) is a dynamic-debug log now (`dyndbg="file drivers/ps5/hdmi.c +p"`), the full-rate link and VRR have no switches
- In-place update: `FILES` lines can have a third column, the file mode; the update enables the Bluetooth services
- **Sleep (suspend-to-idle)** (ps5-linux-patches PR #4 by Dasloh, applied on top of meower): a short power-button press (or Steam's Sleep) sleeps the console, a short press wakes it; games, network and Bluetooth continue. Kernel config gains `CONFIG_SUSPEND=y` (+ PM_SLEEP etc., `AMD_PMC` off)
- **Warm reboot into Linux, optional** (`ps5-warm-reboot on`; off by default): every reboot (Steam, the desktop, `sudo reboot`) then goes through `reboot.target` → `ps5-kexec-prepare.service` (loads the kernel from the boot partition via `kexec_file_load`, no kexec-tools needed) → `ps5-reboot.service` (kexec when loaded, a normal reboot otherwise). Off by default because the IW620's Wi-Fi/Bluetooth sometimes didn't survive a warm reboot in testing
- No chip resets around warm reboots: rc7 reset the Bluetooth adapter's USB host controller (the Salina xHCI, which doesn't survive a reset/D3 and can carry the system drive) and froze on boot; the Wi-Fi function reset can take the combo chip's Bluetooth with it
- **HDMI CEC** (ps5-linux-patches #53 by Slip, ported to 7.3): the TV remote's keys arrive as an input device, and at boot the PS5 turns the TV on and switches it to itself (one-touch play; `ps5-cec.one_touch_play=0` turns that off)
- **Fix: 4K60 and 120 Hz modes gone on some TVs since v1.3.0** (issue #11): the TV presented its HDMI 1.4 EDID (340 MHz, no 120 Hz, 4K60 only as 4:2:0) after v1.3.0 began starting at 1080p60 without any SCDC traffic. HDMI 2.x sources write SCDC Source Version = 1 after hotplug; the HDMI chip now does that at every picture setup for TVs that talk SCDC (HDMI Forum block, or 4K / 4:2:0-only modes, which an HDMI 2.x TV in its 1.4 fallback still lists)
- **Bluetooth adapter no longer vanishes** (thanks to Dasloh's s2idle findings): the PS5's Bluetooth chips drop off USB once their port is suspended (U3) and only return after a full power-off, and the Salina xHCI's setup doesn't survive D3. A udev rule keeps both out of runtime suspend (`99-ps5-usb-power.rules`)
- **Same IP after a reflash**: NetworkManager identifies to DHCP by the hardware address (`ipv4.dhcp-client-id=mac`) instead of a client id derived from the machine id, so a fresh image no longer looks like a new device to the router
- **Sleep without a flickering TV**: when the output goes down (sleep, display off) the HDMI chip is muted and HDR is left (SDR InfoFrame), instead of HDR flickering into a dying signal (rc4 report)
- **One DualSense for the PS5 and Linux also on MediaTek consoles**: the kernel sets the MediaTek chip's address itself (`btmgmt public-addr`, powered off), no vendor command needed; the service picks the method by chip
- **GPU load and temperature in the Steam performance overlay** (and MangoHud): `gpu_busy_percent` from the GFX busy time meower already measures for its GPU frequency driver, and a GPU temperature sensor that reports the chip's one temperature (CPU and GPU are one die; the same reading as the CPU's Tctl). The power-management firmware that normally provides both belongs to Sony's firmware

## [v1.3.1] – 2026-10-<DD>
- **Fix: 1440p picture a few lines too high** with displays whose 1440p timing uses positive vsync (e.g. LG TVs at 1440p120): the HDMI chip expects the standard polarity of both syncs (+hsync, -vsync) and moves the picture by the pulse width otherwise. 1440p timings now get the standard vertical polarity too (horizontal since v1.2.0)
- Same drivers (modules) as v1.3.0; the change is built into the kernel
- Updating: `tools/update-latest.sh`, one command that always installs the latest release (`bash <(curl -fsSL …/tools/update-latest.sh)`)
- README: Ko-fi link, simpler boot-options table, clearer M.2 steps, rmux's loader named

## [v1.3.0] – 2026-10-<DD>
- Based on rmux's current `meower` (baee34d): includes the IW620 Bluetooth fixes (our quirks-table and L2CAP fixes, now upstream, plus Maitreya25's interface-recipient control requests: controller initialization and power-on). Our Bluetooth patch is down to the MediaTek part
- **HDR** (ps5-linux-patches #49, ported to 7.3): HDR10 at 1080p60 and 4K60, sent as 12-bit YCbCr 4:2:2, on consoles whose HDMI chip supports it. Unlike upstream it doesn't depend on the requested colour depth. RGB output stays at 8 bits on every console
- **Standard display modes**: 1080p60, 1080p120, 1440p60, 4K60 and 1440p120 (where the HDMI chip supports it) in their standard timings, offered whenever the display's limits allow them, even if its EDID doesn't list them. **New displays start at 1080p60**; a higher mode picked in Game Mode or the desktop is remembered, no `cmdline.txt` change needed
- **The desktop only offers what the PS5 can output**: "max bpc" is 8 only (no 10-bit choice), and without the "scaling mode" property compositors don't add generated resolutions
- ps5-linux-patches #50 (clear SCDC scrambling when leaving 4K60, replaces our own fix) and #54 (back off HDMI hotplug retries while link training fails), ported to 7.3
- `hdmi.log_notify=1` (off by default): logs every HDMI chip notification and picture setup, for black-screen reports

## [v1.2.0] – 2026-10-<DD>
- **Fix: rainbow / "disco" colours** (posterized contours in gradients, with TVs that offer deep colour): the output is capped at 8 bits per colour in the DRM core on the PS5. The graphics driver defaulted "max bpc" to 16 and compositors may ask for 10; the HDMI bridges show deeper colour as contours. Also stops the TV re-announcing itself every few seconds on such setups
- **Fix: "timing issue" / no picture after switching displays**: the wake-up re-arm (#46) now only runs when the same display re-announces itself (EDID checksum); a different display is set up by the hotplug path and the desktop with its own mode
- **Fix: link training errors at boot**: the chip's "picture up" notification now cancels a pending re-arm, so it no longer fires during the first picture setup
- **Fix: 1440p picture shifted 32 px to the left** with displays whose 1440p timing uses negative hsync (e.g. Elgato 4K X): the bridge places the picture relative to the rising edge of hsync, so 1440p timings now get the standard sync shape and positive polarity
- Same drivers (modules) as v1.1.1; the kernel changes are all built in

## [v1.1.1] – 2026-10-<DD>
- **40-CU unlock opt-in again** (`amdgpu.ps5_cu_unlock=3` no longer in the image's `cmdline.txt`): on some consoles the 4 extra compute units cause artifacts (green dots), a purple tint or crashes (silicon lottery). The in-place update switches it off once for installs coming from v1.1.0; after that, a setting you add yourself is kept across updates. README: section "40 GPU compute units (optional)" with on/off commands
- Same kernel and drivers as v1.1.0

## [v1.1.0] – 2026-10-<DD>
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

## [v1.0.7] – 2026-10-<DD>
- **Fix: black screen at boot on some TVs.** The two event sequences that v1.0.6 enabled (from ps5-linux-patches #43) are off again: on some TVs they made the chip re-announce the TV during the first picture setup, link training failed and the screen stayed black.
- **Fix: 1440p picture shifted.** The chip places a 1440p picture as if the signal had the back porches of the standard 1440p60 reduced-blanking timing (80 px / 33 lines); other 1440p timings (the desktop's generated 1440p60, a TV's 1440p120) were shifted right or down. The sync pulses are now moved so the back porches match; resolution, totals and refresh rate are unchanged
- SSH is enabled by default (user `ps5`, password `ps5`; change it with `passwd`)
- Kernel: `CONFIG_MODULE_ALLOW_BTF_MISMATCH=y`, so kernel-only hotfixes keep loading the release's modules

## [v1.0.6] – 2026-10-<DD>
- **HDMI: picture comes back when the display wakes up** (display already on at boot, woken from standby, power-cycled): the HDMI bridge is set up again after the display re-announces itself. ps5-linux-patches #46 (rdmrocha), merged by hand onto #43. Off switch: add `hdmi.rearm=0` to `cmdline.txt`
- **HDMI hotplug**: switching to a different display or re-plugging the cable is detected, and the picture and HDMI audio are set up again. ps5-linux-patches #43, ported to the 7.3 display code
- **Fix: no signal after switching down from 4K** (e.g. to 1080p or 1080p120): 4K60 turns HDMI 2.0 scrambling on in the TV, and it was never turned off again for lower modes. Now it is. 1080p120 works
- **1440p120, experimental and opt-in**: add `hdmi.allow_1440p120=1` to `cmdline.txt`. Uses the 4K60 high-bandwidth setup
- **In-place updates**: an update bundle (`tools/update.sh`) brings earlier installs to the new version without reflashing; kernel, modules and settings, with a backup

## [v1.0.5] – 2026-10-<DD>
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
