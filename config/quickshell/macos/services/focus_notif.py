#!/usr/bin/env python3
"""Focus the Hyprland window belonging to a notification sender (GUI or CLI app).

Usage:
  focus_notif.py <app_name> <desktop_entry> <summary> <body> <target_pid>
"""
import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
MINIMIZE_SCRIPT = os.path.join(HOME, ".config/hypr/scripts/minimize_window.py")
SPECIAL_MIN = "special:minimized"

TERMINAL_CLASSES = {
    "kitty", "foot", "alacritty", "wezterm", "org.wezfurlong.wezterm",
    "com.mitchellh.ghostty", "ghostty", "cool-retro-term", "konsole", "gnome-terminal",
}

CLI_APP_HINTS = {
    "opencode", "oc", "claude", "claude code", "codex", "gemini", "gemini cli",
    "gemini-cli", "agy", "antigravity-cli", "aider", "goose", "amp", "cline",
    "kiro", "crush", "copilot", "notify-send", "terminal", "kitty", "bash",
    "zsh", "fish", "sh", "tmux", "zellij", "screen", "nvim", "neovim", "vim",
    "nano", "hx", "helix", "git", "lazygit", "btop", "htop", "yazi", "ranger",
    "lf", "pacman", "yay", "paru", "cargo", "rustc", "npm", "pnpm", "yarn",
    "bun", "node", "python", "python3", "go", "docker", "podman", "make",
    "cmake", "ssh", "rsync", "ffmpeg", "curl", "wget",
}

APP_ALIASES = {
    "telegram": ["org.telegram.desktop", "telegramdesktop", "telegram"],
    "telegram desktop": ["org.telegram.desktop", "telegramdesktop", "telegram"],
    "zapfast": ["zapfast", "whatsapp"],
    "whatsapp": ["zapfast", "whatsapp", "firefox"],
    "youtube music": ["com.github.th-ch.youtube-music", "youtube-music", "pear"],
    "pear desktop": ["com.github.th-ch.youtube-music", "youtube-music"],
    "mozilla firefox": ["firefox"],
    "firefox": ["firefox"],
    "discord": ["discord", "vesktop", "webcord"],
    "vesktop": ["vesktop", "discord"],
    "spotify": ["spotify"],
    "antigravity": ["antigravity"],
    "visual studio code": ["code", "code-oss", "vscodium"],
    "code": ["code", "code-oss", "vscodium"],
    "google chrome": ["google-chrome", "chromium"],
    "chromium": ["chromium", "google-chrome"],
    "wps": ["wps", "wpp", "et", "wpsoffice"],
    "wps office": ["wps", "wpp", "et", "wpsoffice"],
    "files": ["org.gnome.nautilus", "nautilus", "dolphin", "thunar"],
    "archivos": ["org.gnome.nautilus", "nautilus", "dolphin", "thunar"],
    "nautilus": ["org.gnome.nautilus", "nautilus"],
    "dolphin": ["org.kde.dolphin", "dolphin"],
    "thunar": ["thunar"],
    "vlc": ["vlc"],
    "mpv": ["mpv"],
}


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


def build_proc_tree():
    """Map ppid -> [child_pids] and pid -> lowercased cmdline+comm."""
    children = {}
    cmdinfo = {}
    try:
        for entry in os.listdir("/proc"):
            if not entry.isdigit():
                continue
            pid = int(entry)
            try:
                with open(f"/proc/{pid}/stat", "r", encoding="utf-8") as f:
                    stat = f.read()
                rp = stat.rfind(")")
                lp = stat.find("(")
                if lp == -1 or rp == -1:
                    continue
                comm = stat[lp + 1:rp].lower()
                ppid = int(stat[rp + 2:].split()[1])
                children.setdefault(ppid, []).append(pid)
                cmdline = ""
                try:
                    with open(f"/proc/{pid}/cmdline", "rb") as cf:
                        raw = cf.read(256)
                    cmdline = raw.replace(b"\x00", b" ").decode("utf-8", "ignore").lower()
                except Exception:
                    pass
                cmdinfo[pid] = f"{comm} {cmdline}".strip()
            except Exception:
                continue
    except Exception:
        pass
    return children, cmdinfo


def descendant_text(root_pid, children, cmdinfo):
    texts = []
    stack = [root_pid]
    seen = set()
    while stack:
        p = stack.pop()
        if p in seen:
            continue
        seen.add(p)
        if p in cmdinfo:
            texts.append(cmdinfo[p])
        stack.extend(children.get(p, ()))
    return "\n".join(texts)


def is_terminal_client(c):
    cls = (c.get("class") or "").lower()
    init_cls = (c.get("initialClass") or "").lower()
    return cls in TERMINAL_CLASSES or init_cls in TERMINAL_CLASSES


