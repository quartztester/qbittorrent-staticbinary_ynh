# qBittorrent (static) pour YunoHost

qBittorrent est un client BitTorrent doté d'une interface web. Ce paquet
installe un build `qbittorrent-nox` statique avec support I2P natif (pont
SAM) : il tourne sur Debian stable même quand les paquets Qt/libtorrent de
la distribution sont plus anciens.

**Version livrée :** 5.3.0

## Caractéristiques

- Client BitTorrent complet avec interface web
- Build statique `qbittorrent-nox` : indépendant des bibliothèques de la
  distribution
- Support I2P natif via le pont SAM
- Mode anonyme : DHT, PeX et LSD désactivés par défaut
- Interface web protégée par le SSO YunoHost (groupe admins)

## Liens

- Projet amont : <https://github.com/qbittorrent/qBittorrent>
- Builds statiques amont : <https://github.com/userdocs/qbittorrent-nox-static>
- Paquet YunoHost : <https://github.com/quartztester/qbittorrent-staticbinary_ynh>

## Screenshots

![qBittorrent WebUI](./doc/screenshots/webui.png)
