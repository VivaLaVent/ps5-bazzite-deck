#!/bin/bash
# build.sh - one-shot build of the PS5 Bazzite Deck image (kernel 7.3 + VCN + Game Mode + Wi-Fi + MediaTek support).
# Run from the repo root, in WSL/Linux with Docker:   bash build.sh
# Output: output/ps5-bazzite-deck-<RELEASE>.img.7z.001/.002/.003 (+ .sha256, VERSIONS.md, local-changes.diff)
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # this repo
RELEASE="${RELEASE:-$(git -C "$SRC" describe --tags --always 2>/dev/null || echo dev)}"

REPO="$HOME/ps5-build-7.3"            # fresh build directory
OLD="${OLD:-$HOME/ps5-linux-image}"   # previous build dir, only used to reuse its download cache
BUILDER_COMMIT=52db0a4                 # ps5-linux/ps5-linux-image
PATCHES_BRANCH=meower                  # rmuxnet/ps5-linux-patches-1, 7.3 port
KERNEL_TAG=v7.3

[ -d "$REPO" ] && { echo "$REPO already exists. Remove it (rm -rf $REPO) or change REPO at the top of this script."; exit 1; }
for t in git docker 7z sha256sum losetup; do command -v $t >/dev/null || { echo "missing tool: $t"; exit 1; }; done

echo "==> 1. builder ($BUILDER_COMMIT)"
git clone -q https://github.com/ps5-linux/ps5-linux-image "$REPO"
cd "$REPO"
git checkout -q "$BUILDER_COMMIT"
[ -d "$OLD/cache" ] && cp -r "$OLD/cache" cache && echo "    reusing download cache from $OLD/cache"

echo "==> 2. builder fixes"
# 2a. mount patches + extra patches into the kernel build container (both kernel docker runs)
sed -i 's#-v "$KERNEL_SRC":/src \\#-v "$KERNEL_SRC":/src -v "'"$REPO"'/work/ps5-linux-patches":/ps5-linux-patches:ro -v "'"$REPO"'/extra-patches":/extra-patches:ro \\#' build_image.sh
[ "$(grep -c 'extra-patches:ro' build_image.sh)" = 2 ] || { echo "mount edit failed"; exit 1; }
# 2b. Wi-Fi driver: apply kernel72, rtnl and kernel73 patches after the kernel71 one
B=docker/kernel-builder/build.sh
# order as upstream install.sh: 71, 72, rtnl, then our 73 compat, then the HE + TX follow-ups
sed -i '/ps5-iw620-kernel71-compat.patch"$/a git -C "$NXP_MW" apply "$PS5_MW/ps5-iw620-tx-priority.patch"' "$B"
sed -i '/ps5-iw620-kernel71-compat.patch"$/a git -C "$NXP_MW" apply "$PS5_MW/ps5-iw620-tx-min128.patch"' "$B"
sed -i '/ps5-iw620-kernel71-compat.patch"$/a git -C "$NXP_MW" apply "$PS5_MW/ps5-iw620-he.patch"' "$B"
sed -i '/ps5-iw620-kernel71-compat.patch"$/a git -C "$NXP_MW" apply /extra-patches/ps5-iw620-kernel73-compat.patch' "$B"
sed -i '/ps5-iw620-kernel71-compat.patch"$/a git -C "$NXP_MW" apply "$PS5_MW/ps5-iw620-rtnl-bounded-wait.patch"' "$B"
sed -i '/ps5-iw620-kernel71-compat.patch"$/a git -C "$NXP_MW" apply "$PS5_MW/ps5-iw620-kernel72-compat.patch"' "$B"
# keep objtool processing for the out-of-tree driver (mwifiex #10); removes the return-thunk warning at boot
sed -i 's#make -C "$NXP_MW" CONFIG_OBJTOOL= KERNELDIR=/src#make -C "$NXP_MW" PWD="$NXP_MW" KERNELDIR=/src#' "$B"
grep -q kernel73 "$B" && grep -q "ps5-iw620-he.patch" "$B" && ! grep -q "CONFIG_OBJTOOL=" "$B" || { echo "wifi patch edit failed"; exit 1; }
# 2c. Game Mode: bpf LSM on the kernel command line (belt and braces, config has it too)
# video=DP-1:1920x1080@60 is rejected by the kernel on every connector probe ("User-defined mode not supported"); drop it
sed -i 's/ video=DP-1:1920x1080@60//' boot/cmdline.txt
grep -q 'video=' boot/cmdline.txt && { echo 'cmdline edit failed'; exit 1; }
# 2d. kernel 7.3 compat patch for the IW620 Wi-Fi driver (from this repo)
mkdir -p extra-patches
cp "$SRC/patches/ps5-iw620-kernel73-compat.patch" extra-patches/

