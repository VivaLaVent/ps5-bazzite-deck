# For the upstream repositories

Single-topic changes that are not part of our series (ours are in `../series`). Each applies alone on its target
and compiles there. rmux's README: contributions come as pull requests, and "AI generated slop will not be
merged", so every pull request states what was measured on which console and that it was prepared with AI
assistance.

| Change | For | Status |
| --- | --- | --- |
| `hdmi-sdr-metadata.patch` | rmuxnet/ps5-linux-patches-1 | sent as #8; lost when the repository was removed (November 2026) |
| `cpufreq-not-on-pro.patch` | rmuxnet/ps5-linux-patches-1 | sent as #9; lost with the repository |
| `cpufreq-rate-limit.patch` | rmuxnet/ps5-linux-patches-1 | sent as #10; lost with the repository |
| `bluetooth-pro.patch` | rmuxnet/ps5-linux-patches-1 | mfoster978's Pro setup (our PR #30), in our kernel since v2.5.1 |
| `mwifiex-no-tdls.patch` | ps5-linux/ps5-linux-mwifiex | in v2.11; the reporter's runtime workaround confirmed the cause, the patch itself not yet |
| `image-no-tdls.patch` | ps5-linux/ps5-linux-image | the apply line for the one above; to be merged after it |

`*.patch` against a `linux.patch` repository go through `tools/upstream-pr.sh`, the others through
`tools/repo-pr.sh` with their `.md` as the description. Both are dry runs without `--submit` and need `--tested`.

When ps5-linux-mwifiex has the TDLS patch and our pins move past it, `../mwifiex/ps5-iw620-no-tdls.patch` goes:
`build.sh` would otherwise apply it a second time.

## Not yet: the display fixes

Re-arm, EDID keep, the SCDC writes, sleep mute and VRR exist for rmux's display code as one 1,345-line patch
(`patches-next/rmux-display/ps5-display.patch` at commit 1081ebe). Its hunks mix topics, and it last ran on a
console in v2.4.x. Each topic has to be cut out, compiled alone on his tree and run on a console before it is
sent; `hdmi.rearm` is the only one with a fresh result (a TV off and on stayed black without it).

## Not ours to send

#71, #72, #75, #77, #78 (Slip's and Sergey's, in the official repository), suspend-to-idle (Dasloh's, his #4).
