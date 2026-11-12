# Test matrix

Every pre-release needs one tester per row of the hardware table, and each of them runs the release checks. A result is
`ps5-report`'s SUMMARY line plus pass or fail per check, posted in the pre-release's Discord thread.

## Hardware

| Slot | Model | HDMI chip | Wi-Fi/Bluetooth | Firmware | Boot drive | Display |
| --- | --- | --- | --- | --- | --- | --- |
| A | Original PS5 | FLAVA3 | IW620 | 3.xx–7.xx | USB SSD | HDMI 2.1 TV (4K120, VRR) |
| B | Original PS5 | FLAVA3 | IW620 | 10.xx–13.xx | M.2 | 1440p monitor (100/120 Hz) |
| C | Original PS5 (late) | VERDE | IW620 or MediaTek | any | USB stick | 4K60 TV |
| D | Slim | FLAVA3 | MediaTek MT7961 | 11.xx–13.xx | USB SSD | HDMI 2.1 TV |
| E | Slim | VERDE | MediaTek MT7961 | any | M.2 | 1080p monitor |
| F | Pro | FLAVA3 | MediaTek MT7925 | 11.xx or 12.xx | USB SSD | HDMI 2.1 TV |
| G | Pro | FLAVA3 | MediaTek MT7925 | 13.20–13.60 | M.2 | 4K60 TV or monitor |

Each slot covers one fresh bootc install from the disk image, and between them at least one update from the previous
release through Steam's Beta channel (or `sudo bootc upgrade`).

## Release checks

| Area | Check |
| --- | --- |
| Install | Image extracted with 7-Zip, `.img` checksum matches, flashed with balenaEtcher, first start reaches the desktop |
| Update | Beta channel or `bootc switch` reaches the release; `sudo bootc rollback` and a power off bring the previous one back; with `ps5-warm-reboot on`, a restart after the rollback goes through the PS5 system instead of straight back into Linux |
| Display | Desktop and Game Mode at the display's best mode; 4K120 over FRL where offered; VRR in a game; 100 Hz modes on 100 Hz displays; VERDE 1440p100/120; on FLAVA3 a non-standard EDID mode (e.g. 1080p144, ultrawide) |
| GPU | A D3D12 game (Dragon's Dogma 2), a D3D9 game, a Vulkan game for 30 minutes each; `active_cu_number` 36, or 60 on a Pro; on a Pro, FSR4 INT8 through OptiScaler, with and without `RADV_VIOLA_ML=0` |
| Memory | `vram.txt` 6 GB in the log (`VRAM: 6144M`); a browser and a game together without OOM |
| Fan | Idle, game, sleep and shutdown without ramps or cycling; `pwm1_enable` 3 after boot; PS5 Hardware Control curve, full speed and Thermal Guard apply, and the mode survives sleep; the PS5 OS fan behaves as before after a Linux session |
| Input | DualSense pairs once and reconnects after switching between the PS5 OS and Linux; sleep and wake |
| Network | Wi-Fi connects and survives sleep; a hidden network; Ethernet; `firewall-cmd --state` says `running`; a warm reboot (`ps5-warm-reboot on`) keeps Wi-Fi and Bluetooth |
| Session | Starts in Desktop Mode; Steam's setting switches the default to Game Mode; Switch to Desktop and back; Steam's own startup video when Game Mode starts; Steam's update check finds nothing |
| M.2 | `ps5-m2-install`, start from the M.2, `--back` |

## Display switches

Four parts of the display code that rmux's tree doesn't have, each with a switch, on by default. Turn one off at a time, at runtime: `echo 0 | sudo tee /sys/module/hdmi/parameters/<switch>` (`ps5-report` shows their state), then do what it is for and note whether anything changes:

| Switch | What it does | Test with it off |
|---|---|---|
| `rearm` | sets the picture up again when the same display re-announces itself | TV off and on, switch the TV's input away and back |
| `edid_keep` | keeps the previous EDID when an announced one is invalid | TV power cycles; modes after that (`ps5-report`, Display) |
| `scdc_writes` | writes SCDC Source Version and TMDS_Config to every SCDC sink | a mode below 4K60 (1080p, 1440p) and the modes the TV offers after a cold start |
| `sleep_mute` | stays muted and leaves HDR when the output goes down | sleep and wake, screen blanking on the desktop, with and without HDR |

Report per switch: console, HDMI chip, TV model, and "no difference" or what broke.

## PS5 pairings in Linux

With a DualSense paired in the PS5 system and the loader of the release:
- Slim (Linux-only address off by default): the controller connects in Linux without pairing, and in the PS5 system afterwards; `journalctl -b -u ps5-bt-import` reports the pairings.
- Original PS5 and Pro with the Linux-only address on (default): the import is skipped, `ps5-bt-sync.json` is gone from the boot partition, existing Linux pairings work.
- After `ps5-bt-address off` and a restart: as on the Slim.

DirectMesh (original PS5 and Slim): a D3D12 game that needs Mesh shaders, with `ps5-directmesh %command%` as its Steam
launch option; `ps5-directmesh vulkaninfo | grep -i mesh_shader` lists `VK_EXT_mesh_shader`, and without the launch option
the game and `vulkaninfo` behave as before. A hang with it: `sudo dmesg | grep -iE "amdgpu|ring|timeout" | tail -20`.

What the loader dumps reaches Linux through the initrd (`loader/patches/0005`): `ps5-report` lists it under Wi-Fi as
"from the loader via the initrd (/run/ps5)", the Wi-Fi firmware and, until it is imported, `ps5-bt-sync.json`. A PS5 Pro
shows 60 compute units on the first start after installing or updating.

## Starting without a USB drive (in progress)

The loader also looks for its files in `/data/PS5/Linux/` on the console's own storage, after the USB drives
(`loader/patches/0003`), so a USB drive that has them always wins. Plan: the loader starts a fixed kernel and initrd
from there, whose initrd mounts the M.2 and kexecs the system's current boot entry; nothing else needs the USB drive.

Test 1, loader only, on a bootc console whose system is on the M.2 (`ps5-m2-install`), done 2026-11-06 on an
original PS5 (IW620): the loader read all four files from `/data/PS5/Linux/` and Linux started from the M.2, then
stopped in emergency mode, because `/boot` is still on the USB drive.

Test 2, `/boot` on the M.2 as well:

1. Start from the USB drive as usual and run `sudo ps5-m2-install --boot`. It copies `/boot` onto the M.2, drops the
   USB `/boot` from fstab (ostree then bind-mounts the M.2's own) and makes the boot partition optional.
2. Power off, start with the loader and the USB drive: the system starts as before, `findmnt /boot` shows the M.2.
3. Copy `bzImage`, `initrd.img`, `cmdline.txt` and `vram.txt` from the boot partition to `/data/PS5/Linux/` again
   (the ones from test 1 still match if nothing was updated since).
4. Unplug the USB drive and start with the test loader. Report how far it gets, `/data/linuxdebug/loader.log`, and
   from the next start with the USB drive `journalctl -b -1 -p warning --no-pager | head -80`.
5. The `/data` copies go stale with the next update; with the USB drive plugged in, updates and starts work as before.

From v2.13 the loader also hands Linux the Wi-Fi firmware, the pairing export and the PS5 Pro GPU firmware in the initrd,
so a start from `/data/PS5/Linux/` gets them without the boot partition: check Wi-Fi, a DualSense paired in the PS5
system, and on a Pro `active_cu_number 60`.
