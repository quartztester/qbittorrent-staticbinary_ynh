# Finding something to download (no account needed)

By design this app never touches the clearnet: qBittorrent is bound to
loopback and routes *everything* — BitTorrent, trackers and torrent
file downloads — through the local I2P proxy.

Discovery is **search-only** (the Search tab); no RSS feeds are
registered by default.

## Searching (Search tab)

Only one torrent index is genuinely **native to I2P** (its population
announces to I2P trackers): **Postman**. The install therefore ticks
just the bundled **postman_i2p** engine by default — it queries
Postman's anonymous search through the I2P proxy and returns
seeders/leechers, sorted by swarm size.

Two *catalog-mirror* engines (TorrentFunk, TorrentZ) are also installed
but **unticked by default**: they mirror the clearnet catalog (their
.torrent files announce to clearnet trackers), so their big seed counts
belong to swarms an I2P-only client cannot reach. Tick them in
"Search plugins" only if you want that extra noise.

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
