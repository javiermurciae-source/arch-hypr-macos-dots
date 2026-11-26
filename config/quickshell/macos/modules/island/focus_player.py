#!/usr/bin/env python3
"""Focus the Hyprland window owning an MPRIS media player (or app).

Usage:
  focus_player.py <dbus_name> <identity> <desktop_entry> <track_title>
"""
import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
MINIMIZE_SCRIPT = os.path.join(HOME, ".config/hypr/scripts/minimize_window.py")
SPECIAL_MIN = "special:minimized"


def hypr_clients():
    try:
        out = subprocess.check_output(["hyprctl", "-j", "clients"], text=True, timeout=4)
        return json.loads(out)
    except Exception:
        return []


def eval_lua(code):
    try:
        subprocess.run(["hyprctl", "eval", code], capture_output=True, text=True, timeout=4)
    except Exception:
        pass


def get_dbus_pid(dbus_name):
    if not dbus_name:
        return None
    full = dbus_name if dbus_name.startswith("org.mpris.MediaPlayer2.") else f"org.mpris.MediaPlayer2.{dbus_name}"
    try:
        out = subprocess.check_output(
            [
                "busctl", "--user", "call",
                "org.freedesktop.DBus", "/org/freedesktop/DBus",
                "org.freedesktop.DBus", "GetConnectionUnixProcessID",
                "s", full,
            ],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=2,
        ).strip()
        parts = out.split()
        if len(parts) >= 2 and parts[-1].isdigit():
            return int(parts[-1])
    except Exception:
        pass
    m = re.search(r"instance(?:_\d+_)?(\d+)", dbus_name)
    if m:
        return int(m.group(1))
    return None


def pid_ancestry(pid):
    chain = set()
    cur = pid
    for _ in range(12):
        if not cur or cur <= 1 or cur in chain:
            break
        chain.add(cur)
        try:
            with open(f"/proc/{cur}/stat", "r", encoding="utf-8") as f:
                data = f.read()
            rparen = data.rfind(")")
            if rparen == -1:
                break
            fields = data[rparen + 2:].split()
            ppid = int(fields[1])
            cur = ppid
        except Exception:
            break
    return chain


def extract_tokens(dbus_name, identity, desktop_entry):
    tokens = []
    for raw in (desktop_entry, identity, dbus_name):
        s = (raw or "").strip().lower()
        if not s:
            continue
        s = s.replace("org.mpris.mediaplayer2.", "")
        s = re.sub(r"\.instance.*$", "", s)
        tokens.append(s)
        for part in re.split(r"[\s._:/-]+", s):
            if len(part) >= 3 and part not in ("com", "org", "net", "app", "github", "media", "player", "mozilla"):
                tokens.append(part)
    # Deduplicate preserving order
    seen = set()
    uniq = []
    for t in tokens:
        if t and t not in seen:
            seen.add(t)
            uniq.append(t)
    return uniq


def score_client(c, pids, tokens, track_title):
    cls = (c.get("class") or "").lower()
    init_cls = (c.get("initialClass") or "").lower()
    title = (c.get("title") or "").lower()
    ws_name = (c.get("workspace") or {}).get("name") or ""
    cpid = c.get("pid") or 0

    score = 0
    if cpid and cpid in pids:
        score += 100
    else:
        # Walk client PID ancestry too in case window is a sibling/child of MPRIS process
        if pids and cpid:
            c_anc = pid_ancestry(cpid)
            if c_anc & pids:
                score += 80

    # Exact class / desktop entry match
    for t in tokens[:3]:
        if t and (t == cls or t == init_cls):
            score += 90
            break
        if t and len(t) >= 4 and (t in cls or t in init_cls):
            score += 60
            break

    if score == 0:
        for t in tokens:
            if len(t) >= 4 and (t in cls or t in init_cls):
                score += 45
                break

    if score == 0:
        return 0

    # Prefer window whose title matches the currently playing track
    clean_track = re.sub(r"\s+", " ", (track_title or "").strip()).lower()
    if len(clean_track) >= 4:
        snippet = clean_track[:24]
        if snippet in title or clean_track in title:
            score += 40
        else:
            words = [w for w in re.split(r"\W+", clean_track) if len(w) >= 4][:3]
            if words and any(w in title for w in words):
                score += 15

    # Prefer non-minimized windows, then most recently focused
    if ws_name != SPECIAL_MIN:
        score += 10
    hist = c.get("focusHistoryID")
    if isinstance(hist, int):
        score += max(0, 8 - min(hist, 8))
    return score


def focus_client(c):
    addr = c.get("address")
    if not addr:
        return False
    ws = c.get("workspace") or {}
    ws_name = ws.get("name") or ""
    ws_id = ws.get("id")

    if ws_name == SPECIAL_MIN and os.path.isfile(MINIMIZE_SCRIPT):
        subprocess.Popen(
            ["python3", MINIMIZE_SCRIPT, "restore", addr],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True

    if isinstance(ws_id, int) and ws_id > 0:
        eval_lua(
            f'hl.dispatch(hl.dsp.focus({{ workspace = {ws_id} }})); '
            f'hl.dispatch(hl.dsp.focus({{ window = "address:{addr}" }}))'
        )
    else:
        eval_lua(f'hl.dispatch(hl.dsp.focus({{ window = "address:{addr}" }}))')
    return True


def main():
    dbus_name = sys.argv[1] if len(sys.argv) > 1 else ""
    identity = sys.argv[2] if len(sys.argv) > 2 else ""
    desktop_entry = sys.argv[3] if len(sys.argv) > 3 else ""
    track_title = sys.argv[4] if len(sys.argv) > 4 else ""

    clients = hypr_clients()
    if not clients:
        return

    pid = get_dbus_pid(dbus_name)
    pids = pid_ancestry(pid) if pid else set()
    tokens = extract_tokens(dbus_name, identity, desktop_entry)

    best = None
    best_score = 0
    for c in clients:
        sc = score_client(c, pids, tokens, track_title)
        if sc > best_score:
            best_score = sc
            best = c

    if best and best_score > 0:
        focus_client(best)


if __name__ == "__main__":
    main()
