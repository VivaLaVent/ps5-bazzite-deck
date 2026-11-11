#!/bin/bash
# shellcheck disable=SC2154  # moddir, initdir and systemdsystemunitdir come from dracut
check() { return 255; }
depends() { echo systemd; }
install() {
    inst_script "$moddir/ps5-ostree-path.sh" /usr/bin/ps5-ostree-path
    inst_simple "$moddir/ps5-ostree-path.service" "$systemdsystemunitdir/ps5-ostree-path.service"
    inst_multiple cat ln readlink
    mkdir -p "$initdir$systemdsystemunitdir/ostree-prepare-root.service.wants"
    ln_r "$systemdsystemunitdir/ps5-ostree-path.service" "$systemdsystemunitdir/ostree-prepare-root.service.wants/ps5-ostree-path.service"
}
