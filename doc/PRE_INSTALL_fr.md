# Notes de pré-installation

Ce paquet fournit un binaire `qbittorrent-nox` statique et attend un
routeur I2P avec son pont SAM en boucle locale si vous utilisez les
torrents via I2P : les applications YunoHost `java_i2p` (127.0.0.1:7656) ou
`i2pd` (127.0.0.1:7666) conviennent. Sans routeur, les torrents clearnet
fonctionnent, mais les réglages I2P par défaut ne trouveront pas de pont.
