#!/bin/bash
# A change set as a PR against another repository (for the ones upstream-pr.sh doesn't fit: no linux.patch):
#   bash tools/repo-pr.sh <owner/repo> "<title>" <change.patch> <body.md> --tested "<what ran where>" [--submit]
# Dry run without --submit. The body file is the description; the tested line and the source are appended.
set -euo pipefail
REPO=${1:?usage: repo-pr.sh <owner/repo> "<title>" <change.patch> <body.md> --tested "..." [--submit]}; TITLE=$2
SRC=$(cd "$(dirname "$0")/.." && pwd); CHANGE=$(readlink -f "$3"); BODYSRC=$(readlink -f "$4"); shift 4
SUBMIT=0; TESTED=""
while [ $# -gt 0 ]; do case "$1" in --submit) SUBMIT=1 ;; --tested) TESTED=$2; shift ;; esac; shift; done
[ -n "$TESTED" ] || { echo "STOP: --tested \"<console, system software, what was seen>\" is required"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "STOP: gh is not logged in"; exit 1; }
ME=$(gh api user -q .login); BRANCH="pr/$(basename "$CHANGE" .patch)"
W=$(mktemp -d /tmp/repo-pr.XXXX); trap 'rm -rf "$W"' EXIT
git clone -q "https://github.com/$REPO" "$W/up"
git -C "$W/up" apply --check "$CHANGE" || { echo "STOP: $(basename "$CHANGE") does not apply on $REPO (upstream moved on)"; exit 1; }
git -C "$W/up" apply "$CHANGE"
{ cat "$BODYSRC"; printf '\n**Tested:** %s\n\nPrepared with AI assistance (Claude), reviewed and tested by me as stated.\nFrom https://github.com/VivaLaVent/ps5-bazzite-deck (%s).\n' "$TESTED" "${CHANGE#"$SRC"/}"; } > "$W/body.md"
echo "==> $REPO: $TITLE"; git -C "$W/up" add -A; git -C "$W/up" diff --cached --stat | tail -4; sed 's/^/    /' "$W/body.md"
if [ "$SUBMIT" != 1 ]; then echo "==> dry run only. Add --submit to push $BRANCH to $ME's fork and open the PR."; exit 0; fi
gh repo fork "$REPO" --clone=false >/dev/null 2>&1 || true
git -C "$W/up" checkout -q -b "$BRANCH"
git -C "$W/up" -c user.name="$ME" -c user.email="$(gh api user -q '.email // empty')" commit -q -F - <<< "$TITLE

$(cat "$W/body.md")"
git -C "$W/up" remote add fork "https://github.com/$ME/$(basename "$REPO").git"
git -C "$W/up" push -q fork "$BRANCH"
gh pr create --repo "$REPO" --head "$ME:$BRANCH" --title "$TITLE" --body-file "$W/body.md"
