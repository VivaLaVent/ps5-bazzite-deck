# fastfetch with the PS5 logo: Bazzite's own command, config and colours, only the logo replaced
L=/usr/local/share/ps5-bazzite-deck/fastfetch-logo.txt
if [ -r "$L" ] && [ -x /usr/libexec/bazzite-bling-fastfetch ] && [ -r /usr/share/ublue-os/bazzite/fastfetch.jsonc ]; then
    for a in neofetch neowofetch fastfetch; do
        # shellcheck disable=SC2139
        alias "$a=/usr/bin/fastfetch --color \$(/usr/libexec/bazzite-bling-fastfetch) -c /usr/share/ublue-os/bazzite/fastfetch.jsonc --logo $L --logo-color-2 97"
    done
fi
unset L a
