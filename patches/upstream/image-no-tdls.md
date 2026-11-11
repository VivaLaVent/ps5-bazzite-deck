The apply line for `ps5-iw620-no-tdls.patch`, which stops the IW620 driver from advertising TDLS (its firmware
rejects `TDLS_OPERATION`, and Wi-Fi is then gone until the driver is rebound). Goes with the pull request of the
same name in ps5-linux/ps5-linux-mwifiex and should be merged after it: the builder follows that repository's
`main`, and the line fails while the patch file isn't there.
