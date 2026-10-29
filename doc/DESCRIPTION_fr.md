qBittorrent est un client BitTorrent en C++ doté d'une interface web. Ce
paquet installe un build `qbittorrent-nox` statique lié en amont : il
tourne sur un Debian stable standard même quand les paquets
qBittorrent/libtorrent/Qt6 de la distribution sont plus anciens, et il
embarque le support I2P natif (pont SAM) pour faire tourner les torrents
via le réseau I2P.

> **Avertissement**
> Le binaire amont embarque ses dépendances de façon statique. Les mises à
> jour de sécurité dépendent donc du maintien de ce paquet YunoHost, et non
> du cycle `apt` / `unattended-upgrades` de Debian.

### Fonctionnalités

- Interface web protégée par le SSO (page admin), LDAP non applicable
- Support I2P natif via le pont SAM (par défaut `127.0.0.1:7656`)
- Mode anonyme : DHT, PeX et LSD désactivés pour ne jamais fuiter vers le
  clearnet
- Interface web liée à la boucle locale uniquement — Prowlarr/Sonarr/Radarr
  se connectent sur `http://127.0.0.1:<port>` (localhost exempt
  d'authentification web)
