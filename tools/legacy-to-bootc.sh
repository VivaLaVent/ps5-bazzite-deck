#!/bin/bash
# One-time switch of a Legacy PS5 Bazzite Deck install to bootc, in place, keeping users, home folders and Flatpaks.
#   curl -fsSLO https://raw.githubusercontent.com/VivaLaVent/ps5-bazzite-deck/main/tools/legacy-to-bootc.sh
#   sudo bash legacy-to-bootc.sh            checks only, changes nothing
#   sudo bash legacy-to-bootc.sh --apply    deploys the Stable bootc image beside the Legacy system
#   sudo bash legacy-to-bootc.sh --undo     on Legacy, before the first bootc start: back to how it was
#   sudo bash legacy-to-bootc.sh --cleanup  on the bootc system, once it works: deletes the Legacy system files
# The Legacy system stays complete until --cleanup: the image goes to /ostree, home folders and Flatpaks move at
# the first bootc start, and the Legacy kernel, initrd and cmdline.txt wait in legacy-backup/ on the boot partition.
# No bootloader is installed (bootc install would run bootupd): ps5-bootc-sync writes the loader's files, as for
# a disk image.
set -euo pipefail
IMAGE=${PS5_IMAGE:-ghcr.io/vivalavent/ps5-bazzite-bootc:stable}
NEED_ROOT_GIB=30; NEED_ESP_MIB=300
MARK=/ostree/ps5-legacy-converted
MODE=${1:-check}

