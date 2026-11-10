#!/usr/bin/bash
# bazzite-deck into the PS5 image; nothing may stay in /var, /usr/local or /boot (bootc doesn't update them)
set -euxo pipefail

CTX=/ctx

# --- kernel (kmod-libs is libkmod, not a module package)
mapfile -t old < <(rpm -qa --qf '%{NAME}\n' |
    grep -E '^kernel(-core|-modules(-core|-extra)?|-devel(-matched)?|-uki-virt)?$|^kmod-' |
    grep -vx kmod-libs || true)
[ ${#old[@]} -eq 0 ] || rpm -e --nodeps --noscripts "${old[@]}"
rm -rf /usr/lib/modules/*

# /usr/local links to /var/usrlocal; the RPM's %post would build an initrd into /boot/efi
mkdir -p /var/usrlocal/bin /var/usrlocal/sbin
rpm -i --nodeps --noscripts --nosignature --replacefiles "$CTX"/kernel/linux-ps5-*.rpm
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
# an RPM built from patches that carry upstream's pairing importer enables it as is; ps5-bt-import gates it here
rm -f /etc/systemd/system/bluetooth.service.wants/ps5-bt-sync.service

depmod -a "$KVER"

# --- firmware: amdgpu writes into the Oberon buffer, read-only when loaded from .xz; unxz skips links
cd /usr/lib/firmware/amdgpu
for f in cyan_skillfish*.xz; do
    xz -dc "$f" > "${f%.xz}"
done
rm -f cyan_skillfish*.xz
cd /

# --- PS5 files: the Legacy bundle's list, /usr/local moved to /usr (the modprobe conf is in system_files)
sed -n "/^cat > \"\$OUT\/FILES\" << 'L'/,/^L\$/p" "$CTX/deck/tools/make-update-bundle.sh" | sed '1d;$d' |
while read -r src dst mode; do
    [ "$src" = ps5-iw620-modprobe.conf ] && continue
    f=$CTX/deck/files/$src; [ -f "$f" ] || f=$CTX/deck/tools/$src
    dst=$(echo "$dst" | sed -e 's#^/usr/local/s\?bin/#/usr/bin/#' -e 's#^/usr/local/share/#/usr/share/#')
    install -Dm"${mode:-644}" "$f" "$dst"
    sed -i -e 's#/usr/local/s\?bin/#/usr/bin/#g' -e 's#/usr/local/share/#/usr/share/#g' "$dst"
done
# --- RADV with the PS5 Pro's int8 matrix instructions and compute queue (bootc/mesa); other GPUs as Bazzite's
for d in lib64 lib; do
    [ -e "/usr/$d/libvulkan_radeon.so" ] || continue
    install -m755 "$CTX/radv/$d/libvulkan_radeon.so" "/usr/$d/libvulkan_radeon.so"
    ! ldd -r "/usr/$d/libvulkan_radeon.so" 2>&1 | grep -E "not found|undefined symbol" ||
        { echo "/usr/$d/libvulkan_radeon.so doesn't load against this image"; exit 1; }
done

if [ ! -e /usr/sbin/kexec ]; then
    install -Dm755 "$CTX/deck/files/kexec-shim" /usr/bin/kexec
    sed -i 's#/usr/local/s\?bin/#/usr/bin/#g' /usr/bin/kexec
fi
bash "$CTX/deck/tools/bt-mainconf.sh" /etc/bluetooth/main.conf

cp -a "$CTX/system_files/." /

# --- services
systemctl enable \
    boot-efi.mount ps5-bootc-sync.service ps5-grow-root.service \
    ps5-bt-addr.service ps5-bt-connectable.service ps5-bt-pro-addr.service \
    ps5-bt-revive.service ps5-bt-import.service ps5-perf.service ps5-stage-viola-fw.service ps5-console-defaults.service \
    ps5-wifi-repair.service ps5-wifi-powersave.timer \
    ps5-bootc-channel.service ps5-session-defaults.service \
    sshd.service
systemctl --global enable ps5-user-defaults.service
mkdir -p /etc/systemd/system/bluetooth.target.wants
ln -sf /etc/systemd/system/ps5-bt-addr.service /etc/systemd/system/bluetooth.target.wants/
ln -sf /etc/systemd/system/ps5-bt-connectable.service /etc/systemd/system/bluetooth.target.wants/
for n in 2 3 4 5 6; do systemctl enable "getty@tty$n.service"; done

# Plasma's wizard would take over the autologin; Bazzite's hardware setup sets x86 kargs
systemctl mask plasma-setup.service bazzite-hardware-setup.service
# no GRUB, so no greenboot; ostree-finalize-staged requires the rollback trigger, which must not be masked
systemctl disable greenboot-healthcheck.service greenboot-set-rollback-trigger.service greenboot-success.target 2>/dev/null || true
rm -f /etc/systemd/system/*.requires/greenboot-* /etc/systemd/system/*.wants/greenboot-* \
      /usr/lib/systemd/system/*.requires/greenboot-* /usr/lib/systemd/system/*.wants/greenboot-*
systemctl mask bootloader-update.service greenboot-healthcheck.service greenboot-success.target
printf '[Unit]\nDescription=No greenboot rollbacks on the PS5\n\n[Service]\nType=oneshot\nExecStart=/usr/bin/true\nRemainAfterExit=yes\n' \
    > /etc/systemd/system/greenboot-set-rollback-trigger.service

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
mkdir -p /usr/share/ps5-bazzite-bootc
cat > /usr/share/ps5-bazzite-bootc/VERSION <<EOF
version=$IMAGE_VERSION
base=$BASE_IMAGE
kernel=$KVER
deck=$DECK
loader=$LOADER
radv=$(cat "$CTX/radv/VERSION")
EOF
echo "$IMAGE_VERSION (bootc, ps5-bazzite-deck $DECK)" > /etc/ps5-bazzite-deck-version   # for ps5-report

# no EROFS in the PS5 kernel, so no composefs: ostree bind-mounts the deployment
C=/usr/lib/ostree/prepare-root.conf
if grep -q '^\[composefs\]' "$C" 2>/dev/null; then
    sed -i '/^\[composefs\]/,/^\[/ s/^enabled *=.*/enabled = no/' "$C"
else
    printf '[composefs]\nenabled = no\n' >> "$C"
fi
cat "$C"

# --- identity: "deck" in image-name keeps Bazzite's deck setup; Steam's own branding
I=/usr/share/ublue-os/image-info.json
if [ -f "$I" ]; then
    jq '."image-name"="ps5-bazzite-deck" | ."image-vendor"="vivalavent" | ."image-tag"="stable"
        | ."image-ref"="ostree-image-signed:docker://ghcr.io/vivalavent/ps5-bazzite-bootc"' "$I" > /tmp/image-info.json
    mv /tmp/image-info.json "$I"
fi
sed -i -e 's|^NAME=.*|NAME="PS5 Bazzite Deck"|' -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"PS5 Bazzite Deck ${DECK%%-*}\"|" \
    -e 's|^HOME_URL=.*|HOME_URL="https://wiki.ps5-linux.eu"|' -e 's|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://wiki.ps5-linux.eu"|' \
    -e 's|^SUPPORT_URL=.*|SUPPORT_URL="https://discord.gg/ps5linux"|' \
    -e 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/VivaLaVent/ps5-bazzite-deck/issues"|' /usr/lib/os-release
[ ! -f /usr/bin/bazzite-steam-brand ] || printf '#!/bin/sh\nexit 0\n' > /usr/bin/bazzite-steam-brand
# Bazzite's rebase helper moves to ublue-os images, which have no PS5 kernel
[ ! -f /usr/bin/bazzite-rollback-helper ] || printf '#!/bin/sh\necho "Not on the PS5: use sudo bootc rollback, or Steam\x27s OS Update Channel"\nexit 1\n' > /usr/bin/bazzite-rollback-helper
# no OS updates from Steam (updates are sudo bootc upgrade): its check always finds none
O=/usr/libexec/ogc/os-update
[ ! -f "$O" ] || { sed -i '/^if ! command -v uupd/i exit 7' "$O"; grep -qx 'exit 7' "$O"; }

# --- initramfs last (amdgpu loads from it), as Bazzite's build-initramfs.sh
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
