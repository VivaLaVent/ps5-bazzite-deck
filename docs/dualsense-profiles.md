> **On by default from v1.8.9, on IW620 and MediaTek (Slim) consoles.** Not yet on the PS5 Pro's Bluetooth chip. IW620: while it's on, restarts go through the PS5 system instead of warm ones (the chip doesn't survive a warm restart with the changed address). `ps5-bt-address off` switches it off. Background: [wiki.ps5-linux.eu](https://wiki.ps5-linux.eu/).

# One DualSense for the PS5 system and Linux

## Description

The PS5 system and Linux use the same Bluetooth chip. The two systems have the same Bluetooth address.

A DualSense with pairing profiles keeps one pairing for each host address. When you pair the DualSense with Linux, the DualSense replaces the PS5 pairing. When you pair the DualSense with the PS5 again, the DualSense replaces the Linux pairing. You must pair the DualSense again each time that you change the system.

The `ps5-bt-addr` service on IW620, or `ps5-bt-pro-addr` on PS5 Pro, gives Linux a different Bluetooth address. The DualSense then keeps two pairings:

- One pairing for the PS5 system, on one profile.
- One pairing for Linux, on a different profile.

You do not need a USB cable when you change the system.

## Applicability

- PS5 consoles with the Marvell IW620 Bluetooth chip (USB ID `1286:2059`). The original PS5 has this chip.
- PS5 Pro consoles with the MediaTek Bluetooth chip (USB ID `0e8d:3605`).
- The service does not change consoles with a different Bluetooth chip. Some PS5 Slim consoles have a MediaTek chip.
- DualSense controllers with pairing profiles (PS button + a face button).

## Procedure: pair the DualSense with Linux

Before you start, make sure that the DualSense is paired with the PS5 system on one profile.

1. Start Linux.
2. On the DualSense, select a different profile. For example, push PS + Square.
3. Put the DualSense in pairing mode.
4. In the Linux Bluetooth settings, pair the DualSense.
5. Start the PS5 system. On the DualSense, select the PS5 profile.
6. Make sure that the DualSense connects to the PS5 system.
7. Start Linux again. On the DualSense, select the Linux profile.
8. Make sure that the DualSense connects to Linux.

## Procedure: make sure that the service operates

1. Open a terminal on Linux.
2. On IW620, type `sudo ps5-bt-addr` and make sure that the result is `chip already uses the Linux address 82:...`.
3. On PS5 Pro, type `journalctl -b -u ps5-bt-pro-addr` and make sure that the log reports `changed volatile Bluetooth address`.

## Procedure: disable the service

1. Type `ps5-bt-address off`.
2. Start Linux again. The chip uses its initial address.
3. Pair the DualSense with Linux again.

## How the IW620 service operates

1. The service starts before `bluetooth.service`.
2. The service reads the USB ID of the Bluetooth chip. If the chip is not the IW620, the service stops.
3. The service reads the address from the chip.
4. The service sets bit 1 of the first byte. This is the "locally administered" bit. For example, `80:60:B7:C5:74:44` becomes `82:60:B7:C5:74:44`.
5. The service sends the Marvell vendor command `0xFC22` to the chip. This command sets the new address.
6. The service reads the address from the chip again. If the address is not correct, the service shows an error.

The chip keeps the new address in its RAM. When you start the PS5 system, the chip gets its initial address again. The service does not change the PS5 system.

On PS5 Pro (`0e8d:3605`), `ps5-bt-pro-addr.service` waits until the adapter is powered, stops
`bluetooth.service`, powers the adapter off, applies the locally administered public address with
`btmgmt public-addr`, verifies it after power-on, and restarts Bluetooth. It runs after
`bluetooth.service`; the earlier IW620 and MediaTek paths continue to run before Bluetooth.

## Why the IW620 service does not use `btmgmt public-addr`

The kernel sends a new public address to the chip only during the first setup of the adapter. When the adapter operates, the kernel keeps the new address in memory. The kernel does not send this address to the chip. For this reason, the service sends the vendor command directly to the chip.

## Known limits

- On IW620, `bluetoothctl` and the Bluetooth settings show the initial address. The kernel does not read the address from the chip again. The chip and the DualSense use the new address.
- In rest mode, the two profiles can start the PS5. After the PS5 starts, only the PS5 profile connects.
- The service is not tested on a PS5 Slim.
