#!/usr/bin/bash
# Runs inside the Containerfile build, on top of bazzite-deck.
# Mirrors what ps5-linux-image's distros/bazzite-deck/build-rootfs.sh and
# ps5-bazzite-deck's build.sh do to the flat image, minus the parts that
# removed ostree. Rule of thumb for this file: nothing may end up in /var,
# /usr/local or /boot, since bootc doesn't update those after install.
set -euxo pipefail

CTX=/ctx

# --- kernel
# Remove Bazzite's kernel and the kmods built for it, then install linux-ps5.
# Same package list as Bazzite's own 03-install-kernel-akmods.sh, plus the
# devel packages and kmods, which only fit Bazzite's kernel. kernel-tools stays.
# --noscripts: linux-ps5's %post runs dracut and copies to /boot/efi, both wrong here.
mapfile -t old < <(rpm -qa --qf '%{NAME}\n' |
    grep -E '^kernel(-core|-modules(-core|-extra)?|-devel(-matched)?|-uki-virt)?$|^kmod-' |
    grep -vx 'kmod-libs' || true)   # kmod-libs is libkmod (modprobe, depmod, udev), not a kmod
[ ${#old[@]} -eq 0 ] || rpm -e --nodeps --noscripts "${old[@]}"
rm -rf /usr/lib/modules/*

# /usr/local is a link to /var/usrlocal, which only exists once installed: give the
# RPM somewhere to put its helper scripts (moved to /usr/bin below)
mkdir -p /var/usrlocal/bin /var/usrlocal/sbin
rpm -i --nodeps --noscripts --replacefiles "$CTX"/kernel/linux-ps5-*.rpm
KVER=$(ls /usr/lib/modules)
[ "$(echo "$KVER" | wc -l)" = 1 ] || { echo "expected one kernel, got: $KVER"; exit 1; }

# bootc looks for the kernel next to its modules
mv "/boot/vmlinuz-$KVER" "/usr/lib/modules/$KVER/vmlinuz"
mv "/boot/config-$KVER" "/usr/lib/modules/$KVER/config"
mv "/boot/System.map-$KVER" "/usr/lib/modules/$KVER/System.map"

# The RPM's helper scripts land in /usr/local/sbin, which is a symlink into
# /var here. Move them to /usr/bin and point their units there.
for f in /var/usrlocal/sbin/ps5-*; do
    [ -e "$f" ] || continue
    mv "$f" /usr/bin/
done
# (which units exist depends on the ps5-linux-image version the RPM was built with)
for u in ps5-stage-firmware ps5-bt-quiet ps5-stage-gpu-firmware; do
    [ -f "/etc/systemd/system/$u.service" ] && sed -i 's#/usr/local/sbin/#/usr/bin/#g' "/etc/systemd/system/$u.service"
done
# ps5-stage-gpu-firmware writes to /usr/lib/firmware, read-only on bootc.
# ps5-stage-viola-fw (below) does the same job on the boot partition instead.
rm -f /etc/systemd/system/multi-user.target.wants/ps5-stage-gpu-firmware.service

depmod -a "$KVER"

# --- firmware
# Oberon GPU firmware must not be xz-compressed: the amdgpu patches write into
# the firmware buffer, and xz-loaded firmware is mapped read-only (oops in
# gfx_v10_0_early_init). Same fix as ps5-linux-image@ed54e99.
# Decompress to new files rather than with unxz: unxz skips symlinks (mec2 -> mec)
# and files with more than one hard link, which ostree images are full of.
cd /usr/lib/firmware/amdgpu
for f in cyan_skillfish*.xz; do
    xz -dc "$f" > "${f%.xz}"   # reads through symlinks
done
rm -f cyan_skillfish*.xz
cd /

# --- PS5 files from ps5-bazzite-deck
grep -v '^#' "$CTX/ps5/install.list" | while read -r src dst mode; do
    [ -n "$src" ] || continue
    install -Dm"${mode:-644}" "$CTX/ps5/$src" "$dst"
    sed -i 's#/usr/local/s\?bin/#/usr/bin/#g' "$dst"
done
# the deck image only installs the shim when kexec-tools is missing
[ -e /usr/sbin/kexec ] || ln -s ps5-kexec-shim /usr/bin/kexec
bash "$CTX/ps5/bt-mainconf.sh" /etc/bluetooth/main.conf

# --- our own files
cp -a "$CTX/system_files/." /

# --- services
systemctl enable \
    boot-efi.mount ps5-bootc-sync.service ps5-grow-root.service \
    ps5-bt-addr.service ps5-bt-connectable.service ps5-bt-pro-addr.service \
    ps5-bt-revive.service ps5-perf.service ps5-stage-viola-fw.service \
    ps5-wifi-repair.service ps5-wifi-powersave.timer \
    ps5-gamescope-recovery.service \
    sshd.service
# deck image: ps5-bt-addr and ps5-bt-connectable also start with bluetooth.target
mkdir -p /etc/systemd/system/bluetooth.target.wants
ln -sf /etc/systemd/system/ps5-bt-addr.service /etc/systemd/system/bluetooth.target.wants/
ln -sf /etc/systemd/system/ps5-bt-connectable.service /etc/systemd/system/bluetooth.target.wants/
for n in 2 3 4 5 6; do systemctl enable "getty@tty$n.service"; done

# Autologin is Bazzite's own (bazzite-autologin, user 1000 into Game Mode). Plasma's
# first-run wizard would take it over, since our user isn't made by Bazzite's installer.
systemctl mask plasma-setup.service
# Runs Bazzite's x86 hardware detection and sets kargs for it; none apply to the PS5.
systemctl mask bazzite-hardware-setup.service
# There is no GRUB to update, and greenboot's boot counting needs GRUB.
systemctl mask bootloader-update.service greenboot-healthcheck.service \
    greenboot-set-rollback-trigger.service greenboot-success.target

# --- packages Bazzite's image lacks (same list as the deck image)
dnf5 install -y --setopt=install_weak_deps=False \
    cloud-utils-growpart plasma-systemmonitor ksystemstats \
    kdiff3 gwenview ark okular spectacle chrony cpio
dnf5 clean all

# --- version
mkdir -p /usr/share/ps5-bazzite-bootc
cat > /usr/share/ps5-bazzite-bootc/VERSION <<EOF
version=$IMAGE_VERSION
base=$BASE_IMAGE
kernel=$KVER
EOF
echo "$IMAGE_VERSION" > /etc/ps5-bazzite-deck-version   # read by ps5-report and vrr-report

# --- initramfs
# Last, so it carries the uncompressed GPU firmware and the amdgpu/moal options:
# amdgpu loads from the initramfs. Same dracut call as Bazzite's build-initramfs.sh,
# including keeping the build-specific os-release lines out of it.
mkdir -p /var/roothome   # /root points here; dracut fails when it's missing
cp /usr/lib/os-release /tmp/os-release
sed -Ei '/^((OSTREE_)?(IMAGE_)?VERSION|PRETTY_NAME|BUILD_ID|BOOTLOADER_NAME|IMAGE_ID)=/d' /usr/lib/os-release
DRACUT_NO_XATTR=1 dracut --no-hostonly --reproducible --zstd --add ostree --add fido2 \
    --kver "$KVER" --force "/usr/lib/modules/$KVER/initramfs.img"
cp /tmp/os-release /usr/lib/os-release
chmod 0600 "/usr/lib/modules/$KVER/initramfs.img"

# --- cleanup, as Bazzite's cleanup.sh does
# shellcheck disable=SC2115  # literal paths, as in Bazzite's cleanup.sh
rm -rf /boot/* /usr/lib/sysimage/libdnf5/*
find /var/* -maxdepth 0 -type d \! -name cache -exec rm -rf {} +
rm -rf /var/cache/*
mkdir -p /var/tmp && chmod 1777 /var/tmp
# rpm-ostree compares against this copy of the rpm database; after our rpm
# transactions it has to be the current one again (coreos/rpm-ostree#4554)
for f in rpmdb.sqlite rpmdb.sqlite-shm rpmdb.sqlite-wal; do
    if [ -f "/usr/share/rpm/$f" ] && [ -f "/usr/lib/sysimage/rpm-ostree-base-db/$f" ]; then
        ln -f "/usr/share/rpm/$f" "/usr/lib/sysimage/rpm-ostree-base-db/$f"
    fi
done
