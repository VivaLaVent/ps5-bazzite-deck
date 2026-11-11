#!/bin/bash
# PS5 kernel RPM: Linux 7.3.3 + rmux's shitshow + patches/series, built with ps5-linux-image's builder
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES=$(cd "${PATCHES:-$SRC/patches}" && pwd)

REPO="${REPO:-$HOME/ps5-build-7.3}"
OLD="${OLD:-$HOME/ps5-linux-image}"
BUILDER_COMMIT=03b59ab
PATCHES_BRANCH=shitshow
KERNEL_TAG=v7.3.3
MWIFIEX_COMMIT=3d81cba

[ -d "$REPO" ] && { echo "$REPO already exists. Remove it (rm -rf $REPO) or change REPO at the top of this script."; exit 1; }
for t in git docker; do command -v $t >/dev/null || { echo "missing tool: $t"; exit 1; }; done

echo "==> 1. builder ($BUILDER_COMMIT)"
git clone -q https://github.com/ps5-linux/ps5-linux-image "$REPO"
cd "$REPO"
git checkout -q "$BUILDER_COMMIT"
[ -d "$OLD/cache" ] && cp -r "$OLD/cache" cache && echo "    reusing download cache from $OLD/cache"

echo "==> 2. builder fixes"
# 2a. Wi-Fi driver: ps5-linux-mwifiex at a fixed commit; the builder applies its patches and sets ext_scan=2
B=docker/kernel-builder/build.sh
sed -i 's/MWIFIEX_REF:-main/MWIFIEX_REF:-'"$MWIFIEX_COMMIT"'/; s/^git -C "$PS5_MW" checkout "$MWIFIEX_REF" 2>\/dev\/null || true$/git -C "$PS5_MW" checkout -q "$MWIFIEX_REF"/' "$B"
grep -q "checkout -q \"\$MWIFIEX_REF\"" "$B" && grep -q "ps5-iw620-fresh-fw.patch" "$B" && grep -q " ext_scan=2 " "$B" && ! grep -q "CONFIG_OBJTOOL=" "$B" || { echo "wifi driver edit failed"; exit 1; }
# 2b. this repository's own driver patches (patches/mwifiex), after the builder's; they reach the container through
#     work/ps5-linux-patches, which the builder mounts at /ps5-linux-patches (copied there in step 3)
#     (each line lands right after the builder's last patch, so going through them in reverse keeps their order)
DP=("$PATCHES"/mwifiex/*.patch)
for ((i = ${#DP[@]} - 1; i >= 0; i--)); do
  p=${DP[i]}; [ -e "$p" ] || continue
  sed -i '/ps5-iw620-fresh-fw.patch"$/a git -C "$NXP_MW" apply "/ps5-linux-patches/'"$(basename "$p")"'"' "$B"
  grep -q "/ps5-linux-patches/$(basename "$p")" "$B" || { echo "driver patch $(basename "$p") not wired in"; exit 1; }
done
grep -q -- '-v "$PATCHES_DIR":/ps5-linux-patches' build_image.sh || { echo "builder no longer mounts work/ps5-linux-patches"; exit 1; }
# 2c. video=DP-1:1920x1080@60 is rejected by the kernel on every connector probe ("User-defined mode not supported"); drop it
sed -i 's/ video=DP-1:1920x1080@60//' boot/cmdline.txt
grep -q 'video=' boot/cmdline.txt && { echo 'cmdline edit failed'; exit 1; }

echo "==> 3. kernel source: $KERNEL_TAG + $PATCHES_BRANCH patches"
mkdir -p work
git clone -q -b "$PATCHES_BRANCH" https://github.com/rmuxnet/ps5-linux-patches-1 work/ps5-linux-patches
git -C work/ps5-linux-patches checkout -q 8de2aff
for p in "$PATCHES"/mwifiex/*.patch; do [ ! -e "$p" ] || cp "$p" work/ps5-linux-patches/; done
sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-viva"/' work/ps5-linux-patches/.config
sed -i 's/^# CONFIG_SUSPEND is not set/CONFIG_SUSPEND=y/' work/ps5-linux-patches/.config
sed -i 's/^CONFIG_LSM=.*/CONFIG_LSM="landlock,lockdown,yama,integrity,apparmor,bpf"/' work/ps5-linux-patches/.config
sed -i 's/^# CONFIG_DEBUG_INFO_BTF is not set/CONFIG_DEBUG_INFO_BTF=y/' work/ps5-linux-patches/.config
sed -i 's/^CONFIG_USB_AUTOSUSPEND_DELAY=.*/CONFIG_USB_AUTOSUSPEND_DELAY=-1/' work/ps5-linux-patches/.config
sed -i 's/^CONFIG_LOG_BUF_SHIFT=.*/CONFIG_LOG_BUF_SHIFT=20/' work/ps5-linux-patches/.config
grep -q '^CONFIG_DEBUG_INFO_BTF=y' work/ps5-linux-patches/.config || echo 'CONFIG_DEBUG_INFO_BTF=y' >> work/ps5-linux-patches/.config
sed -i 's/^# CONFIG_MODULE_ALLOW_BTF_MISMATCH is not set/CONFIG_MODULE_ALLOW_BTF_MISMATCH=y/' work/ps5-linux-patches/.config; grep -q '^CONFIG_MODULE_ALLOW_BTF_MISMATCH=y' work/ps5-linux-patches/.config || echo 'CONFIG_MODULE_ALLOW_BTF_MISMATCH=y' >> work/ps5-linux-patches/.config
sed -i 's/^# CONFIG_MT7921E is not set/CONFIG_MT7921E=m/' work/ps5-linux-patches/.config; grep -q '^CONFIG_MT7921E=m' work/ps5-linux-patches/.config || echo 'CONFIG_MT7921E=m' >> work/ps5-linux-patches/.config
sed -i 's/^CONFIG_PS5_GPUFREQ=.*/# CONFIG_PS5_GPUFREQ is not set/' work/ps5-linux-patches/.config   # rmux's GPU clock driver: replaced by upstream's governor (drivers/ps5/gpufreq.c)
sed -i 's/^# CONFIG_NF_CONNTRACK_NETBIOS_NS is not set/CONFIG_NF_CONNTRACK_NETBIOS_NS=m/' work/ps5-linux-patches/.config   # firewalld's samba-client service
for o in LOGITECH_FF LOGIRUMBLEPAD2_FF LOGIG940_FF LOGIWHEELS_FF; do sed -i "s/^# CONFIG_$o is not set/CONFIG_$o=y/" work/ps5-linux-patches/.config; done   # wheel force feedback, as rmux's meower (36b9828)
git clone -q --branch "$KERNEL_TAG" --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git work/linux73
git -C work/linux73 apply --exclude=Makefile ../ps5-linux-patches/linux.patch
grep -o '^[^# ]*\.patch' "$PATCHES/series" > work/series
while read -r p; do git -C work/linux73 apply "$PATCHES/$p"; done < work/series
# committed and at an annotated tag, so the release is exactly <version>-viva (no "+" or "-dirty")
git -C work/linux73 add -A
git -C work/linux73 -c user.name=ps5-bazzite-deck -c user.email=ps5-bazzite-deck@users.noreply.github.com commit -qm "PS5 patches"
git -C work/linux73 -c user.name=ps5-bazzite-deck -c user.email=ps5-bazzite-deck@users.noreply.github.com tag -f -a "$KERNEL_TAG" -m "$KERNEL_TAG with PS5 patches"
cp work/ps5-linux-patches/.config work/linux73/.config
cp -r work/ps5-linux-patches work/linux73/ps5-linux-patches
grep -E '^CONFIG_LSM=|^CONFIG_DEBUG_INFO_BTF=|^CONFIG_MT7921E=|^CONFIG_MODULE_ALLOW_BTF_MISMATCH=|^CONFIG_NF_CONNTRACK_NETBIOS_NS=' work/linux73/.config

echo "==> 4. kernel package"
./build_image.sh --kernel-only --distro bazzite-deck --kernel "$PWD/work/linux73"
ls -l linux-bin/linux-ps5-*.rpm
