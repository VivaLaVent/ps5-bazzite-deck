# For the upstream repositories

Single-topic changes for other repositories, outside our series (`../series`). Each applies alone on its target and
compiles there; every pull request states what was measured on which console and that it was prepared with AI
assistance. `*.patch` against a `linux.patch` repository go through `tools/upstream-pr.sh`, the others through
`tools/repo-pr.sh` with a `.md` of the same name as the description. Both are dry runs without `--submit` and need
`--tested`.

None are pending. What we sent before went upstream or no longer has a target:

| Change | Outcome |
| --- | --- |
| IW620 without TDLS (Wi-Fi driver and image builder) | merged in ps5-linux-mwifiex and ps5-linux-image #54 |
| SDR HDR metadata as SDR | in the official ps5-linux-patches #81 |
| CPU clock: off on the Pro, rate limit; Pro Bluetooth | sent to rmux's repository (#8 to #10), lost when it was removed |

`../mwifiex/ps5-iw620-no-tdls.patch` stays while our pins are before the merge; when they move past it, it goes, or
`build.sh` applies it twice.
