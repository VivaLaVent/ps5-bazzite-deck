# Tekniska anteckningar

Det här dokumentet vänder sig till den som vill förstå hur avbildningen skapas eller bygga den själv. Det behövs inte för vanlig användning.

## Varför Bazzite Deck tidigare inte fungerade på PS5

Problemet var varken bildutmatning eller gamescope. Bazzites Steam-spelsession startar Steam genom tjänsten `cardwired`, som laddar ett eBPF-program. PS5-kärnans konfiguration hade två saknade förutsättningar:

1. **BPF LSM.** `CONFIG_BPF_LSM=y` var satt, men `bpf` saknades i `CONFIG_LSM` och aktiverades därför aldrig.
2. **Kärnans BTF.** Patcheserien 7.3 hade `CONFIG_DEBUG_INFO_BTF` avstängd, så `/sys/kernel/btf/vmlinux` saknades.

Utan dessa kraschar `cardwired` i en startloop. Sessionsskriptet stänger då gamescope efter en sekund och Bazzite växlar till skrivbordet efter fem försök. Båda problemen löses med konfigurationsrader som `build.sh` tillämpar.

## Innehåll i förrådet

```
build.sh                               engångsbygge: hämtar byggaren, tillämpar korrigeringar, bygger och komprimerar
patches/ps5-iw620-kernel73-compat.patch Wi-Fi-drivrutin för NXP IW620 och ändringar för kärna 7.3
patches/ps5-bluetooth.patch            Bluetooth-korrigeringar för IW620 och MediaTek
patches/ps5-hdmi-rearm-pr46.patch      HDMI: bild tillbaka när samma skärm vaknar
patches/ps5-hdmi-output-fixes.patch    HDMI: kryptering, hotplug och återaktivering för rätt skärm
patches/ps5-hdmi-modes.patch           HDMI: 1440p120, 1440p60 och begränsning av olämpliga lägen
files/                                 filer som bakas in i avbildningen
CHANGELOG.md
```

`build.sh` ändrar Bazzites uppströmsbyggare och sparar alla ändringar i `local-changes.diff` i varje utgåva. Skriptet monterar patchkatalogen i kärnbygget så att VCN-firmware hittas, tillämpar Wi-Fi-patchar och sätter `CONFIG_LSM=…,bpf`. Därefter bygger det Linux 7.3 med PS5-patchar, BPF LSM, BTF och `CONFIG_MT7921E=m`, bakar in filer från `files/` och skapar utgåvans filer.

### Bygg själv

Du behöver Linux eller WSL med Docker och ungefär 60 GB ledigt utrymme:

```
git clone https://github.com/VivaLaVent/ps5-bazzite-deck && cd ps5-bazzite-deck
bash build.sh
```

Bygget tar några timmar eftersom kärnan kompileras och Bazzite hämtas. Resultatet läggs i `~/ps5-build-7.3/output/`.

## Versionering

Utgåvor taggas `vMAJOR.MINOR.PATCH`:

- **MAJOR:** annan grund, exempelvis ny Bazzite-huvudversion eller ny kärnserie
- **MINOR:** nya funktioner eller korrigeringar som förändrar vad som fungerar
- **PATCH:** mindre korrigeringar och ombyggen med nyare uppströmspatchar eller firmware

Varje utgåva innehåller `VERSIONS.md` med exakta låsningar för Bazzite-avbildning, kärntagg, patchförråd, byggarcommit och kärnkonfiguration. `CHANGELOG.md` beskriver förändringar mellan utgåvor.

## Bluetooth och varm omstart

`ps5-bt-addr` och `ps5-bt-addr.service` ger IW620 en Linux-adress. `ps5-bt-connectable.service` gör adaptern mottaglig för inkommande anslutningar. `tools/bt-mainconf.sh` ställer in BlueZ för återparkoppling, `ps5-hidp.conf` laddar `hidp` vid start och `ps5-bt-revive.service` laddar om `btusb` om adaptern inte är igång efter start.

Varm omstart är ett aktivt val med `ps5-warm-reboot on`. `ps5-kexec` laddar kärna, initrd och `cmdline.txt` från startpartitionen med `kexec_file_load`. Den överstyrda `reboot.target` startar om med kexec när en kärna laddats och annars normalt. Funktionen används bara vid omstart, aldrig vid avstängning.

## Skicka ändringar uppströms

`tools/upstream-pr.sh "<titel>" patches/x.patch … [--submit]` återskapar rmux `linux.patch` från v7.3, uppströmsändringar och lokala patchar. Standardläget är en torrkörning. Med `--submit` pushas en gren till din förgrening och en pull request öppnas med patchhuvudet som beskrivning.

Patcher i `patches/parked/` används inte. HDMI CEC, USB-körning och energihantering dokumenteras i respektive patch och regel under `files/`.
