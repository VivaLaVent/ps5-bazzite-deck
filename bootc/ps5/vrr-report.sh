#!/bin/bash
# vrr-report: one file per VRR test run, so results are comparable. Run it right after a test,
# in the same boot (the kernel log is per boot). Read-only. Saves ~/vrr-report-<date>.txt.
#   bash <(curl -fsSL https://raw.githubusercontent.com/VivaLaVent/ps5-bazzite-deck/main/tools/vrr-report.sh)
OUT=~/vrr-report-$(date +%Y%m%d-%H%M).txt
sudo -v || true
echo "Four quick questions (Enter to skip one):"
read -r -p "1. TV/monitor model and its VRR setting (e.g. LG C1, VRR & G-Sync on): " Q1
read -r -p "2. mode and fps (e.g. 4K60, game locked to 60): " Q2
read -r -p "3. what you saw (picture / black / no signal / flicker / rolling or drift, after how long): " Q3
read -r -p "4. what the TV showed (VRR or FreeSync indicator? the refresh rate it reports?): " Q4
k() { sudo dmesg 2>/dev/null; }
{
echo "TEST: $(cat /etc/ps5-bazzite-deck-version 2>/dev/null) | $(uname -v | cut -c1-40) | HDMI $(k | grep -o -m1 'HDMI IC Type \[[A-Z0-9]*\]' | grep -o '\[.*\]' | tr -d '[]')"
echo "display: $Q1"; echo "mode: $Q2"; echo "seen: $Q3"; echo "tv showed: $Q4"
echo "session: $(pgrep -x gamescope >/dev/null && echo Game Mode || (pgrep -f startplasma >/dev/null && echo desktop || echo ?))   uptime: $(uptime -p)"
echo "cmdline: $(grep -o 'hdmi\.[a-z_0-9]*=[^ ]*' /proc/cmdline | paste -sd' ')"
echo "=== vrr parameters"; for p in /sys/module/hdmi/parameters/vrr_*; do [ -e "$p" ] && printf '%s=%s ' "${p##*/}" "$(cat "$p")"; done; echo
echo "=== vrr log (this boot)"
k | grep -e 'PS5 VRR' -e 'PS5 DPCD' -e 'VRR prep' -e 'VRR phy reply' -e 'VSync block' -e 'HF-VSIF' -e 'FreeSync' -e 'VTEM' -e 'picture up' -e 'got real edid' -e 're-arm' -e 'Link Training' | sed 's/^\[ *\([0-9.]*\)\]/[\1]/' | tail -60
echo "counts: switched on=$(k | grep -c 'VRR: switched on') switched off=$(k | grep -c 'VRR: switched off') got real edid=$(k | grep -c 'got real edid') picture up=$(k | grep -c 'picture up')"
echo "=== gpu"; k | grep -i -e 'ring .* timeout' -e 'page fault' -e 'wedged' | tail -4
} 2>&1 | tee "$OUT"
echo; echo "saved to $OUT: post this file (not a photo of the terminal) in #bazzite-prereleases-experimental, one post per test variant"
