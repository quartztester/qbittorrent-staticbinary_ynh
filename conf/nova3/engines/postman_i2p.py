# VERSION: 1.3
# AUTHORS: quartztester
# I2P-only search engine for the Postman tracker (tracker2.postman.i2p).
# Runs inside qBittorrent's nova3 framework; .i2p name resolution comes
# from the HTTP_PROXY env the package sets on the service (i2pd http
# proxy). Anonymous, no account needed.
#
# Real-world quirks this engine handles:
#  * "Site Under Heavy Load" interstitial — cleared by POSTing the page's
#    formtoken to /?action=Enter. The token is bound to the PHPSESSID
#    cookie issued with the page, so a cookie jar is mandatory; we keep
#    one per search run and retry exactly once.
#  * PaTracker tokenizes search on whitespace, so "die hard" never
#    matches uploads named Die.Hard.1988...RUNTIME-. We issue the raw
#    phrase and a dot-joined variant and merge (2 requests max).
#  * v1.3: the torrent list markup moved from <tr>/<td> tables to
#    phpBB-style <li><dl><dd class="views ..."> rows (PaTracker 1.7.5).
#    Parse BOTH shapes — the site is known to A/B markup — and raise a
#    real error when the heavy-load gate is still up after the Enter
#    click, instead of masquerading a block as zero results.

import html as htmllib
import http.cookiejar
import re
import time
import urllib.error
import urllib.parse
import urllib.request
import urllib.response

from novaprinter import prettyPrinter


def _strip(cell):
    return re.sub(r"\s+", " ", htmllib.unescape(
        re.sub(r"<[^>]+>", " ", cell))).strip()


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
    _SIZE_RE = re.compile(r"^([\d.,]+)\s*([KMGT]i?B?)\b")
    _SL_RE = re.compile(r"\b(\d+)\s*/\s*(\d+)")

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

    def _mk(self, rid, name, size, seeds, leech, pub_date=-1):
        return {
            "id": rid,
            "name": htmllib.unescape(name)[:200],
            "link": self.url + "index.php?action=Download&id=" + rid,
            "seeds": seeds,
            "leech": leech,
            "size": size,
            "engine_url": self.url,
            "desc_link": self.url + "index.php?view=TorrentDetail&id=" + rid,
            "pub_date": pub_date,
        }

    def _parse_phpbb(self, html):
        """PaTracker >=1.7 list rows: <li class="row"><dl> ... </dl></li>"""
        out = []
        for row in re.finditer(
                r"<li\b[^>]*class=[\"'][^\"']*\brow\b[^\"']*[\"'].*?</li>",
                html, re.S):
            chunk = row.group(0)
            link = re.search(r"view=TorrentDetail&amp;id=(\d+)|view=TorrentDetail&id=(\d+)",
                             chunk)
            rid = next(g for g in link.groups() if g) if link else None
            slc = re.search(r"views swarmsize\"[^>]*>(.*?)</dd>", chunk, re.S)
            slf = self._SL_RE.search(_strip(slc.group(1))) if slc else None
            if not (rid and slf):
                continue
            nm = re.search(r"view=TorrentDetail&(?:amp;)?id=\d+\"[^>]*title=\"([^\"]+)\"",
                           chunk)
            if not nm:
                nm = re.search(r"view=TorrentDetail&(?:amp;)?id=\d+\"[^>]*>([^<]+)<",
                               chunk)
            name = nm.group(1) if nm else "?"
            sz = "-1"
            szc = re.search(r"views filesize\"[^>]*>(.*?)</dd>", chunk, re.S)
            if szc:
                ms = self._SIZE_RE.match(_strip(szc.group(1)))
                if ms:
                    sz = ms.group(1).replace(",", "") + ms.group(2).upper().replace("I", "")
            pub = -1
            ad = re.search(r"views added\"[^>]*>\s*([\d]{4}-[\d]{2}-[\d]{2})",
                           chunk)
            if ad:
                try:
                    pub = int(time.mktime(
                        time.strptime(ad.group(1), "%Y-%m-%d")))
                except ValueError:
                    pass
            out.append(self._mk(rid, name, sz, int(slf.group(1)),
                                int(slf.group(2)), pub))
        return out

    def _parse_table(self, html):
        """Legacy <tr>/<td> list markup (kept for A/B layout fallback)."""
        out = []
        for row in re.finditer(r"<tr[^>]*>(.*?)</tr>", html, re.S):
            cells = re.findall(r"<td[^>]*>(.*?)</td>", row.group(1), re.S)
            if len(cells) < 4:
                continue
            flat = [_strip(c) for c in cells]
            link = re.search(r"view=TorrentDetail&id=(\d+)", row.group(1))
            sl = None
            for c in flat:
                m = self._SL_RE.search(c)
                if m:
                    sl = m
                    break
            if not (sl and link):
                continue
            name = flat[1] if len(flat) > 1 else flat[0]
            size = "-1"
            for c in flat:
                ms = self._SIZE_RE.match(c)
                if ms:
                    size = ms.group(1) + ms.group(2)
                    break
            out.append(self._mk(link.group(1), name, size,
                                int(sl.group(1)), int(sl.group(2))))
        return out

    def _parse(self, html):
        rows = self._parse_phpbb(html)
        if rows:
            return rows
        return self._parse_table(html)

    def search(self, what, cat="all"):
        phrase = urllib.parse.unquote_plus(what).strip()
        if not phrase:
            raise ValueError("postman_i2p: empty query")
        variants = [phrase]
        dotted = re.sub(r"\s+", ".", phrase)
        if dotted != phrase:
            variants.append(dotted)
        seen, done, last_html = set(), False, ""
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
            last_html = self._get(args)
            for item in self._parse(last_html):
                if item["id"] in seen:
                    continue
                seen.add(item["id"])
                prettyPrinter(item)
                done = True
        if not done:
            low = last_html.lower()
            if "heavy load" in low or "throttling" in low or "formtoken" in low:
                # hard block, not an empty result set — show a real error
                raise RuntimeError(
                    "Postman heavy-load gate still active after Enter "
                    "(site throttling) — retry in ~1 h; polling it now "
                    "only re-arms the cooldown")
            if "view=TorrentDetail" in last_html:
                # rows on the page but parser found none => markup drift
                raise RuntimeError(
                    "postman_i2p: page has torrent rows but none parsed "
                    "— markup changed, update the engine")
