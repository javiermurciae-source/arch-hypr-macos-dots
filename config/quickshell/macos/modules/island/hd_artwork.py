#!/usr/bin/env python3
"""Resolve maximum-resolution (1200x1200) album artwork for MPRIS tracks.

Usage: hd_artwork.py <title> <artist> <album> <raw_art_url>
Outputs a file:// or https:// URL of the highest-resolution cover available.
Caches downloaded HD covers in ~/.cache/quickshell/hd_art/ for instant reuse.
"""
import hashlib, json, os, re, struct, sys, urllib.parse, urllib.request

CACHE_DIR = os.path.expanduser("~/.cache/quickshell/hd_art")
os.makedirs(CACHE_DIR, exist_ok=True)
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"


def clean_text(s):
    s = (s or "").strip()
    s = re.sub(r"\s*-\s*Topic$", "", s, flags=re.I)
    s = re.sub(r"\s*[\(\[](?:Official|Video|Audio|Lyrics|Letra|HD|4K|Visualizer|Remaster|En Vivo|Live)[^\)\]]*[\)\]]", "", s, flags=re.I)
    return re.sub(r"\s+", " ", s).strip()


def local_image_width(path):
    """Fast PNG/JPEG header dimension check without heavy imports."""
    try:
        with open(path, "rb") as f:
            head = f.read(32)
            if head[:8] == b"\x89PNG\r\n\x1a\n" and len(head) >= 24:
                return struct.unpack(">I", head[16:20])[0]
            if head[:2] == b"\xff\xd8":
                f.seek(2)
                while True:
                    b = f.read(1)
                    if not b:
                        break
                    while b == b"\xff":
                        b = f.read(1)
                    marker = b[0]
                    if marker in (0xC0, 0xC1, 0xC2):
                        f.read(3)
                        h, w = struct.unpack(">HH", f.read(4))
                        return w
                    ln = struct.unpack(">H", f.read(2))[0]
                    f.seek(ln - 2, 1)
    except Exception:
        pass
    return 0


def upgrade_http_url(u):
    if "googleusercontent.com" in u or "ggpht.com" in u:
        u2 = re.sub(r"=w\d+-h\d+[^&]*", "=w1200-h1200-l90-rj", u)
        if u2 == u:
            u2 = re.sub(r"=s\d+[^&]*", "=s1200", u)
        return u2
    if "i.ytimg.com" in u:
        return re.sub(r"/(?:hq|mq|sd)?default\.jpg", "/maxresdefault.jpg", u)
    return u


def fetch_json(url, timeout=6):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", errors="ignore"))


def find_hd_cover(title, artist, album):
    q_title = clean_text(title)
    q_artist = clean_text(artist)
    q_album = clean_text(album)
    if not q_title:
        return ""

    # 1. Apple Music / iTunes Search API (official 1200x1200 studio covers!)
    queries = []
    if q_artist:
        queries.append(f"{q_artist} {q_title}")
    if q_album and q_album.lower() != q_title.lower() and q_artist:
        queries.append(f"{q_artist} {q_album}")
    queries.append(q_title)

    for q in queries:
        try:
            url = "https://itunes.apple.com/search?" + urllib.parse.urlencode({
                "term": q, "media": "music", "entity": "song", "limit": 6
            })
            data = fetch_json(url)
            results = data.get("results") or []
            best = None
            for item in results:
                it_t = (item.get("trackName") or "").lower()
                it_a = (item.get("artistName") or "").lower()
                if q_title.lower() in it_t or it_t in q_title.lower():
                    if not q_artist or q_artist.lower() in it_a or it_a in q_artist.lower():
                        best = item
                        break
            if not best and results:
                best = results[0]
            if best:
                art = best.get("artworkUrl100") or best.get("artworkUrl60") or ""
                if art:
                    return re.sub(r"\d+x\d+bb", "1200x1200bb", art)
        except Exception:
            pass

    # 2. Deezer public search API fallback (1000x1000 cover_xl)
    try:
        q = f"{q_artist} {q_title}".strip()
        url = "https://api.deezer.com/search?" + urllib.parse.urlencode({"q": q, "limit": 5})
        data = fetch_json(url)
        for item in data.get("data") or []:
            alb = item.get("album") or {}
            art = alb.get("cover_xl") or alb.get("cover_big") or ""
            if art:
                return art
    except Exception:
        pass
    return ""


def download_cached(url, cache_path):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=8) as r:
        data = r.read()
    if len(data) > 4096:
        tmp = cache_path + ".tmp"
        with open(tmp, "wb") as f:
            f.write(data)
        os.replace(tmp, cache_path)
        return True
    return False


def main():
    title = sys.argv[1] if len(sys.argv) > 1 else ""
    artist = sys.argv[2] if len(sys.argv) > 2 else ""
    album = sys.argv[3] if len(sys.argv) > 3 else ""
    raw = sys.argv[4] if len(sys.argv) > 4 else ""

    # If already a high-res HTTP URL, upgrade resolution params directly
    if raw.startswith("http://") or raw.startswith("https://"):
        print(upgrade_http_url(raw))
        return

    # If local file is already high-res (>= 500px), keep it directly!
    if raw.startswith("file://"):
        local_path = urllib.parse.unquote(raw[7:])
        if os.path.isfile(local_path) and local_image_width(local_path) >= 500:
            print(raw)
            return

    key = hashlib.md5(f"{clean_text(title).lower()}|{clean_text(artist).lower()}|{clean_text(album).lower()}".encode()).hexdigest()[:16]
    cache_img = os.path.join(CACHE_DIR, f"{key}.jpg")
    if os.path.isfile(cache_img) and os.path.getsize(cache_img) > 4096:
        print("file://" + cache_img)
        return

    hd_url = find_hd_cover(title, artist, album)
    if hd_url and download_cached(hd_url, cache_img):
        print("file://" + cache_img)
    else:
        print(raw)


if __name__ == "__main__":
    main()
