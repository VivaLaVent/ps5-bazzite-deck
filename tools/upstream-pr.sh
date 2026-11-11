#!/bin/bash
# Our kernel patches as a PR against rmux's ps5-linux-patches (its kernel changes live in linux.patch):
#   bash tools/upstream-pr.sh "<title>" patches/a.patch [...] [--submit]       dry run without --submit
#   --base (build.sh's branch) --repo (rmuxnet/ps5-linux-patches-1) --tested "<what>" --config "<scripts/config args>"
# Needs gh and the kernel tree build.sh made; list unmerged prerequisite patches too, in order. The kernel version is
# upstream's (KERNEL_REF in its build.cfg), not ours. --submit needs --tested: what ran on which console, as it was seen.
set -euo pipefail
TITLE=${1:?usage: upstream-pr.sh "<title>" patches/x.patch ... [--submit]}; shift
SRC=$(cd "$(dirname "$0")/.." && pwd)
REPO=rmuxnet/ps5-linux-patches-1; BASE=$(sed -n 's/^PATCHES_BRANCH=\([^ ]*\).*/\1/p' "$SRC/build.sh"); SUBMIT=0; TESTED=""; CONFIG=""; PATCHES=()
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
[ "$SUBMIT" != 1 ] || [ -n "$TESTED" ] || { echo "STOP: --submit needs --tested \"<console, system software, what was seen>\""; exit 1; }
KSRC=${REPO_DIR:-$HOME/ps5-build-7.3}/work/linux73
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

KTAG=$(sed -n 's/^KERNEL_REF=//p' "$W/up/build.cfg" 2>/dev/null); KTAG=${KTAG:-$(sed -n 's/^KERNEL_TAG=//p' "$SRC/build.sh")}
git -C "$KSRC" rev-parse -q --verify "refs/tags/$KTAG" >/dev/null || git -C "$KSRC" fetch -q --depth 1 origin tag "$KTAG"
echo "==> kernel tree: $KTAG + upstream linux.patch ($BASE @ $UPSTREAM_COMMIT) + ${#PATCHES[@]} patch(es)"
git -C "$KSRC" worktree add -q -f "$W/k" "$KTAG"
git -C "$W/k" apply "$W/up/linux.patch"
git -C "$W/k" add -A
# the PR is only reviewable if regenerating upstream's linux.patch unchanged gives it back byte for byte
git -C "$W/k" -c core.abbrev=12 diff --cached | cmp -s - "$W/up/linux.patch" || { echo "STOP: linux.patch can't be regenerated identically from $KTAG; the PR would show unrelated changes"; exit 1; }
for p in "${PATCHES[@]}"; do
  git -C "$W/k" apply "$p" || { echo "STOP: $(basename "$p") does not apply on upstream $BASE @ $UPSTREAM_COMMIT (prerequisite missing, or upstream moved on)"; exit 1; }
  echo "    applied $(basename "$p")"
done
git -C "$W/k" add -A
git -C "$W/k" -c core.abbrev=12 diff --cached > "$W/up/linux.patch"
[ -n "$CONFIG" ] && { cp "$W/up/.config" "$W/k/.config"; (cd "$W/k" && ./scripts/config $CONFIG); cp "$W/k/.config" "$W/up/.config"; }

BODY="$W/body.md"
for p in "${PATCHES[@]}"; do sed -n '1,/^---$/p' "$p" | sed '$d'; echo; done > "$BODY"
[ -n "$TESTED" ] && printf '**Tested:** %s\n' "$TESTED" >> "$BODY"
printf '\nPrepared with AI assistance (Claude), reviewed and tested by me as stated.\nFrom https://github.com/VivaLaVent/ps5-bazzite-deck (%s). linux.patch regenerated with `git diff` (12-char abbrev) from %s + upstream linux.patch + this change, so the diff below is only the change itself.\n' "$(for p in "${PATCHES[@]}"; do echo "${p#"$SRC"/}"; done | paste -sd,)" "$KTAG" >> "$BODY"

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
