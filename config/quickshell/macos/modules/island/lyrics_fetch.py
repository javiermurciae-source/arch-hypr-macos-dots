#!/usr/bin/env python3
"""Multi-stage smart synced-lyrics fetcher (LRCLIB + lyrics.ovh fallback) with YouTube/Topic metadata cleaning,
album & duration-aware scoring, and duration+album-aware caching."""
import hashlib
import json
import os
import re
import sys
import unicodedata
import urllib.parse
import urllib.request

CACHE_DIR = os.path.expanduser("~/.cache/quickshell/island/lyrics_v3")
os.makedirs(CACHE_DIR, exist_ok=True)

HEADERS = {"User-Agent": "QuickshellNusaIsland/3.0 (ArchLinux)"}

NOISE_BRACKETS_RE = re.compile(
    r"[\(\[\{][^)\]\}]*?(official|video|audio|lyric|letra|visualizer|hd|4k|8k|remaster|live|en vivo|"
    r"vivo|mv|m/v|music video|video oficial|audio oficial|clean|explicit|sub\.?\s*esp|español|"
    r"prod\.?|remix|version|versión|edit|clip|topic|vevo|feat\.?|ft\.?|con |with )[^)\]\}]*?[\)\]\}]",
    re.IGNORECASE,
)
TRAILING_FEAT_RE = re.compile(r"\s+(feat\.?|ft\.?|featuring|with|prod\.?)\s+.*$", re.IGNORECASE)
LEADING_COUNT_RE = re.compile(r"^\(\d+\)\s*")
ARTIST_NOISE_RE = re.compile(
    r"\s*(-\s*topic|vevo|official(\s+channel|\s+music)?|music\s+channel|records|entertainment)\s*$",
    re.IGNORECASE,
)
EDITION_TAG_RE = re.compile(
    r"\b(live|en vivo|unplugged|acoustic|acústic[oa]|remix|slowed|sped up|nightcore|radio edit|demo|karaoke|instrumental)\b",
    re.IGNORECASE,
)


