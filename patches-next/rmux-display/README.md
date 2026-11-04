# rmux's display rework, adapted (parked)

v2.4.2's kernel: Linux 7.3.1 + rmux's shitshow with his display code (FRL planner, ALLM, recovery) instead of the
display stack v2.5 ships. Build it with `PATCHES=patches-next/rmux-display bash build.sh`.

Where it stands on a FLAVA3 PS5 with an HDMI 2.1 LG TV (v2.4.2):
- 1080p and 1440p at 60/120 Hz, 4K60 (TMDS), HDR at 4K60: work
- 4K120: not offered with `hdmi.frl_4k120=0`; with FRL on, his FRL link hasn't been seen working yet
- VRR: offered, doesn't engage

To do before it can replace the v2.5 display stack: 4K120 over his FRL path (compare an `hdmi.icc_trace=1`
trace with v2.5's working 4K120 setup), VRR on his path, then the same test round on FLAVA3, Verde and Pro.
The SDR-metadata fix belongs upstream either way (`tools/upstream-pr.sh`).
