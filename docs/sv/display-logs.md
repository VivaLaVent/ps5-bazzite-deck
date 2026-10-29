# Bildproblem: detta behöver vi för en felrapport

Använd guiden vid svart bild, en bild som blinkar eller kopplar om, VRR som inte fungerar eller ett bildläge som saknas. Den samlar in TV:ns eller skärmens lägen, konsolens val och HDMI-kretsens logg.

## 1. Öppna ett skal

Om du har bild öppnar du en terminal i skrivbordsläget eller ansluter med SSH. Om du saknar bild använder du SSH från en dator (`ssh ps5@<konsolens IP-adress>`, lösenord `ps5`) eller ett tangentbord med <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>F3</kbd>. Se [återställning av bild](display-recovery.md) för mer information.

## 2. Återskapa felet och samla in uppgifter

Välj läget eller aktivera inställningen som inte fungerar, vänta ungefär 15 sekunder och kör sedan följande på en rad:

```
F=~/display-log-$(date +%H%M).txt; { echo "== version"; cat /etc/ps5-bazzite-deck-version; uname -v; cat /proc/cmdline; echo "== EDID (base64)"; sudo cat /sys/class/drm/card0-DP-1/edid | base64 -w0; echo; echo "== modes offered"; cat /sys/class/drm/card0-DP-1/modes | sort | uniq -c; echo "== current mode and VRR"; sudo grep -E "crtc\[|enable=|active=|mode:|vrr_enabled" /sys/kernel/debug/dri/0/state 2>/dev/null | head -20; echo "== HDMI chip"; sudo dmesg | grep -i -e "hdmi" -e "VRR" -e "FRL" -e "re-arm" | tail -60; echo "== Game Mode"; journalctl --user -b --no-pager -o cat 2>/dev/null | grep -i -e "drm:" -e "modeset" -e "vrr" -e "adaptive" -e "edid" | tail -40; } > $F 2>&1; E=$(for d in /boot/efi /efi; do sudo test -f $d/cmdline.txt && echo $d && break; done); sudo cp $F $E/ 2>/dev/null; echo "saved $F"
```

Kommandot läser bara information. Filen `display-log-<tid>.txt` sparas i hemkatalogen och kopieras till enhetens lilla FAT-partition, så att den kan hämtas på en dator även utan nätverk.

## 3. Få tillbaka bilden

För VRR: `export XDG_RUNTIME_DIR=/run/user/$(id -u) GAMESCOPE_WAYLAND_DISPLAY=gamescope-0; gamescopectl adaptive_sync 0`.

För ett bildläge: se [återställning av bild](display-recovery.md).

## 4. Skicka rapporten

Lägg upp filen i `#bazzite-problems` och ange:

- exakt modell på TV eller skärm, HDMI-port och kabel
- valt läge: upplösning, uppdateringsfrekvens, VRR/HDR av eller på, samt vad som syntes
- skärmens egna inställningar för VRR/FreeSync/Adaptive-Sync, HDMI-förbättrat läge/Deep Colour och spelläge
- om problemet fungerade i en tidigare version och vilken
