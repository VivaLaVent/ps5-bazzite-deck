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
| `initrd.img` | loader | its initramfs; on a PS5 Pro with the Viola GPU firmware appended by `ps5-stage-viola-fw` |
| `cmdline.txt` | loader | one line: the boot entry's options, then any options you added; yours are kept across updates |
| `vram.txt` | loader | VRAM size in hex bytes: 6 GB (`0x180000000`), from the disk image and once on existing installs (`ps5-console-defaults`) |
| `ostree/<id>/vmlinuz`, `initramfs.img`, `cmdline.txt` | you, for a manual rollback | the other deployments bootc keeps (normally the previous one); `<id>` is 12 hex characters |
| `path-override.txt` | loader | absent normally. Its presence means a manual rollback: `bzImage=ostree/<id>/vmlinuz` and `initrd.img=ostree/<id>/initramfs.img`, and `ps5-bootc-sync` leaves the partition alone |
| `ROLLBACK.txt` | you | how to start the previous deployment from a PC |
| `lib/` | Linux | Wi-Fi and PS5 Pro GPU firmware the loader dumps next to the `initrd.img` it loaded |
| `ps5-bt-sync.json` | `ps5-bt-import` | written by the loader at every start next to the `initrd.img` it loaded: the PS5 system's active Bluetooth pairings, with their keys. Imported into BlueZ and deleted before Bluetooth starts; deleted without import while the Linux-only Bluetooth address is on |
| `.ps5-bootc-sync.json` | `ps5-bootc-sync` | which deployment the root files belong to, and the options it wrote |

Two limits of the loader matter here. The standard loader's `path-override.txt` redirects `bzImage` and
`initrd.img` only (bazzite-bootc-loader also `cmdline.txt` and `vram.txt`), so `ROLLBACK.txt` has the
deployment's `cmdline.txt` copied over the root one, which works with both. And the firmware is
dumped next to the redirected initrd, under `ostree/<id>/lib/`, where Linux doesn't look: during a manual
rollback Wi-Fi and the PS5 Pro GPU firmware can be missing until you're back on the default deployment.

The boot entries stay on `/boot` (ext4), which the loader can't read: this table is the contract.
