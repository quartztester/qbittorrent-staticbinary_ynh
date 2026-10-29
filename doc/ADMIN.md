## I2P / SAM bridge

Torrent traffic is handed to your I2P router through the SAM bridge, which
must be running and listening. This package does **not** install an I2P
router — it expects one of the `java_i2p` / `i2pd` YunoHost apps to provide
SAM. Note their ports on this server: the `i2pd` app serves SAM on
`127.0.0.1:7666` (deliberately not 7656, to leave that free for
`java_i2p`, whose SAM bridge is registered on 7656 when enabled). Set
`i2p_sam_port` to whichever router you use; `7656` is only the upstream
default.

Only torrents whose tracker/peer is an I2P `*.i2p` address work over I2P;
clearnet torrents are unaffected (and hidden when anonymous mode is on).

Check the bridge is up: `ss -ltn | grep -E ':7656|:7666'` — and that
qBittorrent holds a session to it: `ss -tnp | grep qbittorrent`.

## Connecting the *arr stack (Prowlarr/Sonarr/Radarr)

Add a qBittorrent download client pointing at the internal loopback URL:

```
Host: 127.0.0.1      Port: <the app 'port' setting>   WebUI: /
Username: admin      Password: see below
```

localhost connections skip the web login (qBittorrent 5.x semantics:
`WebUI\LocalHostAuth=false` in the generated conf enables the loopback
exemption). The credentials below still work and keep you covered if you
flip that setting in the WebUI security options.

- Password: `yunohost app setting qbittorrent_static webui_password`
- Port:     `yunohost app setting qbittorrent_static port`

## Changing I2P / anonymous settings

The qBittorrent conf file is fully managed: it is re-rendered from the app
settings while the service is stopped. Change settings, then re-apply by
re-running the package scripts:

```
yunohost app setting qbittorrent_static i2p_sam_port -v 7666
yunohost app setting qbittorrent_static anonymous -v true
yunohost app upgrade qbittorrent_static \
    -u https://github.com/quartztester/qbittorrent-staticbinary_ynh \
    --no-safety-backup --force
```

Do **not** edit the conf file while the service runs — qBittorrent rewrites
its own conf at shutdown and would clobber both your edit and any
re-render. (If you only need a quick look: `yunohost app shell
qbittorrent_static` gives an interactive shell with the helpers loaded.)

## Upgrading the binary version

This package pins a specific `qbittorrent-nox-static` release. To bump it,
edit the `version` and `[resources.sources.main.*]` `url`/`sha256` in
`manifest.toml`, then `yunohost app upgrade`.
