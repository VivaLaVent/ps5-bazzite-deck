#!/bin/bash
# ps5-report: one hardware + health report for bug reports and the tester list.
# Read-only. Works on any ps5-bazzite-deck version. Saves ~/ps5-report-<date>.txt.
#   bash <(curl -fsSL https://raw.githubusercontent.com/VivaLaVent/ps5-bazzite-deck/main/tools/ps5-report.sh)
OUT=~/ps5-report-$(date +%Y%m%d-%H%M).txt
sudo -v || true
k() { sudo dmesg 2>/dev/null; sudo journalctl -k -b --no-pager -o cat 2>/dev/null; }
{
VER=$(cat /etc/ps5-bazzite-deck-version 2>/dev/null || echo unknown)
HDMI=$(k | grep -o -m1 'HDMI IC Type \[[A-Z0-9]*\]' | grep -o '\[.*\]' | tr -d '[]'); HDMI=${HDMI:-unknown}
if lsusb 2>/dev/null | grep -q 1286:2059 || lspci -n 2>/dev/null | grep -qi '11ab:\|1b4b:'; then WL=IW620; elif lsusb 2>/dev/null | grep -qi 0e8d:3605; then WL="MediaTek (Pro Viola BT)"; elif lsusb 2>/dev/null | grep -qi 0e8d: || lspci -n 2>/dev/null | grep -qi 14c3:; then WL=MediaTek; else WL=unknown; fi
MODEL=$(lspci -n 2>/dev/null | grep -qi '1002:13da' && echo "PS5 Pro" || echo "PS5/Slim")
WLID=$(lspci -n 2>/dev/null | grep -o -i -m1 '14c3:79[0-9a-f][0-9a-f]\|1b4b:2b56'); [ -n "$WLID" ] && WL="$WL ($WLID)"
ROOTDEV=$(lsblk -no tran "/dev/$(lsblk -no pkname "$(findmnt -no SOURCE /)" 2>/dev/null | head -1)" 2>/dev/null | head -1)
CON=$(for c in /sys/class/drm/card0-*; do [ -f "$c/status" ] && [ "$(cat "$c/status")" = connected ] && echo "${c##*card0-}" && break; done)
NAME=$([ -n "$CON" ] && python3 -c "
import sys
e=open('/sys/class/drm/card0-$CON/edid','rb').read()
for i in range(54,126,18):
    if e[i:i+3]==b'\0\0\0' and e[i+3]==0xfc: print(e[i+5:i+18].decode('ascii','replace').strip()); break
" 2>/dev/null)
WARM=$(journalctl -b -u ps5-wifi-repair --no-pager -o cat 2>/dev/null | grep -c 'after the warm reboot')
echo "SUMMARY: $VER | $MODEL | HDMI $HDMI | Wi-Fi/BT $WL | display ${NAME:-?} on ${CON:-none} | system on ${ROOTDEV:-?} | $( [ "$WARM" -gt 0 ] && echo warm || echo cold) boot"
echo
echo "=== system"; uname -rv; uptime -p; cat /sys/class/dmi/id/product_name /sys/class/dmi/id/board_name 2>/dev/null | paste -sd' '; grep -m1 'model name' /proc/cpuinfo
echo "cmdline: $(cat /proc/cmdline)"
echo "warm reboot: $([ -e /etc/ps5-bazzite-deck/warm-reboot ] && echo on || echo off) | linux-only BT address: $([ -e /etc/ps5-bazzite-deck/bt-address ] && echo on || echo off/n.a.)"
command -v ps5-perf >/dev/null && ps5-perf status
echo "=== chips"; lspci -nn | grep -i -e network -e wireless -e ethernet -e usb -e display -e vga | cut -c1-120; lsusb | grep -v 'root hub'
echo "=== display"; for c in /sys/class/drm/card0-*; do [ -f "$c/status" ] && echo "${c##*card0-}: $(cat "$c/status") $(cat "$c/enabled" 2>/dev/null) $(head -1 "$c/modes" 2>/dev/null)"; done
k | grep -e 'hdmi:' -e 'PS5' | grep -v -e 'switched on' | tail -25
echo "counts: got real edid=$(k | grep -c 'got real edid') re-arm=$(k | grep -c 're-arm #') ignored EDID=$(k | grep -c 'EDID announcement')"
echo "=== display details"; echo "EDID: $(sudo cat /sys/class/drm/card0-DP-1/edid 2>/dev/null | base64 -w0)"
cat /sys/class/drm/card0-DP-1/modes 2>/dev/null | sort | uniq -c | tr '\n' ' '; echo
sudo grep -E "vrr_enabled|mode:" /sys/kernel/debug/dri/0/state 2>/dev/null | head -4
echo "=== gpu"; k | grep -i -e 'ring .* timeout' -e 'page fault' -e 'Process .* pid' -e 'gpu reset' -e 'wedged' -e 'amdgpu.*error' | sed 's/^\[ *[0-9.]*\] //' | uniq -c | tail -10
if [ "$MODEL" = "PS5 Pro" ]; then
echo "=== PS5 Pro"
CUS=$(k | grep -o -m1 'active_cu_number [0-9]*' | awk '{print $2}')
VIOLA_FW=$(k | grep -qi 'using Viola firmware' && echo yes || echo no)
SMU_OK=$(k | grep -qi 'SMU is initialized successfully' && echo yes || echo no)
VIOLA_FILES=$(for d in /boot/efi /efi; do sudo test -f "$d/cmdline.txt" && { sudo sh -c "ls $d/lib/firmware/amdgpu/viola_*.bin 2>/dev/null" | wc -l; break; }; done)   # the boot partition is root-only
echo "compute units active: ${CUS:-unknown (base-PS5 clock path, or not yet logged this boot)}"
echo "Viola GPU firmware: loaded by the kernel: $VIOLA_FW | SMU initialised: $SMU_OK | files on the boot partition: ${VIOLA_FILES:-0}"
journalctl -u ps5-stage-viola-fw --no-pager -o cat 2>/dev/null | tail -5
k | grep -i -o -m1 'FanServo:[^$]*' | head -3
echo "cu_unlock in cmdline: $(grep -qo 'ps5_cu_unlock=[0-9]*' /proc/cmdline && echo "yes (not supported on Pro, ignored)" || echo no)"
fi
echo "=== bluetooth"; btmgmt info 2>/dev/null | grep -m3 -e 'addr ' -e 'current settings'; k | grep -i -e 'bluetooth' -e btusb -e 'usb 5-3' | grep -i -e error -e fail -e timeout -e 'not accepting' | tail -6
echo "=== wifi / network"; nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>/dev/null | grep -v -e '^lo' -e p2p
W=$(ls /sys/class/net | grep -e ^wl -e ^mlan | head -1); [ -n "$W" ] && { iw dev "$W" get power_save 2>/dev/null; iw dev "$W" link 2>/dev/null | grep -e freq -e signal -e 'rx bitrate'; }
k | grep -i -e moal -e mwifiex -e mt79 -e wlan | grep -i -e fail -e error -e timeout | tail -6
echo "=== session"; systemctl is-active sddm 2>/dev/null; pgrep -a gamescope 2>/dev/null | head -1 | cut -c1-120; pgrep -a startplasma 2>/dev/null | head -1
echo "=== boot timing"; systemd-analyze 2>/dev/null | head -1
echo "=== failed services"; systemctl --failed --no-legend 2>/dev/null | head -8
echo "=== greenboot"; journalctl -b --no-pager -o cat 2>/dev/null | grep -i -e greenboot -e redboot -e 'boot_counter' | tail -8
} 2>&1 | tee "$OUT"
echo; echo "saved to $OUT (paste the SUMMARY line in the tester list, the whole file in bug reports)"
