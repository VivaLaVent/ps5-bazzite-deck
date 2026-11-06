#!/usr/bin/bash
# RADV with patches/, 64- and 32-bit, built in the base image against its own libraries.
#   build-radv.sh <out dir>
set -euxo pipefail
M=$(cd "$(dirname "$0")" && pwd)
OUT=${1:?usage: build-radv.sh <out dir>}
. "$M/pins.env"

base=$(rpm -q --qf '%{VERSION}\n' mesa-vulkan-drivers | head -1)
[ "$base" = "$MESA_VERSION" ] || echo "::warning::Bazzite ships Mesa $base, RADV is built from $MESA_VERSION (bootc/mesa/pins.env)"

# Bazzite builds with Terra and disables it afterwards; libdrm-devel must match the installed libdrm.
# Arch on every -devel package: a bare name next to its .i686 is satisfied by the i686 one alone.
dnf5 config-manager setopt terra.enabled=1 terra-mesa.enabled=1
x64=(libdrm-devel expat-devel zlib-ng-compat-devel libzstd-devel elfutils-libelf-devel wayland-devel libffi-devel
     libxcb-devel libXau-devel libX11-devel libxshmfence-devel libXrandr-devel libXrender-devel libXext-devel
     libXxf86vm-devel libXfixes-devel libdisplay-info-devel)
x32=(glibc-devel libstdc++-devel libdrm-devel expat-devel zlib-ng-compat-devel libzstd-devel elfutils-libelf-devel
     wayland-devel libffi-devel libxcb-devel libXau-devel libX11-devel libxshmfence-devel libXrandr-devel libXrender-devel
     libXext-devel libXxf86vm-devel libXfixes-devel)
dnf5 -y install --setopt=install_weak_deps=False \
    gcc gcc-c++ meson ninja-build patch git-core pkgconf-pkg-config bison flex glslang \
    python3-mako python3-pyyaml python3-packaging wayland-protocols-devel \
    "${x64[@]/%/.x86_64}" "${x32[@]/%/.i686}"
rpm -q libdrm libdrm-devel
pcs=(libdrm libdrm_amdgpu wayland-client xcb x11-xcb xcb-dri3 xcb-present xcb-randr xcb-shm xcb-sync xcb-xfixes
     xrandr xshmfence expat zlib libzstd libelf)
pc_x86_64() { pkg-config "$@"; }
pc_i686() { PKG_CONFIG_LIBDIR=/usr/lib/pkgconfig:/usr/share/pkgconfig pkg-config "$@"; }
# a -devel package's pkgconfig() requirements can be met by the other arch: install what each arch's .pc files miss
for arch in x86_64 i686; do
    for _ in 1 2 3 4; do
        need=$("pc_$arch" --exists --print-errors "${pcs[@]}" 2>&1 | sed -n "s/^Package '\([^']*\)'.* not found$/\1/p" | sort -u)
        [ -n "$need" ] || break
        pkgs=$(for n in $need; do rpm -q --whatprovides "pkgconfig($n)" --qf "%{NAME}.$arch\n" 2>/dev/null | head -1; done | sort -u)
        [ -n "$pkgs" ] || break
        echo "$arch: $need -> $pkgs"
        # shellcheck disable=SC2086
        dnf5 -y install --setopt=install_weak_deps=False $pkgs
    done
    "pc_$arch" --exists --print-errors "${pcs[@]}" || { echo "$arch .pc files missing"; exit 1; }
done

W=$(mktemp -d)
git clone -q --depth 1 --branch "mesa-$MESA_VERSION" "https://github.com/$MESA_REPO" "$W/mesa"
[ "$(git -C "$W/mesa" rev-parse HEAD)" = "$MESA_COMMIT" ] || { echo "mesa-$MESA_VERSION is not $MESA_COMMIT"; exit 1; }
for p in "$M"/patches/*.patch; do patch -d "$W/mesa" -p1 -s --no-backup-if-mismatch < "$p"; done

cat > "$W/i686.ini" <<'EOF'
[binaries]
c = ['gcc', '-m32']
cpp = ['g++', '-m32']
ar = 'gcc-ar'
strip = 'strip'
pkg-config = 'pkg-config'

[properties]
pkg_config_libdir = ['/usr/lib/pkgconfig', '/usr/share/pkgconfig']

[host_machine]
system = 'linux'
cpu_family = 'x86'
cpu = 'i686'
endian = 'little'
EOF

# shellcheck disable=SC2054
opts=(-Dbuildtype=release -Doptimization=2 -Dplatforms=x11,wayland -Dvulkan-drivers=amd
      -Dgallium-drivers= -Dvulkan-layers= -Dvideo-codecs=all -Dllvm=disabled -Dopengl=false -Dgles1=disabled
      -Dgles2=disabled -Degl=disabled -Dgbm=disabled -Dglx=disabled -Dbuild-tests=false -Dvalgrind=disabled
      -Dlibunwind=disabled -Dlmsensors=disabled)
meson setup "$W/b64" "$W/mesa" "${opts[@]}"
ninja -C "$W/b64" src/amd/vulkan/libvulkan_radeon.so
meson setup "$W/b32" "$W/mesa" --cross-file "$W/i686.ini" "${opts[@]}"
ninja -C "$W/b32" src/amd/vulkan/libvulkan_radeon.so

mkdir -p "$OUT/lib64" "$OUT/lib"
install -m755 -s "$W/b64/src/amd/vulkan/libvulkan_radeon.so" "$OUT/lib64/"
install -m755 -s "$W/b32/src/amd/vulkan/libvulkan_radeon.so" "$OUT/lib/"
echo "$MESA_VERSION+$(cat "$M"/patches/*.patch | sha256sum | cut -c1-12)" > "$OUT/VERSION"
rm -rf "$W"
