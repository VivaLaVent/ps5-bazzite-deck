# Ingen bild? Anslut och ändra bildläge med kommando

För att rapportera problemet efteråt, se [insamling av bildloggar](display-logs.md).

När konsolen kör men TV:n inte visar något kan du ändå ansluta och ändra läget. Standardanvändare och lösenord är `ps5` / `ps5`.

## 1. Öppna ett skal

**Tangentbord på PS5:an (TTY):** tryck <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>F3</kbd> för textinloggning. Gå tillbaka med <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>F1</kbd> eller <kbd>F2</kbd>. Om TV:n inte visar något alls syns inte heller textkonsolen; använd då SSH.

**Via nätverket (SSH):** kör följande från en dator på samma nätverk:

```
ssh ps5@<konsolens IP-adress>
```

Lösenordet är `ps5`. Konsolens IP-adress finns i routerns enhetslista, ofta under namnet `bazzite`.

## 2. Steam-spelläge

**Stäng av eller sätt på VRR:**

```
export XDG_RUNTIME_DIR=/run/user/$(id -u) GAMESCOPE_WAYLAND_DISPLAY=gamescope-0
gamescopectl adaptive_sync 0      # av (1 = på)
```

Bilden kommer tillbaka inom några sekunder.

**Upplösning:** Steam-spelläget använder Steams bildskärmsinställning. Om den minns ett läge som TV:n inte kan visa, ta bort det för en start så att Steam faller tillbaka till 1080p60:

```
E=$(for d in /boot/efi /efi; do sudo test -f $d/cmdline.txt && echo $d && break; done)
sudo sed -i 's/[[:space:]]*$/ amdgpu.force_1080p=1/' $E/cmdline.txt && sudo systemctl poweroff
```

Starta med laddaren, välj önskat läge i `Settings` → `Display`, ta sedan bort alternativet igen och stäng av:

```
E=$(for d in /boot/efi /efi; do sudo test -f $d/cmdline.txt && echo $d && break; done)
sudo sed -i 's/ *amdgpu\.force_1080p=1//' $E/cmdline.txt && sudo systemctl poweroff
```

För enbart **4K120** använder du ` hdmi.frl_4k120=0` i stället för ` amdgpu.force_1080p=1`.

Byt till skrivbordet med `steamos-session-select plasma` och tillbaka med `steamos-session-select gamescope`.

## 3. Skrivbordsläge

KDE:s `kscreen-doctor` ändrar bildläget direkt. Över SSH börjar du med:

```
export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
```

Kör sedan:

```
kscreen-doctor -o
kscreen-doctor output.DP-1.mode.3840x2160@60
kscreen-doctor output.DP-1.hdr.disable
kscreen-doctor output.DP-1.vrrpolicy.never
```

Till skillnad från Systeminställningar tillämpar `kscreen-doctor` ändringen direkt och frågar inte om läget ska behållas. Kontrollera därför TV:n efter varje ändring och kör föregående kommando igen för att återställa.

## 4. TV:n själv

Efter ett misslyckat försök med 4K120 kan vissa TV-apparater förbli mörka i alla lägen. Dra ur TV:ns strömkabel i en minut, eftersom viloläge inte räcker, och starta därefter konsolen igen.
