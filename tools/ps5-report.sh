#!/bin/bash
# Read-only report for bug reports; saves ~/ps5-report-<date>.txt.
#   bash <(curl -fsSL https://raw.githubusercontent.com/VivaLaVent/ps5-bazzite-deck/main/tools/ps5-report.sh)
OUT=~/ps5-report-$(date +%Y%m%d-%H%M).txt
sudo -v || true
# the journal holds the whole boot (dmesg's ring can lose the start); both would count every line twice
KLOG=$(sudo journalctl -k -b --no-pager -o cat 2>/dev/null); [ -n "$KLOG" ] || KLOG=$(sudo dmesg 2>/dev/null)
k() { printf '%s\n' "$KLOG"; }
last() { sed 's/^\[ *[0-9.]*\] //' | uniq -c | sed 's/^ *1 /  /' | tail -"$1"; }
PCI=$(lspci -n 2>/dev/null); USB=$(lsusb 2>/dev/null)
has() { grep -qi "$2" <<< "$1"; }

# --- identification
if has "$PCI" '1002:13d[ac]'; then MODEL="PS5 Pro"
elif has "$USB" '0e8d:3603' || has "$PCI" '14c3:'; then MODEL="PS5 Slim"
elif has "$USB" '1286:2059' || has "$PCI" '1b4b:2b56'; then MODEL="PS5 (original)"
else MODEL="PS5 (unknown model)"; fi
GPU=$(grep -o -i -m1 '1002:13d[ac]\|1002:13fe\|1002:13f9' <<< "$PCI")
HDMI=$(k | grep -o -m1 'HDMI IC Type \[[A-Z0-9]*\]' | tr -d '[]' | awk '{print $4}')
if has "$USB" '1286:2059' || has "$PCI" '1b4b:2b56'; then
  WIRELESS="NXP IW620 (Wi-Fi 1b4b:2b56, Bluetooth 1286:2059)"
else
  WID=$(grep -o -i -m1 '14c3:[0-9a-f]*' <<< "$PCI"); BID=$(grep -o -i -m1 '0e8d:36[0-9a-f]*' <<< "$USB")
  WIRELESS="MediaTek (Wi-Fi ${WID:-?}, Bluetooth ${BID:-?})"
fi
if [ -e /run/ostree-booted ]; then
  IMGREF=$(sudo bootc status --format=json 2>/dev/null | python3 -c 'import json,sys; s=json.load(sys.stdin)["status"]["booted"]["image"]; print(s["image"]["image"])' 2>/dev/null)
  INSTALL="bootc ${IMGREF:-?} ($(grep -m1 '^version=' /usr/share/ps5-bazzite-bootc/VERSION 2>/dev/null | cut -d= -f2))"
else
  INSTALL="classic $(cat /etc/ps5-bazzite-deck-version 2>/dev/null || echo '(version unknown)')"