def strip_accents(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def clean_artist(raw: str) -> str:
    s = (raw or "").strip()
    s = ARTIST_NOISE_RE.sub("", s).strip()
    s = re.sub(r"\s*[-–—]\s*topic\s*$", "", s, flags=re.IGNORECASE).strip()
    return s


def primary_artist(artist: str) -> str:
    parts = re.split(r"\s*(?:,|&|feat\.?|ft\.?|/|;|\bx\b)\s*", artist, flags=re.IGNORECASE)
    return (parts[0] if parts else artist).strip()


def clean_title(raw: str) -> str:
    s = (raw or "").strip()
    s = LEADING_COUNT_RE.sub("", s)
    s = NOISE_BRACKETS_RE.sub(" ", s)
    if " | " in s:
        s = s.split(" | ", 1)[0]
    if " // " in s:
        s = s.split(" // ", 1)[0]
    s = TRAILING_FEAT_RE.sub("", s)
    s = re.sub(r"\s{2,}", " ", s).strip(" -–—")
    return s


def clean_album(raw: str) -> str:
    s = (raw or "").strip()
    s = re.sub(r"\s*[\(\[](?:deluxe|expanded|remaster(?:ed)?|anniversary|special|bonus|explicit|clean)[^\)\]]*[\)\]]", "", s, flags=re.IGNORECASE)
    return re.sub(r"\s{2,}", " ", s).strip(" -–—")


def split_artist_title_from_title(title: str):
    """If YouTube crammed 'Artist - Song Title' into trackTitle, return (artist, song)."""
    for sep in (" - ", " – ", " — "):
        if sep in title:
            left, right = title.split(sep, 1)
            left, right = left.strip(), right.strip()
            if 1 < len(left) <= 45 and len(right) >= 2:
                return clean_artist(left), clean_title(right)
    return None, None


def parse_lrc(lrc_text: str):
    lines = []
    pattern = re.compile(r"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]")
    offset_ms = 0.0
    for raw in lrc_text.splitlines():
        off_m = re.match(r"^\s*\[offset:\s*([+-]?\d+)\s*\]\s*$", raw, re.IGNORECASE)
        if off_m:
            try:
                offset_ms = float(off_m.group(1))
            except Exception:
                pass
            continue
        matches = list(pattern.finditer(raw))
        if not matches:
            continue
        lyric = pattern.sub("", raw).strip()
        if not lyric:
            continue
        for m in matches:
            mins = int(m.group(1))
            secs = int(m.group(2))
            frac = m.group(3) or "0"
            ms = int(frac.ljust(3, "0")[:3])
            # LRC [offset:+/-ms]: positive shifts lyrics earlier (subtract offset)
            t = max(0.0, mins * 60.0 + secs + (ms - offset_ms) / 1000.0)
            lines.append({"t": round(t, 2), "text": lyric})
    lines.sort(key=lambda x: x["t"])
    return lines


def http_json(url: str, timeout: float = 4.5):
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8", errors="replace"))
    except Exception:
        return None


def edition_tags(text: str):
    return set(m.group(1).lower() for m in EDITION_TAG_RE.finditer(text or ""))


def score_candidate(item: dict, target_title: str, target_artist: str, target_album: str, duration: int, raw_context: str):
    if not isinstance(item, dict):
        return -1e9
    synced = (item.get("syncedLyrics") or "").strip()
    plain = (item.get("plainLyrics") or "").strip()
    if not synced and not plain:
        return -1e9

    score = 100.0 if synced else 20.0
    cand_title_raw = item.get("trackName") or ""
    cand_artist_raw = item.get("artistName") or ""
    cand_album_raw = item.get("albumName") or ""

    cand_title = strip_accents(cand_title_raw.lower()).strip()
    cand_artist = strip_accents(cand_artist_raw.lower()).strip()
    cand_album = strip_accents(clean_album(cand_album_raw).lower()).strip()

    tt = strip_accents(target_title.lower()).strip()
    ta = strip_accents(target_artist.lower()).strip()
    talb = strip_accents(clean_album(target_album).lower()).strip()

    if tt and cand_title == tt:
        score += 40.0
    elif tt and (tt in cand_title or cand_title in tt):
        score += 20.0
    else:
        score -= 25.0

    if ta:
        if cand_artist == ta:
            score += 35.0
        elif ta in cand_artist or cand_artist in ta:
            score += 22.0
        else:
            tw = set(re.findall(r"\w+", ta))
            cw = set(re.findall(r"\w+", cand_artist))
            if tw & cw:
                score += 12.0
            else:
                score -= 20.0

    if talb and cand_album:
        if cand_album == talb:
            score += 35.0
        elif talb in cand_album or cand_album in talb:
            score += 20.0

    # Penalize live/unplugged/remix mismatches (these almost always have different intros!)
    want_tags = edition_tags(raw_context)
    cand_tags = edition_tags(f"{cand_title_raw} {cand_album_raw}")
    if cand_tags and not want_tags:
        score -= 35.0
    elif want_tags and (want_tags & cand_tags):
        score += 18.0

    cand_dur = item.get("duration")
    if duration > 0 and isinstance(cand_dur, (int, float)) and cand_dur > 0:
        diff = abs(cand_dur - duration)
        if diff <= 1.5:
            score += 50.0
        elif diff <= 3.5:
            score += 38.0
        elif diff <= 7.0:
            score += 20.0
        elif diff <= 12.0:
            score += 0.0
        elif diff <= 25.0:
            score -= 25.0
        elif diff <= 45.0:
            score -= 55.0
        else:
            score -= 85.0

    return score


def candidate_to_result(item: dict):
    synced = (item.get("syncedLyrics") or "").strip()
    if synced:
        parsed = parse_lrc(synced)
        if parsed:
            return {"synced": True, "lines": parsed}
    plain = (item.get("plainLyrics") or "").strip()
    if plain:
        plines = [{"t": -1, "text": l.strip()} for l in plain.splitlines() if l.strip()]
        if plines:
            return {"synced": False, "lines": plines[:120]}
    return None


def fetch_lrclib(title: str, artist: str, duration: int, album: str = ""):
    c_title = clean_title(title)
    c_artist = clean_artist(artist)
    p_artist = primary_artist(c_artist)
    c_album = clean_album(album)
    split_a, split_t = split_artist_title_from_title(title)
    raw_context = f"{title} {album}"

    # 1. Fast exact GET first — ALWAYS try with album_name + duration first so we get the exact edition!
    get_attempts = []
    if c_title and c_artist and c_album and duration > 0:
        get_attempts.append({"track_name": c_title, "artist_name": c_artist, "album_name": c_album, "duration": str(duration)})
    if c_title and p_artist and p_artist != c_artist and c_album and duration > 0:
        get_attempts.append({"track_name": c_title, "artist_name": p_artist, "album_name": c_album, "duration": str(duration)})
    if duration > 0:
        for t_try, a_try in [(c_title, c_artist), (c_title, p_artist), (split_t, split_a)]:
            if t_try and a_try:
                get_attempts.append({"track_name": t_try, "artist_name": a_try, "duration": str(duration)})

    seen_get = set()
    for params in get_attempts:
        qs = urllib.parse.urlencode(params)
        if qs in seen_get:
            continue
        seen_get.add(qs)
        data = http_json("https://lrclib.net/api/get?" + qs)
        if isinstance(data, dict):
            # Double-check duration sanity & edition match before accepting
            cand_dur = data.get("duration")
            if duration > 0 and isinstance(cand_dur, (int, float)) and abs(cand_dur - duration) > 4.0:
                continue
            # If we have an album, prefer searching when /api/get didn't include album_name and returned a different album
            if c_album and "album_name" not in params:
                got_alb = strip_accents(clean_album(data.get("albumName") or "").lower())
                want_alb = strip_accents(c_album.lower())
                if got_alb and want_alb and got_alb != want_alb and want_alb not in got_alb and got_alb not in want_alb:
                    continue
            res = candidate_to_result(data)
            if res and res["synced"]:
                return res

    # 2. Smart multi-query search with strict duration + album + edition scoring
    queries = []
    if c_title and c_artist and c_album:
        queries.append({"track_name": c_title, "artist_name": c_artist, "album_name": c_album})
    if c_title and c_artist:
        queries.append({"track_name": c_title, "artist_name": c_artist})
    if c_title and p_artist and p_artist != c_artist:
        queries.append({"track_name": c_title, "artist_name": p_artist})
    if split_t and split_a:
        queries.append({"track_name": split_t, "artist_name": split_a})
    if c_title and p_artist:
        queries.append({"q": f"{c_title} {p_artist}"})
    if split_t:
        queries.append({"q": f"{split_t} {split_a or ''}".strip()})
    if c_title:
        queries.append({"q": c_title})
        no_acc = strip_accents(c_title)
        if no_acc != c_title:
            queries.append({"q": f"{no_acc} {strip_accents(p_artist)}".strip()})

    best_item = None
    best_score = -1e9
    seen_q = set()

    ref_title = split_t or c_title
    ref_artist = split_a or p_artist or c_artist

    for q in queries:
        qs = urllib.parse.urlencode(q)
        if qs in seen_q:
            continue
        seen_q.add(qs)
        data = http_json("https://lrclib.net/api/search?" + qs)
        if not isinstance(data, list) or not data:
            continue
        for item in data[:20]:
            sc = score_candidate(item, ref_title, ref_artist, c_album, duration, raw_context)
            if sc > best_score:
                best_score = sc
                best_item = item
        # Only stop early when we have a synced match with title + artist + close duration (+ album if known)
        early_threshold = 230.0 if (c_album and duration > 0) else (205.0 if duration > 0 else 165.0)
        if best_item and (best_item.get("syncedLyrics") or "").strip() and best_score >= early_threshold:
            break

    if best_item and best_score > 0:
        res = candidate_to_result(best_item)
        if res:
            return res

    # 3. Last-resort fallback: lyrics.ovh (plain lyrics)
    for t_try, a_try in [(c_title, p_artist), (split_t, split_a)]:
        if not t_try or not a_try:
            continue
        url = (
            "https://api.lyrics.ovh/v1/"
            + urllib.parse.quote(a_try)
            + "/"
            + urllib.parse.quote(t_try)
        )
        data = http_json(url, timeout=4.0)
        if isinstance(data, dict) and data.get("lyrics"):
            plines = [{"t": -1, "text": l.strip()} for l in data["lyrics"].splitlines() if l.strip()]
            if plines:
                return {"synced": False, "lines": plines[:120]}

    return {"synced": False, "lines": []}


def main():
    args = [a for a in sys.argv[1:] if a != "--force"]
    force = "--force" in sys.argv[1:]

    title = (args[0] if len(args) > 0 else "").strip()
    artist = (args[1] if len(args) > 1 else "").strip()
    try:
        duration = int(round(float(args[2]))) if len(args) > 2 and args[2] else 0
    except Exception:
        duration = 0
    album = (args[3] if len(args) > 3 else "").strip()

    if not title:
        print(json.dumps({"synced": False, "lines": []}))
        return

    # Bucket duration in 3-second increments so tiny ±1s player rounding hits cache
    # while distinct editions/intros (or duration=0 before load) NEVER poison each other!
    dur_bucket = (duration // 3) if duration > 0 else 0
    key_raw = f"{title.lower()}|{artist.lower()}|{clean_album(album).lower()}|{dur_bucket}"
    key = hashlib.sha1(key_raw.encode("utf-8")).hexdigest()
    cache_path = os.path.join(CACHE_DIR, f"{key}.json")

    if not force and os.path.exists(cache_path):
        try:
            with open(cache_path, "r", encoding="utf-8") as f:
                cached = json.loads(f.read())
                if cached.get("lines"):
                    print(json.dumps(cached, ensure_ascii=False))
                    return
        except Exception:
            pass

    result = fetch_lrclib(title, artist, duration, album)
    out = json.dumps(result, ensure_ascii=False)
    # Only persist cache when duration > 0 (never permanently cache a pre-load duration=0 lookup)
    if result.get("lines") and duration > 0:
        try:
            with open(cache_path, "w", encoding="utf-8") as f:
                f.write(out)
        except Exception:
            pass
    print(out)


if __name__ == "__main__":
    main()
