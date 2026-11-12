#!/bin/bash
# shellcheck disable=SC2154  # moddir, initdir and systemdsystemunitdir come from dracut
check() { return 255; }
depends() { echo systemd; }
install() {
    inst_script "$moddir/ps5-dumps.sh" /usr/bin/ps5-dumps
    inst_simple "$moddir/ps5-dumps.service" "$systemdsystemunitdir/ps5-dumps.service"
    inst_multiple cp mkdir
    mkdir -p "$initdir$systemdsystemunitdir/initrd.target.wants"
    ln_r "$systemdsystemunitdir/ps5-dumps.service" "$systemdsystemunitdir/initrd.target.wants/ps5-dumps.service"
}
