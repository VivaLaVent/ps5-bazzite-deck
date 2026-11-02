#!/bin/bash
# Quick kernel test without an image build (minutes instead of an hour), for kernel-only
# changes such as the VRR tests: builds bzImage (the HDMI driver is built in) and amdgpu.ko
# in the kernel builder container, packs them with an installer, and installs them on the PS5.
#   bash tools/quick-kernel.sh <label> [ps5-host]        e.g.  bash tools/quick-kernel.sh vrr-test11
# Output: ~/ps5-build-7.3/output/ps5-quick-<label>.tar.gz. The PS5 must run the same kernel
# version (7.3.0) the tree builds; the installer keeps a backup and prints the undo command.
set -euo pipefail
L=${1:?usage: quick-kernel.sh <label> [ps5-host]}; PS5=${2:-ps5@192.168.66.55}
B=~/ps5-build-7.3; K=$B/work/linux73; O=$B/output/ps5-quick-$L; mkdir -p "$O"; rm -rf "$O"/*
cd "$B"
echo "==> kernel build (bzImage + modules, incremental)"
docker run --rm -v "$K":/src -v "$B/work/ps5-linux-patches":/ps5-linux-patches:ro -v "$B/cache/ccache":/ccache \
  ps5-kernel-builder bash -c 'export CCACHE_DIR=/ccache; make -s LOCALVERSION= -j$(nproc) bzImage modules && make -s LOCALVERSION= kernelrelease > /src/.quick-release && strip --strip-debug -o /src/.quick-amdgpu.ko drivers/gpu/drm/amd/amdgpu/amdgpu.ko && strip --strip-debug -o /src/.quick-btusb.ko drivers/bluetooth/btusb.ko'
R=$(cat "$K/.quick-release"); rm -f "$K/.quick-release"
echo "    kernel release: $R"
cp "$K/arch/x86/boot/bzImage" "$O/bzImage"
cp "$K/.quick-amdgpu.ko" "$O/amdgpu.ko"; rm -f "$K/.quick-amdgpu.ko"          # stripped, as the image's modules are
zstd -q -f -19 -o "$O/amdgpu.ko.zst" "$O/amdgpu.ko"
echo "    amdgpu.ko: $(du -h "$O/amdgpu.ko" | cut -f1) stripped, $(du -h "$O/amdgpu.ko.zst" | cut -f1) compressed"
zstd -q -f -19 -o "$O/btusb.ko.zst" "$K/.quick-btusb.ko"; rm -f "$K/.quick-btusb.ko"   # Bluetooth is a module: ship it too
# QUICK_FILES="name ...": scripts and services from files/ (or tools/), installed where the update bundle puts them
SRC=$(cd "$(dirname "$0")/.." && pwd)
if [ -n "${QUICK_FILES:-}" ]; then
  mkdir -p "$O/files"; : > "$O/files/MAP"
  for f in $QUICK_FILES; do
    line=$(sed -n "/^cat > \"\$OUT\/FILES\" << 'L'$/,/^L$/p" "$SRC/tools/make-update-bundle.sh" | grep "^$f " | head -1)
    [ -n "$line" ] || { echo "STOP: $f isn't in the update bundle's file list"; exit 1; }
    src=$SRC/files/$f; [ -f "$src" ] || src=$SRC/tools/$f; [ -f "$src" ] || { echo "STOP: $f not found"; exit 1; }
    cp "$src" "$O/files/$f"; echo "$line" >> "$O/files/MAP"
  done
  echo "    files: $QUICK_FILES"
fi
echo "$R" > "$O/KERNEL"; echo "$L" > "$O/LABEL"
cat > "$O/install.sh" << 'EOI'
#!/bin/bash
# Installs a quick test kernel (bzImage + amdgpu module) with a backup. Undo command at the end.
# amdgpu usually sits in the initrd too: instead of rebuilding the initrd, a small cpio archive
# with the new module is appended to the untouched original (the kernel reads concatenated
# archives, later files replace earlier ones). The original is kept as initrd.img.base.
set -euo pipefail
cd "$(dirname "$0")"
K=${QUICK_KERNEL:-$(uname -r)}; [ "$K" = "$(cat KERNEL)" ] || { echo "STOP: running kernel $K, this build is $(cat KERNEL)"; exit 1; }   # QUICK_KERNEL: installing into an image (chroot)
EFI=$(for d in /efi /boot/efi; do sudo test -f $d/bzImage && echo $d && break; done)
[ -n "$EFI" ] || { sudo mkdir -p /boot/efi; mountpoint -q /boot/efi || sudo mount LABEL=boot /boot/efi; EFI=/boot/efi; }
sudo test -f "$EFI/bzImage" || { echo "STOP: no bzImage on the boot partition"; exit 1; }
MD=/usr/lib/modules/$K/kernel/drivers/gpu/drm/amd/amdgpu; M=$(ls $MD/amdgpu.ko* | sed -n 1p)
BK=/var/lib/ps5-quick-kernel/$(date +%Y%m%d-%H%M%S); sudo mkdir -p "$BK"
sudo cp "$EFI/bzImage" "$EFI/initrd.img" "$M" /etc/ps5-bazzite-deck-version "$BK/" 2>/dev/null || true
sudo install -m644 bzImage "$EFI/bzImage"
sudo install -m644 amdgpu.ko.zst "$MD/amdgpu.ko.zst"; [ "$M" = "$MD/amdgpu.ko.zst" ] || sudo rm -f "$M"
sudo depmod "$K"
# the initrd: the original is kept once (off the small boot partition). amdgpu is replaced INSIDE
# the initrd (unpack, swap the module, repack with the same compression), because appending an
# overlay doesn't fit on small boot partitions.
BASE=/var/lib/ps5-quick-kernel/initrd.img.base
sudo mkdir -p /var/lib/ps5-quick-kernel
if sudo test -f "$EFI/initrd.img.base"; then sudo mv "$EFI/initrd.img.base" "$BASE"; fi   # older installs kept it on the boot partition
sudo test -f "$BASE" || sudo cp "$EFI/initrd.img" "$BASE"
IP=$( { sudo lsinitrd "$BASE" 2>/dev/null || true; } | grep -o '[^ ]*amdgpu/amdgpu\.ko[a-z.]*' | sed -n 1p | sed 's#^\./##'; true)
IP=${IP:-usr/lib/modules/$K/kernel/drivers/gpu/drm/amd/amdgpu/amdgpu.ko.zst}
W=$(mktemp -d /var/tmp/quick-initrd.XXXXXX)   # user-owned (the shell writes here); only root/ below is root-owned
# an early (uncompressed) cpio for microcode may come first: split it off
if [ -x /usr/lib/dracut/skipcpio ] && sudo /usr/lib/dracut/skipcpio "$BASE" > "$W/main.img" 2>/dev/null && [ -s "$W/main.img" ]; then
  E=$(( $(sudo stat -c%s "$BASE") - $(stat -c%s "$W/main.img") )); sudo head -c "$E" "$BASE" > "$W/early.cpio"
else sudo cp "$BASE" "$W/main.img"; : > "$W/early.cpio"; fi
MAGIC=$(head -c4 "$W/main.img" | od -An -tx1 | tr -d ' ')
case "$MAGIC" in 28b52ffd) DEC="zstd -dc"; ENC="zstd -19 -T0 -q";; 1f8b*) DEC="gzip -dc"; ENC="gzip -9";; fd377a58) DEC="xz -dc"; ENC="xz --check=crc32 -9";; *) DEC="cat"; ENC="cat";; esac
# decompress tolerantly: an initrd that already got an overlay appended has trailing data
# after the compressed stream, which zstd/gzip report as an error after a complete decode
# the unpack root MUST be root-owned: the archive's "." entry becomes the initrd's "/", and systemd
# refuses a root directory owned by a normal user (no boot). The first in-initrd installer got this wrong.
sudo mkdir -m 755 "$W/root" && (cd "$W/root" && { $DEC ../main.img 2>/dev/null || true; } | sudo cpio -idm --quiet 2>/dev/null || true)
[ -n "$(ls -A "$W/root" 2>/dev/null)" ] || { echo "STOP: could not unpack the initrd (format $MAGIC); nothing changed"; sudo cp "$BK/bzImage" "$EFI/"; sudo rm -rf "$W"; exit 1; }
[ -e "$W/root/$IP" ] || echo "note: $IP wasn't in the initrd; adding it"
sudo mkdir -p "$W/root/$(dirname "$IP")"
case "$IP" in *.ko.zst) sudo cp amdgpu.ko.zst "$W/root/$IP";; *.ko.xz) xz -c -9 amdgpu.ko | sudo tee "$W/root/$IP" >/dev/null;; *.ko.gz) gzip -9c amdgpu.ko | sudo tee "$W/root/$IP" >/dev/null;; *) sudo cp amdgpu.ko "$W/root/$IP";; esac
echo "initrd module: $IP ($(sudo du -h "$W/root/$IP" | cut -f1))"
# small boot partition: QUICK_SLIM=1 drops the amdgpu firmware of other GPUs from the initrd (the
# PS5's own files, navi10_* and ps5_*, stay; QUICK_FW_KEEP overrides the list) and compresses harder
if [ "${QUICK_SLIM:-0}" = 1 ] && [ -d "$W/root/usr/lib/firmware/amdgpu" ]; then
  KEEP=${QUICK_FW_KEEP:-"navi10_ ps5_"}; N=0
  for f in "$W/root"/usr/lib/firmware/amdgpu/*; do b=$(basename "$f"); k=0; for pre in $KEEP; do case "$b" in $pre*) k=1;; esac; done; [ $k = 1 ] || { sudo rm -f "$f"; N=$((N+1)); }; done
  echo "slim initrd: removed $N amdgpu firmware files of other GPUs (kept: $KEEP)"
  case "$ENC" in zstd*) ENC="zstd --ultra -22 --long=27 -T0 -q";; esac
fi
(cd "$W/root" && sudo find . -print0 | sudo cpio --null -o -H newc --quiet | $ENC > "$W/main.new")
ROOTENT=$( { $DEC "$W/main.new" 2>/dev/null || true; } | cpio -itv --quiet 2>/dev/null | sed -n 1p; true)
case "$ROOTENT" in drwxr-xr-x*root*root*" ."*) ;; *) echo "STOP: repacked initrd root entry is not root-owned ($ROOTENT); nothing changed"; sudo cp "$BK/bzImage" "$EFI/"; sudo rm -rf "$W"; exit 1;; esac
cat "$W/early.cpio" "$W/main.new" > "$W/initrd.img"
NEED=$(stat -c%s "$W/initrd.img"); HAVE=$(( $(df --output=avail -B1 "$EFI" | tail -1) + $(sudo stat -c%s "$EFI/initrd.img" 2>/dev/null || echo 0) ))
echo "initrd: new $((NEED/1024/1024)) MB, room on the boot partition after removing the old one: $((HAVE/1024/1024)) MB"
if [ "$NEED" -gt "$HAVE" ]; then
  echo "STOP: the new initrd doesn't fit. On the boot partition:"; sudo ls -la "$EFI" | grep -v -e cmdline -e "^total" | awk '{print "   " $5/1024/1024 " MB  " $9}' | sort -rn | sed -n 1,8p
  echo "   remove leftovers there (old initrd.img.bak-* / bzImage copies), or run with QUICK_SLIM=1 to drop other GPUs' firmware from the initrd"
  sudo cp "$BK/bzImage" "$EFI/"; sudo rm -rf "$W"; exit 1
fi
sudo rm -f "$EFI/initrd.img"
if ! sudo cp "$W/initrd.img" "$EFI/initrd.img"; then echo "STOP: copy failed; restoring"; sudo cp "$BASE" "$EFI/initrd.img"; sudo cp "$BK/bzImage" "$EFI/"; sudo rm -rf "$W"; exit 1; fi
sudo rm -rf "$W"
echo "initrd: amdgpu replaced inside ($IP), $(sudo du -h "$EFI/initrd.img" | cut -f1), boot partition free: $(df -h "$EFI" | awk 'NR==2{print $4}')"
BD=/usr/lib/modules/$K/kernel/drivers/bluetooth; BM=$(ls $BD/btusb.ko* 2>/dev/null | sed -n 1p)
if [ -f btusb.ko.zst ] && [ -n "$BM" ]; then
  sudo cp "$BM" "$BK/"; sudo install -m644 btusb.ko.zst "$BD/btusb.ko.zst"; [ "$BM" = "$BD/btusb.ko.zst" ] || sudo rm -f "$BM"
  sudo depmod "$K"; echo "btusb: replaced"
fi
if [ -f files/MAP ]; then
  while read -r f dest mode; do
    sudo test -f "$dest" && { sudo mkdir -p "$BK/files"; sudo cp "$dest" "$BK/files/$f"; }
    sudo install -D -m "${mode:-644}" "files/$f" "$dest"
  done < files/MAP
  sudo systemctl daemon-reload
  grep -q "\.rules$" <(awk '{print $1}' files/MAP) && { sudo udevadm control --reload 2>/dev/null || true; }
  for u in $(awk '$1 ~ /\.service$/ {print $1}' files/MAP); do sudo systemctl enable "$u" >/dev/null 2>&1 || true; done
  echo "files: $(awk '{print $1}' files/MAP | tr '\n' ' ')"
fi
echo "$(cat LABEL) (quick kernel)" | sudo tee /etc/ps5-bazzite-deck-version >/dev/null
sync
[ -e /etc/ps5-bazzite-deck/warm-reboot ] && sudo touch /run/ps5-reboot-to-ps5 && echo "note: warm reboot is on; the next restart goes through the PS5 system (cold), as a new kernel needs"
echo "DONE: $(cat LABEL) installed. Power off and start with the loader (no warm reboot)."
echo "undo: sudo cp $BK/bzImage $EFI/ && sudo cp $BASE $EFI/initrd.img && sudo cp $BK/$(basename "$M") $MD/ && { [ -z \"$BM\" ] || sudo cp $BK/$(basename "${BM:-x}") $BD/; } && sudo depmod $K && sudo cp $BK/ps5-bazzite-deck-version /etc/ && sync   (scripts: $BK/files)"
EOI
chmod +x "$O/install.sh"
tar -C "$B/output" -czf "$O.tar.gz" "$(basename "$O")"
echo "==> $O.tar.gz ($(du -h "$O.tar.gz" | cut -f1))"
if [ "${NO_INSTALL:-0}" != 1 ]; then
  echo "==> install on $PS5"
  scp "$O.tar.gz" "$PS5:~" && ssh -t "$PS5" "rm -rf ps5-quick-$L && tar xzf ps5-quick-$L.tar.gz && bash ps5-quick-$L/install.sh"
fi
