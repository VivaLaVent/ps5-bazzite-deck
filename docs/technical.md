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
Full write-up: [docs/game-mode-fix.md](docs/game-mode-fix.md).

## What's in this repo

```
build.sh                               one-shot build: clone builder, apply fixes, build, post-build, compress
patches/ps5-iw620-kernel73-compat.patch Wi-Fi driver (NXP IW620): kernel 7.3 API changes (applied to the out-of-tree driver)
patches/ps5-bluetooth.patch            Bluetooth: IW620 quirks table fix, MediaTek bulk-OUT endpoint, L2CAP defer security
patches/ps5-hdmi-rearm-pr46.patch      HDMI: picture back when the same display wakes up (upstream PR #46, rdmrocha)
patches/ps5-hdmi-output-fixes.patch    HDMI: scrambling off below 340 MHz, no FLAVA3 event sequences, hotplug work queue, re-arm only for the same display, 8-bit colour cap
patches/ps5-hdmi-modes.patch           HDMI: 1440p120, 1440p60, 1440p sync shape/polarity, skip 4:2:0-only modes
files/                                 files baked into the image: NetworkManager stable MAC, MediaTek BT udev/modprobe,
                                       boot ordering-cycle fix for ps5-stage-firmware.service,
                                       IW620 Linux-only Bluetooth address (ps5-bt-addr + its service)
docs/game-mode-fix.md                  how the Game Mode problem was found and fixed
docs/dualsense-profiles.md             one DualSense for the PS5 and Linux (ps5-bt-addr)
docs/release-template.md               release notes of the current release
CHANGELOG.md
```

`build.sh` changes the upstream image builder (all recorded in `local-changes.diff` in each release):
mounts the patches directory into the kernel build so the VCN firmware is found, applies the Wi-Fi driver
patches (kernel 7.2/7.3 compat, RTNL, HE/TX) with objtool enabled, and sets `lsm=…,bpf` in `cmdline.txt`.
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