stop() { echo "STOP: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || stop "run it with sudo"

find_esp() {
    EFI=
    for d in /efi /boot/efi; do [ -f "$d/cmdline.txt" ] && { EFI=$d; return 0; }; done
    mkdir -p /efi
    mount LABEL=boot /efi 2>/dev/null && [ -f /efi/cmdline.txt ] && { EFI=/efi; return 0; }
    return 1
}

# users with a login (uid 1000-59999), their groups and memberships, into the deployment's /etc
carry_accounts() {
    python3 - "$1" "$2" << 'PY'
import os, sys
old, new = sys.argv[1], sys.argv[2]
def lines(p): return [l.rstrip("\n") for l in open(p)] if os.path.exists(p) else []
def names(ls): return {l.split(":")[0] for l in ls}
users = [l for l in lines(f"{old}/etc/passwd") if l.count(":") >= 6 and 1000 <= int(l.split(":")[2]) < 60000]
who = names(users)
for f in ("passwd", "shadow", "subuid", "subgid"):
    have = lines(f"{new}/etc/{f}")
    add = [l for l in lines(f"{old}/etc/{f}") if l.split(":")[0] in who and l.split(":")[0] not in names(have)]
    open(f"{new}/etc/{f}", "w").write("\n".join(have + add) + "\n")
groups = lines(f"{new}/etc/group")
system = {l.split(":")[0]: l for l in lines(f"{new}/usr/lib/group")}
for l in lines(f"{old}/etc/group"):
    name, _, gid, members = (l.split(":") + [""] * 4)[:4]
    mine = [m for m in members.split(",") if m in who]
    if name not in names(groups) and (1000 <= int(gid or 0) < 60000):
        groups.append(l)
    elif mine:
        if name not in names(groups) and name in system:
            groups.append(system[name])
        for i, g in enumerate(groups):
            p = g.split(":")
            if p[0] == name:
                p[3] = ",".join(dict.fromkeys([m for m in p[3].split(",") if m] + mine))
                groups[i] = ":".join(p)
open(f"{new}/etc/group", "w").write("\n".join(groups) + "\n")
print("  users: " + (" ".join(sorted(who)) or "NONE: the bootc system will have no login"))
PY
}

# the image's own kernel arguments (bootc applies kargs.d at install; ostree's deploy doesn't)
append_kargs() {
    python3 - "$1" "$2" << 'PY'
import glob, sys, tomllib
dep, entries = sys.argv[1], sys.argv[2]
kargs = [k for f in sorted(glob.glob(f"{dep}/usr/lib/bootc/kargs.d/*.toml")) for k in tomllib.load(open(f, "rb")).get("kargs", [])]
for f in glob.glob(f"{entries}/*.conf"):
    out = []
    for l in open(f).read().splitlines():
        if l.startswith("options "):
            have = l.split()[1:]
            l = "options " + " ".join(have + [k for k in kargs if k not in have])
        out.append(l)
    open(f, "w").write("\n".join(out) + "\n")
PY
}

# moves by rename inside /sysroot (one filesystem), before anything else writes to the new /var
write_firstboot() {
    install -Dm755 /dev/stdin "$1/etc/ps5-legacy-migrate" << 'SH'
#!/bin/sh
# Once, at the first bootc start after legacy-to-bootc.sh: the Legacy system's home folders, Flatpaks and
# Bluetooth pairings into this system. Renames on one filesystem: instant, no extra space.
S=${PS5_SYSROOT:-/sysroot}; N=$S/ostree/deploy/default/var
[ -n "${PS5_SYSROOT:-}" ] || mount -o remount,rw "$S" || exit 1
mkdir -p "$N/home" "$N/lib"
for src in "$S/var/home" "$S/home"; do
    [ -d "$src" ] && [ ! -L "$src" ] || continue
    for h in "$src"/*; do
        [ -e "$h" ] && [ ! -e "$N/home/$(basename "$h")" ] && mv "$h" "$N/home/" && echo "moved $h"
    done
done
for d in flatpak bluetooth; do
    [ -d "$S/var/lib/$d" ] && [ ! -e "$N/lib/$d" ] && mv "$S/var/lib/$d" "$N/lib/$d" && echo "moved /var/lib/$d"
done
mkdir -p "$N/lib/ps5-bazzite-bootc" && : > "$N/lib/ps5-bazzite-bootc/legacy-migrated"
SH
    cat > "$1/etc/systemd/system/ps5-legacy-migrate.service" << 'UNIT'
[Unit]
Description=Move the Legacy install's home folders and Flatpaks into the bootc system (once)
DefaultDependencies=no
After=local-fs.target
Before=systemd-tmpfiles-setup.service sysinit.target
ConditionPathExists=!/var/lib/ps5-bazzite-bootc/legacy-migrated

[Service]
Type=oneshot
PrivateMounts=yes
ExecStart=/etc/ps5-legacy-migrate

[Install]
WantedBy=sysinit.target
UNIT
    mkdir -p "$1/etc/systemd/system/sysinit.target.wants"
    ln -sf ../ps5-legacy-migrate.service "$1/etc/systemd/system/sysinit.target.wants/ps5-legacy-migrate.service"
}

case "$MODE" in
check|--apply)
    [ -e /run/ostree-booted ] && stop "this is already a bootc install (update with: sudo bootc upgrade)"
    grep -qs '^ID=bazzite' /etc/os-release && [ -e /usr/local/sbin/ps5-bt-addr ] || stop "this is not a Legacy PS5 Bazzite Deck install"
    [ -e "$MARK" ] && stop "already converted: power off and start with bazzite-bootc-loader (or: --undo)"
    [ "$(findmnt -no FSTYPE /)" = ext4 ] || stop "the system partition is $(findmnt -no FSTYPE /), not ext4: flash the bootc image instead"
    UUID=$(blkid -s UUID -o value "$(findmnt -no SOURCE /)") && [ -n "$UUID" ] || stop "no UUID for the system partition"
    find_esp || stop "boot partition (label 'boot') not found: is the USB drive plugged in?"
    [ "$(sed -n 's/.*\broot=\([^ ]*\).*/\1/p' "$EFI/cmdline.txt")" = "$(sed -n 's/.*\broot=\([^ ]*\).*/\1/p' /proc/cmdline)" ] ||
        stop "$EFI/cmdline.txt starts another system than the one running: plug in only this install's drive"
    # without the command, ostree prints its general help and exits 0: look for the command's own option
    case "$(ostree container image deploy --help 2>&1 || true)" in *--stateroot*) ;; *) stop "this system has no 'ostree container image deploy': flash the bootc image instead" ;; esac
    command -v python3 >/dev/null && python3 -c 'import tomllib' || stop "python3 with tomllib is missing: flash the bootc image instead"
    free=$(df -BG --output=avail / | tail -1 | tr -dc 0-9); efree=$(df -BM --output=avail "$EFI" | tail -1 | tr -dc 0-9)
    echo "Legacy install on UUID=$UUID, boot partition $EFI; free: ${free} GiB system, ${efree} MiB boot partition"
    [ "$free" -ge "$NEED_ROOT_GIB" ] || stop "the image needs $NEED_ROOT_GIB GiB free on the system partition (the Legacy files, about 20 GiB, are freed by --cleanup afterwards)"
    [ "$efree" -ge "$NEED_ESP_MIB" ] || stop "the boot partition needs $NEED_ESP_MIB MiB free"
    if [ "$MODE" = check ]; then
        echo "Ready. --apply downloads $IMAGE (about 7 GB) and sets it up beside this system; nothing here is deleted."
        exit 0
    fi

    echo "==> ostree layout on this partition"
    [ -d /ostree/repo ] || ostree admin init-fs --modern /
    ostree config --repo=/ostree/repo set sysroot.bootloader none
    [ -d /ostree/deploy/default ] || ostree admin os-init default --sysroot=/
    echo "==> downloading and deploying $IMAGE"
    ostree container image deploy --sysroot=/ --stateroot=default --imgref="ostree-unverified-registry:$IMAGE" \
        --target-imgref="ostree-image-signed:docker://$IMAGE" --karg="root=UUID=$UUID" --karg=rw
    D=$(ls -d /ostree/deploy/default/deploy/*.0 | head -1)
    [ -x "$D/usr/bin/ps5-bootc-sync" ] || stop "the deployed image has no ps5-bootc-sync: nothing on the boot partition was changed (--undo removes /ostree)"
    append_kargs "$D" /boot/loader/entries

    echo "==> accounts and settings"
    carry_accounts "" "$D"
    for f in hostname machine-id localtime locale.conf vconsole.conf; do
        if [ -e "/etc/$f" ] || [ -L "/etc/$f" ]; then cp -a "/etc/$f" "$D/etc/$f"; fi
    done
    for d in NetworkManager/system-connections ps5-bazzite-deck; do
        [ -d "/etc/$d" ] && mkdir -p "$D/etc/$d" && cp -a "/etc/$d/." "$D/etc/$d/"
    done
    cp -a /etc/ssh/ssh_host_*key* "$D/etc/ssh/" 2>/dev/null || true
    write_firstboot "$D"

    echo "==> boot partition: Legacy files to legacy-backup/, then the bootc ones"
    mkdir -p "$EFI/legacy-backup"
    cp "$EFI/cmdline.txt" "$EFI/legacy-backup/"
    for f in bzImage initrd.img; do mv "$EFI/$f" "$EFI/legacy-backup/$f"; done
    rm -f "$EFI/initrd.img.noviola"
    if ! python3 "$D/usr/bin/ps5-bootc-sync" --boot /boot --esp "$EFI"; then
        for f in bzImage initrd.img; do mv -f "$EFI/legacy-backup/$f" "$EFI/$f"; done
        cp "$EFI/legacy-backup/cmdline.txt" "$EFI/cmdline.txt"
        stop "writing the boot partition failed: the Legacy files are back in place, this install still starts"
    fi
    [ -f "$EFI/vram.txt" ] || echo 0x180000000 > "$EFI/vram.txt"
    date -u +"%F $IMAGE" > "$MARK"
    sync
    cat << EOF

Done. Power off, and start with bazzite-bootc-loader from the Stable release (not an older loader).
- The first start moves your home folders and Flatpaks over; this install's files are still all here.
- If it doesn't start: on a PC, copy bzImage, initrd.img and cmdline.txt from legacy-backup/ on the drive's
  'boot' partition back to its top folder. Legacy starts again as before.
- Once bootc works: sudo bash legacy-to-bootc.sh --cleanup   frees the space of the Legacy system.
- Options you added to cmdline.txt were kept. Decky Loader and packages installed into the system need installing again.
EOF
    ;;
--undo)
    [ -e /run/ostree-booted ] && stop "--undo is for the Legacy system, before the first bootc start. From bootc: copy the files in legacy-backup/ back from a PC"
    find_esp || stop "boot partition (label 'boot') not found"
    if [ -f "$EFI/legacy-backup/bzImage" ]; then
        for f in bzImage initrd.img cmdline.txt; do cp "$EFI/legacy-backup/$f" "$EFI/$f"; done
        rm -rf "$EFI/legacy-backup" "$EFI/ostree" "$EFI/.ps5-bootc-sync.json" "$EFI/ROLLBACK.txt"
    fi
    for d in /ostree/deploy/*/deploy/*.0; do [ -d "$d" ] && chattr -i "$d" 2>/dev/null; done
    rm -rf /ostree /boot/loader /boot/loader.0 /boot/loader.1 /boot/ostree
    echo "Back to Legacy: the bootc image and its boot files are removed."
    ;;
--cleanup)
    [ -e /run/ostree-booted ] && [ -e "/sysroot$MARK" ] || stop "--cleanup runs on the bootc system this script converted"
    [ -e /var/lib/ps5-bazzite-bootc/legacy-migrated ] || stop "the first-start move hasn't run: journalctl -b -u ps5-legacy-migrate"
    left=$(for src in /sysroot/var/home /sysroot/home; do [ -d "$src" ] && [ ! -L "$src" ] && ls -A "$src"; done 2>/dev/null | tr '\n' ' ')
    [ -z "$left" ] || stop "home folders still in the Legacy system: $left(move what you need from /sysroot/var/home first)"
    mapfile -t old < <(cd /sysroot && find . -mindepth 1 -maxdepth 1 ! -name ostree ! -name boot ! -name 'lost+found' -printf '%f\n')
    [ ${#old[@]} -gt 0 ] || { echo "Nothing left of the Legacy system."; exit 0; }
    echo "This deletes the Legacy system for good, in /sysroot: ${old[*]}"
    [ "${2:-}" = --yes ] || { read -r -p "Type DELETE to go on: " a; [ "$a" = DELETE ] || stop "nothing deleted"; }
    unshare -m sh -c 'mount -o remount,rw /sysroot && cd /sysroot && rm -rf --one-file-system -- "$@"' sh "${old[@]}"
    rm -f /etc/systemd/system/ps5-legacy-migrate.service /etc/systemd/system/sysinit.target.wants/ps5-legacy-migrate.service /etc/ps5-legacy-migrate
    for d in /boot/efi /efi; do rm -rf "$d/legacy-backup"; done
    echo "Legacy system deleted. Free now: $(df -h --output=avail / | tail -1 | tr -d ' ')"
    ;;
*)
    stop "usage: legacy-to-bootc.sh [--apply | --undo | --cleanup]"
    ;;
esac
