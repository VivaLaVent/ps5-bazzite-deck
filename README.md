# PS5 Bazzite Deck

[English](README.md) | [Svenska](README.sv.md)

Turn your PS5 into a Steam console: this is [Bazzite](https://bazzite.gg) in Steam Deck mode, adapted for the
PlayStation 5. It boots straight into **Steam Gaming Mode** (the Steam Deck interface), and a full KDE
desktop is one click away.

It runs from a USB drive, started by **rmux's** [PS5 Linux loader](https://github.com/rmuxwashere/ps5-linux-loader/releases).
Your PS5 itself is not modified. Linux only starts when you run the loader; restart or power off and the PS5 starts
its own system again, with the drive still plugged in.

**Which version:** use the release marked **Latest** on the [releases page](https://github.com/VivaLaVent/ps5-bazzite-deck/releases).
Releases marked **Pre-release** are test builds for testers, even when their number is higher.

**Download:** [Releases](../../releases) · **Help & testing:** [Discord](https://discord.gg/qGcuTgBBYU) · **Support the project:** [Ko-fi](https://ko-fi.com/vivalavent)

## Features and your hardware

One image runs on every supported PS5. What differs is decided by three parts of the console:

| Part | Kinds | How to tell |
|---|---|---|
| **HDMI chip** | FLAVA3 (most consoles), VERDE (some later models) | `ps5-report` (first line), or `sudo dmesg \| grep "HDMI IC Type"` |
| **Wi-Fi/Bluetooth chip** | IW620 (most original PS5s, `1b4b:2b56`), MediaTek MT7961 (most Slims, `14c3:7961`), MediaTek MT7925 (PS5 Pro, `14c3:7925`) | `ps5-report`, or `lspci -nn \| grep -i -e 1b4b -e 14c3` |
| **Model** | PS5 or Slim, PS5 Pro (GPU `1002:13da`) | `ps5-report`, or `lspci -nn \| grep 1002:13da` |

**What differs by HDMI chip**

| | FLAVA3 | VERDE | |
|---|:---:|:---:|---|
| **1440p120** | ✅ | ❌ | |
| **4K120** | ✅ | ❌ | v1.7.2+, HDMI 2.1 TV and cable; from v1.8.5 only offered when the TV can take it, and back to 4K by itself if the link fails |
| **HDR** (1080p60, 4K60) | ✅ | ❌ | Game Mode → Settings → Display |
| **VRR** (displays with HDMI VRR) | ✅ | ❌ | v1.7.1+, every resolution: Game Mode → Settings → Display → Enable VRR. As on the PS5 system, not on monitors that only have FreeSync (from v1.8.6) |

Both chips: 1080p60, 1080p120, 1440p60 and 4K60, when the TV/monitor can do them. Other resolutions (ultrawide,
other refresh rates) aren't offered: the HDMI chip only has setups for these.

**What differs by Wi-Fi/Bluetooth chip**

| | IW620 | MediaTek | |
|---|:---:|:---:|---|
| **One DualSense for PS5 and Linux** (separate pairing profiles) | 🧪 | ✅ | IW620: opt-in with `ps5-bt-address on`. From v1.9.0, restarts then go through the PS5 system instead of warm (the chip doesn't survive a warm restart with it). Without it: one pairing, pair again after using the controller on the PS5 system. MediaTek: always on. See [docs/dualsense-profiles.md](docs/dualsense-profiles.md) |
| **Wi-Fi after a restart straight into Linux** (`ps5-warm-reboot on`) | ⚠️ | ✅ | IW620: repaired automatically; if it's still missing, power off and run the loader |

**PS5 Pro:** supported from v1.8.4, as a first version (GPU with 64 compute units and its own firmware, Wi-Fi,
Bluetooth). After the first start, start Linux with the loader once more: that one uses the Pro's GPU firmware.
Reports welcome in #bazzite-ps5-pro-tests.

## Prerequisites

- A PS5 on a firmware **rmux's** [PS5 Linux loader](https://github.com/rmuxwashere/ps5-linux-loader/releases) supports (see its releases). Tested on firmware 13.60.
- An original PS5, a PS5 Slim or a PS5 Pro (see [Features and your hardware](#features-and-your-hardware)).
- **etaHEN and kstuff off:** they don't work with the Linux loader (freezes, especially when going to sleep).
- A USB drive of **32 GB or more**, ideally an external SSD (much faster than a stick).
- A PC to download and flash the image, and for the first setup a USB keyboard is handy.
- **PS5 settings**, in the normal PS5 menu, before the first start (set them again after a PS5 reset or firmware update):
  - `Settings` → `System` → `Power Saving` → `Features Available in Rest Mode` → `Supply Power to USB Ports`: **Always**.
  - `Settings` → `HDMI` → `Enable HDMI Device Link`: **off**. If it's on, you'll typically get a black screen.

## Install

1. **Download** all `ps5-bazzite-deck-vX.Y.Z.img.7z.00*` files from the latest [release](../../releases)
   into one folder.
2. **Extract** the `.001` file with [7-Zip](https://7-zip.org) (Windows), Keka (macOS) or `7z x` (Linux).
   You get `ps5-bazzite-deck.img`.
3. **Flash** it to the USB drive with [Rufus](https://rufus.ie): select the drive, select the `.img`, click Start.
   This erases the drive.
4. **Plug** the drive into a fast USB port. Every PS5 has fast ports (SuperSpeed, 10 Gbit/s) and one slow port
   (Hi-Speed, the older USB 2.0 speed of 480 Mbit/s). A slow port works, but booting, loading and installing
   games become much slower.
   - **Original PS5:** the two **rear** USB-A ports or the **front USB-C** port. The front USB-A port is the slow one.
   - **PS5 Slim:** the two **rear** USB-A ports. One of the two front USB-C ports is the slow one, so the rear
     ports are the safe choice.

   Use the slow port for a controller or keyboard.
5. **Run the jailbreak and the loader** as described in the loader's instructions. The PS5 goes into rest mode;
   wait until the orange light stops blinking, then press the power button. A **white light** means Linux is booting.
6. **First boot is slow.** The screen can stay black for a few minutes. Let it be.

Already installed? Each release's notes say how to update.

## First boot

- The default password is **`ps5`** (asked for anything that needs admin rights). SSH is on: `ssh ps5@<your PS5's IP>`.
  **Change the password** with `passwd`, since anyone on your network can try `ps5`.
- **After joining Wi-Fi, Steam updates itself** in the background, often behind a blank screen with a blinking cursor
  that looks frozen, for several minutes. Don't power off then: that's the most common reason for a broken first start.
- The first start is at **1080p60**. Pick your resolution in the display settings (Game Mode: Settings → Display); it's remembered.
- Set **RGB range** to **Full**, in both Game Mode and the desktop.

## Boot options (cmdline.txt)
`cmdline.txt` is on the USB drive's small FAT32 partition and must stay **one single line**: add an option at the
end with a space in front of it, or delete it again to undo. Leave the entries that are already there as they are.

| Option | What it does | When to use it |
|---|---|---|
| `amdgpu.force_1080p=1` | Only allows 1080p60 | Black or garbled picture you can't get past, e.g. after picking a resolution your display can't show. Remove it once you've set a working resolution; step by step in [docs/display-recovery.md](docs/display-recovery.md) |
| `usb-storage.quirks=xxxx:yyyy:u` | Turns off UAS for one USB drive (`xxxx:yyyy` from `lsusb`) | USB-C SSDs or enclosures that disconnect, freeze or show I/O errors (many have buggy UAS) |
| `usbc_dp.enable=1` | Switches on the front USB-C port's DisplayPort output (v1.6.1+) | USB-C displays and the PSVR2. Not with your boot drive on the front USB-C port |
| `hdmi.frl_4k120=0` | Never offers 4K at 120 Hz (v1.7.2+) | A TV where 4K120 misbehaves |

To switch off VRR, use Steam's setting (Settings → Display); to keep the TV from following the console at boot,
switch off HDMI-CEC in the TV's settings (SIMPLINK, Anynet+, BRAVIA Sync…).

## 40 GPU compute units

*Original PS5 and Slim only.* The PS5 Pro's 60 compute units are all active already; don't use this on a Pro.

The PS5's GPU has 40 compute units (CUs); Sony ships it with 36 active. The other 4 were switched off at the
factory, partly because on some chips one of them is faulty. That's the **silicon lottery**: on many consoles all
40 work and you get more GPU power, on others the extra units cause green dots and other artifacts, a purple
tint, or crashes. Try it, and switch it back off if you see any of that.

**Switch on** (in a terminal or over SSH), then reboot and run the loader:
```
E=$(for d in /boot/efi /efi; do sudo test -f $d/cmdline.txt && echo $d && break; done); sudo sed -i -e 's/amdgpu\.ps5_cu_unlock=[0-9]*/amdgpu.ps5_cu_unlock=3/' -e '/ps5_cu_unlock/!s/[[:space:]]*$/ amdgpu.ps5_cu_unlock=3/' $E/cmdline.txt && sudo cat $E/cmdline.txt
```
**Check:** `dmesg | grep active_cu_number` shows `40` (36 without it).

**Switch off** again:
```
E=$(for d in /boot/efi /efi; do sudo test -f $d/cmdline.txt && echo $d && break; done); sudo sed -i 's/ *amdgpu\.ps5_cu_unlock=[0-9]*//' $E/cmdline.txt && sudo cat $E/cmdline.txt
```

The setting stays as it is across updates.

## Troubleshooting

**Ask in [Discord](https://discord.gg/qGcuTgBBYU)** (#bazzite-problems), with the report from `ps5-report` (in a
terminal or over SSH). It only reads, and saves one file with your hardware and the relevant logs. Without network,
copy it to the USB drive's FAT32 partition and take it from there on your PC:
`E=$(for d in /boot/efi /efi; do sudo test -f $d/cmdline.txt && echo $d && break; done); sudo cp ~/ps5-report-*.txt $E/`.
Other commands: `ps5-perf` (CPU boost, fan target), `ps5-warm-reboot` (restart straight into Linux, experimental).

- **Console running, no picture** (wrong mode, a mode the TV doesn't take): get in with SSH or a TTY and change the
  mode by command, see [docs/display-recovery.md](docs/display-recovery.md). To report a display problem (VRR, a
  mode, blinking): [docs/display-logs.md](docs/display-logs.md) says what to send.
- **White light but black screen:** HDMI Device Link off (see [Prerequisites](#prerequisites)), another HDMI
  port or TV, HDCP on/off in the PS5 settings; last resort `amdgpu.force_1080p=1` ([boot options](#boot-options-cmdlinetxt)).
- **Black screen, but the PS5 is running:** <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>F2</kbd>, wait 2–3 seconds, then
  <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>F1</kbd> (over SSH: `sudo chvt 2; sleep 3; sudo chvt 1`).
- **Boots back into the PS5 menu:** you pressed the power button before the orange light stopped blinking, or USB
  power in rest mode isn't set to `Always`.
- **Artifacts, green dots or crashes:** switch the [40 compute units](#40-gpu-compute-units) off again; for glitches in one game, launch
  options `RADV_DEBUG=nohiz %command%`.
- **VRR:** no "Enable VRR" means a VERDE console, a display without HDMI VRR (FreeSync-only monitors), or VRR off for that input in the TV. The screen going dark
  for 2 seconds in menus: use VRR per game (quick access menu → Performance). OLED flicker on the desktop: Adaptive
  Sync on **Automatic**, not Always.
- **HEVC video with broken colours or a red screen** (recording, streaming with Sunshine, Moonlight): the PS5's
  video engine gets HEVC P-frames wrong. Use **H.264**, or for encoding HEVC with I-frames only (ffmpeg: `-g 1 -bf 0`;
  much higher bitrate). As a Moonlight client: H.264, or "Force software decoding" for HEVC.
- **Won't boot from an SSD in a USB enclosure:** some enclosures don't work with the loader; try another one.

## Installing to the PS5's internal M.2

The USB drive stays required: the PS5 loader always starts the kernel from its small FAT32
partition. The M.2 holds the system. Install the **same version** on the M.2 as on the USB.
If a step doesn't work for you, tell us in [Discord](https://discord.gg/qGcuTgBBYU).

All steps run on the PS5, booted from the USB, in a terminal (password `ps5`).

1. **Get the tools** ([ps5-linux-tools](https://github.com/ps5-linux/ps5-linux-tools); Bazzite has everything needed to build them).
   If the M.2 isn't prepared for Linux yet, follow their README (`m2_init`) first.
   ```
   git clone https://github.com/ps5-linux/ps5-linux-tools ~/ps5-linux-tools && make -C ~/ps5-linux-tools
   ```

2. **Install.** `m2_install.sh` looks for the boot partition at `/boot/efi`; Bazzite has it at `/efi`, so mount it there too:
   ```
   sudo mkdir -p /boot/efi && (mountpoint -q /boot/efi || sudo mount LABEL=boot /boot/efi)
   cd ~/ps5-linux-tools && sudo ./m2_install.sh --install /path/to/ps5-bazzite-deck.img
   ```
   - Use the extracted `.img`, not the `.7z` files.
   - Keep the `.img` **on the USB system** (e.g. in `~/Downloads`), **not on the M.2**: the M.2 is wiped during the install.
   - Tip: type the command up to `--install ` (with the space), then drag the `.img` from the file manager into the
     terminal to insert its path.
   - **What you'll see:** `Formatting /dev/nvme0n1p1 …`, then `Copying files to M.2...`, and then **nothing for
     10–30 minutes** while it copies the system (there's no progress bar). Wait until it prints `Installation complete.`
   - **It asks for the password and then ends without printing anything:** `/boot/efi` isn't mounted, or it's mounted
     several times (from running a plain `mount` line more than once). Reset it to one mount, then run the install again:
     `while mountpoint -q /boot/efi; do sudo umount /boot/efi; done; sudo mount LABEL=boot /boot/efi`
   - `/dev/nvme0n1p1 not found`: the M.2 isn't prepared for Linux yet, see step 1 (`m2_init`).

3. **Boot from the M.2 from now on:** point `cmdline.txt` at the M.2:
   ```
   E=$(for d in /boot/efi /efi; do sudo test -f $d/cmdline.txt && echo $d && break; done); sudo sed -i 's/root=LABEL=bazzite-deck /root=LABEL=bazzite-deck-m2 /' $E/cmdline.txt && sudo cat $E/cmdline.txt
   ```

4. **Start it:** reboot (`sudo reboot`) and run the loader as usual; it now starts the system on the M.2.
   `cd ~/ps5-linux-tools && sudo ./m2_exec.sh` switches right away without a reboot; if it says `kexec` isn't
   found, just reboot instead.

To go back to the USB system, change `bazzite-deck-m2` back to `bazzite-deck` in `cmdline.txt`.

Notes:
- The first start from the M.2 can show a grey or black screen: reboot once and run the loader again.
- **The USB drive afterwards:** keep its small FAT32 partition (label `boot`): the loader always starts Linux from
  there, and updates put the new kernel there. The big Linux partition on the USB is only a fallback now. You can
  reformat that one for storage (only that partition, not the whole drive), but then you can no longer switch back
  to the USB system via `cmdline.txt`.
- Updating: run the in-place update while booted from the M.2, with the USB drive plugged in. The update script
  finds the USB drive's boot partition by itself: on an M.2 install it is often mounted at `/boot/efi` instead of
  `/efi`, or not at all.
- The commands in this README find `cmdline.txt` themselves (`/boot/efi` or `/efi`). If neither has it, the boot
  partition isn't mounted: edit `cmdline.txt` from your PC instead.
- Stuck in emergency mode when booting the M.2: its `/etc/fstab` may contain a boot-partition line with an empty
  `UUID=`. Replace that line with `LABEL=boot /efi vfat defaults,nofail 0 2` (mount the M.2 from the USB system
  with `sudo mount LABEL=bazzite-deck-m2 /mnt` to edit it).

## Useful plugins

Community-made, not part of the image:

| Plugin | What it does |
|---|---|
| [Decky Loader](https://decky.xyz) | Plugins in Game Mode's quick access menu (the `...` button). Install it from Desktop Mode with the installer on its site; the two below need it |
| [PS5 hardware control](https://github.com/NotHavocc/ps5-hwcon-plugin) (Decky) | Fan target, live temperatures, CPU and GPU governors and clocks, LED presets. It sets the same things as `ps5-perf`: whichever was set last applies. Desktop version: [ps5-hwcon-gui](https://github.com/NotHavocc/ps5-hwcon-gui) |
| [PS5 Bazzite Updater](https://github.com/cmartinespinosa/decky-ps5-bazzite-updater) (Decky) | Shows when a new release is out, its notes, and installs it (the same update as in the release notes), then powers off. Unofficial; full releases only |

## Support the project

This is a hobby project, built and tested in my free time. If it's useful to you, you can support it on
[Ko-fi](https://ko-fi.com/vivalavent). Thank you!

## Credits

- **[ps5-linux](https://github.com/ps5-linux)** (theflow, c0w, resulknad, rmuxnet and contributors) – the PS5 Linux
  loader, kernel patches and image builder this is built on.
- **[rmuxnet](https://github.com/rmuxnet)** – 7.3 PS5 kernel patches, video decoding, the
  [PS5 Linux Guide](https://rmuxnet.gitlab.io/ps5-linux-guide/).
- **[soniciso1](https://github.com/soniciso1)** – loader with firmware 13.60 support.
- **[ps5-linux-mwifiex](https://github.com/ps5-linux/ps5-linux-mwifiex)** contributors – PS5 Wi-Fi driver patches.
- **[WizGery](https://github.com/WizGery/ps5-mediatek-fixes)** – MediaTek Bluetooth patches.
- **[etawen](https://repo.etawen.dev/)** – PS5 package repo and documentation.
- **[Universal Blue / Bazzite](https://github.com/ublue-os/bazzite)** – Bazzite itself.
- **Lawson** – the VRR fix and 4K120 over HDMI 2.1 FRL; **hsgodd** – captures and research on the stock system's
  HDMI setup; **Slip** – HDR, SCDC, CEC and hotplug patches; **Tertium** – USB-C display output; **Dasloh** – sleep.
- **Gilles ([@VivaLaVent](https://github.com/VivaLaVent))** – developer of this image.

Not affiliated with Sony, Valve or Universal Blue. Use at your own risk. Scripts and docs: MIT; patches: GPL-2.0.
