#!/usr/bin/env python3
"""Extract 3 harmonious aurora colors + readable accent from an album art URL/path."""
import colorsys
import hashlib
import io
import json
import os
import sys
import urllib.parse
import urllib.request
from PIL import Image

CACHE_DIR = os.path.expanduser("~/.cache/quickshell/island/palettes")
os.makedirs(CACHE_DIR, exist_ok=True)

DEFAULT = {
    "c1": "#107a9c",
    "c2": "#2056dc",
    "c3": "#602cc2",
    "accent": "#5eb0ff",
}


def rgb_hex(r, g, b):
    return "#{:02x}{:02x}{:02x}".format(
        max(0, min(255, int(r))),
        max(0, min(255, int(g))),
        max(0, min(255, int(b))),
    )


def boost_hsv(r, g, b, min_s=0.45, max_s=0.88, min_v=0.42, max_v=0.85):
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    if s < 0.08:
        # Monochrome / grayscale cover: give a sleek cool silver-blue tint
        return (110, 130, 165)
    s = max(min_s, min(max_s, s * 1.15))
    v = max(min_v, min(max_v, v))
    rr, gg, bb = colorsys.hsv_to_rgb(h, s, v)
    return (int(rr * 255), int(gg * 255), int(bb * 255))


def load_image(src: str):
    if src.startswith("file://"):
        path = urllib.parse.unquote(src[7:])
        return Image.open(path)
    if src.startswith("http://") or src.startswith("https://"):
        req = urllib.request.Request(src, headers={"User-Agent": "QuickshellIsland/1.0"})
        with urllib.request.urlopen(req, timeout=4) as resp:
            return Image.open(io.BytesIO(resp.read()))
    if os.path.exists(src):
        return Image.open(src)
    return None


def extract(src: str):
    img = load_image(src)
    if img is None:
        return DEFAULT
    img = img.convert("RGB").resize((36, 36), Image.Resampling.BILINEAR)
    pal = img.quantize(colors=8, method=Image.Quantize.MEDIANCUT)
    palette = pal.getpalette()[:24]
    counts = pal.getcolors() or []

    scored = []
    for count, idx in counts:
        r, g, b = palette[idx * 3 : idx * 3 + 3]
        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        # Prefer rich colorful midtones over pure black/white background
        weight = count * (0.25 + s * 1.6) * (0.2 + (1.0 - abs(v - 0.55)))
        scored.append((weight, (r, g, b), h, s, v))

    scored.sort(key=lambda x: x[0], reverse=True)
    if not scored:
        return DEFAULT

    picked = [scored[0][1]]
    picked_h = [scored[0][2]]
    for _, rgb, h, s, v in scored[1:]:
        # Pick visually distinct hues when available
        if all(min(abs(h - ph), 1.0 - abs(h - ph)) > 0.08 for ph in picked_h):
            picked.append(rgb)
            picked_h.append(h)
        if len(picked) >= 3:
            break

    while len(picked) < 3:
        # Derive harmonious analogous shift from primary
        base = picked[0]
        h, s, v = colorsys.rgb_to_hsv(base[0] / 255.0, base[1] / 255.0, base[2] / 255.0)
        shift = 0.09 if len(picked) == 1 else -0.09
        rr, gg, bb = colorsys.hsv_to_rgb((h + shift) % 1.0, max(0.35, s), max(0.45, v))
        picked.append((int(rr * 255), int(gg * 255), int(bb * 255)))

    c1 = boost_hsv(*picked[0], min_s=0.45, max_s=0.88, min_v=0.46, max_v=0.82)
    c2 = boost_hsv(*picked[1], min_s=0.45, max_s=0.90, min_v=0.48, max_v=0.86)
    c3 = boost_hsv(*picked[2], min_s=0.42, max_s=0.85, min_v=0.42, max_v=0.78)
    acc = boost_hsv(*picked[0], min_s=0.45, max_s=0.85, min_v=0.78, max_v=0.98)

    return {
        "c1": rgb_hex(*c1),
        "c2": rgb_hex(*c2),
        "c3": rgb_hex(*c3),
        "accent": rgb_hex(*acc),
    }


def main():
    src = (sys.argv[1] if len(sys.argv) > 1 else "").strip()
    if not src:
        print(json.dumps(DEFAULT))
        return

    key = hashlib.sha1(src.encode("utf-8")).hexdigest()
    cache_path = os.path.join(CACHE_DIR, f"{key}.json")
    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r", encoding="utf-8") as f:
                print(f.read())
                return
        except Exception:
            pass

    try:
        res = extract(src)
    except Exception:
        res = DEFAULT

    out = json.dumps(res)
    try:
        with open(cache_path, "w", encoding="utf-8") as f:
            f.write(out)
    except Exception:
        pass
    print(out)


if __name__ == "__main__":
    main()
