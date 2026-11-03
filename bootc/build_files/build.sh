#!/usr/bin/bash
# Turns bazzite-deck into the PS5 image. Nothing may be left in /var, /usr/local
# or /boot: bootc doesn't update those after install.
set -euxo pipefail

CTX=/ctx

# --- kernel
# kmod-libs is libkmod, not a kernel module package
mapfile -t old < <(rpm -qa --qf '%{NAME}\n' |
    grep -E '^kernel(-core|-modules(-core|-extra)?|-devel(-matched)?|-uki-virt)?$|^kmod-' |
    grep -vx kmod-libs || true)
[ ${#old[@]} -eq 0 ] || rpm -e --nodeps --noscripts "${old[@]}"
rm -rf /usr/lib/modules/*

# /usr/local links to /var/usrlocal, which doesn't exist until install.
# --noscripts: the RPM's %post builds an initrd and copies it to /boot/efi.
mkdir -p /var/usrlocal/bin /var/usrlocal/sbin
rpm -i --nodeps --noscripts --replacefiles "$CTX"/kernel/linux-ps5-*.rpm
KVER=$(ls /usr/lib/modules)
[ "$(echo "$KVER" | wc -l)" = 1 ] || { echo "expected one kernel, got: $KVER"; exit 1; }

mv "/boot/vmlinuz-$KVER" "/usr/lib/modules/$KVER/vmlinuz"
mv "/boot/config-$KVER" "/usr/lib/modules/$KVER/config"
mv "/boot/System.map-$KVER" "/usr/lib/modules/$KVER/System.map"

for f in /var/usrlocal/sbin/ps5-*; do
    [ -e "$f" ] && mv "$f" /usr/bin/
done
# older RPMs don't ship ps5-stage-gpu-firmware
for u in ps5-stage-firmware ps5-bt-quiet ps5-stage-gpu-firmware; do
    [ -f "/etc/systemd/system/$u.service" ] && sed -i 's#/usr/local/sbin/#/usr/bin/#g' "/etc/systemd/system/$u.service"
done
# writes to /usr/lib/firmware, read-only here; ps5-stage-viola-fw does this instead
rm -f /etc/systemd/system/multi-user.target.wants/ps5-stage-gpu-firmware.service

depmod -a "$KVER"

# --- firmware
# The amdgpu patches write into the Oberon firmware buffer, which is read-only
# when loaded from .xz (ps5-linux-image@ed54e99). unxz would skip the symlinked
# and hard-linked files, so decompress to new files.
cd /usr/lib/firmware/amdgpu
for f in cyan_skillfish*.xz; do
    xz -dc "$f" > "${f%.xz}"
done
rm -f cyan_skillfish*.xz
cd /

# --- PS5 files from ps5-bazzite-deck
grep -v '^#' "$CTX/ps5/install.list" | while read -r src dst mode; do
    [ -n "$src" ] || continue
    install -Dm"${mode:-644}" "$CTX/ps5/$src" "$dst"
    sed -i -e 's#/usr/local/s\?bin/#/usr/bin/#g' -e 's#/usr/local/share/#/usr/share/#g' "$dst"
done
[ -e /usr/sbin/kexec ] || ln -s ps5-kexec-shim /usr/bin/kexec
bash "$CTX/ps5/bt-mainconf.sh" /etc/bluetooth/main.conf

cp -a "$CTX/system_files/." /

# --- services
systemctl enable \
    boot-efi.mount ps5-bootc-sync.service ps5-grow-root.service \
    ps5-bt-addr.service ps5-bt-connectable.service ps5-bt-pro-addr.service \
    ps5-bt-revive.service ps5-perf.service ps5-stage-viola-fw.service \
    ps5-wifi-repair.service ps5-wifi-powersave.timer \
    ps5-gamescope-recovery.service \
    sshd.service
mkdir -p /etc/systemd/system/bluetooth.target.wants
ln -sf /etc/systemd/system/ps5-bt-addr.service /etc/systemd/system/bluetooth.target.wants/
ln -sf /etc/systemd/system/ps5-bt-connectable.service /etc/systemd/system/bluetooth.target.wants/
for n in 2 3 4 5 6; do systemctl enable "getty@tty$n.service"; done

# Our user doesn't come from Bazzite's installer, so Plasma's wizard would take
# over the autologin.
systemctl mask plasma-setup.service
# x86 hardware detection; sets kargs that don't apply to the PS5
systemctl mask bazzite-hardware-setup.service
# no GRUB here
systemctl mask bootloader-update.service greenboot-healthcheck.service \
    greenboot-set-rollback-trigger.service greenboot-success.target

dnf5 install -y --setopt=install_weak_deps=False \
    cloud-utils-growpart plasma-systemmonitor ksystemstats \
    kdiff3 gwenview ark okular spectacle chrony cpio
dnf5 clean all

# --- image signature, once a public key ships in system_files
KEY=/etc/pki/containers/ps5-bazzite-bootc.pub
if [ -f "$KEY" ]; then
    REPO=ghcr.io/vivalavent/ps5-bazzite-bootc
    jq --arg r "$REPO" --arg k "$KEY" \
        '.transports.docker[$r] = [{type: "sigstoreSigned", keyPath: $k, signedIdentity: {type: "matchRepository"}}]' \
        /etc/containers/policy.json > /tmp/policy.json
    mv /tmp/policy.json /etc/containers/policy.json
    mkdir -p /etc/containers/registries.d
    printf 'docker:\n  %s:\n    use-sigstore-attachments: true\n' "$REPO" \
        > /etc/containers/registries.d/ps5-bazzite-bootc.yaml
fi

# --- version
DECK=$(sed -n 's/.* at \(v[0-9.]*\) .*/\1/p' "$CTX/ps5/VENDORED")
mkdir -p /usr/share/ps5-bazzite-bootc
cat > /usr/share/ps5-bazzite-bootc/VERSION <<EOF
version=$IMAGE_VERSION
base=$BASE_IMAGE
kernel=$KVER
deck=$DECK
loader=$LOADER
EOF
echo "$IMAGE_VERSION (bootc, ps5-bazzite-deck $DECK)" > /etc/ps5-bazzite-deck-version   # for ps5-report

# The PS5 kernel has no EROFS, so composefs can't mount the root ("No such device").
# Without it ostree bind-mounts the deployment, as before composefs.
C=/usr/lib/ostree/prepare-root.conf
if grep -q '^\[composefs\]' "$C" 2>/dev/null; then
    sed -i '/^\[composefs\]/,/^\[/ s/^enabled *=.*/enabled = no/' "$C"
else
    printf '[composefs]\nenabled = no\n' >> "$C"
fi
cat "$C"

# --- initramfs, last: amdgpu loads from it, so it needs the firmware and options above.
# Same as Bazzite's build-initramfs.sh.
mkdir -p /var/roothome   # /root links here; dracut fails without it
cp /usr/lib/os-release /tmp/os-release
sed -Ei '/^((OSTREE_)?(IMAGE_)?VERSION|PRETTY_NAME|BUILD_ID|BOOTLOADER_NAME|IMAGE_ID)=/d' /usr/lib/os-release
DRACUT_NO_XATTR=1 dracut --no-hostonly --reproducible --zstd --add ostree --add fido2 \
    --kver "$KVER" --force "/usr/lib/modules/$KVER/initramfs.img"
cp /tmp/os-release /usr/lib/os-release
chmod 0600 "/usr/lib/modules/$KVER/initramfs.img"

# --- cleanup, as Bazzite's cleanup.sh
# shellcheck disable=SC2115
rm -rf /boot/* /usr/lib/sysimage/libdnf5/*
find /var/* -maxdepth 0 -type d \! -name cache -exec rm -rf {} +
rm -rf /var/cache/*
mkdir -p /var/tmp && chmod 1777 /var/tmp
# rpm-ostree diffs against this copy of the rpm database (coreos/rpm-ostree#4554)
for f in rpmdb.sqlite rpmdb.sqlite-shm rpmdb.sqlite-wal; do
    if [ -f "/usr/share/rpm/$f" ] && [ -f "/usr/lib/sysimage/rpm-ostree-base-db/$f" ]; then
        ln -f "/usr/share/rpm/$f" "/usr/lib/sysimage/rpm-ostree-base-db/$f"
    fi
done
