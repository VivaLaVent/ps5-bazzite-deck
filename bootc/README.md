# PS5 Bazzite (bootc)

[PS5 Bazzite Deck](https://github.com/VivaLaVent/ps5-bazzite-deck), built the way Bazzite itself is built. Same
**Steam Gaming Mode**, same KDE desktop, same PS5 fixes, but the system is a bootc image: it **updates from Steam's
update button** like any Bazzite Deck, and a bad update is **undone with one command**. Runs from a USB drive and leaves
the PS5 itself untouched: restart or power off and the PS5 starts its own system again.

**Experimental.** It hasn't been tested on many consoles yet. For a console you use every day, the Legacy install of
[PS5 Bazzite Deck](https://github.com/VivaLaVent/ps5-bazzite-deck) is the safer choice.

## Not affiliated with Bazzite

This is a community project. It is **not** made or supported by the [Bazzite](https://bazzite.gg) project, Universal Blue
or Sony. Ask here or on Discord, not in Bazzite's channels.

## Install

You need a PS5 that runs the PS5 Linux loader (firmware 3.00 to 13.60), **bazzite-bootc-loader** from the same release
(rmux's loader with support for bootc's boot entries; it starts Legacy installs too), and a USB drive or SSD of 64 GB or
more (the system alone is about 25 GB; an SSD is much faster). Use a different drive from your Legacy one, so you can
always swap back.

1. Download all `ps5-bazzite-deck-bootc-*.img.7z` parts of the newest release from the
   [releases page](https://github.com/VivaLaVent/ps5-bazzite-deck/releases)
   and extract them with [7-Zip](https://www.7-zip.org) (open the `.001` file).
2. Write the `.img` to the drive with [Rufus](https://rufus.ie) in **DD mode** or [Balena Etcher](https://etcher.balena.io). This erases the drive.
3. Plug it into a **rear** USB-A port of the PS5.
4. In the PS5 settings: keep USB power on in rest mode, and switch HDMI Device Link off.
5. Run the jailbreak and bazzite-bootc-loader, and wait until the light stops blinking orange before pressing power.
6. The first start takes a few minutes. You land in Steam Gaming Mode. Login for the desktop and `sudo`: **ps5** / **ps5**.

## Updating

In Steam: **Settings → System**, check for updates and apply. Or in a terminal: `sudo bootc upgrade`.

After an update, restart: the PS5 starts its own system first (a warm restart is skipped once), then run the loader as
usual and you're on the new version. Your games, settings and files are kept.

Still on the old version after that? The shutdown was probably cut short (power loss, holding the power button) before
the USB drive was updated. It catches up during the start, so restart once more and run the loader again.

## Going back to the previous version

`sudo bootc rollback`, then restart and run the loader. If the new version doesn't start at all, the USB drive's
small `boot` partition has a `ROLLBACK.txt` that explains how to start the previous one from a PC.

## Boot options (cmdline.txt)

On the console: `sudo rpm-ostree kargs --append=amdgpu.ps5_cu_unlock=3` (or `--delete=` to remove one), then restart.
This is the Bazzite way: the option becomes part of the system and survives updates and rollbacks.

From a PC, for example when the screen stays black: add the option at the end of the single line in `cmdline.txt`, on
the USB drive's small `boot` partition, for example `amdgpu.force_1080p=1`. Options added there are kept through updates
too. What the loader reads from the drive is described in [docs/loader-contract.md](docs/loader-contract.md).

## Problems

Run `ps5-report` in a terminal and post the file it makes, with what you did and what happened, on Discord or as a
[GitHub issue](https://github.com/VivaLaVent/ps5-bazzite-deck/issues). Mention that it's the bootc version.

## Join the PS5 Linux community on Discord

**[discord.gg/ps5linux](https://discord.gg/ps5linux)**: help in `#bazzite-problems`, test builds, and everything
else about Linux on the PS5.

## Like this project? Donate

[Buy me a coffee on Ko-fi](https://ko-fi.com/vivalavent).

## Credits

Everything PS5-specific comes from [PS5 Bazzite Deck](https://github.com/VivaLaVent/ps5-bazzite-deck),
[ps5-linux-image](https://github.com/ps5-linux/ps5-linux-image), rmux's loader and kernel patches, and their
contributors. The image is built like Universal Blue's [image template](https://github.com/ublue-os/image-template);
the boot partition sync follows Armada's (thanks JustRadical).

How it works and how to build it: [docs/building.md](docs/building.md).
