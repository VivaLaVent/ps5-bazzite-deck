#!/bin/bash
# Build, test and publish a release:
#   bash tools/release.sh vX.Y "title"                                stable: image + update bundle
#   PRERELEASE=1 BUNDLE_ONLY=1 bash tools/release.sh vX.Y.Z "title"  pre-release: bundle only
#   NO_DEPLOY=1: no test install or publish question · FRESH=1: from-scratch build.sh first
# Uses ~/ps5-build-7.3/work/linux73 as it is; publishes only after you confirm the PS5 works.
set -euo pipefail
V=${1:?usage: release.sh vX.Y.Z "title"}
TITLE=${2:?usage: release.sh vX.Y.Z "title"}
R=VivaLaVent/ps5-bazzite-deck; B=~/ps5-build-7.3; SRC=~/ps5-bazzite-deck; PS5=${PS5:-ps5@192.168.66.55}

cd "$SRC"
[ -f "docs/release-notes/$V.md" ] && [ -f "docs/update-sections/$V.md" ] || { echo "STOP: docs/release-notes/$V.md or docs/update-sections/$V.md missing"; exit 1; }
pgrep -f build_image.sh >/dev/null && { echo "STOP: a build is running"; exit 1; }
gh release view "$V" --repo "$R" >/dev/null 2>&1 && { echo "STOP: $V is already released"; exit 1; }
FREE=$(df --output=avail -BG "$HOME" | tail -1 | tr -dc 0-9)
echo "free space: ${FREE}G"; [ "$FREE" -ge 60 ] || { echo "STOP: need at least 60G free"; exit 1; }

if [ -n "${FRESH:-}" ]; then
  echo "==> FRESH: from-scratch build with build.sh (the previous build dir is kept as $B.prev)"
  [ -d "$B" ] && { sudo rm -rf "$B.prev"; mv "$B" "$B.prev"; }   # the old build dir holds root-owned files (chroot)
  OLD="$B.prev" SKIP_7Z=1 RELEASE="$V" bash "$SRC/build.sh"
  cd "$B"
  [ -f "output/ps5-bazzite-deck-$V-update.tar.xz" ] || { echo "STOP: build.sh produced no bundle"; exit 1; }
else
echo "==> build image + update bundle ($V)"
cd "$B"
# root-owned; the builder would reuse them instead of building
sudo mkdir -p linux-bin-prev && (sudo mv linux-bin/*.rpm linux-bin-prev/ 2>/dev/null || true)
[ "$(ls linux-bin/*.rpm 2>/dev/null | wc -l)" = 0 ] || { echo "STOP: old kernel packages still in linux-bin"; exit 1; }
sudo rm -rf work/chroot
./build_image.sh --distro bazzite-deck --kernel "$PWD/work/linux73"
printf 'set -euo pipefail\nSRC=%s\nRELEASE=%s\nREPO=%s\nKERNEL_TAG=v7.3\nPATCHES_BRANCH=meower\nBUILDER_COMMIT=52db0a4\nIMG=output/ps5-bazzite-deck.img\ncd "$REPO"\n' "$SRC" "$V" "$PWD" > /tmp/finish.sh
sed -n '/==> 5\. post-build/,$p' "$SRC/build.sh" >> /tmp/finish.sh
sudo -v
SKIP_7Z=1 bash /tmp/finish.sh
# release assets only: drop patch files left by earlier builds that are no longer in the repo
for f in output/*.patch; do [ -f "$SRC/patches/$(basename "$f")" ] || rm -f "$f"; done
fi
BUNDLE=ps5-bazzite-deck-$V-update.tar.xz

if [ -n "${NO_DEPLOY:-}" ]; then
  echo "==> NO_DEPLOY: no install on the PS5, publishing straight away"
else
  echo "==> install on the PS5 ($PS5)"
  scp "output/$BUNDLE" "$PS5:~" && ssh -t "$PS5" "rm -rf ps5-bazzite-deck-$V-update && tar xJf $BUNDLE && bash ps5-bazzite-deck-$V-update/update.sh && sudo systemctl reboot" || echo "(install on the PS5 failed or the PS5 is offline: install it yourself before answering)"
  echo
  read -r -p "Boot the PS5 with the loader and test it. Publish $V now? [y/N] " OK
  [ "$OK" = y ] || { echo "Not published. The bundle is in $B/output."; exit 0; }
fi

IMGFILES=()
if [ -z "${BUNDLE_ONLY:-}" ]; then
  echo "==> 7-Zip volumes"
  cd "$B/output"
  rm -f "ps5-bazzite-deck-$V.img.7z".*
  7z a -mx=5 -mmt=on -v1900m "ps5-bazzite-deck-$V.img.7z" ps5-bazzite-deck.img >/dev/null
  sha256sum "ps5-bazzite-deck-$V.img.7z".* > "ps5-bazzite-deck-$V.sha256"
  IMGFILES=("ps5-bazzite-deck-$V.img.7z".* "ps5-bazzite-deck-$V.sha256")
else
  echo "==> update bundle only (no image volumes)"
fi

echo "==> changelog date, commit, tag"
cd "$SRC"
sed -i "s/^## \[$V\] – .*/## [$V] – $(date +%F)/" CHANGELOG.md
git add -A && (git commit -q -m "$V" || true) && git push
git rev-parse -q --verify "refs/tags/$V" >/dev/null || { git tag -a "$V" -m "$V" && git push --tags; }

echo "==> GitHub release"
cd "$B/output"
gh release create "$V" "${IMGFILES[@]}" "$BUNDLE" "$BUNDLE.sha256" VERSIONS.md local-changes.diff ./*.patch ${PRERELEASE:+--prerelease} \
  --repo "$R" --title "$TITLE" --notes "Release notes follow."
cd "$SRC" && python3 tools/release_notes.py
echo "https://github.com/$R/releases/tag/$V"
