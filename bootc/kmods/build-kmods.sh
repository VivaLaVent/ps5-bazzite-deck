#!/bin/bash
# Bazzite's out-of-tree modules are built for its kernel and go with it (build.sh removes kmod-*); the ones for
# games and streaming are built here for ours (modules.list), against the build tree in our kernel package.
# Each is optional: when its source is gone, its tag no longer names the pinned commit or it doesn't build,
# the image is built without it and a warning. VERSION in the output names what is in.
set -euo pipefail
OUT=$1
M=$(dirname "$(readlink -f "$0")")
W=/tmp/kmods
mkdir -p "$W/src" "$OUT"
none() { echo "::warning::no out-of-tree drivers in the image: $1"; exit 0; }
command -v rpm2cpio >/dev/null && command -v cpio >/dev/null || none "rpm2cpio or cpio missing"
rpm2cpio /kernel/linux-ps5-*.rpm | (cd "$W" && cpio -idm --quiet './usr/lib/modules/*') || none "the kernel package didn't unpack"
KVER=$(ls "$W/usr/lib/modules")
B=$W/usr/lib/modules/$KVER/build
[ -f "$B/Module.symvers" ] || none "no build tree in the kernel package"
dnf5 -y install --setopt=install_weak_deps=False gcc make >/dev/null || none "gcc and make didn't install"

# name repo tag commit dir module...; every failure returns 1 (errexit is off inside an if)
build() {
    local name=$1 repo=$2 tag=$3 commit=$4 dir=$5 src=$W/src/$1 m
    shift 5
    git clone -q --depth 1 --branch "$tag" --recurse-submodules --shallow-submodules \
        "https://github.com/$repo" "$src" 2>/dev/null || { echo "$name: $repo $tag not available"; return 1; }
    [ "$(git -C "$src" rev-parse HEAD)" = "$commit" ] || { echo "$name: $tag is no longer $commit"; return 1; }
    make -C "$B" M="$src/$dir" modules > "$W/$name.log" 2>&1 || { tail -15 "$W/$name.log"; echo "$name: does not build"; return 2; }
    mkdir -p "$OUT/$name" || return 1
    for m in "$@"; do
        install -m644 "$src/$dir/$m.ko" "$OUT/$name/" || return 1
    done
    if [ "$name" = xpadneo ]; then
        install -m644 -t "$OUT/$name" "$src"/hid-xpadneo/etc-udev-rules.d/*.rules \
            "$src"/hid-xpadneo/etc-modprobe.d/*.conf || return 1
    fi
}

grep -v '^[[:space:]]*#' "$M/modules.list" | while read -r name repo tag commit dir mods; do
    [ -n "$name" ] || continue
    # shellcheck disable=SC2086  # the module names are one word each
    if build "$name" "$repo" "$tag" "$commit" "$dir" $mods; then
        echo "$name $tag" >> "$OUT/VERSION"
    else
        rc=$?
        rm -rf "${OUT:?}/${name:?}"
        # a driver whose source is gone is left out; one that no longer compiles stops the build (a kernel change broke it)
        if [ "$rc" = 2 ]; then echo "::error::$name $tag doesn't build against this kernel"; touch "$W/failed"; continue; fi
        echo "::warning::$name $tag left out of the image (source not available)"
    fi
done
[ ! -e "$W/failed" ] || exit 1
