#!/bin/bash
# Do the patches still apply to upstream's newest work? Kernel: rmux's default branch of ps5-linux-patches-1
# on the kernel it names; loader: the main branch of the loader in loader/pins.env. Read-only; prints a Markdown report.
#   bash tools/audit-upstream.sh [workdir]
set -uo pipefail
SRC=$(cd "$(dirname "$0")/.." && pwd); W=${1:-$(mktemp -d)}; mkdir -p "$W"
PIN=$(sed -n 's/^git -C work\/ps5-linux-patches checkout -q \([0-9a-f]*\).*/\1/p' "$SRC/build.sh")

echo "## Kernel: patches/ on rmux's newest branch"
git clone -q https://github.com/rmuxnet/ps5-linux-patches-1 "$W/rmux"
HEAD=$(git -C "$W/rmux" rev-parse --short HEAD); BR=$(git -C "$W/rmux" branch --show-current)
REF=$(sed -n 's/^KERNEL_REF=\(.*\)/\1/p' "$W/rmux/build.cfg" 2>/dev/null); REF=${REF:-v7.3.1}
echo "rmux $BR at $HEAD (built on $PIN), kernel $REF; $(git -C "$W/rmux" rev-list --count "$PIN..HEAD" 2>/dev/null || echo "?") new commits"
echo
case "$REF" in v*.*.*) URL=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git;; *) URL=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git;; esac
git clone -q --depth 1 --branch "$REF" "$URL" "$W/linux"
if git -C "$W/linux" apply --exclude=Makefile "$W/rmux/linux.patch"; then
  echo "| patch | on $BR $HEAD |"; echo "|---|---|"
  for p in $(grep -o '^[^# ]*\.patch' "$SRC/patches/series"); do
    if git -C "$W/linux" apply --check "$SRC/patches/$p" 2>/dev/null; then git -C "$W/linux" apply "$SRC/patches/$p"; r="applies"
    elif git -C "$W/linux" apply -R --check "$SRC/patches/$p" 2>/dev/null; then r="already upstream"
    else r="**conflicts**: $(git -C "$W/linux" apply --check "$SRC/patches/$p" 2>&1 | sed -n 's/^error: patch failed: //p' | head -3 | tr '\n' ' ')"; fi
    echo "| $p | $r |"
  done
else
  echo "rmux's linux.patch doesn't apply to $REF itself; check build.cfg"
fi

. "$SRC/loader/pins.env"
echo; echo "## Loader: loader/patches on $LOADER_REPO main"
git clone -q "https://github.com/$LOADER_REPO" "$W/loader"
LH=$(git -C "$W/loader" rev-parse --short HEAD)
echo "upstream main at $LH (built on ${LOADER_COMMIT:0:7}); $(git -C "$W/loader" rev-list --count "$LOADER_COMMIT..HEAD" 2>/dev/null || echo "?") new commits"
echo; echo "| patch | on main $LH |"; echo "|---|---|"
for p in "$SRC"/loader/patches/*.patch; do
  if git -C "$W/loader" -c user.name=a -c user.email=a@a am -q --3way "$p" >/dev/null 2>&1; then r="applies"
  else git -C "$W/loader" am --abort >/dev/null 2>&1; r="**conflicts**"; fi
  echo "| ${p##*/} | $r |"
done

echo; echo "## Other pins"
C=$(sed -n 's/^COMMIT=//p' "$SRC/tools/fetch-bt-sync.sh")
git clone -q https://github.com/ps5-linux/ps5-linux-patches "$W/official"
echo "- pairing importer (tools/fetch-bt-sync.sh): $(git -C "$W/official" rev-list --count "$C..HEAD" -- bluetooth 2>/dev/null || echo "?") new commits to bluetooth/ upstream"
B=$(sed -n 's/^BUILDER_COMMIT=\([0-9a-f]*\).*/\1/p' "$SRC/build.sh")
git clone -q https://github.com/ps5-linux/ps5-linux-image "$W/builder"
echo "- image builder (build.sh): $(git -C "$W/builder" rev-list --count "$B..HEAD" -- docker build_image.sh boot 2>/dev/null || echo "?") new commits to the kernel build"
