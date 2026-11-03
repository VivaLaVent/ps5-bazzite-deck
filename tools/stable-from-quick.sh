#!/bin/bash
# Stable release without an image build: the quick package installed into a copy of vPREV's image
# (chroot), every swapped file checked, bundle and 7-Zip volumes made and verified, published as Latest.
#   QUICK_FILES="..." QUICK_REMOVE="..." BASE_IMG=... UNPRERELEASE="..." bash tools/stable-from-quick.sh vNEW vPREV
set -euo pipefail
V=${1:?vNEW}; PREV=${2:?vPREV}
B=~/ps5-build-7.3; O=$B/output; SRC=~/ps5-bazzite-deck; R=VivaLaVent/ps5-bazzite-deck
IMG0=${BASE_IMG:-$O/ps5-bazzite-deck.img}; IMG=$O/ps5-bazzite-deck-$V.img; Q=$O/ps5-quick-$V; N=ps5-bazzite-deck-$V-update
MNT=/mnt/stable-$V
step() { echo "== $*"; }

gh release view $V --repo $R >/dev/null 2>&1 && { echo "STOP: $V already exists on GitHub"; exit 1; }
[ -f $SRC/docs/release-notes/$V.md ] && [ -f $SRC/docs/update-sections/$V.md ] || { echo "STOP: notes for $V missing"; exit 1; }
[ -f "$IMG0" ] || { echo "STOP: $IMG0 ($PREV's image) not found"; exit 1; }
[ -f "$O/VERSIONS.md" ] || { echo "STOP: $O/VERSIONS.md ($PREV's) not found"; exit 1; }
pgrep -f "build_image.sh|tools/release.sh|kernel-release.sh" >/dev/null && { echo "STOP: a build is running"; exit 1; }
sudo -v

cleanup() {
  for m in dev/pts dev proc sys boot/efi ""; do sudo umount "$MNT/$m" 2>/dev/null || true; done
  [ -n "${L:-}" ] && sudo losetup -d "$L" 2>/dev/null || true
}
trap cleanup EXIT
mount_img() {   # $1 = rw|ro, $2 = image (default: the new one)
  L=$(sudo losetup -fP --show "${2:-$IMG}"); sudo udevadm settle 2>/dev/null || true
  RP=$(for p in ${L}p*; do [ "$(sudo blkid -o value -s LABEL $p)" = bazzite-deck ] && echo $p && break; done)
  BP=$(for p in ${L}p*; do [ "$(sudo blkid -o value -s TYPE $p)" = vfat ] && echo $p && break; done)
  [ -n "$RP" ] && [ -n "$BP" ] || { echo "STOP: image partitions not found"; exit 1; }
  sudo mkdir -p "$MNT"; sudo mount -o "$1" "$RP" "$MNT"; sudo mkdir -p "$MNT/boot/efi"; sudo mount -o "$1" "$BP" "$MNT/boot/efi"
}
umount_img() { sync; for m in dev/pts dev proc sys boot/efi ""; do sudo umount "$MNT/$m" 2>/dev/null || true; done; sudo losetup -d "$L"; L=; }

step "image $PREV is the base"
mount_img ro "$IMG0"
BASEV=$(sudo cat "$MNT/etc/ps5-bazzite-deck-version"); KV=$(sudo ls "$MNT/usr/lib/modules")
umount_img
[ "$BASEV" = "$PREV" ] || { echo "STOP: $IMG0 is $BASEV, not $PREV"; exit 1; }
echo "   $IMG0: $BASEV, kernel $KV"

step "quick package $V"
NO_INSTALL=1 bash $SRC/tools/quick-kernel.sh $V ps5@none
[ "$(cat $Q/KERNEL)" = "$KV" ] || { echo "STOP: package kernel $(cat $Q/KERNEL), image kernel $KV"; exit 1; }