fi
CON=$(for c in /sys/class/drm/card*-*; do [ "$(cat "$c/status" 2>/dev/null)" = connected ] && echo "${c##*/}" && break; done)
DNAME=$([ -n "$CON" ] && python3 -c "
e=open('/sys/class/drm/$CON/edid','rb').read()
for i in range(54,126,18):
    if e[i:i+3]==b'\0\0\0' and e[i+3]==0xfc: print(e[i+5:i+18].decode('ascii','replace').strip()); break
" 2>/dev/null)
MODE=$(sudo grep -m1 'mode: "' /sys/kernel/debug/dri/0/state 2>/dev/null | awk '{print $2, $3 "Hz"}' | tr -d '"')
VRR=$(sudo grep -m1 'vrr_enabled' /sys/kernel/debug/dri/0/state 2>/dev/null | awk -F= '{print $2}')
ROOT=$(lsblk -no tran "/dev/$(lsblk -no pkname "$(findmnt -no SOURCE /sysroot 2>/dev/null || findmnt -no SOURCE /)" 2>/dev/null | head -1)" 2>/dev/null | head -1)
WARM=$(journalctl -b -u ps5-wifi-repair --no-pager -o cat 2>/dev/null | grep -c 'after the warm reboot')
BTA=$(cat /sys/class/bluetooth/hci0/address 2>/dev/null)
if [ -z "$BTA" ]; then BT="no adapter"
elif [ -e /etc/ps5-bazzite-deck/bt-address-off ]; then BT="$BTA (Linux-only address off)"
elif [ $(( 0x${BTA%%:*} & 2 )) -ne 0 ]; then BT="$BTA (Linux-only address applied)"
else BT="$BTA (Linux-only address NOT applied)"; fi
WIFI=$(nmcli -t -f TYPE,STATE device 2>/dev/null | grep -m1 '^wifi' | cut -d: -f2)

{
INFO=(
  "$(whoami)@$(hostname)"
  "-----------------"
  "Console    $MODEL${GPU:+ (GPU $GPU)}"
  "HDMI chip  ${HDMI:-unknown (not logged this boot)}"
  "Wireless   $WIRELESS"
  "Install    $INSTALL"
  "Kernel     $(uname -r)"
  "Display    ${DNAME:-?} on ${CON:-nothing connected}${MODE:+, $MODE}${VRR:+, VRR $VRR}"
  "Bluetooth  $BT"
  "Wi-Fi      ${WIFI:-no Wi-Fi device}"
  "System on  ${ROOT:-?}"
  "Boot       $( [ "$WARM" -gt 0 ] && echo "warm reboot" || echo "cold start"), up $(uptime -p | sed 's/^up //')"
)
LOGO=(' ____  ____  ____ ' '|  _ \/ ___|| ___| ' '| |_) \___ \|___ \ ' '|  __/ ___) |___) |' '|_|   |____/|____/ ')
for i in "${!INFO[@]}"; do printf '%-20s  %s\n' "${LOGO[$i]:-}" "${INFO[$i]}"; done
echo
echo "SUMMARY: $INSTALL | $MODEL | HDMI ${HDMI:-?} | ${WIRELESS%% (*} | ${DNAME:-?} ${MODE:-} | $(uname -r) | ${ROOT:-?}"

echo; echo "=== Bluetooth"
btmgmt info 2>/dev/null | grep -m2 -e 'addr ' -e 'current settings' | sed 's/^\s*/  /'
for u in ps5-bt-addr ps5-bt-pro-addr ps5-bt-revive; do
  s=$(systemctl is-active "$u" 2>/dev/null); [ "$s" = inactive ] && s=$(systemctl show -p Result --value "$u" 2>/dev/null)
  echo "  $u: $s"; journalctl -b -u "$u" --no-pager -o cat 2>/dev/null | tail -3 | sed 's/^/    /'
done
echo "  kernel: $(k | grep -c -i 'tx timeout') command timeouts"
k | grep -i -e 'bluetooth' -e 'btusb' -e 'hci0' | grep -i -e error -e fail -e timeout -e 'not found' | last 10

echo; echo "=== Wi-Fi"
nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null | grep -v -e '^lo' -e p2p | sed 's/^/  /'
W=; for n in /sys/class/net/wl* /sys/class/net/mlan*; do [ -e "$n" ] && W=${n##*/} && break; done
[ -n "$W" ] && echo "  $W: driver $(basename "$(readlink -f "/sys/class/net/$W/device/driver")" 2>/dev/null), $(iw dev "$W" get power_save 2>/dev/null)"
echo "  firmware: $(ls /etc/firmware/nxp/ /lib/firmware/nxp/pcieuartiw620_combo_v1.bin 2>/dev/null | tr '\n' ' ')"
journalctl -b -u ps5-stage-firmware -u ps5-wifi-repair --no-pager -o cat 2>/dev/null | tail -4 | sed 's/^/  /'
k | grep -i -e moal -e mlan -e wlan -e mt79 -e 'firmware' | grep -i -e fail -e error -e timeout -e 'already running' | last 10

echo; echo "=== USB"
grep -v 'root hub' <<< "$USB" | sed 's/^/  /'
k | grep -E 'usb [0-9]+-[0-9.]+:' | grep -i -E 'error|reset|disconnect|-71|descriptor read|over-current' | last 10

echo; echo "=== Display"
for c in /sys/class/drm/card*-*; do [ -f "$c/status" ] && echo "  ${c##*/}: $(cat "$c/status")$( [ "$(cat "$c/status")" = connected ] && echo ", modes: $(sort "$c/modes" | uniq -c | awk '{printf "%s(%s) ", $2, $1}')")"; done
k | grep -e 'hdmi' -e 'PS5 VRR' -e 'FRL' -e 'EDID' -e 'ALLM' | grep -v -e 'switched on' | last 25
echo "  counts: EDID announcements $(k | grep -ciE 'got real (hdmi )?edid'), re-arms $(k | grep -c 're-arm #'), ignored EDIDs $(k | grep -c 'EDID announcement')"
[ -n "$CON" ] && echo "  EDID: $(sudo base64 -w0 "/sys/class/drm/$CON/edid" 2>/dev/null)"

echo; echo "=== GPU"
k | grep -i -e 'ring .* timeout' -e 'page fault' -e 'gpu reset' -e 'wedged' -e 'amdgpu.*error' | last 8
if [ "$MODEL" = "PS5 Pro" ]; then
  echo "  compute units: $(k | grep -o -m1 'active_cu_number [0-9]*' | awk '{print $2}')"
  echo "  Viola firmware loaded: $(k | grep -qi 'using Viola firmware' && echo yes || echo no), SMU: $(k | grep -qi 'SMU is initialized successfully' && echo up || echo down)"
  k | grep -i -e 'ps5-gpufreq' -e 'mp1fw_sendmsg' | last 5
  journalctl -b -u ps5-stage-viola-fw -u ps5-console-defaults --no-pager -o cat 2>/dev/null | tail -4 | sed 's/^/  /'
fi
command -v ps5-perf >/dev/null && ps5-perf status | sed 's/^/  /'

if [ -e /run/ostree-booted ]; then
  echo; echo "=== bootc"
  sudo bootc status 2>/dev/null | sed 's/^/  /' | head -20
  journalctl -b -u ps5-bootc-sync -u ps5-grow-root --no-pager -o cat 2>/dev/null | tail -4 | sed 's/^/  /'
fi

echo; echo "=== System"
echo "  cmdline: $(cat /proc/cmdline)"
echo "  session: $(pgrep -a gamescope | head -1 | cut -c1-80)$(pgrep -a startplasma | head -1 | cut -c1-60)"
echo "  boot: $(systemd-analyze 2>/dev/null | head -1)"
systemctl --failed --no-legend 2>/dev/null | head -8 | sed 's/^/  failed: /'
} 2>&1 | tee "$OUT"
echo; echo "saved to $OUT (paste the SUMMARY line in the tester list, the whole file in bug reports)"
