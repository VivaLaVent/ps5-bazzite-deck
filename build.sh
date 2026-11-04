#!/bin/bash
# The PS5 kernel package: Linux 7.3 + rmux's meower patches + patches/, built with ps5-linux-image's
# builder. CI runs this for every release (.github/workflows/release.yml); locally: bash build.sh
# Output: $REPO/linux-bin/linux-ps5-*.rpm
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # this repo
RELEASE="${RELEASE:-$(git -C "$SRC" describe --tags --always 2>/dev/null || echo dev)}"

REPO="${REPO:-$HOME/ps5-build-7.3}"   # fresh build directory
OLD="${OLD:-$HOME/ps5-linux-image}"   # previous build dir, only used to reuse its download cache
BUILDER_COMMIT=52db0a4                 # ps5-linux/ps5-linux-image
PATCHES_BRANCH=meower                  # rmuxnet/ps5-linux-patches-1, 7.3 port
KERNEL_TAG=v7.3

[ -d "$REPO" ] && { echo "$REPO already exists. Remove it (rm -rf $REPO) or change REPO at the top of this script."; exit 1; }
for t in git docker; do command -v $t >/dev/null || { echo "missing tool: $t"; exit 1; }; done

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
git -C work/linux73 apply "$SRC/patches/ps5-fan-shutdown-spike.patch"    # fan: no spike at shutdown
cp work/ps5-linux-patches/.config work/linux73/.config
cp -r work/ps5-linux-patches work/linux73/ps5-linux-patches
grep -E '^CONFIG_LSM=|^CONFIG_DEBUG_INFO_BTF=|^CONFIG_MT7921E=|^CONFIG_MODULE_ALLOW_BTF_MISMATCH=' work/linux73/.config

echo "==> 4. kernel package"
./build_image.sh --kernel-only --distro bazzite-deck --kernel "$PWD/work/linux73"
ls -l linux-bin/linux-ps5-*.rpm
