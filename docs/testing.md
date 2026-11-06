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
release through Steam's Beta channel and one Legacy in-place update.

## Release checks

| Area | Check |
| --- | --- |
| Install | Image extracted with 7-Zip, `.img` checksum matches, flashed with balenaEtcher, first start reaches the desktop |
| Update | Beta channel or `bootc switch` reaches the release; `sudo bootc rollback` and a power off bring the previous one back |
| Display | Desktop and Game Mode at the display's best mode; 4K120 over FRL where offered; VRR in a game; `hdmi.modes_100hz=1` modes on 100 Hz displays |
| GPU | A D3D12 game (Dragon's Dogma 2), a D3D9 game, a Vulkan game for 30 minutes each; `active_cu_number` 36, or 60 on a Pro from the second start; on a Pro, FSR4 INT8 through OptiScaler, with and without `RADV_VIOLA_ML=0` |
| Memory | `vram.txt` 6 GB in the log (`VRAM: 6144M`); a browser and a game together without OOM |
| Fan | Idle, game, sleep and shutdown without ramps; `target_temp` 80; PS5 Hardware Control curve applies and survives a restart |
| Input | DualSense pairs once and reconnects after switching between the PS5 OS and Linux; sleep and wake |
| Network | Wi-Fi connects and survives sleep; Ethernet; a warm reboot (`ps5-warm-reboot on`) keeps Wi-Fi and Bluetooth |
| Session | Starts in Desktop Mode; Steam's setting switches the default to Game Mode; Switch to Desktop and back; Steam's own startup video |
| M.2 | `ps5-m2-install`, start from the M.2, `--back` |

## Starting without a USB drive (in progress)

The loader also looks for its files in `/data/PS5/Linux/` on the console's own storage, after the USB drives
(`loader/patches/0003`), so a USB drive that has them always wins. Plan: the loader starts a fixed kernel and initrd
from there, whose initrd mounts the M.2 and kexecs the system's current boot entry; nothing else needs the USB drive.

First test, loader only, on a console whose system is on the M.2 (`ps5-m2-install`):

1. Over FTP, create `/data/PS5/Linux/` and copy `bzImage`, `initrd.img`, `cmdline.txt` and `vram.txt` from the USB
   drive's boot partition into it.
2. Unplug the USB drive and start with the test loader.
3. Report: does Linux start, and how far (desktop, emergency shell, waiting for a device), a photo of where it stops,
   `/data/linuxdebug/loader.log` over FTP, and on a Pro whether `/data/PS5/Linux/lib/firmware/amdgpu/` was created.
4. Plug the USB drive back in; it is used again from the next start. The copies go stale after the next update.
