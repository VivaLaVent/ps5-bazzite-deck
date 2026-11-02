# Technical notes

For people who want to know how the image is made or build it themselves. Users don't need any of this.

## Why Bazzite Deck never worked on the PS5

It was never the display or gamescope. Bazzite's Game Mode session launches Steam through the
`cardwired` service, which loads an eBPF program and therefore needs two kernel features that the
PS5 kernel configs don't enable:

1. **The BPF LSM.** `CONFIG_BPF_LSM=y` is set, but `bpf` is missing from `CONFIG_LSM`, so it never
   activates. (`lsm=landlock,lockdown,yama,integrity,apparmor,bpf` on the kernel command line also works.)
2. **Kernel BTF.** The 7.3 patch set has `CONFIG_DEBUG_INFO_BTF` off, so `/sys/kernel/btf/vmlinux`
   doesn't exist.

Without them `cardwired` crash-loops (`CardwireEbpfError(LSMNotEnabled)` / `error parsing
/sys/kernel/btf/vmlinux`), the session script kills gamescope one second after it starts, and after
five attempts Bazzite drops you to the desktop. Both are one-line config changes, applied in `build.sh`.

## What's in this repo

```
build.sh                               one-shot build: clone builder, apply fixes, build, post-build, compress
patches/ps5-iw620-kernel73-compat.patch Wi-Fi driver (NXP IW620): kernel 7.3 API changes (applied to the out-of-tree driver)
patches/ps5-bluetooth.patch            Bluetooth: IW620 quirks table fix, MediaTek bulk-OUT endpoint, L2CAP defer security
patches/ps5-hdmi-rearm-pr46.patch      HDMI: picture back when the same display wakes up (upstream PR #46, rdmrocha)
patches/ps5-hdmi-output-fixes.patch    HDMI: scrambling off below 340 MHz, no FLAVA3 event sequences, hotplug work queue, re-arm only for the same display, 8-bit colour cap
patches/ps5-hdmi-modes.patch           HDMI: 1440p120, 1440p60, 1440p sync shape/polarity, skip 4:2:0-only modes
files/                                 files baked into the image: NetworkManager stable MAC, MediaTek BT udev/modprobe,
                                       boot ordering-cycle fix for ps5-stage-firmware.service
CHANGELOG.md
```

`build.sh` changes the upstream image builder (all recorded in `local-changes.diff` in each release):
mounts the patches directory into the kernel build so the VCN firmware is found, applies the Wi-Fi driver
patches (kernel 7.2/7.3 compat, RTNL, HE/TX) with objtool enabled, and sets `CONFIG_LSM=…,bpf` in the kernel config (before v1.5.1 also `lsm=…` in `cmdline.txt`).
It then builds Linux 7.3 with rmuxnet's 7.3 PS5 patches plus the patches above, `bpf` LSM + BTF +
`CONFIG_MT7921E=m`, bakes the files from `files/` into the image, and produces the release files.

### Building it yourself

Linux or WSL with Docker and ~60 GB free:
```
git clone https://github.com/VivaLaVent/ps5-bazzite-deck && cd ps5-bazzite-deck
bash build.sh
```
Takes a couple of hours (kernel compile + Bazzite download). Output lands in `~/ps5-build-7.3/output/`.

## Versioning

Releases are tagged `vMAJOR.MINOR.PATCH`:

- **MAJOR** – a different base (new Bazzite major, new kernel series such as 7.4)
- **MINOR** – new features or fixes that change what works (Wi-Fi, Bluetooth, Game Mode, …)
- **PATCH** – fixes and rebuilds with newer upstream patches/firmware

Every release ships a `VERSIONS.md` with the exact pins: Bazzite image digest, kernel tag, patch repo
commits, builder commit and the kernel config changes. `CHANGELOG.md` tracks changes between releases.

Bluetooth services (files/): `ps5-bt-addr` + `ps5-bt-addr.service` give the IW620 a Linux-only address (PR #9 by Dasloh, see docs/dualsense-profiles.md); `ps5-bt-connectable.service` makes the adapter accept incoming connections, so controllers reconnect by themselves.

Bluetooth pairing and recovery (from the ps5-cachyos-setup project's packet traces): `tools/bt-mainconf.sh` sets BlueZ `JustWorksRepairing = always` and `PairableTimeout = 0` in `/etc/bluetooth/main.conf`; `files/ps5-hidp.conf` loads `hidp` at boot; `ps5-bt-revive.service` reloads `btusb` once if hci0 isn't up and powered ~30 s after boot (the IW620's Bluetooth side can hang after a warm reboot). The address and connectable services run again when hci0 re-appears (udev rule).

Warm reboot (files/, opt-in via `ps5-warm-reboot on`, which creates `/etc/ps5-bazzite-deck/warm-reboot`, the condition of `ps5-kexec-prepare.service`): `ps5-kexec` loads bzImage + initrd.img + cmdline.txt from the boot partition with `kexec_file_load` (loaded by `ps5-kexec-prepare.service`, which the overridden `reboot.target` pulls in before `umount.target`, so only for reboots and never for poweroff; skipped when `/run/ps5-reboot-to-ps5` exists); `reboot.target` also requires `ps5-reboot.service`, which runs `systemctl --force kexec` when a kernel is loaded and `systemctl --force reboot` otherwise; systemd executes `/usr/sbin/kexec -e` at the end, which is `kexec-shim` (→ `ps5-kexec exec`, the `reboot(LINUX_REBOOT_CMD_KEXEC)` system call) unless kexec-tools is installed. Sleep: ps5-linux-patches PR #4 (Dasloh) applied to the pinned patch set in build.sh.

Upstreaming: `tools/upstream-pr.sh "<title>" patches/x.patch … [--submit]` regenerates rmux's `linux.patch` (a `git diff` of the kernel tree, 12-char abbrev, reproduced byte for byte) from v7.3 + upstream + our patch, so the PR's diff is only the change itself; dry run by default, `--submit` pushes a branch to your fork and opens the PR with the patch header as the description.

Parked (in the `archive/research-2026-11` tag, not applied): `ps5-hdmi-vrr` — VRR via DRR with the FreeSync InfoFrame through the bridge; the bridge doesn't pass a variable frame timing on (v1.4.0-rc2 test).

HDMI CEC: upstream #53 (Slip) ported as `patches/ps5-hdmi-cec-upstream53.patch`: `drivers/ps5/ps5-cec.c` taken as is, the handler hook placed at the end of our `hdmi_notification_handler`, `X86_PS5` selects `CEC_CORE` (built in).

Runtime PM: `files/99-ps5-usb-power.rules` sets `power/control=on` for the IW620 Bluetooth (1286:2059), the MediaTek Bluetooth (0e8d:3603) and the Salina xHCI (104d:9108): the Bluetooth chips drop off USB in U3 until a power-off, and the Salina xHCI's setup doesn't survive D3 (Dasloh).
