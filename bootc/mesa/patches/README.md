# RADV patches

Applied in order on Mesa 26.2.6 (`pins.env`, the `mesa-26.2.6` tag of a GitHub mirror of gitlab.freedesktop.org/mesa/mesa):

- `0001` to `0003`: Terra's Mesa patches, as in Bazzite's `mesa-vulkan-drivers` (OpenGamingCollective/mesa, tag 26.2.6)
- `0004`: RADV support for the PS5 Pro's int8 matrix instructions and its compute queue, Borchev/mesa_viola_support @ 7da6e50 (MIT)

When Bazzite's Mesa moves to a new version, move `pins.env` and these patches with it.
