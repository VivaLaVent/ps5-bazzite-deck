#!/bin/bash
# This was the Legacy update command. Legacy installs are no longer updated: it now points to the switch to bootc.
if [ -e /run/ostree-booted ]; then echo "This is a bootc install: update with  sudo bootc upgrade"; exit 0; fi
cat << 'MSG'
Legacy installs are no longer supported or updated, from v2.13 on.

Switch this install to bootc in place, keeping your users, games and Flatpaks:
  curl -fsSLO https://raw.githubusercontent.com/VivaLaVent/ps5-bazzite-deck/main/tools/legacy-to-bootc.sh
  sudo bash legacy-to-bootc.sh            # checks only, changes nothing
  sudo bash legacy-to-bootc.sh --apply

Both ways are on https://wiki.ps5-linux.eu/updating/legacy
MSG
exit 1
