# PS5 Bazzite Deck

[English](README.md) | [Svenska](README.sv.md)

Gör din PS5 till en Steam-konsol. Det här är [Bazzite](https://bazzite.gg) i Steam Deck-läge, anpassat för PlayStation 5. Systemet startar direkt i **Steam-spelläget**, och KDE-skrivbordet är ett klick bort.

Systemet körs från en USB-enhet som startas med **rmux** [PS5 Linux-laddare](https://github.com/rmuxwashere/ps5-linux-loader/releases). PS5-systemet ändras inte: Linux startas bara när du kör laddaren och efter en omstart startar konsolens vanliga system igen.

Använd den utgåva som är märkt **Latest** på [utgåvessidan](../../releases). Utgåvor märkta **Pre-release** är testbyggen, även om versionsnumret är högre.

**Hämta:** [utgåvor](../../releases) · **Hjälp och tester:** [Discord](https://discord.gg/qGcuTgBBYU) · **Stöd projektet:** [Ko-fi](https://ko-fi.com/vivalavent)

## Funktioner och hårdvara

Samma avbildning används för alla PS5-modeller som stöds. HDMI-krets, Wi-Fi/Bluetooth-krets och konsolmodell avgör vilka funktioner som finns. Kör `ps5-report` för en sammanställning, eller använd kommandona i den engelska [hårdvarutabellen](README.md#features-and-your-hardware).

- **FLAVA3** har 1440p120, 4K120, HDR och VRR när skärm och kabel stödjer det. **VERDE** saknar dessa funktioner men har 1080p60/120, 1440p60 och 4K60 där skärmen stödjer dem.
- **IW620** kan använda en separat Bluetooth-adress för Linux med `ps5-bt-address on`. Funktionen är ett aktivt val, eftersom omstarter då går via PS5-systemet. MediaTek använder separata parkopplingsprofiler automatiskt.
- **PS5 Pro** stöds från v1.8.4. Starta laddaren en gång till efter första starten så används Pro-modellens GPU-firmware.

Detaljer om DualSense-profiler finns i [den engelska guiden](docs/dualsense-profiles.md). Rapporter från PS5 Pro tas emot i `#bazzite-ps5-pro-tests`.

## Förberedelser

- En PS5 med firmware som rmux laddare stöder. Testat med 13.60.
- En ursprunglig PS5, PS5 Slim eller PS5 Pro.
- Stäng av **etaHEN** och **kstuff**. De fungerar inte med Linux-laddaren.
- En USB-enhet på minst 32 GB, helst en extern SSD.
- En dator för hämtning och skrivning av avbildningen. Ett USB-tangentbord underlättar första starten.
- I PS5-systemets inställningar: ange `Settings` → `System` → `Power Saving` → `Features Available in Rest Mode` → `Supply Power to USB Ports` till **Always**. Stäng också av `Settings` → `HDMI` → `Enable HDMI Device Link`; annars blir skärmen ofta svart.

## Installera

1. Hämta alla filer med namnet `ps5-bazzite-deck-vX.Y.Z.img.7z.00*` från senaste [utgåvan](../../releases) till samma mapp.
2. Packa upp `.001` med [7-Zip](https://7-zip.org), Keka eller `7z x`. Resultatet är `ps5-bazzite-deck.img`.
3. Skriv avbildningen till USB-enheten med [Rufus](https://rufus.ie). Välj enheten, välj `.img` och klicka på Start. Detta raderar enheten.
4. Anslut enheten till en snabb USB-port. På ursprungliga PS5 fungerar de bakre USB-A-portarna eller främre USB-C. På PS5 Slim är de bakre USB-A-portarna säkrast. Använd den långsamma porten för handkontroll eller tangentbord.
5. Kör jailbreak och laddare enligt laddarens instruktioner. Vänta tills det orange ljuset slutat blinka innan du trycker på strömknappen. Vitt ljus betyder att Linux startar.
6. Första starten tar tid. Skärmen kan vara svart några minuter; låt systemet arbeta klart.

Utgåvornas anteckningar beskriver uppdateringar för redan installerade system.

## Första starten

- Standardlösenordet är **`ps5`**. Byt det med `passwd`; SSH är aktiverat via `ssh ps5@<PS5:ans IP-adress>`.
- Efter att Wi-Fi anslutits kan Steam uppdateras bakom en svart skärm med blinkande markör. Stäng inte av konsolen då.
- Första starten använder 1080p60. Välj sedan upplösning i Steam-spellägets `Settings` → `Display`.
- Sätt RGB-omfång till **Full** både i Steam-spelläget och på skrivbordet.

## Startalternativ i cmdline.txt

`cmdline.txt` finns på USB-enhetens lilla FAT32-partition och ska alltid vara en enda rad. Lägg till alternativ i slutet med ett inledande mellanslag.

| Alternativ | Funktion | När det används |
|---|---|---|
| `amdgpu.force_1080p=1` | Begränsar till 1080p60 | Svart eller förvrängd bild efter en olämplig upplösning |
| `usb-storage.quirks=xxxx:yyyy:u` | Stänger av UAS för en USB-enhet | SSD-kabinett som kopplas från, låser sig eller visar I/O-fel |
| `usbc_dp.enable=1` | Aktiverar DisplayPort över främre USB-C | USB-C-skärmar och PSVR2 |
| `hdmi.frl_4k120=0` | Erbjuder aldrig 4K vid 120 Hz | TV där 4K120 fungerar dåligt |

Stäng av VRR i Steams bildskärmsinställningar. Stäng av HDMI-CEC på TV:n om den inte ska följa konsolens start.

## 40 GPU-beräkningsenheter

*Gäller endast ursprunglig PS5 och Slim.* PS5 Pro har alla 60 enheter aktiva redan från början.

PS5 har 40 beräkningsenheter, men Sony aktiverar normalt 36. De övriga kan ge bättre GPU-prestanda men kan också orsaka gröna prickar, missfärgning eller krascher. Följ kommandona i [engelska README](README.md#40-gpu-compute-units), starta om och kontrollera att `dmesg | grep active_cu_number` visar `40`. Stäng av funktionen igen vid bildfel eller krascher.

## Felsökning

Be om hjälp i [Discord](https://discord.gg/qGcuTgBBYU), kanalen `#bazzite-problems`, och bifoga rapporten från `ps5-report`. Rapporten läser bara systeminformation och relevanta loggar.

- **Konsolen kör men visar ingen bild:** anslut med SSH eller TTY och följ [återställningsguiden](docs/display-recovery.md).
- **Vitt ljus men svart skärm:** kontrollera HDMI Device Link, HDMI-port, TV och HDCP. Som sista utväg, använd `amdgpu.force_1080p=1`.
- **Återgår till PS5-menyn:** strömknappen trycktes troligen innan orange ljus slutat blinka eller USB-ström i viloläge är inte satt till `Always`.
- **Artefakter eller krascher:** stäng av upplåsning av 40 GPU-enheter. För enskilda spel kan `RADV_DEBUG=nohiz %command%` hjälpa.
- **VRR saknas:** VERDE, FreeSync-skärmar utan HDMI VRR eller avstängt VRR för TV-ingången stöds inte.
- **SSD i USB-kabinett startar inte:** prova ett annat kabinett.

För skärmproblem och logginsamling finns [engelska visningsguiden](docs/display-logs.md).

## Installera på PS5:ans interna M.2

USB-enheten behövs fortfarande, eftersom laddaren startar kärnan från dess lilla FAT32-partition. M.2-enheten lagrar systemet och ska ha samma version som USB-installationen. Kör stegen i ett terminalfönster på PS5:an medan USB-systemet är igång.

1. Hämta [ps5-linux-tools](https://github.com/ps5-linux/ps5-linux-tools). Om M.2 inte redan är förberedd för Linux, kör först verktygets `m2_init` enligt dess README.
   ```
   git clone https://github.com/ps5-linux/ps5-linux-tools ~/ps5-linux-tools && make -C ~/ps5-linux-tools
   ```
2. Montera startpartitionen och installera den uppackade `.img`-filen, inte `.7z`-filerna. Behåll `.img` på USB-systemet, inte på M.2 eftersom M.2 raderas under installationen.
   ```
   sudo mkdir -p /boot/efi && (mountpoint -q /boot/efi || sudo mount LABEL=boot /boot/efi)
   cd ~/ps5-linux-tools && sudo ./m2_install.sh --install /sökväg/till/ps5-bazzite-deck.img
   ```
   Kopieringen kan ta 10–30 minuter utan förloppsindikator. Vänta på `Installation complete.`.
3. Ändra `cmdline.txt` så att den använder etiketten `bazzite-deck-m2`, enligt [engelska instruktionen](README.md#installing-to-the-ps5s-internal-m2), starta sedan om och kör laddaren som vanligt.

## Användbara insticksmoduler

| Insticksmodul | Funktion |
|---|---|
| [Decky Loader](https://decky.xyz) | Lägger till insticksmoduler i Steam-spellägets snabbmeny. Installera från skrivbordsläget. |
| [PS5 hardware control](https://github.com/NotHavocc/ps5-hwcon-plugin) | Fläktmål, temperaturer, CPU/GPU-profiler, klockor och LED-förinställningar. |
| [PS5 Bazzite Updater](https://github.com/cmartinespinosa/decky-ps5-bazzite-updater) | Visar och installerar fullständiga utgåvor. |

## Stöd projektet och erkännanden

Projektet byggs och testas på fritid. Om du har nytta av det kan du stödja arbetet via [Ko-fi](https://ko-fi.com/vivalavent).

Tack till [ps5-linux](https://github.com/ps5-linux), [rmuxnet](https://github.com/rmuxnet), [soniciso1](https://github.com/soniciso1), bidragsgivarna till [ps5-linux-mwifiex](https://github.com/ps5-linux/ps5-linux-mwifiex), [WizGery](https://github.com/WizGery/ps5-mediatek-fixes), [etawen](https://repo.etawen.dev/), [Universal Blue/Bazzite](https://github.com/ublue-os/bazzite) och alla som bidragit med HDMI-, USB-C- och vilolägesarbete.

Projektet är inte knutet till Sony, Valve eller Universal Blue. Använd det på egen risk. Skript och dokumentation är MIT-licensierade, patchar är GPL-2.0.