echo "==> 3. kernel source: $KERNEL_TAG + $PATCHES_BRANCH patches"
mkdir -p work
git clone -q -b "$PATCHES_BRANCH" https://github.com/rmuxnet/ps5-linux-patches-1 work/ps5-linux-patches
git -C work/ps5-linux-patches checkout -q baee34d                                                   # pinned: the commit the patches below were made against; newer meower commits (fan hwmon 883eef9, IW620 LE cf37af5) are carried as our own patches
git -C work/ps5-linux-patches apply "$SRC/patches/ps5-linux-patches-pr4-s2idle.patch"              # suspend-to-idle (sleep), ps5-linux-patches PR #4 by Dasloh (.config + linux.patch)
sed -i 's/^CONFIG_LSM=.*/CONFIG_LSM="landlock,lockdown,yama,integrity,apparmor,bpf"/' work/ps5-linux-patches/.config
sed -i 's/^# CONFIG_DEBUG_INFO_BTF is not set/CONFIG_DEBUG_INFO_BTF=y/' work/ps5-linux-patches/.config
sed -i 's/^CONFIG_USB_AUTOSUSPEND_DELAY=.*/CONFIG_USB_AUTOSUSPEND_DELAY=-1/' work/ps5-linux-patches/.config   # USB never sleeps: the kernel default now, not a cmdline option
sed -i 's/^CONFIG_LOG_BUF_SHIFT=.*/CONFIG_LOG_BUF_SHIFT=20/' work/ps5-linux-patches/.config   # 1 MiB boot log (was 256 KiB): early lines (HDMI chip, Pro firmware) were scrolling out of ps5-report
grep -q '^CONFIG_DEBUG_INFO_BTF=y' work/ps5-linux-patches/.config || echo 'CONFIG_DEBUG_INFO_BTF=y' >> work/ps5-linux-patches/.config
sed -i 's/^# CONFIG_MODULE_ALLOW_BTF_MISMATCH is not set/CONFIG_MODULE_ALLOW_BTF_MISMATCH=y/' work/ps5-linux-patches/.config; grep -q '^CONFIG_MODULE_ALLOW_BTF_MISMATCH=y' work/ps5-linux-patches/.config || echo 'CONFIG_MODULE_ALLOW_BTF_MISMATCH=y' >> work/ps5-linux-patches/.config   # kernel-only hotfixes keep loading the release modules
sed -i 's/^# CONFIG_MT7921E is not set/CONFIG_MT7921E=m/' work/ps5-linux-patches/.config; grep -q '^CONFIG_MT7921E=m' work/ps5-linux-patches/.config || echo 'CONFIG_MT7921E=m' >> work/ps5-linux-patches/.config   # MediaTek MT7921 Wi-Fi (PS5 Slim)
sed -i 's/^CONFIG_PS5_GPUFREQ=.*/# CONFIG_PS5_GPUFREQ is not set/' work/ps5-linux-patches/.config   # rmux's GPU clock driver: replaced by upstream's governor (drivers/ps5/gpufreq.c)
for o in LOGITECH_FF LOGIRUMBLEPAD2_FF LOGIG940_FF LOGIWHEELS_FF; do sed -i "s/^# CONFIG_$o is not set/CONFIG_$o=y/" work/ps5-linux-patches/.config; done   # wheel force feedback, as rmux's meower (36b9828)
git clone -q --branch "$KERNEL_TAG" --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git work/linux73
git -C work/linux73 apply --exclude=Makefile ../ps5-linux-patches/linux.patch
git -C work/linux73 apply "$SRC/patches/ps5-bluetooth.patch"          # MediaTek bulk-OUT endpoint (IW620 + L2CAP fixes are in meower)
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-upstream.patch"      # ps5-linux-patches #49 HDR (FLAVA3), #50 SCDC, #54 hotplug back-off, ported to 7.3
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-rearm-pr46.patch"     # picture back when the same display wakes up (upstream PR #46)
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-output-fixes.patch"   # no FLAVA3 event sequences, re-arm same display only, 8-bit cap (HDR exception)
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-modes.patch"          # standard modes within the display limits, 1080p60 preferred, 1440p sync safety net, no 4:2:0-only
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-debug-log.patch"      # debug log of bridge notifications and picture setups (dynamic debug)
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-link-lock.patch"        # full-rate DP link to the HDMI chip
git -C work/linux73 apply "$SRC/patches/ps5-gpu-overlay.patch"           # GPU load (gpu_busy_percent) and temperature (hwmon) for the Steam overlay / MangoHud
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-cec-upstream53.patch"    # HDMI CEC (TV remote, one-touch play), upstream #53 ported to 7.3
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-sleep-mute.patch"        # mute and leave HDR when the output goes down (sleep)
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-scdc-source-version.patch" # SCDC Source Version at every setup: TVs keep their HDMI 2.x EDID (issue #11)
git -C work/linux73 apply "$SRC/patches/ps5-usbc-dp-pr57.patch"           # USB-C DisplayPort (PSVR2) + GFX1013 fixes, ps5-linux-patches #57 ported to 7.3
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-rgb-full-range.patch"     # AVI: full RGB range (1080p colours), hdmi.rgb_range
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-edid-fallback.patch"     # EDID for all DP connectors if none is bound (PR #57 safety net)
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-edid-keep.patch"         # keep the EDID on a short/invalid announcement ("generic display" after the desktop)
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-verde-game-content.patch" # Verde: IT + content type game in the AVI InfoFrame
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-session-switch.patch"    # no hang on the blinking cursor when switching Game Mode <-> desktop
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-rgb-range-encoding.patch"  # RGB range flag in the right CTA-861 code (v1.5.0-v1.5.2 sent "limited")
git -C work/linux73 apply "$SRC/patches/ps5-usbc-dp-optin.patch"           # USB-C DP off by default (usbc_dp.enable=1): it can reset a boot drive there
git -C work/linux73 apply "$SRC/patches/ps5-fan-hwmon-curve.patch"       # fan hwmon curve control (rmux meower), Kconfig selects HWMON too
git -C work/linux73 apply "$SRC/patches/ps5-vrr.patch"                     # VRR on FLAVA3 (hsgodd, Lawson), switched with Steam's VRR setting
git -C work/linux73 apply "$SRC/patches/ps5-vrr-stock-setup.patch"         # v1.7.1: stock PHY tail + VSync block in every setup (VRR needs them)
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-frl-4k120.patch"         # 4K120 over HDMI 2.1 FRL on FLAVA3 (Lawson), hdmi.frl_4k120=1
git -C work/linux73 apply "$SRC/patches/ps5-vrr-follow-guard.patch"         # VRR: a running follow block stops when a newer setup starts
git -C work/linux73 apply "$SRC/patches/ps5-vrr-min-48.patch"              # VRR never below 48 Hz (PS5 system floor), SPD with the actual range
git -C work/linux73 apply "$SRC/patches/ps5-pro-gpu.patch"                 # PS5 Pro GPU (upstream #58, Borchev), only with the Viola firmware
git -C work/linux73 apply "$SRC/patches/ps5-pro-bluetooth.patch"           # PS5 Pro internal Bluetooth 0e8d:3605 (QuartConz)
git -C work/linux73 apply "$SRC/patches/ps5-pro-no-freqdrivers.patch"      # PS5 Pro: no PS5 CPU/GPU frequency drivers (MP1 busy flood)
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-4k120-guard.patch"        # 4K120 only where it can work, back to 4K60 by itself (after Slip)
git -C work/linux73 apply "$SRC/patches/ps5-vrr-hdmi-only.patch"           # VRR only with HDMI VRR, as on the PS5 system
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-100hz-test.patch"         # 100 Hz modes (test): 1080p100, 1440p100, 4K100
git -C work/linux73 apply "$SRC/patches/ps5-hdmi-scdc-tmds-config.patch"    # SCDC TMDS_Config at every setup (Beyond TV dropping to HDMI 1.4)
git -C work/linux73 apply "$SRC/patches/ps5-pro-upstream66.patch"          # PS5 Pro: upstream #66 (GPU governor, WGP check, 0x13dc, no thermal.c)
git -C work/linux73 apply "$SRC/patches/ps5-vrr-hdmi-range.patch"         # HDMI VRR with an open-ended VRRmax, and the HF-SCDB
git -C work/linux73 apply "$SRC/patches/ps5-pro-gpu-telemetry.patch"      # PS5 Pro: GPU load and metrics with the Viola firmware (after PR #29)
git -C work/linux73 apply "$SRC/patches/ps5-cpufreq-boost.patch"           # CPU boost off really off, cpufreq stats (rmux b465697)
cp work/ps5-linux-patches/.config work/linux73/.config
cp -r work/ps5-linux-patches work/linux73/ps5-linux-patches
grep -E '^CONFIG_LSM=|^CONFIG_DEBUG_INFO_BTF=|^CONFIG_MT7921E=|^CONFIG_MODULE_ALLOW_BTF_MISMATCH=' work/linux73/.config

