#!/bin/sh
# What the loader dumped comes in the initrd: Wi-Fi firmware and pairing export under /ps5, the PS5 Pro GPU firmware
# where amdgpu loads it. Linux needs them after the initramfs is gone, in the boot partition's layout: /run/ps5.
# ps5-kexec gives the GPU firmware to a warm reboot, which starts without the loader.
[ -d /ps5 ] && cp -a /ps5 /run/
for f in /usr/lib/firmware/amdgpu/viola_*.bin; do
    [ -f "$f" ] || break
    mkdir -p /run/ps5/lib/firmware/amdgpu && cp -a "$f" /run/ps5/lib/firmware/amdgpu/
done
exit 0
