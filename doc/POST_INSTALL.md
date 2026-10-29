# Post-install notes

The WebUI is served on the chosen domain behind the YunoHost portal
(admins group by default). The qBittorrent WebUI password is generated at
install:

```
yunohost app setting qbittorrent_static webui_password
```

Loopback clients (Prowlarr/Sonarr/Radarr) connect without login — see
[ADMIN.md](ADMIN.md) for the *arr stack and I2P settings.
