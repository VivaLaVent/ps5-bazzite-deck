# IW620: Linux-only Bluetooth address together with warm restarts

**Status: interim solution in v1.8.9, real fix open.** Requested by Max (fat PS5, IW620), who offered to test.
v1.8.9 keeps the address on by default on IW620, and while it's on, a restart goes through the PS5 system instead
of warm (idea 4 below). The aim is still both together.

## The request
On consoles with the IW620 Wi-Fi/Bluetooth chip, keep both:
- the **Linux-only Bluetooth address** (`ps5-bt-address on`): a DualSense keeps one pairing for the PS5 system and one
  for Linux on separate profiles, no re-pairing when switching ([dualsense-profiles.md](dualsense-profiles.md));
- **warm restarts** (`ps5-warm-reboot on`): restart straight back into Linux without the PS5 system and the loader.

They don't go together yet: v1.8.4's update switched the address off on IW620 consoles; from v1.8.9 it's on by
default again, with warm restarts replaced by normal ones while it's on.

## What we know
- With the address on, a warm restart can leave the chip hung: its Bluetooth part doesn't answer on USB any more
  (`usb 5-3: device descriptor read/64, error -110`, `device not accepting address`), and in Max's first report Wi-Fi
  was gone too (`wlan_pcie … probe … failed`). Only a power-off and a start with the loader brings it back.
- With the address **off**, Bluetooth survives a warm restart (Max, 29 Oct).
- A cold start always works, with or without the address.
- Separately, with the address on, a controller sometimes didn't reconnect after a cold boot: the chip kept the PS5
  system's address while the pairing was made with the Linux one (`ps5-bt-address status` shows the current address).

## How the address is set (IW620)
`files/ps5-bt-addr` sends the chip a Marvell vendor command at every boot (HCI opcode `0xFC22`, "set BD address",
parameters `FE 06` + the address), when the adapter appears. Linux's address is the chip's own with one bit set. The
chip is a Wi-Fi/Bluetooth combo: Wi-Fi on PCIe, Bluetooth on the Salina USB controller.

A warm restart (`files/ps5-kexec`) starts the new kernel without resetting any hardware: the chip goes into the next
boot in whatever state the last one left it, then gets the vendor command again.

## Ideas to make both work
1. **Undo the address before a warm restart.** On the way down (before `ps5-kexec` runs the new kernel), send the same
   command with the chip's original address, so the chip starts the next boot as after a cold start. The original
   address has to be kept when it's changed (e.g. in `/run`).
2. **Don't send it twice.** On a warm boot, read the chip's current address first and skip the command if it already
   has the Linux one (the MediaTek path already does this).
3. **Reset the Bluetooth part before a warm restart:** unbind `btusb` and reset the chip's USB device, or send an HCI
   reset, so nothing is half-done when the new kernel takes over.
4. **Fallback:** if none of these work, make a restart with the address on go through the PS5 system (a normal
   restart), instead of switching the address off.

1 and 2 are cheap to try and can be tested on their own. 1 is the most likely: Max's results point at the chip's state
after the command, not at the warm restart itself.

## Test plan (IW620 console, address on, warm restart on)
1. Cold start, check `ps5-bt-address status` shows the Linux address, DualSense connects.
2. Warm restart (`sudo reboot`): does the Bluetooth adapter come back (`bluetoothctl show`), does the controller reconnect?
3. Ten warm restarts in a row, then a cold start: same checks. Also Wi-Fi each time.
4. On failure: `ps5-report` plus `sudo dmesg | grep -i -e btusb -e btmrvl -e "usb 5-"`.

If it holds up on two IW620 consoles, the address comes back as opt-in on IW620 in a v1.9.x release.
