#!/bin/bash
# rmux's ps5-linux-loader @ 940bce3 + BLS patches 0001-0006.
# https://github.com/ps5-linux/ps5-linux-loader
# bash loader/build.sh [TAG]
set -euo pipefail

SRC="$(cd "$(dirname "$0")"/.. && pwd)"
. "$SRC/loader/pins.env"
TAG="${1:-$(git -C "$SRC" describe --tags 2>/dev/null || git -C "$SRC" rev-parse --short HEAD)}"
OUT="$SRC/loader/output"; mkdir -p "$OUT"

for cmd in clang-18 lld-18 xxd unzip git make gcc; do
  command -v "$cmd" >/dev/null || { echo "STOP: missing $cmd"; exit 1; }
done

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

echo "--- SDK $SDK_TAG"
gh release download "$SDK_TAG" --repo ps5-payload-dev/sdk \
  --pattern 'ps5-payload-sdk.zip' --output "$WORK/sdk.zip" --clobber
actual=$(sha256sum "$WORK/sdk.zip" | cut -d' ' -f1)
[ "$actual" = "$SDK_SHA256" ] || { echo "STOP: SDK sha256 mismatch: $actual"; exit 1; }
unzip -q "$WORK/sdk.zip" -d "$WORK/sdk"
SDK_DIR=$(find "$WORK/sdk" -maxdepth 1 -mindepth 1 -type d | head -1)

echo "--- upstream @ $LOADER_COMMIT"
git clone -q https://github.com/"$LOADER_REPO" "$WORK/loader"
git -C "$WORK/loader" checkout -q "$LOADER_COMMIT"
[ "$(git -C "$WORK/loader" rev-parse HEAD)" = "$LOADER_COMMIT" ] || \
  { echo "STOP: commit mismatch"; exit 1; }

echo "--- unpatched build (baseline shellcode headers)"
make -C "$WORK/loader" PS5_PAYLOAD_SDK="$SDK_DIR"
HEADER_HASHES=$(find "$WORK/loader" -path '*/shellcode_*/*.h' | sort | xargs sha256sum)
make -C "$WORK/loader" clean 2>/dev/null || true

echo "--- patches 0001-0006"
git -C "$WORK/loader" config user.email "ci@ps5-bazzite-deck"
git -C "$WORK/loader" config user.name "PS5 Bazzite Deck CI"
git -C "$WORK/loader" config user.email "ci@ps5-bazzite-deck"
git -C "$WORK/loader" config user.name "PS5 Bazzite Deck CI"
for n in 0001 0002 0003 0004 0005 0006; do
  p=$(ls "$SRC/loader/patches/${n}"-*.patch)
  git -C "$WORK/loader" am --no-gpg-sign "$p"
done

echo "--- host tests"
make -C "$WORK/loader/tests" 2>&1 | tail -3

echo "--- patched build"
BUILD_LOG=$(make -C "$WORK/loader" PS5_PAYLOAD_SDK="$SDK_DIR" 2>&1)
WARN=$(echo "$BUILD_LOG" | grep -c "warning:.*RWX" || true)
[ "$WARN" -eq 5 ] || echo "note: expected 5 RWX warnings, got $WARN"

echo "--- shellcode header check"
NEW_HASHES=$(find "$WORK/loader" -path '*/shellcode_*/*.h' | sort | xargs sha256sum)
if [ "$HEADER_HASHES" != "$NEW_HASHES" ]; then
  echo "STOP: shellcode headers changed (firmware paths must be byte-identical)"
  exit 1
fi
echo "shellcode headers: byte-identical"

echo "--- output"
ELF=$WORK/loader/bin/ps5-linux-loader.elf
cp "$ELF" "$OUT/ps5-linux-loader-$TAG.elf"
sha256sum "$OUT/ps5-linux-loader-$TAG.elf" | tee "$OUT/ps5-linux-loader-$TAG.elf.sha256"

KNOWN=89830d50324c3d10cefdbb1fbf1b9aeb0c6d2ea9d8cd15750eac39091ea42d3f
actual=$(cut -d' ' -f1 "$OUT/ps5-linux-loader-$TAG.elf.sha256")
if [ "$actual" = "$KNOWN" ]; then
  echo "known-good sha256 reproduced"
else
  echo "NOTE: got $actual (known-good: $KNOWN)"
fi
