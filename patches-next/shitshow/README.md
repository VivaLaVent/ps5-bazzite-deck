# Our kernel work on Linux 7.3.1 + rmux's shitshow (8de2aff)

Ported in v2.4 and withdrawn in v2.4.1: on FLAVA3 with an HDMI 2.1 TV, 4K60 stayed black in Game Mode on
rmux's reworked 4K path, while our own display code (v2.1.x, v2.4.1) shows 4K60 and 4K120 on the same TV.
Apply in this order on 7.3.1 + shitshow's linux.patch: ps5-s2idle, ps5-display, ps5-hdmi-sdr-metadata,
ps5-gpu, ps5-fan. Before it replaces the built kernel, FLAVA3, Verde and Pro owners test it.
