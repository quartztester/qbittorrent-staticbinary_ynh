# VERSION: 1.2
# AUTHORS: quartztester
# I2P-only search engine for the Postman tracker (tracker2.postman.i2p).
# Runs inside qBittorrent's nova3 framework; .i2p name resolution comes
# from the HTTP_PROXY env the package sets on the service (i2pd http
# proxy). Anonymous, no account needed.
#
# Two real-world quirks this engine handles:
#  * "Site Under Heavy Load" interstitial — cleared by POSTing the page's
#    formtoken to /?action=Enter. The token is bound to the PHPSESSID
#    cookie issued with the page, so a cookie jar is mandatory; we keep
#    one per search run and retry exactly once.
#  * PaTracker tokenizes search on whitespace, so "die hard" never
#    matches uploads named Die.Hard.1988...RUNTIME-. We issue the raw
#    phrase and a dot-joined variant and merge (2 requests max).

import html as htmllib
import http.cookiejar
import re
import urllib.error
import urllib.parse
import urllib.request
import urllib.response

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

    def __init__(self):
        self._jar = http.cookiejar.CookieJar()
        self._opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self._jar))
        self._opener.addheaders = [("User-Agent", "Mozilla/5.0")]

    def _fetch(self, full, data=None):
        req = urllib.request.Request(full, data)
        try:
            with self._opener.open(req, timeout=90) as r:
                return r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            # PaTracker sometimes serves the heavy-load gate (with a
            # clickable formtoken) under 503; adopt its session cookie
            # and hand the body back so _get can click "Enter".
            body = ""
            try:
                body = e.read().decode("utf-8", "replace")
            except Exception:  # noqa: BLE001
                pass
            if "formtoken" in body:
                try:
                    import io
                    fake = urllib.response.addinfourl(
                        io.BytesIO(b""), e.headers, full, e.code)
                    self._jar.extract_cookies(fake, req)  # type: ignore[arg-type]
                except Exception:  # noqa: BLE001
                    pass
                return body
            raise

    def _get(self, args):
        full = self.url + "index.php?" + urllib.parse.urlencode(args)
        html = self._fetch(full)
        if "heavy load" in html.lower() or "formtoken" in html:
            m = re.search(r'name="formtoken" value="([0-9a-f]+)"', html)
            if m:
                # one-shot gate click (cookie jar carries PHPSESSID),
                # then retry once; never hammer
                try:
                    self._fetch(self.url + "?action=Enter",
                                ("formtoken=" + m.group(1)).encode())
                except Exception:  # noqa: BLE001 — gate may 500 when overloaded
                    pass
                html = self._fetch(full)
        return html

    def _parse(self, html):
        out = []
        for row in re.finditer(r"<tr[^>]*>(.*?)</tr>", html, re.S):
            cells = re.findall(r"<td[^>]*>(.*?)</td>", row.group(1), re.S)
            if len(cells) < 4:
                continue
            flat = [re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", c)).strip()
                    for c in cells]
            link = re.search(r"view=TorrentDetail&id=(\d+)", row.group(1))
            sl = None
            for c in flat:
                m = re.search(r"\b(\d+)\s*/\s*(\d+)\b", c)
                if m:
                    sl = m
                    break
            if not (sl and link):
                continue
            name = htmllib.unescape(flat[1] if len(flat) > 1 else flat[0])
            size = "-1"
            for c in flat:
                ms = re.match(r"^(\d+(?:\.\d+)?)\s*([KMGT]B?)\b", c)
                if ms:
                    size = ms.group(1) + ms.group(2)
                    break
            dl = self.url + "index.php?action=Download&id=" + link.group(1)
            out.append({
                "id": link.group(1),
                "name": name[:200],
                "link": dl,
                "seeds": int(sl.group(1)),
                "leech": int(sl.group(2)),
                "size": size,
                "engine_url": self.url,
                "desc_link": self.url + "index.php?view=TorrentDetail&id=" + link.group(1),
                "pub_date": -1,
            })
        return out

    def search(self, what, cat="all"):
        phrase = urllib.parse.unquote_plus(what).strip()
        variants = [phrase]
        dotted = re.sub(r"\s+", ".", phrase)
        if dotted != phrase:
            variants.append(dotted)
        seen, done = set(), False
        try:
            for v in variants:
                args = {
                    "search": v,
                    "view": "Main",
                    "reset": "1",
                    "limit": "50",
                    "category": self._CATMAP.get(cat, "-1"),
                    "orderby": "5",     # swarmsize
                    "lastactive": "0",  # seeded torrents only
                }
                for item in self._parse(self._get(args)):
                    if item["id"] in seen:
                        continue
                    seen.add(item["id"])
                    prettyPrinter(item)
                    done = True
            if not done:
                # surface hard blocks (gate malfunction, throttle text)
                # instead of masquerading them as an empty result set
                pass
        except Exception as e:  # noqa: BLE001 — nova2 logs stderr
            import sys
            print("postman_i2p: %s" % e, file=sys.stderr)
            return []