echo "==> 4. build image (long)"
./build_image.sh --distro bazzite-deck --kernel "$PWD/work/linux73"
IMG=output/ps5-bazzite-deck.img
[ -f "$IMG" ] || { echo "build did not produce $IMG, see build.log"; exit 1; }

echo "==> 5. post-build: cmdline check + Wi-Fi driver option (needs sudo)"
LOOP=$(sudo losetup -fP --show "$IMG")
BOOT=/mnt/ps5boot; ROOT=/mnt/ps5root
sudo mkdir -p "$BOOT" "$ROOT"
cleanup() { sudo umount "$BOOT" "$ROOT" 2>/dev/null || true; sudo losetup -d "$LOOP"; }
trap cleanup EXIT
sudo mount "${LOOP}p2" "$BOOT"      # FAT32 boot
sudo mount "${LOOP}p1" "$ROOT"      # ext4 root
echo "    cmdline: $(cat "$BOOT/cmdline.txt")"
echo "options moal ps_mode=0" | sudo tee "$ROOT/etc/modprobe.d/ps5-iw620.conf" >/dev/null
sudo install -Dm644 "$SRC/files/99-ps5-wifi.conf" "$ROOT/etc/NetworkManager/conf.d/99-ps5-wifi.conf"          # stable MAC during scans, DHCP by MAC
sudo install -Dm644 "$SRC/files/ps5-stage-firmware-no-default-deps.conf" "$ROOT/etc/systemd/system/ps5-stage-firmware.service.d/10-no-default-deps.conf"   # fixes boot ordering cycle (random missing services)
sudo install -Dm644 "$SRC/files/50-ps5-pro-bt-power.rules" "$ROOT/etc/udev/rules.d/50-ps5-pro-bt-power.rules"     # PS5 Pro BT: no USB autosuspend (else the Salina xHCI dies)
sudo install -Dm644 "$SRC/files/99-ps5-bt-phantom.rules" "$ROOT/etc/udev/rules.d/99-ps5-bt-phantom.rules"      # MediaTek BT: phantom interfaces, no autosuspend
sudo install -Dm644 "$SRC/files/btusb-ps5.conf" "$ROOT/etc/modprobe.d/btusb-ps5.conf"
sudo install -Dm755 "$SRC/files/ps5-bt-addr" "$ROOT/usr/local/sbin/ps5-bt-addr"                                 # IW620: Linux-only BT address, DualSense keeps PS5 + Linux profiles (PR #9, Dasloh)
sudo install -Dm644 "$SRC/files/ps5-bt-addr.service" "$ROOT/etc/systemd/system/ps5-bt-addr.service"
sudo install -Dm755 "$SRC/files/ps5-bt-pro-addr" "$ROOT/usr/local/sbin/ps5-bt-pro-addr"                         # PS5 Pro: apply its volatile Linux-only address after Bluetooth is powered
sudo install -Dm644 "$SRC/files/ps5-bt-pro-addr.service" "$ROOT/etc/systemd/system/ps5-bt-pro-addr.service"
sudo install -Dm644 "$SRC/files/ps5-bt-connectable.service" "$ROOT/etc/systemd/system/ps5-bt-connectable.service"   # adapter accepts incoming connections (controllers reconnect)
sudo install -Dm644 "$SRC/files/99-ps5-bt-services.rules" "$ROOT/etc/udev/rules.d/99-ps5-bt-services.rules"   # both services every time the adapter appears
sudo mkdir -p "$ROOT/etc/systemd/system/bluetooth.target.wants" && for u in ps5-bt-addr ps5-bt-connectable; do sudo ln -sf /etc/systemd/system/$u.service "$ROOT/etc/systemd/system/bluetooth.target.wants/$u.service"; done
sudo mkdir -p "$ROOT/etc/systemd/system/multi-user.target.wants" && sudo ln -sf /etc/systemd/system/ps5-bt-pro-addr.service "$ROOT/etc/systemd/system/multi-user.target.wants/ps5-bt-pro-addr.service"
sudo install -Dm755 "$SRC/files/ps5-bt-revive" "$ROOT/usr/local/sbin/ps5-bt-revive"                             # revive a Bluetooth adapter that hangs after a warm reboot
sudo install -Dm644 "$SRC/files/ps5-bt-revive.service" "$ROOT/etc/systemd/system/ps5-bt-revive.service"
sudo mkdir -p "$ROOT/etc/systemd/system/multi-user.target.wants" && sudo ln -sf /etc/systemd/system/ps5-bt-revive.service "$ROOT/etc/systemd/system/multi-user.target.wants/ps5-bt-revive.service"
sudo install -Dm644 "$SRC/files/ps5-hidp.conf" "$ROOT/etc/modules-load.d/ps5-hidp.conf"                        # load hidp at boot (first controller connection)
sudo bash "$SRC/tools/bt-mainconf.sh" "$ROOT/etc/bluetooth/main.conf"                                         # DualSense pairing: JustWorksRepairing = always, PairableTimeout = 0
sudo install -Dm755 "$SRC/files/ps5-kexec" "$ROOT/usr/local/sbin/ps5-kexec"                                   # warm reboot into Linux (kexec_file_load, no kexec-tools needed)
sudo install -Dm755 "$SRC/files/ps5-reboot-to-ps5" "$ROOT/usr/local/sbin/ps5-reboot-to-ps5"                     # ...and the way back to the PS5 system
sudo install -Dm755 "$SRC/files/ps5-warm-reboot" "$ROOT/usr/local/sbin/ps5-warm-reboot"                       # warm reboot: off by default, "ps5-warm-reboot on"
sudo install -Dm755 "$SRC/files/ps5-bt-address" "$ROOT/usr/local/sbin/ps5-bt-address"                         # IW620: Linux-only BT address, opt-in
sudo install -Dm755 "$SRC/tools/ps5-report.sh" "$ROOT/usr/local/bin/ps5-report"                            # bug reports: ps5-report
sudo install -Dm755 "$SRC/tools/vrr-report.sh" "$ROOT/usr/local/bin/vrr-report"                              # VRR test results: vrr-report
sudo install -Dm755 "$SRC/files/ps5-perf" "$ROOT/usr/local/sbin/ps5-perf"                                     # CPU boost + fan target, default on
sudo install -Dm644 "$SRC/files/ps5-perf.service" "$ROOT/etc/systemd/system/ps5-perf.service"
sudo install -Dm755 "$SRC/files/ps5-stage-viola-fw" "$ROOT/usr/local/sbin/ps5-stage-viola-fw"                   # PS5 Pro: Viola GPU firmware into the initrd
sudo install -Dm644 "$SRC/files/ps5-stage-viola-fw.service" "$ROOT/etc/systemd/system/ps5-stage-viola-fw.service"
sudo install -Dm644 "$SRC/files/ps5-wifi-powersave.service" "$ROOT/etc/systemd/system/ps5-wifi-powersave.service"
sudo install -Dm644 "$SRC/files/ps5-wifi-powersave.timer" "$ROOT/etc/systemd/system/ps5-wifi-powersave.timer"
sudo mkdir -p "$ROOT/etc/systemd/system/timers.target.wants" && sudo ln -sf /etc/systemd/system/ps5-wifi-powersave.timer "$ROOT/etc/systemd/system/timers.target.wants/ps5-wifi-powersave.timer"
sudo ln -sf /etc/systemd/system/ps5-perf.service "$ROOT/etc/systemd/system/multi-user.target.wants/ps5-perf.service"
sudo ln -sf /etc/systemd/system/ps5-stage-viola-fw.service "$ROOT/etc/systemd/system/multi-user.target.wants/ps5-stage-viola-fw.service"
# Bazzite's ostree-only services fail at every boot on this non-ostree image: masked (vanilla Bazzite doesn't run them on such installs)
for u in bootloader-update.service greenboot-healthcheck.service greenboot-success.target; do sudo ln -sf /dev/null "$ROOT/etc/systemd/system/$u"; done
sudo install -Dm755 "$SRC/files/ps5-wifi-repair" "$ROOT/usr/local/sbin/ps5-wifi-repair"                        # IW620: Wi-Fi back after a warm reboot
sudo install -Dm644 "$SRC/files/ps5-wifi-repair.service" "$ROOT/etc/systemd/system/ps5-wifi-repair.service"
sudo mkdir -p "$ROOT/etc/systemd/system/multi-user.target.wants" && sudo ln -sf /etc/systemd/system/ps5-wifi-repair.service "$ROOT/etc/systemd/system/multi-user.target.wants/ps5-wifi-repair.service"
sudo install -Dm644 "$SRC/files/99-ps5-usb-power.rules" "$ROOT/etc/udev/rules.d/99-ps5-usb-power.rules"       # Bluetooth chips + Salina xHCI: no runtime suspend
sudo install -Dm755 "$SRC/files/90-ps5-wifi-powersave" "$ROOT/etc/NetworkManager/dispatcher.d/90-ps5-wifi-powersave"   # Wi-Fi power saving off (700 vs 100 Mbit/s)
sudo install -Dm644 "$SRC/files/ps5-kexec-prepare.service" "$ROOT/etc/systemd/system/ps5-kexec-prepare.service" # loads the kernel when a reboot starts
sudo install -Dm644 "$SRC/files/ps5-reboot.service" "$ROOT/etc/systemd/system/ps5-reboot.service"               # reboot = kexec when loaded, else normal
sudo install -Dm644 "$SRC/files/reboot.target" "$ROOT/usr/local/share/ps5-bazzite-deck/reboot.target"          # installed as /etc/systemd/system/reboot.target only by "ps5-warm-reboot on"
[ -e "$ROOT/usr/sbin/kexec" ] || sudo install -Dm755 "$SRC/files/kexec-shim" "$ROOT/usr/sbin/kexec"            # systemd runs "kexec -e"; stand-in when kexec-tools is absent
sudo mkdir -p "$ROOT/etc/systemd/system/multi-user.target.wants" && sudo ln -sf /usr/lib/systemd/system/sshd.service "$ROOT/etc/systemd/system/multi-user.target.wants/sshd.service"   # SSH on by default
echo "$RELEASE" | sudo tee "$ROOT/etc/ps5-bazzite-deck-version" >/dev/null
sync
cleanup; trap - EXIT

