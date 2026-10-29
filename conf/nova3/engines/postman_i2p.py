# VERSION: 1.0
# AUTHORS: quartztester
# I2P-only search engine for the Postman tracker (tracker2.postman.i2p).
# Runs inside qBittorrent's nova3 framework; .i2p name resolution comes
# from the HTTP_PROXY env the package sets on the service (i2pd http
# proxy). Anonymous, no account needed. Results pre-filtered server-side
# to seeded torrents, sorted by swarm size.

import re
import urllib.parse

from helpers import retrieve_url
from novaprinter import prettyPrinter


class postman_i2p:
    name = "Postman (I2P)"
    url = "http://tracker2.postman.i2p/"
    supported_categories = {
        "all": "All",
        "movies": "Movies",
        "music": "Music",
        "tv": "TV",
        "games": "Games",
        "software": "Applications",
        "pictures": "Pictures",
        "anime": "Anime",
        "books": "Books",
    }
    _CATMAP = {
        "all": "-1", "movies": "1", "music": "2", "tv": "3",
        "games": "4", "software": "5", "pictures": "8", "anime": "9",
        "comics": "10", "books": "13", "documentary": "20",
    }

    def _get(self, args):
        full = self.url + "index.php?" + urllib.parse.urlencode(args)
        html = retrieve_url(full)
        if "SITE UNDER HEAVY LOAD" in html:
            m = re.search(r'name="formtoken" value="([0-9a-f]+)"', html)
            if m:
                # one-shot gate click, then retry once; never hammer
                retrieve_url(self.url + "?action=Enter",
                             request_data=("formtoken=" + m.group(1)).encode())
                html = retrieve_url(full)
        return html

    def _parse(self, html):
        out = []
        for row in re.finditer(r"<tr[^>]*>(.*?)</tr>", html, re.S):
            cells = re.findall(r"<td[^>]*>(.*?)</td>", row.group(1), re.S)
            if len(cells) < 4:
                continue
            flat = [re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", c)).strip()
                    for c in cells]
            link = re.search(r"href=\"[^\"]*(?:page=detail|id=)(\d+)",
                             row.group(1))
            sl = None
            for c in flat:
                m = re.match(r"^(\d+)\s*/\s*(\d+)$", c)
                if m:
                    sl = m
                    break
            if not (sl and link):
                continue
            name = flat[1] if len(flat) > 1 else flat[0]
            dl = self.url + "index.php?action=Download&id=" + link.group(1)
            out.append({
                "id": link.group(1),
                "name": name[:200],
                "link": dl,
                "seeds": int(sl.group(1)),
                "leech": int(sl.group(2)),
                "size": flat[-2] if len(flat) > 3 else "-1",
                "engine_url": self.url,
                "desc_link": self.url + "index.php?page=detail&id=" + link.group(1),
                "pub_date": -1,
            })
        return out

    def search(self, what, cat="all"):
        args = {
            "search": urllib.parse.unquote_plus(what),
            "view": "Main",
            "reset": "1",
            "limit": "50",
            "category": self._CATMAP.get(cat, "-1"),
            "orderby": "5",     # swarmsize
            "lastactive": "0",  # seeded torrents only
        }
        try:
            for item in self._parse(self._get(args)):
                prettyPrinter(item)
        except Exception:  # noqa: BLE001 — nova2 treats stdout-only contract
            return []
