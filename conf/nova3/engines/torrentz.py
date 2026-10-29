# VERSION: 1.0
# AUTHORS: quartztester
# Torrentz (torrentz.i2p) — meta-search across the big I2P-listed
# indexes via its machine-readable RSS feed (/feed?q=). Anonymous, no
# account, third independent operator (its own throttle bucket).
# NOTE: like all I2P catalog sites it indexes mostly clearnet-origin
# release hashes; the Seeds/Peers shown are what its own tracker
# reports.

import calendar
import re
import urllib.parse
from email.utils import parsedate_to_datetime

from helpers import retrieve_url
from novaprinter import prettyPrinter


class torrentz:
    name = "Torrentz (I2P)"
    url = "http://torrentz.i2p/"
    supported_categories = {"all": "All"}

    _ITEM = re.compile(r"<item>(.*?)</item>", re.S)

    def _field(self, blob, label):
        m = re.search(label + r": ([^\s<]+)", blob)
        return m.group(1) if m else None

    def _size_bytes(self, s):
        if not s:
            return -1
        m = re.match(r"([\d.]+)\s*([KMGT]?B)", s, re.I)
        if not m:
            return -1
        mult = {"B": 1, "KB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12}
        return int(float(m.group(1)) * mult.get(m.group(2).upper(), 1))

    def _pub(self, s):
        try:
            return calendar.timegm(parsedate_to_datetime(s.strip()).utctimetuple())
        except Exception:  # noqa: BLE001
            return -1

    def search(self, what, cat="all"):
        q = urllib.parse.quote_plus(what)
        try:
            xml = retrieve_url(self.url + "feed?q=" + q)
        except Exception as e:  # noqa: BLE001
            raise RuntimeError(
                "Torrentz request failed (possibly rate-limited; wait a "
                "few minutes and retry once). Error: %r" % (e,)) from e
        if not xml.strip():
            raise RuntimeError("Torrentz returned empty response (rate limit?)")
        rows = []
        for item in self._ITEM.findall(xml):
            t = re.search(r"<title>([^<]*)</title>", item)
            h = re.search(r"([0-9a-f]{40})", item)
            if not (t and h):
                continue
            d = re.search(r"<description>([^<]*)</description>", item)
            blob = d.group(1) if d else ""
            pub = re.search(r"<pubDate>([^<]*)</pubDate>", item)
            rows.append({
                "name": t.group(1)[:200],
                "link": "magnet:?xt=urn:btih:" + h.group(1),
                "seeds": int(self._field(blob, "Seeds") or 0),
                "leech": int(self._field(blob, "Peers") or 0),
                "size": self._size_bytes(self._field(blob, "Size")),
                "engine_url": self.url,
                "desc_link": self.url + h.group(1),
                "pub_date": self._pub(pub.group(1)) if pub else -1,
            })
        for item in sorted(rows, key=lambda x: -x["seeds"]):
            prettyPrinter(item)
