qBittorrent is a BitTorrent client written in C++, providing a web
interface. This package installs a statically linked `qbittorrent-nox`
upstream build, so it runs on stock Debian stable even when the distro's
own qBittorrent/libtorrent/Qt6 packages are older, and ships with native
I2P (SAM bridge) support for running torrents over the I2P network.

> **Warning**
> The upstream binary bundles its dependencies statically. Security updates
> therefore depend on this YunoHost package being kept current, not on
> Debian's `apt` / `unattended-upgrades` cycle.

## Features

- SSO-protected web interface (admin page), LDAP not applicable
- Native I2P support through the SAM bridge (default `127.0.0.1:7656`)
- Anonymous mode: DHT, PeX and LSD disabled so peers never leak to clearnet
- WebUI bound to loopback only — Prowlarr/Sonarr/Radarr connect to
  `http://127.0.0.1:<port>` (localhost is exempt from web authentication)