def extract_tokens(app_name, desktop_entry):
    tokens = []
    for raw in (desktop_entry, app_name):
        s = (raw or "").strip().lower().removesuffix(".desktop")
        if not s:
            continue
        tokens.append(s)
        if s in APP_ALIASES:
            tokens.extend(APP_ALIASES[s])
        for part in re.split(r"[\s._:/-]+", s):
            if len(part) >= 2 and part not in ("com", "org", "net", "app", "desktop", "the"):
                tokens.append(part)
    seen = set()
    out = []
    for t in tokens:
        if t and t not in seen:
            seen.add(t)
            out.append(t)
    return out


def is_cli_hint(app_name, desktop_entry, summary, body):
    low_app = (app_name or "").strip().lower()
    low_de = (desktop_entry or "").strip().lower().removesuffix(".desktop")
    if low_app in CLI_APP_HINTS or low_de in CLI_APP_HINTS:
        return True
    for tok in re.split(r"[\s._:/-]+", f"{low_app} {low_de}"):
        if tok in CLI_APP_HINTS:
            return True
    # OpenCode often titles notifications with "OC" or "OpenCode"
    low_sum = (summary or "").strip().lower()
    if low_sum.startswith("oc ") or low_sum.startswith("oc|") or "opencode" in low_sum or "claude code" in low_sum:
        return True
    return False


def title_overlap_score(title, summary, body, app_name):
    t = (title or "").lower()
    if not t:
        return 0
    bonus = 0
    for field, weight in ((app_name, 30), (summary, 28), (body, 14)):
        clean = re.sub(r"\s+", " ", (field or "").strip()).lower()
        if len(clean) >= 3 and clean[:24] in t:
            bonus += weight
            continue
        words = [w for w in re.split(r"\W+", clean) if len(w) >= 3][:4]
        matches = sum(1 for w in words if w in t)
        if matches:
            bonus += min(weight, matches * 10)
    # Special boost: OpenCode notifications -> Kitty window titled "OC | ..."
    low_all = f"{app_name} {summary} {body}".lower()
    if ("opencode" in low_all or re.search(r"\boc\b", low_all)) and ("oc |" in t or "opencode" in t):
        bonus += 55
    return bonus


def score_client(c, target_pid, tokens, cli_mode, app_name, summary, body, term_procs):
    cls = (c.get("class") or "").lower()
    init_cls = (c.get("initialClass") or "").lower()
    title = (c.get("title") or "").lower()
    ws_name = (c.get("workspace") or {}).get("name") or ""
    cpid = c.get("pid") or 0

    score = 0
    if target_pid and cpid == target_pid:
        score += 200

    # Exact / alias class match
    for t in tokens:
        if t == cls or t == init_cls:
            score += 110
            break
    if score == 0:
        for t in tokens:
            if len(t) >= 3 and (t in cls or t in init_cls):
                score += 75
                break

    # Terminal / CLI dynamic process tree match (catches ANY CLI app running inside kitty!)
    if is_terminal_client(c):
        if cli_mode:
            score += 95
        proc_blob = term_procs.get(cpid, "")
        if proc_blob:
            for t in tokens:
                if len(t) >= 2 and re.search(rf"(?:^|[\s/]){re.escape(t)}(?:$|[\s.])", proc_blob):
                    score += 85
                    break

    # Fallback partial title match when no class/terminal match yet
    if score == 0:
        for t in tokens:
            if len(t) >= 4 and t in title:
                score += 45
                break

    if score == 0:
        return 0

    score += title_overlap_score(title, summary, body, app_name)

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
    app_name = sys.argv[1] if len(sys.argv) > 1 else ""
    desktop_entry = sys.argv[2] if len(sys.argv) > 2 else ""
    summary = sys.argv[3] if len(sys.argv) > 3 else ""
    body = sys.argv[4] if len(sys.argv) > 4 else ""
    pid_raw = sys.argv[5] if len(sys.argv) > 5 else ""
    target_pid = int(pid_raw) if pid_raw.isdigit() else 0

    clients = hypr_clients()
    if not clients:
        sys.exit(1)

    tokens = extract_tokens(app_name, desktop_entry)
    cli_mode = is_cli_hint(app_name, desktop_entry, summary, body)

    term_procs = {}
    term_clients = [c for c in clients if is_terminal_client(c) and c.get("pid")]
    if term_clients:
        children, cmdinfo = build_proc_tree()
        for tc in term_clients:
            term_procs[tc["pid"]] = descendant_text(tc["pid"], children, cmdinfo)

    best = None
    best_score = 0
    for c in clients:
        sc = score_client(c, target_pid, tokens, cli_mode, app_name, summary, body, term_procs)
        if sc > best_score:
            best_score = sc
            best = c

    if best and best_score > 0:
        focus_client(best)
        sys.exit(0)
    sys.exit(1)


if __name__ == "__main__":
    main()
