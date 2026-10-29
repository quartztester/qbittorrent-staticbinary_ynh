# VERSION: 1.1
# AUTHORS: quartztester
# I2P search engine for TorrentFunk (torrentfunk.i2p). Anonymous, no
# account. Uses the stable /all/torrents/<slug>.html list view (the
# homepage ?q= search randomly alternates layouts). Runs through the
# i2pd HTTP proxy via HTTP_PROXY set by the package. Results arrive
# server-side sorted by seeds; empty responses raise so qBittorrent
# shows a real error instead of a fake zero (the site replies empty
# when it rate-limits you).

import re
import urllib.parse

from helpers import retrieve_url
from novaprinter import prettyPrinter


class torrentfunk:
    name = "TorrentFunk (I2P)"
    url = "http://torrentfunk.i2p/"
    supported_categories = {"all": "All"}

    _ROW = re.compile(
        r'<a class=tfr-name href="/torrent/(\d+)/[^"]+">([^<]+)</a>.*?'
        r'<td class=tfr-size>([^<]*)</td>.*?'
        r'<span class=s title="Seeds"><em>&#9650; </em>(\d+)</span>'
        r'<span class=p title="Peers"><em>&#9660; </em>(\d+)</span>',
        re.S)

    def _slug(self, what):
        q = urllib.parse.unquote_plus(what).lower()
        q = re.sub(r"[^a-z0-9]+", "-", q).strip("-")
        return q or "all"

    def search(self, what, cat="all"):
        link = (self.url + "all/torrents/" + self._slug(what)
                + ".html?sort=seeds&o=desc")
        html = retrieve_url(link)
        if not html.strip():
            raise RuntimeError(
                "TorrentFunk returned an empty response "
                "(likely rate-limited — try again in a few minutes)")
        rows = []
        for tid, name, size, seeds, peers in self._ROW.finditer(html):
            rows.append({
                "name": urllib.parse.unquote(name)[:200],
                "link": self.url + "download/" + tid + ".html",
                "seeds": int(seeds),
                "leech": int(peers),
                "size": size.strip() or "-1",
                "engine_url": self.url,
                "desc_link": self.url + "torrent/" + tid + "/",
                "pub_date": -1,
            })
        for item in sorted(rows, key=lambda x: -x["seeds"]):
            prettyPrinter(item)