step "fresh image"
rm -f "$IMG"; cp --sparse=always "$IMG0" "$IMG"
mount_img rw
for d in dev dev/pts proc sys; do sudo mount --bind /$d "$MNT/$d"; done
sudo rm -rf "$MNT/var/tmp/ps5-quick-$V"; sudo cp -a "$Q" "$MNT/var/tmp/"
sudo mkdir -p "$MNT/var/tmp/ps5-quick-$V/bin"
printf '#!/bin/sh\nexec "$@"\n' | sudo tee "$MNT/var/tmp/ps5-quick-$V/bin/sudo" >/dev/null; sudo chmod 755 "$MNT/var/tmp/ps5-quick-$V/bin/sudo"
sudo chroot "$MNT" /usr/bin/env -i HOME=/root QUICK_KERNEL="$KV" \
  PATH="/var/tmp/ps5-quick-$V/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  bash /var/tmp/ps5-quick-$V/install.sh
sudo rm -rf "$MNT/var/tmp/ps5-quick-$V" "$MNT/var/lib/ps5-quick-kernel"
echo "$V" | sudo tee "$MNT/etc/ps5-bazzite-deck-version" >/dev/null

step "checking the image"
same() { [ "$(sudo sha256sum "$1" | cut -d' ' -f1)" = "$(sha256sum "$2" | cut -d' ' -f1)" ] || { echo "STOP: $1 differs from $2"; exit 1; }; echo "   ok: ${1#$MNT}"; }
MD=$MNT/usr/lib/modules/$KV/kernel
same "$MNT/boot/efi/bzImage" "$Q/bzImage"
same "$MD/drivers/gpu/drm/amd/amdgpu/amdgpu.ko.zst" "$Q/amdgpu.ko.zst"
same "$MD/drivers/bluetooth/btusb.ko.zst" "$Q/btusb.ko.zst"
[ -f "$Q/files/MAP" ] && while read -r f dest _; do same "$MNT$dest" "$Q/files/$f"; done < "$Q/files/MAP"
IP=$(sudo chroot "$MNT" lsinitrd /boot/efi/initrd.img 2>/dev/null | grep -o '[^ ]*amdgpu/amdgpu\.ko[a-z.]*' | sed -n 1p)
[ -n "$IP" ] || { echo "STOP: amdgpu not found in the image's initrd"; exit 1; }
sudo chroot "$MNT" lsinitrd -f "$IP" /boot/efi/initrd.img > /tmp/initrd-amdgpu
case "$IP" in *.zst) zstd -dc /tmp/initrd-amdgpu > /tmp/initrd-amdgpu.ko;; *) cp /tmp/initrd-amdgpu /tmp/initrd-amdgpu.ko;; esac
zstd -dc "$Q/amdgpu.ko.zst" > /tmp/quick-amdgpu.ko
cmp -s /tmp/initrd-amdgpu.ko /tmp/quick-amdgpu.ko || { echo "STOP: the initrd's amdgpu isn't the new one"; exit 1; }
echo "   ok: initrd $IP"; rm -f /tmp/initrd-amdgpu /tmp/initrd-amdgpu.ko /tmp/quick-amdgpu.ko
umount_img

step "update bundle"
IMG="$IMG" bash $SRC/tools/make-update-bundle.sh $V
(cd $O && sha256sum -c --quiet $N.tar.xz.sha256)
rm -rf /tmp/schk; mkdir /tmp/schk; tar -C /tmp/schk -xJf $O/$N.tar.xz
(cd /tmp/schk/$N && sha256sum -c --quiet SHA256SUMS && [ "$(cat VERSION)" = "$V" ] && cmp -s efi/bzImage $Q/bzImage) || { echo "STOP: bundle check failed"; exit 1; }
rm -rf /tmp/schk; echo "   bundle ok: outer and inner checksums, VERSION $V, new kernel"

