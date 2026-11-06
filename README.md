# PS5 Bazzite Deck

Turn your PS5 into a Steam console: [Bazzite](https://bazzite.gg) in Steam Deck mode, adapted for the PlayStation 5.
It boots straight into **Steam Gaming Mode**, with a full KDE desktop one click away, runs from a USB drive or the M.2
slot, and leaves the PS5 itself untouched: restart or power off and the PS5 starts its own system again.

## Not affiliated with Bazzite

This is a community project. It is **not** made or supported by the [Bazzite](https://bazzite.gg) project, Universal Blue
or Sony. Ask here or on Discord, not in Bazzite's channels.

## Get started: the official wiki

Everything is on **[wiki.ps5-linux.eu](https://wiki.ps5-linux.eu)**: what you need, the install step by step, what works
on your console, and how to fix problems.

- [Install PS5 Bazzite Deck](https://wiki.ps5-linux.eu/choose/bazzite-deck)
- [Before you install](https://wiki.ps5-linux.eu/getting-started/overview): firmware, loader, drive, TV
- [Troubleshooting](https://wiki.ps5-linux.eu/troubleshooting/getting-help): logs over SSH, then one page per component

**Downloads:** the [releases page](https://github.com/VivaLaVent/ps5-bazzite-deck/releases). Use the release marked
**Latest**; releases marked **Pre-release** are test builds, even when their number is higher. Flash with balenaEtcher. What changed in which
version is in the [changelog](CHANGELOG.md).

## Built with bootc

PS5 Bazzite Deck is a bootc image: the whole system is one image, built and checked by GitHub Actions, the way Bazzite
itself is made. Updates come from Steam's update button (or `sudo bootc upgrade`), download in the background and take
over at the next start; `sudo bootc rollback` goes back to the version before. Steam's OS Update Channel offers **Stable**
(the stable release's kernel) and **Beta** (the newest pre-release's). It starts with bazzite-bootc-loader from
the release. More: [bootc/README.md](bootc/README.md).

Installs from before v2.5 run the older **Legacy** form and update in place with the command in each release's notes.
Switching to bootc (a reflash) is recommended. `ps5-report` shows which one you run on its Install line.

## Join the PS5 Linux community on Discord

**[discord.gg/ps5linux](https://discord.gg/ps5linux)**: help in `#bazzite-problems`, test builds, and everything
else about Linux on the PS5.

## Like this project? Donate

[Buy me a coffee on Ko-fi](https://ko-fi.com/vivalavent).

## Credits

Built on the work of the PS5 Linux community: [credits](https://wiki.ps5-linux.eu/credits).