echo "==> 6. record exact versions"
SKOPEO_OUT="$(docker run --rm quay.io/skopeo/stable inspect docker://ghcr.io/ublue-os/bazzite-deck:stable 2>/dev/null || true)"
# no pipe here: with pipefail, grep -m1 closing the pipe early would abort the script
BAZZITE_DIGEST="$(sed -n '/"Digest"/{s/.*"\(sha256:[0-9a-f]*\)".*/\1/p;q}' <<<"$SKOPEO_OUT")"; [ -n "$BAZZITE_DIGEST" ] || BAZZITE_DIGEST=unknown
cat > output/VERSIONS.md << V
# Versions in release $RELEASE (built $(date -u +%Y-%m-%d))

| Component | Version / commit |
|---|---|
| Bazzite Deck | \`ghcr.io/ublue-os/bazzite-deck:stable\` @ \`$BAZZITE_DIGEST\` |
| Linux kernel | \`$KERNEL_TAG\` (kernel.org stable) |
| PS5 kernel patches | rmuxnet/ps5-linux-patches-1 \`$PATCHES_BRANCH\` @ \`$(git -C work/ps5-linux-patches rev-parse --short HEAD)\` + PR #4 (suspend-to-idle, Dasloh) |
| Image builder | ps5-linux/ps5-linux-image @ \`$BUILDER_COMMIT\` + local-changes.diff |
| IW620 Wi-Fi patches | ps5-linux/ps5-linux-mwifiex \`main\` @ \`$(git ls-remote https://github.com/ps5-linux/ps5-linux-mwifiex.git main | cut -c1-7)\` + patches/ps5-iw620-kernel73-compat.patch |
| NXP mwifiex base driver | \`lf-6.18.2_1.0.0\` |
| IW620 firmware | not in the image; pcieuartiw620_combo_v1.bin is staged at boot from the loader's boot partition (ps5-stage-firmware) |
| Kernel config changes | CONFIG_LSM += bpf, CONFIG_DEBUG_INFO_BTF=y, CONFIG_MT7921E=m, CONFIG_MODULE_ALLOW_BTF_MISMATCH=y |
| Extra kernel patches | ps5-bluetooth, ps5-hdmi-upstream, ps5-hdmi-rearm-pr46, ps5-hdmi-output-fixes, ps5-hdmi-modes, ps5-hdmi-debug-log, ps5-hdmi-link-lock, ps5-gpu-overlay, ps5-hdmi-cec-upstream53, ps5-hdmi-sleep-mute, ps5-hdmi-scdc-source-version (patches/) |
| Image config | NetworkManager stable MAC (IW620), MediaTek BT udev + modprobe, ps5-stage-firmware boot-cycle drop-in, IW620 Linux-only BT address (ps5-bt-addr), BT connectable, BT revive, hidp preload, BlueZ pairing options, warm reboot into Linux (kexec) (files/, tools/bt-mainconf.sh), SSH enabled |
| cmdline.txt | $(sed 's/__DISTRO__/bazzite-deck/' boot/cmdline.txt) |
V
cat output/VERSIONS.md

NAME="ps5-bazzite-deck-$RELEASE"
echo "==> 7. in-place update bundle (kernel, modules, settings) - ready to test before the 7-Zip step"
bash "$SRC/tools/make-update-bundle.sh" "$RELEASE"
git diff > output/local-changes.diff
cp "$SRC"/patches/*.patch output/

if [ "${SKIP_7Z:-0}" = 1 ]; then
  echo "==> 8. 7-Zip volumes skipped (SKIP_7Z=1)"
else
  echo "==> 8. package as 7-Zip volumes (GitHub caps assets at 2 GB)"
  rm -f output/$NAME.img.7z.*
  7z a -mx=5 -mmt=on -v1900m "output/$NAME.img.7z" "$IMG" >/dev/null
  (cd output && sha256sum $NAME.img.7z.* > "$NAME.sha256")
fi

echo
echo "DONE. Release assets in $REPO/output:"
ls -lh output/$NAME-update.tar.xz* output/VERSIONS.md output/local-changes.diff output/*.patch
[ "${SKIP_7Z:-0}" = 1 ] || ls -lh output/$NAME.img.7z.* output/$NAME.sha256
echo "Flash output/ps5-bazzite-deck.img (raw) to test. On the PS5: uname -r, systemctl status cardwired, nmcli device"