step "7-Zip volumes (10-15 min) and their check against the image"
cd $O; rm -f ps5-bazzite-deck-$V.img.7z.* ps5-bazzite-deck-$V.sha256
rm -rf $O/s7; mkdir $O/s7; ln "$IMG" $O/s7/ps5-bazzite-deck.img
(cd $O/s7 && 7z a -mx=5 -mmt=on -v1900m $O/ps5-bazzite-deck-$V.img.7z ps5-bazzite-deck.img >/dev/null); rm -rf $O/s7   # the archive holds ps5-bazzite-deck.img, as every release
sha256sum ps5-bazzite-deck-$V.img.7z.* > ps5-bazzite-deck-$V.sha256; sha256sum -c --quiet ps5-bazzite-deck-$V.sha256
[ "$(7z x -so ps5-bazzite-deck-$V.img.7z.001 | sha256sum | cut -d' ' -f1)" = "$(sha256sum "$IMG" | cut -d' ' -f1)" ] || { echo "STOP: unpacked volumes differ from the image"; exit 1; }
echo "   volumes ok: checksums, and they unpack to exactly the $V image"

step "release files"
rm -rf $O/stable-$V; mkdir $O/stable-$V
sed "s/$PREV/$V/g" $O/VERSIONS.md > $O/stable-$V/VERSIONS.md
[ -f $O/local-changes.diff ] && cp $O/local-changes.diff $O/stable-$V/
for p in $(sed -n 's#.*apply "$SRC/patches/\([^"]*\)".*#\1#p' $SRC/build.sh); do cp $SRC/patches/$p $O/stable-$V/; done
read -r -p "== Publish $V as the latest release? (test the $V image or the quick package on a console first) [y/N] " ok
[ "$ok" = y ] || { echo "Not published. Everything is in $O"; exit 0; }

step "publish"
cd $SRC; git pull -q --rebase
sed -i "s/^## \[$V\] – [^ ]*/## [$V] – $(date +%F)/" CHANGELOG.md
git add -A; git commit -q -m "$V" || true; git push -q
git rev-parse -q --verify refs/tags/$V >/dev/null || { git tag -a $V -m $V; git push -q --tags; }
cd $O
gh release create $V ps5-bazzite-deck-$V.img.7z.* ps5-bazzite-deck-$V.sha256 $N.tar.xz $N.tar.xz.sha256 \
  --repo $R --latest --title "$V" --notes "Release notes follow."

step "checking what GitHub has"
rm -rf /tmp/schk; mkdir /tmp/schk; cd /tmp/schk
gh release download $V --repo $R -p "$N.tar.xz" -p "$N.tar.xz.sha256" -p "ps5-bazzite-deck-$V.sha256"
sha256sum -c --quiet $N.tar.xz.sha256 && tar xJf $N.tar.xz && (cd $N && sha256sum -c --quiet SHA256SUMS)
cmp -s ps5-bazzite-deck-$V.sha256 $O/ps5-bazzite-deck-$V.sha256 || { echo "STOP: published image checksums differ"; exit 1; }
for f in $O/ps5-bazzite-deck-$V.img.7z.*; do
  RS=$(gh release view $V --repo $R --json assets -q ".assets[] | select(.name==\"$(basename $f)\") | .size")
  [ "$RS" = "$(stat -c %s $f)" ] || { echo "STOP: $(basename $f) on GitHub is $RS bytes, local $(stat -c %s $f)"; exit 1; }
done
cd /; rm -rf /tmp/schk; echo "   published bundle and image volumes check out"

for t in ${UNPRERELEASE:-}; do
  [ "$(gh release view $t --repo $R --json isPrerelease -q .isPrerelease 2>/dev/null)" = true ] && gh release edit $t --repo $R --prerelease=false && echo "   $t: no longer a pre-release"
done
gh release edit $V --repo $R --latest >/dev/null
cd $SRC; python3 tools/release_notes.py >/dev/null
echo "PUBLISHED $V, latest: $(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/$R/releases/latest | sed 's#.*/##')"
