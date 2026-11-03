#!/bin/bash
# Kernel-only release: apply the named patches, build, test on the PS5, publish.
#   bash tools/kernel-release.sh vNEW vPREV patch-name...
#   PRERELEASE=1: quick package only · PROMOTE=1: swap a published quick kernel into vPREV's image and bundle
#   TITLE="..." (keep tools/release-titles.tsv in sync)
set -euo pipefail
V=${1:?vNEW}; PREV=${2:?vPREV}; shift 2
B=~/ps5-build-7.3; O=$B/output; K=$B/work/linux73; SRC=~/ps5-bazzite-deck; P=$SRC/patches
R=VivaLaVent/ps5-bazzite-deck; KB=$K/arch/x86/boot/bzImage; PS5=${PS5:-ps5@192.168.66.55}; N=ps5-bazzite-deck-$V-update
pgrep -f "build_image.sh|tools/release.sh" >/dev/null && { echo "STOP: a build is running"; exit 1; }   # not "release.sh": that matches this script itself
if [ -n "${PROMOTE:-}" ]; then
  [ "$(gh release view $V --repo $R --json isPrerelease -q .isPrerelease 2>/dev/null)" = true ] || { echo "STOP: $V isn't a published pre-release"; exit 1; }
else
  gh release view $V --repo $R >/dev/null 2>&1 && { echo "STOP: $V is already released"; exit 1; }
fi
[ -f $SRC/docs/release-notes/$V.md ] && [ -f $SRC/docs/update-sections/$V.md ] || { echo "STOP: notes for $V missing"; exit 1; }
[ -n "${PRERELEASE:-}" ] || { [ -f $O/ps5-bazzite-deck.img ] && [ -f $O/ps5-bazzite-deck-$PREV-update.tar.xz ]; } || { echo "STOP: $PREV image/bundle missing in $O"; exit 1; }
sudo -v
if [ -z "${PROMOTE:-}" ]; then
echo "== kernel tree"; cd $K
for p in "$@"; do
  if git apply -R --check $P/$p.patch 2>/dev/null; then echo "   already in: $p"
  elif git apply --check $P/$p.patch 2>/dev/null; then git apply $P/$p.patch; echo "   applied: $p"
  else echo "STOP: $p doesn't fit the kernel tree"; exit 1; fi
