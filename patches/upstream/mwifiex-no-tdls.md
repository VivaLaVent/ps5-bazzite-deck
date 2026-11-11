The PS5's IW620 firmware rejects `TDLS_OPERATION` (0x122). When a peer on the same network starts a direct link
(an Android phone opening a page the console serves was the trigger), `wpa_supplicant` accepts it, the driver
sends the command, and Wi-Fi is gone until the driver is rebound:

    Recv TDLS SETUP Request: peer=<peer>
    CMD_RESP: cmd 0x122 error, result=0x2
    TDLS CREATE operation: cmd error reason 0
    wlan: HostMlme Disconnected: sub_type=12 <AP>
    Timeout cmd id (...) 802_11_SCAN [0x6], act = 0x3
    IW620: cmd 0x6 timeout is not recoverable (soft 0/3)

Without the TDLS wiphy flags `wpa_supplicant` declines the request and the peer keeps going through the access
point. `install.sh` and the README list the new patch; the image builder needs the matching apply line
(ps5-linux/ps5-linux-image, sent separately).
