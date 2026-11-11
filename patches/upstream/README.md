# For rmux's ps5-linux-patches-1

Single-topic changes against his tree, not part of our series (ours are in `../series`). Each applies alone on his
`linux.patch` and compiles there. His README: contributions come as pull requests, and "AI generated slop will not
be merged", so every pull request states what was measured on which console and that it was prepared with AI
assistance.

| Patch | Status |
| --- | --- |
| `hdmi-sdr-metadata.patch` | in PS5 Bazzite Deck v2.4.1 on his display code; ready to send |
| `cpufreq-not-on-pro.patch` | in our kernel since v2.5.1; ready to send |
| `cpufreq-rate-limit.patch` | fitamix's finding; send once v2.11 testers confirm the in-driver value |

Dry run first (prints the pull request text and the size of the change to his `linux.patch`), then again with
`--submit`. Needs `gh` logged in and the kernel checkout `build.sh` made:

```bash
bash tools/upstream-pr.sh "hdmi: SDR metadata is not an HDR request" patches/upstream/hdmi-sdr-metadata.patch \
  --tested "<console, system software, TV; what you saw before and after>"
```

Not ours to send: #71, #72, #75, #77, #78 (Slip's and Sergey's, in the official repository), suspend-to-idle
(Dasloh's), the Pro Bluetooth setup (mfoster978's).
