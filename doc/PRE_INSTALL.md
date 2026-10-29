# Pre-install notes

This package ships a statically linked `qbittorrent-nox` and expects an I2P
router with its SAM bridge on loopback if you intend to run torrents over
I2P: the `java_i2p` (127.0.0.1:7656) or `i2pd` (127.0.0.1:7666) YunoHost
apps both work. Without a router, clearnet torrents still function, but the
I2P-first defaults will not find a bridge.
