# IW620: Bluetooth-adress enbart för Linux tillsammans med varma omstarter

**Status: tillfällig lösning i v1.9.0, den egentliga korrigeringen är fortfarande öppen.** När den separata adressen är aktiverad på IW620 går en omstart via PS5-systemet i stället för varm omstart. Målet är fortfarande att båda funktionerna ska fungera samtidigt.

## Önskemålet

På konsoler med Wi-Fi/Bluetooth-kretsen IW620 ska följande kunna användas samtidigt:

- **Bluetooth-adress enbart för Linux** med `ps5-bt-address on`, så att DualSense behåller en parkoppling för PS5-systemet och en för Linux på olika profiler
- **varm omstart** med `ps5-warm-reboot on`, alltså direkt tillbaka till Linux utan PS5-systemet och laddaren

Funktionerna fungerar ännu inte ihop. V1.8.4 stängde av adressändringen på IW620. Från v1.9.0 är den åter ett aktivt val, men varma omstarter ersätts av vanliga omstarter när den används.

## Vad vi vet

- Med adressändringen aktiverad kan en varm omstart låsa kretsen. Bluetooth-sidan svarar då inte längre på USB (`usb 5-3: device descriptor read/64, error -110`, `device not accepting address`) och Wi-Fi kan också försvinna. Endast avstängning och start med laddaren återställer den.
- Med adressändringen avstängd överlever Bluetooth en varm omstart.
- Kallstart fungerar alltid, med eller utan adressändring.
- Med adressändringen på kan en handkontroll ibland misslyckas med att återansluta efter kallstart, eftersom kretsen behåller PS5-systemets adress medan parkopplingen skapades med Linux-adressen.

## Hur adressen sätts

`files/ps5-bt-addr` skickar Marvells leverantörskommando vid varje start när adaptern visas. Linux-adressen är kretsens egen adress med en bit ändrad. Kretsen är en kombinerad Wi-Fi/Bluetooth-enhet: Wi-Fi använder PCIe och Bluetooth Salina-USB-styrenheten.

En varm omstart med `files/ps5-kexec` startar nästa kärna utan att återställa hårdvaran. Kretsen förs alltså över till nästa start i samma tillstånd som den hade vid föregående, och får sedan leverantörskommandot igen.

## Vägar till en riktig lösning

1. Återställ ursprunglig adress före varm omstart genom att skicka samma kommando med originaladressen innan `ps5-kexec` startar nästa kärna.
2. Skicka inte kommandot två gånger. Vid varmstart läses aktuell adress först; om kretsen redan har Linux-adressen hoppas kommandot över.
3. Återställ Bluetooth-delen före varm omstart genom att koppla loss `btusb`, återställa USB-enheten eller skicka HCI-återställning.
4. Behåll reservlösningen: om inget annat fungerar ska omstart med adressändring gå via PS5-systemet.

De två första alternativen är enklast att prova. Den första förklarar bäst hittillsvarande testresultat, som pekar på kretsens tillstånd efter kommandot snarare än den varma omstarten själv.

## Testplan för IW620 med adress och varm omstart aktiverade

1. Kallstarta, kontrollera att `ps5-bt-address status` visar Linux-adressen och att DualSense ansluter.
2. Starta varmt med `sudo reboot`. Kontrollera att Bluetooth-adaptern kommer tillbaka med `bluetoothctl show` och att handkontrollen ansluter.
3. Gör tio varma omstarter i rad och sedan en kallstart. Kontrollera Bluetooth och Wi-Fi varje gång.
4. Vid fel, bifoga `ps5-report` samt `sudo dmesg | grep -i -e btusb -e btmrvl -e "usb 5-"`.

Om detta håller på två IW620-konsoler kan adressändringen åter erbjudas som ett aktivt val i en v1.9.x-utgåva.
