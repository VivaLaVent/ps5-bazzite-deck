#!/bin/bash
# bazzite-bootc-loader: soniciso1's ps5-linux-loader (PS5 Pro GPU firmware offsets) + loader/patches.
#   bash loader/build.sh [TAG]
set -euo pipefail

SRC="$(cd "$(dirname "$0")"/.. && pwd)"
. "$SRC/loader/pins.env"
TAG="${1:-$(git -C "$SRC" describe --tags 2>/dev/null || git -C "$SRC" rev-parse --short HEAD)}"
OUT="$SRC/loader/output"; mkdir -p "$OUT"

for cmd in clang-18 lld-18 xxd unzip git make gcc curl; do
  command -v "$cmd" >/dev/null || { echo "STOP: missing $cmd"; exit 1; }
done

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

echo "--- SDK $SDK_TAG"
curl -fsSL -o "$WORK/sdk.zip" "https://github.com/ps5-payload-dev/sdk/releases/download/$SDK_TAG/ps5-payload-sdk.zip"
actual=$(sha256sum "$WORK/sdk.zip" | cut -d' ' -f1)
[ "$actual" = "$SDK_SHA256" ] || { echo "STOP: SDK sha256 mismatch: $actual"; exit 1; }
unzip -q "$WORK/sdk.zip" -d "$WORK/sdk"
SDK_DIR=$(find "$WORK/sdk" -maxdepth 1 -mindepth 1 -type d | sed -n 1p)

echo "--- $LOADER_REPO @ $LOADER_COMMIT"
git clone -q https://github.com/"$LOADER_REPO" "$WORK/loader"
git -C "$WORK/loader" checkout -q "$LOADER_COMMIT"

echo "--- unpatched build (baseline shellcode headers)"
make -C "$WORK/loader" PS5_PAYLOAD_SDK="$SDK_DIR" >/dev/null
HEADER_HASHES=$(find "$WORK/loader" -path '*/shellcode_*/*.h' | sort | xargs sha256sum)
git -C "$WORK/loader" clean -qfdx

echo "--- patches"
for p in "$SRC"/loader/patches/*.patch; do
  git -C "$WORK/loader" -c user.email="ci@ps5-bazzite-deck" -c user.name="PS5 Bazzite Deck CI" am -q --no-gpg-sign "$p"
done

echo "--- patched build"
make -C "$WORK/loader" PS5_PAYLOAD_SDK="$SDK_DIR" >/dev/null
NEW_HASHES=$(find "$WORK/loader" -path '*/shellcode_*/*.h' | sort | xargs sha256sum)
[ "$HEADER_HASHES" = "$NEW_HASHES" ] || { echo "STOP: shellcode headers changed (firmware paths must be byte-identical)"; exit 1; }
echo "shellcode headers: byte-identical"

cp "$WORK/loader/bin/ps5-linux-loader.elf" "$OUT/bazzite-bootc-loader-$TAG.elf"
(cd "$OUT" && sha256sum "bazzite-bootc-loader-$TAG.elf" | tee "bazzite-bootc-loader-$TAG.elf.sha256")
