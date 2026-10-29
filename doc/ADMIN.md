## I2P / SAM bridge

Torrent traffic is handed to your I2P router through the SAM bridge, which
must be running and listening. This package does **not** install an I2P
router — it expects one of the `java_i2p` / `i2pd` YunoHost apps to provide
SAM. Both apps enable SAM by default on the upstream default port 7656;
whichever router was installed first keeps 7656, the other automatically
fell back to 7666. Read the live value with
`yunohost app setting i2pd port_sam` (or `java_i2p`) and set
`i2p_sam_port` to match the router you use.

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

## I2P settings applied (per the official i2pd qBittorrent guide)

- SAM bridge on/off/host/port: settings `i2p_enabled`, `i2p_sam_host`, `i2p_sam_port`
- HTTP proxy used for tracker traffic AND `.i2p` hostname resolution:
  settings `http_proxy_host` (default `127.0.0.1`), `http_proxy_port`
  (default `4447` = the i2pd app's proxy; the java_i2p router's proxy is
  the upstream `4444`)
- Auto-appended I2P tracker list (i2pd guide + ngosang/trackerslist,
  deduped): toggle with setting `add_trackers_enabled`; the list itself is
  in `scripts/_common.sh` (`I2P_TRACKERS`)
- Anonymous mode: DHT/PeX/LSD off and everything bound to `lo`/`127.0.0.1`
  (the guide's "Network interface" + "Optional IP to bind to" steps), so a
  clearnet leak is structurally impossible while `anonymous=true`
- Encryption: allow (not required, not forced) — I2P encrypts on its own

## Verifying seeding works

The installer creates a **seed-test torrent** (`add_seed_test` setting,
payload at `$data_dir/downloads/i2p-seedtest/`) and starts seeding it to
the bundled I2P opentrackers. Check it:

```
curl -s http://127.0.0.1:$(yunohost app setting qbittorrent_static port)/api/v2/torrents/info \
  | python3 -m json.tool | grep -E '"name"|"state"'
```

`state` of `stalledUP` means: seeding, no peers yet (normal for a fresh
torrent). To confirm the trackers actually answer (proves announce-over-
proxy-over-I2P), list them:

```
H=$(curl -s http://127.0.0.1:8090/api/v2/torrents/info | python3 -c "import json,sys;print(json.load(sys.stdin)[0]['hash'])")
curl -s "http://127.0.0.1:8090/api/v2/torrents/trackers?hash=$H" \
  | python3 -c "import json,sys;[print(t['url'][:48],'| status',t['status'],'|',t['msg'][:60]) for t in json.load(sys.stdin)]"
```

`status 2` with messages like "updated" = tracker confirmed your announce.
To go further (a real remote peer fetching from you), add a popular I2P
torrent (e.g. from a nyaa2p index) and watch it download at a nonzero
speed — that exercises inbound I2P connections from strangers to your
seeder end-to-end.
