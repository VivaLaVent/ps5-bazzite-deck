# PS5 Bazzite (bootc)

[PS5 Bazzite Deck](https://github.com/VivaLaVent/ps5-bazzite-deck), built the way Bazzite itself is built. Same
**Steam Gaming Mode**, same KDE desktop, same PS5 fixes, but the system is a bootc image: it **updates from Steam's
update button** like any Bazzite Deck, and a bad update is **undone with one command**. Runs from a USB drive and leaves
the PS5 itself untouched: restart or power off and the PS5 starts its own system again.

**Experimental.** It hasn't been tested on many consoles yet. For a console you use every day, install
[PS5 Bazzite Deck](https://github.com/VivaLaVent/ps5-bazzite-deck) instead.

## Not affiliated with Bazzite

This is a community project. It is **not** made or supported by the [Bazzite](https://bazzite.gg) project, Universal Blue
or Sony. Ask here or on Discord, not in Bazzite's channels.

## Install

You need a PS5 that runs the [PS5 Linux loader](https://github.com/ps5-linux/ps5-linux-loader) and a USB drive of at
least 32 GB (an SSD is much faster). Use a different drive from your PS5 Bazzite Deck one, so you can always swap back.

1. Download all `.img.7z` parts of the newest release from the [releases page](https://github.com/VivaLaVent/ps5-bazzite-bootc/releases)
   and extract them with [7-Zip](https://www.7-zip.org) (open the `.001` file).
2. Write the `.img` to the USB drive with [Rufus](https://rufus.ie). This erases the drive.
3. Plug it into a **rear** USB-A port of the PS5.
4. In the PS5 settings: keep USB power on in rest mode, and switch HDMI Device Link off.
5. Run the jailbreak and the loader as usual, and wait until the light stops blinking orange before pressing power.
6. The first start takes a few minutes. You land in Steam Gaming Mode. Login for the desktop and `sudo`: **ps5** / **ps5**.

## Updating

In Steam: **Settings → System**, check for updates and apply. Or in a terminal: `sudo bootc upgrade`.

After an update, restart: the PS5 starts its own system first (a warm restart is skipped once), then run the loader as
usual and you're on the new version. Your games, settings and files are kept.

## Going back to the previous version

`sudo bootc rollback`, then restart and run the loader. If the new version doesn't start at all, the USB drive's
small `boot` partition has a `ROLLBACK.txt` that explains how to start the previous one from a PC.

## Boot options (cmdline.txt)

`cmdline.txt` is on the USB drive's small `boot` partition and works as in PS5 Bazzite Deck: add an option at the end of
the single line, for example `amdgpu.ps5_cu_unlock=3` or `amdgpu.force_1080p=1`. Options you add are kept through updates.
You can also edit it from a PC.

## Problems

Run `ps5-report` in a terminal and post the file it makes, with what you did and what happened, on Discord or as a
[GitHub issue](https://github.com/VivaLaVent/ps5-bazzite-bootc/issues). Mention that it's the bootc version.

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