done
echo "== build"; NO_INSTALL=1 bash $SRC/tools/quick-kernel.sh $V ps5@none
cd $O
read -r -p "== Install $V on the PS5 now? [Y/n] " inst
if [ "$inst" != n ] && [ "$inst" != N ]; then
  ping -c1 -W2 ${PS5#*@} >/dev/null || { echo "STOP: PS5 not reachable"; exit 1; }
  scp ps5-quick-$V.tar.gz $PS5:~
  ssh -t $PS5 "rm -rf ps5-quick-$V && tar xzf ps5-quick-$V.tar.gz && bash ps5-quick-$V/install.sh && sudo systemctl reboot" || true
else
  echo "   not installed on the PS5"
fi
read -r -p "== Start Linux with the loader and test. Publish $V as $([ -n "${PRERELEASE:-}" ] && echo a pre-release || echo the stable release)? [y/N] " ok
[ "$ok" = y ] || { echo "Not published."; exit 0; }
fi
cd $O
if [ -n "${PRERELEASE:-}" ]; then
  echo "== publish (pre-release, quick kernel)"; cd $SRC; git pull -q --rebase
  sed -i "s/^## \[$V\] – [^ ]*/## [$V] – $(date +%F)/" CHANGELOG.md
  git add -A; git commit -q -m "$V" || true; git push -q
  git rev-parse -q --verify refs/tags/$V >/dev/null || { git tag -a $V -m $V; git push -q --tags; }
  gh release create $V $O/ps5-quick-$V.tar.gz --repo $R --prerelease --title "${TITLE:-$V}" --notes "Release notes follow."
  python3 tools/release_notes.py >/dev/null
  echo "PUBLISHED $V (pre-release)"; exit 0
fi
sudo -v; [ $KB -nt $K/drivers/ps5/hdmi.c ]
echo "== image"; L=$(sudo losetup -fP --show ps5-bazzite-deck.img); sudo mkdir -p /mnt/krb /mnt/krr
BP=$(for p in ${L}p*; do [ "$(sudo blkid -o value -s TYPE $p)" = vfat ] && echo $p && break; done)
RP=$(for p in ${L}p*; do [ "$(sudo blkid -o value -s LABEL $p)" = bazzite-deck ] && echo $p && break; done)
sudo mount $BP /mnt/krb; sudo test -f /mnt/krb/bzImage; sudo cp $KB /mnt/krb/bzImage; sync; sudo umount /mnt/krb
sudo mount $RP /mnt/krr; VF=$(sudo find /mnt/krr -maxdepth 4 -path '*/etc/ps5-bazzite-deck-version' | head -1); [ -n "$VF" ]
echo $V | sudo tee "$VF" >/dev/null; E2=$(dirname "$VF"); for u in bootloader-update.service greenboot-healthcheck.service greenboot-success.target; do sudo ln -sf /dev/null "$E2/systemd/system/$u"; done; for z in $(sudo find /mnt/krr -maxdepth 6 -path '*/usr/lib/modules/*/vmlinuz'); do sudo cp $KB "$z"; done
sync; sudo umount /mnt/krr; sudo losetup -d $L
echo "== update bundle"; rm -rf /tmp/krel; mkdir /tmp/krel
tar -C /tmp/krel -xJf ps5-bazzite-deck-$PREV-update.tar.xz; mv /tmp/krel/ps5-bazzite-deck-$PREV-update /tmp/krel/$N
cp $KB /tmp/krel/$N/efi/bzImage; echo $V > /tmp/krel/$N/VERSION; cp $SRC/tools/update.sh /tmp/krel/$N/update.sh
(cd /tmp/krel/$N && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS && sha256sum -c --quiet SHA256SUMS)
tar -C /tmp/krel -cJf $N.tar.xz $N; sha256sum $N.tar.xz > $N.tar.xz.sha256; rm -rf /tmp/krel
mkdir /tmp/krel; tar -C /tmp/krel -xJf $N.tar.xz; (cd /tmp/krel/$N && sha256sum -c --quiet SHA256SUMS); rm -rf /tmp/krel; echo "   bundle verified"
sed -i "s/$PREV/$V/g" VERSIONS.md; for p in "$@"; do cp $P/$p.patch .; done
echo "== 7-Zip volumes (10-15 min)"; rm -f ps5-bazzite-deck-$V.img.7z.*
7z a -mx=5 -mmt=on -v1900m ps5-bazzite-deck-$V.img.7z ps5-bazzite-deck.img >/dev/null; sha256sum ps5-bazzite-deck-$V.img.7z.* > ps5-bazzite-deck-$V.sha256
echo "== publish"; cd $SRC; git pull -q --rebase
sed -i "s/^## \[$V\] – [^ ]*/## [$V] – $(date +%F)/" CHANGELOG.md
d=$(gh release view $PREV --repo $R --json publishedAt -q .publishedAt | cut -c1-10); sed -i "s/^## \[$PREV\] – [^ ]*/## [$PREV] – $d/" CHANGELOG.md
git add -A; git commit -q -m "$V" || true; git push -q
git rev-parse -q --verify refs/tags/$V >/dev/null || { git tag -a $V -m $V; git push -q --tags; }
cd $O
if [ -n "${PROMOTE:-}" ]; then
  gh release upload $V ps5-bazzite-deck-$V.img.7z.* ps5-bazzite-deck-$V.sha256 $N.tar.xz $N.tar.xz.sha256 VERSIONS.md local-changes.diff --repo $R --clobber
  gh release edit $V --repo $R --prerelease=false --latest --title "${TITLE:-$V}"
else
  gh release create $V ps5-bazzite-deck-$V.img.7z.* ps5-bazzite-deck-$V.sha256 $N.tar.xz $N.tar.xz.sha256 VERSIONS.md local-changes.diff ./*.patch --repo $R --title "${TITLE:-$V}" --notes "Release notes follow."
fi
echo "== checking the published bundle (the v1.7.1 SHA256SUMS problem)"
rm -rf /tmp/kchk; mkdir /tmp/kchk; (cd /tmp/kchk && gh release download $V --repo $R -p "$N.tar.xz" -p "$N.tar.xz.sha256" && sha256sum -c --quiet $N.tar.xz.sha256 && tar xJf $N.tar.xz && cd $N && sha256sum -c --quiet SHA256SUMS && [ "$(cat VERSION)" = $V ]) && echo "   published bundle verified: outer checksum, inner SHA256SUMS, VERSION $V" || { echo "STOP: the published bundle doesn't verify"; exit 1; }; rm -rf /tmp/kchk
cd $SRC; python3 tools/release_notes.py >/dev/null
echo "PUBLISHED $V, latest: $(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/$R/releases/latest | sed 's#.*/##')"
