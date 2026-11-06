# What the loader reads from the USB drive

The [PS5 Linux loader](https://github.com/ps5-linux/ps5-linux-loader) doesn't know about bootc. It looks for
fixed file names on the USB drive's FAT partition (the EFI partition of this image, labelled `boot`), in
`/mnt/usb0/` to `/mnt/usb3/` and their `PS5/Linux/` subfolders. Everything below is written by
`ps5-bootc-sync`, at every start and at every shutdown (after ostree has finished a staged update).
Each release records the loader it was tested with: `loader=` in `/usr/share/ps5-bazzite-bootc/VERSION`
and in the release notes.

| Path | Read by | Contents |
|---|---|---|
| `bzImage` | loader | kernel of the default deployment |
| `initrd.img` | loader | its initramfs; on a PS5 Pro with the Viola GPU firmware appended by `ps5-stage-viola-fw` |
| `cmdline.txt` | loader | one line: the boot entry's options, then any options you added; yours are kept across updates |
| `vram.txt` | loader | not shipped; without it the loader uses 512 MB, the same as ps5-bazzite-deck's file |
| `ostree/<id>/vmlinuz`, `initramfs.img`, `cmdline.txt` | you, for a manual rollback | the other deployments bootc keeps (normally the previous one); `<id>` is 12 hex characters |
| `path-override.txt` | loader | absent normally. Its presence means a manual rollback: `bzImage=ostree/<id>/vmlinuz` and `initrd.img=ostree/<id>/initramfs.img`, and `ps5-bootc-sync` leaves the partition alone |
| `ROLLBACK.txt` | you | how to start the previous deployment from a PC |
| `lib/` | Linux | Wi-Fi and PS5 Pro GPU firmware the loader dumps next to the `initrd.img` it loaded |
| `.ps5-bootc-sync.json` | `ps5-bootc-sync` | which deployment the root files belong to, and the options it wrote |

Two limits of the loader matter here. The standard loader's `path-override.txt` redirects `bzImage` and
`initrd.img` only (bazzite-bootc-loader also `cmdline.txt` and `vram.txt`), so `ROLLBACK.txt` has the
deployment's `cmdline.txt` copied over the root one, which works with both. And the firmware is
dumped next to the redirected initrd, under `ostree/<id>/lib/`, where Linux doesn't look: during a manual
rollback Wi-Fi and the PS5 Pro GPU firmware can be missing until you're back on the default deployment.

bazzite-bootc-loader boots Boot Loader Specification entries when the FAT partition has `loader/entries/`.
This image keeps them on `/boot` (ext4), so the loader uses the files above, and this table is the contract.
