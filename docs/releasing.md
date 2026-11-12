# Releasing

`bash tools/release.sh vX.Y[.Z]` tags the release; `.github/workflows/release.yml` does the rest. The pre-release is public with its notes at once, and files are added as they're built: the kernel RPM, the bootc disk image, the bazzite-bootc-loader. The kernel builds on this PC's self-hosted runner; `release.sh` starts it if needed and stops it again after the kernel job. `gh workflow run release.yml -f tag=vX.Y -f hosted=true` uses GitHub's runner instead.

Before tagging: the CHANGELOG entry and `docs/release-notes/vX.Y.md`, cumulative since the last release people actually ran. Its sections, rendered in this order by `tools/release_notes.py`: **What's new** (Discord posts this part), **bootc** with *New install* and *Updating*, **Problems** (rollback, the previous stable version), **Known issues**, **What to test**, **Sharing logs**. Written plainly, without "we" or "our".

Legacy installs (from before v2.5) are no longer supported or built for, from v2.13 on: no update bundle, no Legacy section in the notes. `tools/legacy-to-bootc.sh` converts one in place; `tools/update-latest.sh`, their old update command, now points there.

Releases kept on GitHub: the current stable and the previous stable as the fallback, plus open pre-releases.

A failed part doesn't need a full rebuild: `gh workflow run release.yml -f tag=vX.Y -f resume=true` reuses the kernel RPM on the release and the `:vX.Y` image, and redoes the disk image and loader.

A new release's kernel becomes the kernel of `:beta` as soon as it is built (`pin-kernel.yml` from `release.yml`), and both images are rebuilt. After testers confirm: `gh release edit vX.Y --prerelease=false --latest`; `pin-kernel.yml` then pins it for `:stable` (and `:beta`, unless a newer pre-release is there) and rebuilds both. Both images are rebuilt every Monday with Bazzite's base updates, or with `gh workflow run bootc-build-image.yml`: `:stable` from the stable release's tag (only the pins come from `main`), `:beta` from `main`. A fix reaches Stable with the next stable release.

Who tests what before a pre-release is promoted: [testing.md](testing.md).

## Upstreaming

`tools/upstream-pr.sh` turns a patch into a pull request against a ps5-linux-patches-style repository (`--repo`). rmux's, the original target, was removed from GitHub in November 2026.

## X.Y releases rebase

Every X.Y release (not X.Y.Z) starts from the newest upstream loader, and from rmux's newest kernel branch while it was published. His repository was removed from GitHub in November 2026: `build.sh` takes his branch from our mirror, [VivaLaVent/ps5-linux-patches-rmux](https://github.com/VivaLaVent/ps5-linux-patches-rmux), at the pinned commit, and the kernel base moves only by our own choice now.

1. Run **Upstream audit** (Actions, or `bash tools/audit-upstream.sh`): which of `patches/` and `loader/patches/` still apply, which upstream already has, which conflict.
2. Drop what upstream has, port what conflicts, move the pins (`build.sh`: branch, commit and `KERNEL_TAG`; `loader/pins.env`).
3. Compile the changed files, then release as a pre-release for FLAVA3, Verde, Pro and original-PS5 testers.

The kernel is named `<version>-viva` (for example `7.3.3-viva`).
