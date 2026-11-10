#!/bin/bash
# The PS5 pairing importer from ps5-linux-patches (bluetooth/ps5-bt-sync), fetched at a pinned commit into files/
# for the update bundle and the bootc image. Upstream's file, unchanged; it isn't kept in this repository.
set -euo pipefail
COMMIT=7842e1882b969da575acf6599574e7cf4d5477cf
SHA256=1b79c9cd8059d1f4e3757bb78b64f8aa53003dfcb5190bb752b7b5a879fa40ee
OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/files/ps5-bt-sync"
[ -f "$OUT" ] && [ "$(sha256sum "$OUT" | cut -d' ' -f1)" = "$SHA256" ] && exit 0
curl -fsSL --retry 3 -o "$OUT.tmp" "https://raw.githubusercontent.com/ps5-linux/ps5-linux-patches/$COMMIT/bluetooth/ps5-bt-sync"
[ "$(sha256sum "$OUT.tmp" | cut -d' ' -f1)" = "$SHA256" ] || { rm -f "$OUT.tmp"; echo "STOP: ps5-bt-sync sha256 mismatch"; exit 1; }
mv "$OUT.tmp" "$OUT"
