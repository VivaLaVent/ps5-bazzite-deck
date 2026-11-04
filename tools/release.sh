#!/bin/bash
# Tag a release. .github/workflows/release.yml then builds everything and publishes a pre-release:
# kernel RPM, update bundle for existing installs, bazzite-bootc-loader, bootc image and disk image.
#   bash tools/release.sh vX.Y[.Z]
# Promote a tested pre-release:  gh release edit vX.Y --prerelease=false --latest
set -euo pipefail
V=${1:?usage: release.sh vX.Y[.Z]}
cd "$(dirname "$0")/.."
[ -f "docs/release-notes/$V.md" ] && [ -f "docs/update-sections/$V.md" ] || { echo "STOP: docs/release-notes/$V.md or docs/update-sections/$V.md missing"; exit 1; }
grep -q "^## \[$V\]" CHANGELOG.md || { echo "STOP: no CHANGELOG entry for $V"; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo "STOP: uncommitted changes"; exit 1; }
git fetch -q origin main --tags
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "STOP: not at origin/main"; exit 1; }
git rev-parse -q --verify "refs/tags/$V" >/dev/null && { echo "STOP: tag $V exists"; exit 1; }
sed -i "s/^## \[$V\] – .*/## [$V] – $(date +%F)/" CHANGELOG.md
git commit -qam "$V" && git push -q
pgrep -f "actions-runner/bin/Runner.Listener" >/dev/null || echo "The kernel job waits for the self-hosted runner: start ~/actions-runner/run.sh"
git tag -a "$V" -m "$V" && git push -q origin "$V"
echo "Building $V in CI: https://github.com/VivaLaVent/ps5-bazzite-deck/actions/workflows/release.yml"
