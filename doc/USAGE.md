# Finding something to download (no account needed)

By design this app never touches the clearnet: qBittorrent is bound to
loopback and routes *everything* — BitTorrent, trackers, RSS and torrent
file downloads — through the local I2P proxy.

## RSS discovery (pre-configured)

The install registers one feed under **WebUI → RSS → Postman**:
`http://tracker2.postman.i2p/?view=RSS`.

tracker2.postman.i2p ("Postman") is the tracker where the live I2P swarms
actually are; its RSS feed is anonymous and refreshed with new uploads.
To download something:

1. WebUI → RSS → select *Postman* → double-click an article (or
   right-click → *Download now*).
2. The .torrent/magnet is fetched over I2P and the download starts
   anonymously. Enable *Auto-downloading* in the RSS pane if you want
   rule-based automation.

If the feed stays empty for a long time, Postman is rate-limiting or
temporarily down — its *tracker* announcing still works meanwhile
(`torrents/trackers` in the API shows status `Working`).

## Searching (Search tab)

The install also registers a bundled **postman_i2p** search plugin
(WebUI → Search tab → tick *postman_i2p*, hit Search): it queries
Postman's anonymous search HTML through the same I2P proxy and returns
name/seeders/leechers rows — sorted by swarm size, seeded torrents only.
If the Search tab stays empty on a fresh box, give it a minute: qbt probes
for the bundled CPython 3.13 at startup (qbt's plugin runtime requires
Python >= 3.13, so the package ships one).

Note: Postman rate-limits aggressively ("Ratelimit active" = wait, don't
retry in a loop); repeated hammering can get an account/network blocked.

## Browsing with more detail

For seed counts and sorting (e.g. *Swarmsize*, *active torrents only*)
open `http://tracker2.postman.i2p/` through any I2P-enabled browser —
no login is required for browsing or downloading; an account is only
needed to upload or to use the JSON API (which is rate-credit based).

## The guaranteed-forever test torrent

The community-maintained setup test torrent (also announced at
<https://github.com/tusx/i2pd-qbittorrent-setup>):

```
magnet:?xt=urn:btih:c7fc714f75624601979f54bca0ed05d92feda3e4&dn=I2P+Propaganda&tr=http://tracker2.postman.i2p/announce.php
```

If this magnet downloads, the whole SAM → router → tracker pipeline is
proven end to end.
