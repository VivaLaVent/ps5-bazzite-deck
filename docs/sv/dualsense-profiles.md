> **Konsoler med IW620:** funktionen aktiveras med `ps5-bt-address on`. Den överlever inte en varm omstart; från v1.9.0 går omstarter därför via PS5-systemet när funktionen är på. Mer information finns i [IW620-anteckningen](iw620-bt-address-warm-restart.md).

# En DualSense för PS5-systemet och Linux

## Vad funktionen gör

PS5-systemet och Linux använder samma Bluetooth-krets och har därför normalt samma Bluetooth-adress. En DualSense med parkopplingsprofiler sparar en parkoppling per värdadress. När handkontrollen parkopplas med Linux ersätter den PS5-parkopplingen, och tvärtom.

Tjänsten `ps5-bt-addr` ger Linux en annan Bluetooth-adress. Handkontrollen kan då behålla två parkopplingar:

- en för PS5-systemet på en profil
- en för Linux på en annan profil

Du behöver då inte USB-kabel när du växlar system.

## När den kan användas

- Ursprungs-PS5 med Marvell IW620-Bluetooth (USB-ID `1286:2059`).
- Tjänsten ändrar inte konsoler med en annan Bluetooth-krets. Vissa PS5 Slim har MediaTek.
- DualSense-handkontroller med parkopplingsprofiler, alltså PS-knappen tillsammans med en av ansiktsknapparna.

## Parkoppla DualSense med Linux

Kontrollera först att DualSense redan är parkopplad med PS5-systemet på en profil.

1. Starta Linux.
2. Välj en annan profil på DualSense, till exempel PS + fyrkant.
3. Sätt handkontrollen i parkopplingsläge.
4. Parkoppla den i Linux Bluetooth-inställningar.
5. Starta PS5-systemet och välj PS5-profilen på handkontrollen.
6. Kontrollera att handkontrollen ansluter till PS5-systemet.
7. Starta Linux igen, välj Linux-profilen och kontrollera anslutningen.

## Kontrollera tjänsten

1. Öppna en terminal i Linux.
2. Kör `sudo ps5-bt-addr`.
3. Resultatet ska vara `chip already uses the Linux address 82:...`.
4. Vid annat resultat, kör `journalctl -b -u ps5-bt-addr` och läs loggen.

## Stäng av tjänsten

1. Kör `sudo systemctl disable ps5-bt-addr.service`.
2. Starta Linux igen. Kretsen använder då sin ursprungliga adress.
3. Parkoppla DualSense med Linux igen.

## Så fungerar tjänsten

1. Tjänsten startar före `bluetooth.service`.
2. Den läser Bluetooth-kretsens USB-ID. Om kretsen inte är IW620 avslutas tjänsten.
3. Den läser kretsens adress och sätter bit 1 i första byten, den lokalt administrerade biten. Exempel: `80:60:B7:C5:74:44` blir `82:60:B7:C5:74:44`.
4. Tjänsten skickar Marvells leverantörskommando `0xFC22` till kretsen och läser sedan adressen på nytt. Om den inte stämmer rapporteras fel.

Kretsen behåller den nya adressen i sitt RAM-minne. När PS5-systemet startar får den tillbaka den ursprungliga adressen; tjänsten ändrar aldrig PS5-systemet.

## Varför inte `btmgmt public-addr`?

Kärnan skickar bara en ny publik adress till kretsen vid adapterns första konfigurering. När adaptern kör behåller kärnan den nya adressen i minnet och skickar den inte till kretsen. Därför använder tjänsten leverantörskommandot direkt.

## Kända begränsningar

- `bluetoothctl` och Bluetooth-inställningarna visar den ursprungliga adressen, eftersom kärnan inte läser om den från kretsen. Kretsen och DualSense använder ändå den nya adressen.
- I viloläge kan båda profilerna starta PS5-systemet. När systemet har startat ansluter endast PS5-profilen.
- Tjänsten är inte testad på PS5 Slim.
