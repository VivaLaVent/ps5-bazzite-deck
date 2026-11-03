#!/bin/bash
# Our kernel patches as a PR against rmux's ps5-linux-patches (its kernel changes live in linux.patch):
#   bash tools/upstream-pr.sh "<title>" patches/a.patch [...] [--submit]       dry run without --submit
#   --base (meower) --repo (rmuxnet/ps5-linux-patches-1) --tested "<what>" --config "<scripts/config args>"
# Needs gh and ~/ps5-build-7.3/work/linux73 at v7.3; list unmerged prerequisite patches too, in order.
set -euo pipefail
TITLE=${1:?usage: upstream-pr.sh "<title>" patches/x.patch ... [--submit]}; shift
REPO=rmuxnet/ps5-linux-patches-1; BASE=meower; SUBMIT=0; TESTED=""; CONFIG=""; PATCHES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --submit) SUBMIT=1 ;;
    --base) BASE=$2; shift ;;
    --repo) REPO=$2; shift ;;
    --tested) TESTED=$2; shift ;;
    --config) CONFIG=$2; shift ;;
    *) PATCHES+=("$(readlink -f "$1")") ;;
  esac; shift
done
[ ${#PATCHES[@]} -gt 0 ] || { echo "no patches given"; exit 1; }
KSRC=~/ps5-build-7.3/work/linux73
[ -d "$KSRC/.git" ] || { echo "STOP: kernel checkout $KSRC not found"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "STOP: gh is not logged in"; exit 1; }
ME=$(gh api user -q .login)
SLUG=$(basename "${PATCHES[0]}" .patch); BRANCH="pr/$SLUG"
W=$(mktemp -d /tmp/upstream-pr.XXXX); trap 'rm -rf "$W"; git -C "$KSRC" worktree prune' EXIT

echo "==> fork of $REPO for $ME"
gh repo fork "$REPO" --clone=false >/dev/null 2>&1 || true
git clone -q "https://github.com/$REPO" "$W/up"
git -C "$W/up" checkout -q "$BASE"
UPSTREAM_COMMIT=$(git -C "$W/up" rev-parse --short HEAD)

echo "==> kernel tree: v7.3 + upstream linux.patch ($BASE @ $UPSTREAM_COMMIT) + ${#PATCHES[@]} patch(es)"
git -C "$KSRC" worktree add -q -f "$W/k" v7.3
git -C "$W/k" apply --exclude=Makefile "$W/up/linux.patch"
for p in "${PATCHES[@]}"; do
  git -C "$W/k" apply "$p" || { echo "STOP: $(basename "$p") does not apply on upstream $BASE @ $UPSTREAM_COMMIT (prerequisite missing, or upstream moved on)"; exit 1; }
  echo "    applied $(basename "$p")"
done
git -C "$W/k" add -A
git -C "$W/k" -c core.abbrev=12 diff --cached > "$W/up/linux.patch"
[ -n "$CONFIG" ] && { cp "$W/up/.config" "$W/k/.config"; (cd "$W/k" && ./scripts/config $CONFIG); cp "$W/k/.config" "$W/up/.config"; }

BODY="$W/body.md"
for p in "${PATCHES[@]}"; do sed -n '1,/^---$/p' "$p" | sed '$d'; echo; done > "$BODY"
[ -n "$TESTED" ] && printf '**Firmware and models tested:** %s\n' "$TESTED" >> "$BODY"
printf '\nFrom https://github.com/VivaLaVent/ps5-bazzite-deck (patches/%s). linux.patch regenerated with `git diff` (12-char abbrev) from v7.3 + upstream linux.patch + this change, so the diff below is only the change itself.\n' "$(for p in "${PATCHES[@]}"; do basename "$p"; done | paste -sd,)" >> "$BODY"

echo "==> resulting change to upstream (linux.patch$( [ -n "$CONFIG" ] && echo ", .config")):"
git -C "$W/up" diff --stat | tail -3
echo "==> PR body:"; sed 's/^/    /' "$BODY"
if [ "$SUBMIT" != 1 ]; then echo "==> dry run only. Add --submit to push branch $BRANCH to $ME's fork and open the PR."; exit 0; fi

git -C "$W/up" checkout -q -b "$BRANCH"
git -C "$W/up" add -A
git -C "$W/up" -c user.name="$ME" -c user.email="$(gh api user -q '.email // empty')" commit -q -F - <<< "$TITLE

$(cat "$BODY")"
git -C "$W/up" remote add fork "https://github.com/$ME/$(basename "$REPO").git"
git -C "$W/up" push -q fork "$BRANCH"
gh pr create --repo "$REPO" --base "$BASE" --head "$ME:$BRANCH" --title "$TITLE" --body-file "$BODY"
