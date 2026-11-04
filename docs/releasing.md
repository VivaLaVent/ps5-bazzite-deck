# Releasing

`bash tools/release.sh vX.Y[.Z]` tags the release; `.github/workflows/release.yml` does the rest. The pre-release is public with its notes at once, and files are added as they're built: the kernel RPM, the update bundle for existing installs, the bootc disk image, the bazzite-bootc-loader. The kernel builds on this PC's self-hosted runner; `release.sh` starts it if needed and stops it again after the kernel job. `gh workflow run release.yml -f tag=vX.Y -f hosted=true` uses GitHub's runner instead.

Before tagging: the CHANGELOG entry, `docs/release-notes/vX.Y.md` (cumulative since the last release people actually ran) and `docs/update-sections/vX.Y.md`.

A failed part doesn't need a full rebuild: `gh workflow run release.yml -f tag=vX.Y -f resume=true` reuses the kernel RPM on the release and the `:vX.Y` image, and redoes the bundle, disk image and loader.

After testers confirm: `gh release edit vX.Y --prerelease=false --latest`. That makes it the release `update-latest.sh` installs and, through `pin-kernel.yml`, the kernel of the nightly `:stable` bootc image.

## X.Y releases rebase

Every X.Y release (not X.Y.Z) starts from rmux's newest kernel branch and the newest upstream loader:

1. Run **Upstream audit** (Actions, or `bash tools/audit-upstream.sh`): which of `patches/` and `loader/patches/` still apply, which upstream already has, which conflict.
2. Drop what upstream has, port what conflicts, move the pins (`build.sh`: branch, commit and `KERNEL_TAG`; `loader/pins.env`).
3. Compile the changed files, then release as a pre-release for FLAVA3, Verde, Pro and original-PS5 testers.

The kernel is named `<version>-viva` (for example `7.3.1-viva`).
