# What the loader reads from the USB drive

bazzite-bootc-loader ([soniciso1's ps5-linux-loader](https://github.com/soniciso1/ps5-linux-loader) + `loader/patches`) doesn't know about bootc. It looks for
fixed file names on the USB drive's FAT partition (the EFI partition of this image, labelled `boot`), in
`/mnt/usb0/` to `/mnt/usb3/` and their `PS5/Linux/` subfolders, then in `/data/PS5/Linux/` on the console's
own storage. Everything below is written by
`ps5-bootc-sync`, at every start and at every shutdown (after ostree has finished a staged update).
Each release records the loader it was tested with: `loader=` in `/usr/share/ps5-bazzite-bootc/VERSION`
and in the release notes.

| Path | Read by | Contents |
|---|---|---|
| `bzImage` | loader | kernel of the default deployment |
| `initrd.img` | loader | its initramfs. The loader appends what it dumps (below) to it in memory: the PS5 Pro GPU firmware where amdgpu loads it, the Wi-Fi firmware and the pairing export under `/ps5`. `ps5-dumps` copies all of it to `/run/ps5` before the initramfs ends, in this table's layout; a warm reboot (`ps5-kexec`) appends the GPU firmware from there, since it starts without the loader |
| `cmdline.txt` | loader | one line: the boot entry's options, then any options you added; yours are kept across updates |
| `vram.txt` | loader | VRAM size in hex bytes: 6 GB (`0x180000000`), from the disk image and once on existing installs (`ps5-console-defaults`) |
| `ostree/<id>/vmlinuz`, `initramfs.img`, `cmdline.txt` | you, for a manual rollback | the other deployments bootc keeps (normally the previous one); `<id>` is 12 hex characters |
| `path-override.txt` | loader | absent normally. Its presence means a manual rollback: `bzImage=ostree/<id>/vmlinuz` and `initrd.img=ostree/<id>/initramfs.img`, and `ps5-bootc-sync` leaves the partition alone |
| `ROLLBACK.txt` | you | how to start the previous deployment from a PC |
| `lib/` | Linux, after `/run/ps5` | Wi-Fi and PS5 Pro GPU firmware the loader dumps next to the `initrd.img` it loaded |
| `ps5-bt-sync.json` | `ps5-bt-import`, after `/run/ps5` | written by the loader at every start next to the `initrd.img` it loaded: the PS5 system's active Bluetooth pairings, with their keys. Imported into BlueZ and deleted before Bluetooth starts; deleted without import while the Linux-only Bluetooth address is on |
| `.ps5-bootc-sync.json` | `ps5-bootc-sync` | which deployment the root files belong to, and the options it wrote |

Two limits of the loader matter here. The standard loader's `path-override.txt` redirects `bzImage` and
`initrd.img` only (bazzite-bootc-loader also `cmdline.txt` and `vram.txt`), so `ROLLBACK.txt` has the
deployment's `cmdline.txt` copied over the root one, which works with both. The firmware is
dumped next to the redirected initrd, under `ostree/<id>/lib/`, and appended to it from there: a manual rollback with
bazzite-bootc-loader starts with it too. With the standard loader, Wi-Fi and the PS5 Pro GPU firmware can be missing
until you're back on the default deployment.

The boot entries stay on `/boot` (ext4), which the loader can't read: this table is the contract.
