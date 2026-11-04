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
PATCHES_BRANCH=shitshow                # rmuxnet/ps5-linux-patches-1, 7.3.1 port
KERNEL_TAG=v7.3.1

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
git -C work/ps5-linux-patches checkout -q 8de2aff        # pinned: the commit patches/ was ported onto
sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-viva"/' work/ps5-linux-patches/.config
sed -i 's/^# CONFIG_SUSPEND is not set/CONFIG_SUSPEND=y/' work/ps5-linux-patches/.config   # suspend-to-idle (patches/ps5-s2idle.patch)
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
git -C work/linux73 apply "$SRC/patches/ps5-s2idle.patch"     # suspend-to-idle (Dasloh, PR #4)
git -C work/linux73 apply "$SRC/patches/ps5-display.patch"    # re-arm, session switch, EDID keep, SCDC, VRR: what shitshow lacks
git -C work/linux73 apply "$SRC/patches/ps5-gpu.patch"        # thermal GPU governor, overlay metrics
git -C work/linux73 apply "$SRC/patches/ps5-fan.patch"        # no fan spike at shutdown
# committed and at an annotated tag, so the release is exactly <version>-viva (no "+" or "-dirty")
git -C work/linux73 add -A
git -C work/linux73 -c user.name=ps5-bazzite-deck -c user.email=ps5-bazzite-deck@users.noreply.github.com commit -qm "PS5 patches"
git -C work/linux73 -c user.name=ps5-bazzite-deck -c user.email=ps5-bazzite-deck@users.noreply.github.com tag -f -a "$KERNEL_TAG" -m "$KERNEL_TAG with PS5 patches"
cp work/ps5-linux-patches/.config work/linux73/.config
cp -r work/ps5-linux-patches work/linux73/ps5-linux-patches
grep -E '^CONFIG_LSM=|^CONFIG_DEBUG_INFO_BTF=|^CONFIG_MT7921E=|^CONFIG_MODULE_ALLOW_BTF_MISMATCH=' work/linux73/.config

echo "==> 4. kernel package"
./build_image.sh --kernel-only --distro bazzite-deck --kernel "$PWD/work/linux73"
ls -l linux-bin/linux-ps5-*.rpm
