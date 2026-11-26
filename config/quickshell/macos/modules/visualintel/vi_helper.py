#!/usr/bin/env python3
"""Backend helper for macOS-style Visual Intelligence (Shift + Super + 6).

Commands:
  capture <nx> <ny> <nw> <nh> <out_png>   Capture normalized region via grim
  lens <image_path>                        Google Lens reverse image search (local HTML POST -> Firefox)
  ask <image_path> <prompt...>             Ask agy -p (Gemini 3.8 Flash Low) about the cropped image
  ocr <image_path>                         Extract text (tesseract if available, else agy -p) + wl-copy
  quick_url <image_path>                   Fast URL detection if tesseract is installed
"""
import base64, json, os, re, shutil, subprocess, sys, tempfile, time

HOME = os.path.expanduser("~")
AGY_BIN = os.path.join(HOME, ".local/bin/agy")
MINIMIZE_SCRIPT = os.path.join(HOME, ".config/hypr/scripts/minimize_window.py")
MODEL = "Gemini 3.8 Flash (Low)"


def focus_firefox_for_lens(existing_addrs):
    """Switch to the Firefox workspace and focus the window receiving Google Lens."""
    def get_firefox_clients():
        try:
            cs = json.loads(subprocess.check_output(["hyprctl", "-j", "clients"], text=True, timeout=3))
        except Exception:
            return []
        return [
            c for c in cs
            if "firefox" in (c.get("class") or "").lower()
            or "firefox" in (c.get("initialClass") or "").lower()
        ]

    target = None
    deadline = time.monotonic() + 2.6
    while time.monotonic() < deadline:
        fcs = get_firefox_clients()
        if fcs:
            # 1. Exact window showing Google Lens tab
            lens_win = next(
                (c for c in fcs if "lens" in (c.get("title") or "").lower()),
                None,
            )
            if lens_win:
                target = lens_win
                break
            # 2. Brand new Firefox window spawned by this launch
            new_win = next((c for c in fcs if c.get("address") not in existing_addrs), None)
            if new_win:
                target = new_win
                break
            # 3. Existing Firefox window (after a brief grace window for tab title update)
            if time.monotonic() > deadline - 2.0:
                visible = [c for c in fcs if (c.get("workspace") or {}).get("name") != "special:minimized"]
                pool = visible if visible else fcs
                target = min(pool, key=lambda c: c.get("focusHistoryID", 999))
                break
        time.sleep(0.12)

    if not target:
        return
    addr = target.get("address")
    ws = target.get("workspace") or {}
    ws_name = ws.get("name") or ""
    ws_id = ws.get("id")
    if ws_name == "special:minimized" and os.path.isfile(MINIMIZE_SCRIPT):
        subprocess.Popen(
            ["python3", MINIMIZE_SCRIPT, "restore", addr],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return
    if isinstance(ws_id, int) and ws_id > 0:
        lua = (
            f'hl.dispatch(hl.dsp.focus({{ workspace = {ws_id} }})); '
            f'hl.dispatch(hl.dsp.focus({{ window = "address:{addr}" }}))'
        )
    else:
        lua = f'hl.dispatch(hl.dsp.focus({{ window = "address:{addr}" }}))'
    subprocess.run(["hyprctl", "eval", lua], capture_output=True, text=True, timeout=3)


def cmd_capture(args):
    nx, ny, nw, nh = [float(x) for x in args[:4]]
    out_png = args[4]
    monitors = json.loads(subprocess.check_output(["hyprctl", "-j", "monitors"]))
    mon = next((m for m in monitors if m.get("focused")), monitors[0])
    sc = mon.get("scale", 1.0) or 1.0
    lw = mon["width"] / sc
    lh = mon["height"] / sc
    if mon.get("transform", 0) % 2 == 1:
        lw, lh = lh, lw
    x = int(round(mon["x"] + nx * lw))
    y = int(round(mon["y"] + ny * lh))
    w = max(4, int(round(nw * lw)))
    h = max(4, int(round(nh * lh)))
    geom = f"{x},{y} {w}x{h}"
    subprocess.run(["grim", "-g", geom, out_png], check=True)
    print(out_png)


def cmd_lens(args):
    img_path = args[0]
    if not os.path.isfile(img_path):
        sys.exit(1)
    tmp_jpg = tempfile.mktemp(suffix=".jpg", prefix="vi_lens_")
    tmp_html = tempfile.mktemp(suffix=".html", prefix="vi_lens_")
    try:
        if shutil.which("magick"):
            subprocess.run(
                ["magick", img_path, "-resize", "1000x1000>", "-quality", "88", tmp_jpg],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
            src = tmp_jpg
            mime = "image/jpeg"
        else:
            src = img_path
            mime = "image/png"
        with open(src, "rb") as f:
            b64 = base64.b64encode(f.read()).decode("ascii")
        html = f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Google Lens...</title></head>
<body style="background:#111;color:#eee;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
<p>Buscando imagen en Google Lens…</p>
<form id="f" method="POST" action="https://lens.google.com/v3/upload" enctype="multipart/form-data">
  <input type="hidden" name="encoded_image" value="{b64}">
  <input type="hidden" name="image_content" value="">
</form>
<script>
(async () => {{
  try {{
    const res = await fetch("data:{mime};base64,{b64}");
    const blob = await res.blob();
    const dt = new DataTransfer();
    dt.items.add(new File([blob], "capture.jpg", {{ type: "{mime}" }}));
    const form = document.createElement("form");
    form.method = "POST";
    form.action = "https://lens.google.com/v3/upload";
    form.enctype = "multipart/form-data";
    const inp = document.createElement("input");
    inp.type = "file";
    inp.name = "encoded_image";
    inp.files = dt.files;
    form.appendChild(inp);
    document.body.appendChild(form);
    form.submit();
  }} catch (e) {{
    document.getElementById("f").submit();
  }}
}})();
</script>
</body></html>"""
        with open(tmp_html, "w", encoding="utf-8") as f:
            f.write(html)
        try:
            existing_addrs = {
                c.get("address")
                for c in json.loads(subprocess.check_output(["hyprctl", "-j", "clients"], text=True, timeout=3))
                if "firefox" in (c.get("class") or "").lower()
            }
        except Exception:
            existing_addrs = set()
        subprocess.Popen(["setsid", "-f", "firefox", f"file://{tmp_html}"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        focus_firefox_for_lens(existing_addrs)
        subprocess.Popen(
            ["setsid", "-f", "sh", "-c", f"sleep 15; rm -f '{tmp_html}' '{tmp_jpg}'"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
    except Exception as e:
        print(f"Error Google Lens: {e}", file=sys.stderr)
        sys.exit(1)


def run_agy(img_path, prompt_text):
    if not os.path.exists(AGY_BIN):
        print(f"Error: no se encontró {AGY_BIN}")
        sys.exit(1)
    full_prompt = (
        f"Analiza la imagen en {img_path} usando tu herramienta para leer archivos. "
        f"Responde en español de forma clara, directa y concisa (usa Markdown limpio si ayuda).\n\n"
        f"Solicitud del usuario: {prompt_text}"
    )
    cmd = [
        AGY_BIN, "-p", full_prompt,
        "--output-format", "text",
        "--disable-slash-commands",
        "--dangerously-skip-permissions",
        "--model", MODEL,
    ]
    env = os.environ.copy()
    env["PATH"] = os.path.join(HOME, ".local/bin") + ":" + env.get("PATH", "")
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)
    out_chunks = []
    assert proc.stdout is not None
    for line in proc.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
        out_chunks.append(line)
    proc.wait()
    return "".join(out_chunks).strip()


def cmd_ask(args):
    img_path = args[0]
    question = " ".join(args[1:]).strip() or "Explica de forma breve y clara qué aparece en esta imagen."
    run_agy(img_path, question)


def cmd_ocr(args):
    img_path = args[0]
    text = ""
    if shutil.which("tesseract"):
        r = subprocess.run(["tesseract", img_path, "-", "-l", "spa+eng"],
                           capture_output=True, text=True)
        text = r.stdout.strip()
    if not text:
        text = run_agy(
            img_path,
            "Extrae y devuelve ÚNICAMENTE el texto exacto visible en la imagen, sin explicaciones ni comentarios extra."
        )
    if text:
        subprocess.run(["wl-copy"], input=text, text=True)
        if shutil.which("tesseract"):
            print(text)


def cmd_quick_url(args):
    img_path = args[0]
    if not shutil.which("tesseract"):
        return
    r = subprocess.run(["tesseract", img_path, "-", "-l", "eng+spa"],
                       capture_output=True, text=True)
    m = re.search(r'(https?://[^\s]+|[a-zA-Z0-9-]+\.(?:com|org|net|io|dev|ai|co|es|app|gg|tv)(?:/[^\s]*)?)', r.stdout)
    if m:
        print(m.group(1).rstrip(".,);:\"'"))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(1)
    sub = sys.argv[1]
    if sub == "capture":
        cmd_capture(sys.argv[2:])
    elif sub == "lens":
        cmd_lens(sys.argv[2:])
    elif sub == "ask":
        cmd_ask(sys.argv[2:])
    elif sub == "ocr":
        cmd_ocr(sys.argv[2:])
    elif sub == "quick_url":
        cmd_quick_url(sys.argv[2:])
