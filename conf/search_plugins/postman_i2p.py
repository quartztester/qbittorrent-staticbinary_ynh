# postman_i2p.py — qBittorrent search plugin for tracker2.postman.i2p
# Anonymous HTML search of the one I2P tracker with live swarms.
# Requires HTTP_PROXY=http://127.0.0.1:4447 (or the app's I2P proxy) in
# qBittorrent's environment so that .i2p hostnames resolve.
import re
import requests
from requests.utils import dict_from_cookiejar

API = {
    'search':   {'name': 'search'},
    'category': {'name': 'category', 'default': '-1'},
    'orderby':  {'name': 'orderby',  'default': '5'},   # swarmsize
    'lastact':  {'name': 'lastactive', 'default': '0'}  # seeded torrents only
}
BASEURL = 'http://tracker2.postman.i2p/'
CATEGORIES = {
    '-1': 'All', '1': 'Movies', '2': 'Music', '3': 'TV', '4': 'Games',
    '5': 'Apps', '6': 'Misc', '8': 'Pictures', '9': 'Anime', '10': 'Comics',
    '13': 'Books', '20': 'Documentary',
}
UA = 'Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0'


class search(object):
    def __init__(self):
        self.sessions = []
        self.session = self.get_session()

    def get_session(self):
        session = requests.Session()
        session.headers.update({'User-Agent': UA,
                                'Accept': 'text/html,application/xhtml+xml'})
        self.sessions.append(session)
        return session

    def clean_session(self, session):
        session.close()

    def cleanup(self):
        for s in self.sessions:
            try:
                s.close()
            except Exception:
                pass


class SearchEngine(search):
    def __init__(self):
        super(SearchEngine, self).__init__()
        self.url = BASEURL

    def _pass_gate(self, page):
        """Postman's optional 'heavy load' interstitial: one-click Proceed."""
        if 'SITE UNDER HEAVY LOAD' not in page.text:
            return page
        tok = re.search(r'name="formtoken" value="([0-9a-f]+)"', page.text)
        if not tok:
            return page
        return self.session.post(self.url + '?action=Enter',
                                 data={'formtoken': tok.group(1)},
                                 headers={'Referer': page.url}, timeout=90)

    def _parse(self, html):
        results = []
        for row in re.finditer(r'<tr[^>]*>(.*?)</tr>', html, re.S):
            cells = re.findall(r'<td[^>]*>(.*?)</td>', row.group(1), re.S)
            if len(cells) < 4:
                continue
            flat = [re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', c)).strip()
                    for c in cells]
            link = re.search(r'href="[^"]*(?:view=TorrentDetail|id=)(\d+)',
                             row.group(1))
            sl = None
            for c in flat:
                m = re.match(r'^(\d+)\s*/\s*(\d+)$', c)
                if m:
                    sl = m
                    break
            name = flat[1] if len(flat) > 1 else flat[0]
            if sl and link:
                results.append({'name': name[:200],
                                'seed': int(sl.group(1)),
                                'leech': int(sl.group(2)),
                                'url': self.url +
                                       'index.php?action=Download&id=' + link.group(1),
                                'magnet': ''})
        return results

    def search(self, key, page=0):
        args = {'search': key, 'view': 'Main', 'reset': '1', 'limit': '50'}
        args['category'] = self._getArg(API['category'], '-1')
        args['orderby'] = self._getArg(API['orderby'], '5')
        args['lastactive'] = self._getArg(API['lastact'], '0')
        try:
            r = self.session.get(self.url, params=args, timeout=90)
            r = self._pass_gate(r)
            return self._parse(r.text)
        except Exception:
            return []

    def _getArg(self, arg, default):
        # qBittorrent injects the user's search-tab selections as the
        # 'config' property on the engine instance.
        try:
            return getattr(self, 'config', {}).get(API[arg]['name'], default)
        except Exception:
            return default


__all__ = ['SearchEngine']
