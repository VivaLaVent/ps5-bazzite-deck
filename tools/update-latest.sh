#!/bin/bash
# In-place update to the latest release, or to a given version. On the PS5:
#   bash <(curl -fsSL https://raw.githubusercontent.com/VivaLaVent/ps5-bazzite-deck/main/tools/update-latest.sh) [vX.Y.Z]
set -euo pipefail
REPO=VivaLaVent/ps5-bazzite-deck
V=${1:-}
if [ -z "$V" ]; then
  # github.com/<repo>/releases/latest redirects to .../releases/tag/<latest version>
  LATEST=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest") ||
    { echo "STOP: can't reach GitHub (network?)"; exit 1; }
  V=${LATEST##*/}
  case "$V" in v[0-9]*) ;; *) echo "STOP: couldn't find the latest version (got '$V')"; exit 1 ;; esac
fi
case "$V" in ""|*[!A-Za-z0-9._-]*) echo "STOP: invalid version '$V'"; exit 1 ;; esac

CUR=$(cat /etc/ps5-bazzite-deck-version 2>/dev/null || echo "unknown (v1.0.6 or older)")
echo "installed: $CUR"
echo "update to: $V"
[ "$CUR" = "$V" ] && { echo "Already on $V, nothing to do."; exit 0; }

cd ~
F=ps5-bazzite-deck-$V-update.tar.xz; D=${F%.tar.xz}
URL=https://github.com/$REPO/releases/download/$V/$F
curl -fL -o "$F.sha256" "$URL.sha256" || { echo "STOP: $V has no update bundle"; exit 1; }
curl -fL -o "$F" "$URL"
sha256sum -c "$F.sha256"
rm -rf "$D" && tar xJf "$F"
bash "$D/update.sh"
echo
echo "Now reboot (sudo reboot) and run the loader as usual. Anything to do after updating is in the release notes:"
echo "https://github.com/$REPO/releases/tag/$V"
