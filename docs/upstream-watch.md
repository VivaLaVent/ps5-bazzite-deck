# What to watch (repos and channels)

**[wiki.ps5-linux.eu](https://wiki.ps5-linux.eu/)** is the official PS5-Linux wiki (loaders, hardware, other images); check it before searching repos individually.

Checked to find fixes, features and problems relevant to this image. "Last seen" is the newest commit when last checked.

## Kernel and drivers
| Repo | What it is for us | Last seen |
|---|---|---|
| [ps5-linux/ps5-linux-patches](https://github.com/ps5-linux/ps5-linux-patches) | upstream PS5 kernel patches (7.2.x): Pro GPU #58, fan curve #60, USB-C DP off by default #62 | 2026-11-01 `53809a3` (#66 Pro fixes + GPU governor: ported in full, v2.0.0; #40 MT7921 config already in) |
| [rmuxnet/ps5-linux-patches-1](https://github.com/rmuxnet/ps5-linux-patches-1) (`meower`) | the 7.3 port our kernel is based on; branches `fanfix`, `vcn_script` | 2026-11-01 `cf37af5` (IW620 LE reconnect, taken; hwmon fan driver taken with firmware control as default) |
| [Slip-Up/ps5-linux-patches](https://github.com/Slip-Up/ps5-linux-patches) | Slip's HDMI work: native FRL, ALLM, modes (`hdmi-usbc-test`) | 2026-10-28 `12c11d8` |
| [ps5-linux/ps5-linux-mwifiex](https://github.com/ps5-linux/ps5-linux-mwifiex) | IW620 Wi-Fi driver | 2026-10-20 |
| [QuartConz/ps5-pro-viola-bluetooth](https://github.com/QuartConz/ps5-pro-viola-bluetooth) | PS5 Pro Bluetooth (in v1.8.0) | 2026-10-26 |
| [WizGery/ps5-mediatek-fixes](https://github.com/WizGery/ps5-mediatek-fixes) | MediaTek Bluetooth fixes (Slim) | 2026-10-19 |
| Lawson's VRR work (shared on Google Drive) | VRR, 4K120 over FRL (in v1.7/1.8) | 2026-10-28 |

## Image and loaders
| Repo | What it is for us | Last seen |
|---|---|---|
| [ps5-linux/ps5-linux-image](https://github.com/ps5-linux/ps5-linux-image) | the image builder we build on; Pro GPU firmware staging #46 | 2026-10-29 `d68a854` |
| [ublue-os/bazzite](https://github.com/ublue-os/bazzite) | the base (`bazzite-deck:stable`); its digest is in each release's VERSIONS.md | per build |
| [rmuxwashere/ps5-linux-loader](https://github.com/rmuxwashere/ps5-linux-loader) | the loader (fat/slim) | 2026-10-25 |
| [gzimbric/ps5-linux-loader](https://github.com/gzimbric/ps5-linux-loader) | Pro loader, 11.xx (branches `ps5-pro-11xx`) | 2026-10-25 |
| [Wigglez-sudo/12.xx-linux-loader](https://github.com/Wigglez-sudo/12.xx-linux-loader) | 12.xx loader incl. Pro | 2026-10-27 |

## Plugins and tools
| Repo | What it is for us | Last seen |
|---|---|---|
| [NotHavocc/ps5-hwcon-plugin](https://github.com/NotHavocc/ps5-hwcon-plugin) | fan/clock/LED plugin; handles kernels with and without `target_temp` | 2026-10-28 v1.4.0 |
| [cmartinespinosa/decky-ps5-bazzite-updater](https://github.com/cmartinespinosa/decky-ps5-bazzite-updater) | updater plugin for this image | 2026-10-28 |
| [BnuuySolutions/PSVR2Toolkit](https://github.com/BnuuySolutions/PSVR2Toolkit) | PSVR2 on the USB-C port | — |

## Discord channels (Linux For PlayStation 5)
`#bazzite-general`, `#bazzite-problems` (forum), `#bazzite-prereleases-experimental`, `#bazzite-ps5-pro-tests`,
`#dev`, `#loader` (pins: current payload), `#fixes`, `#drivers`, `#patches`, `#submit`.
