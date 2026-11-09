#!/bin/bash
# Tag a release. .github/workflows/release.yml then builds everything and publishes a pre-release:
# kernel RPM, update bundle for existing installs, bazzite-bootc-loader, bootc image and disk image.
#   bash tools/release.sh vX.Y[.Z]
# Promote a tested pre-release:  gh release edit vX.Y --prerelease=false --latest
set -euo pipefail
V=${1:?usage: release.sh vX.Y[.Z]}
cd "$(dirname "$0")/.."
[ -f "docs/release-notes/$V.md" ] || { echo "STOP: docs/release-notes/$V.md missing"; exit 1; }
grep -q "^## \[$V\]" CHANGELOG.md || { echo "STOP: no CHANGELOG entry for $V"; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo "STOP: uncommitted changes"; exit 1; }
git fetch -q origin main --tags
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "STOP: not at origin/main"; exit 1; }
git rev-parse -q --verify "refs/tags/$V" >/dev/null && { echo "STOP: tag $V exists"; exit 1; }
# the kernel builds on this PC's self-hosted runner: start it if needed, stop it again after the kernel job
RUNNER=~/actions-runner; STARTED=0
if ! pgrep -f "Runner.Listener" >/dev/null; then
  [ -x "$RUNNER/run.sh" ] || { echo "STOP: no runner in $RUNNER (docs/releasing.md)"; exit 1; }
  nohup "$RUNNER/run.sh" > "$RUNNER/release.log" 2>&1 &
  for _ in $(seq 1 90); do grep -q "Listening for Jobs" "$RUNNER/release.log" && break; sleep 2; done
  grep -q "Listening for Jobs" "$RUNNER/release.log" || { echo "STOP: the runner didn't connect, see $RUNNER/release.log"; exit 1; }
  STARTED=1; echo "runner started (log: $RUNNER/release.log)"
fi
sed -i "s/^## \[$V\] – .*/## [$V] – $(date +%F)/" CHANGELOG.md
git diff --quiet || { git commit -qam "$V" && git push -q; }
git tag -a "$V" -m "$V" && git push -q origin "$V"
echo "Building $V in CI: https://github.com/VivaLaVent/ps5-bazzite-deck/actions/workflows/release.yml"
[ "$STARTED" = 1 ] || exit 0
R=VivaLaVent/ps5-bazzite-deck; ID=
for _ in $(seq 1 30); do ID=$(gh run list --repo "$R" --workflow release.yml --branch "$V" --limit 5 --json databaseId,headSha -q ".[] | select(.headSha==\"$(git rev-parse HEAD)\") | .databaseId" | head -1); [ -n "$ID" ] && break; sleep 5; done
[ -n "$ID" ] || { echo "STOP: no release run for $(git rev-parse --short HEAD) after 150 s; the runner keeps running"; exit 1; }
echo "kernel building on this PC (run $ID); the runner stops when that job is done"
until [ "$(gh run view "$ID" --repo "$R" --json jobs -q '.jobs[] | select(.name=="kernel") | .status' 2>/dev/null)" = completed ]; do sleep 30; done
echo "kernel job: $(gh run view "$ID" --repo "$R" --json jobs -q '.jobs[] | select(.name=="kernel") | .conclusion')"
pkill -f "Runner.Listener"; pkill -f "actions-runner/run.sh" 2>/dev/null || true
echo "runner stopped; the rest of the release continues on GitHub"
