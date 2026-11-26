#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-region}"

# Evitar lanzar dos selectores a la vez si se pulsa Print dos veces
if pgrep -x slurp >/dev/null 2>&1; then
    exit 0
fi

PIC_DIR="$(xdg-user-dir PICTURES 2>/dev/null || true)"
if [[ -z "$PIC_DIR" || "$PIC_DIR" == "$HOME" ]]; then
    PIC_DIR="$HOME/Pictures"
fi
mkdir -p "$PIC_DIR"

FILENAME="$(date +'%Y-%m-%d-%H%M%S_hyprshot.png')"
OUT="$PIC_DIR/$FILENAME"

SLURP_OPTS=(-d -b 00000077 -c 5e9cffff -s 5e9cff18 -w 2)

notify_saved() {
    local file="$1"
    local label="$2"
    notify-send -a "Screenshot" -i "$file" "Captura guardada ($label)" "Copiada al portapapeles · $(basename "$file")" -t 3000
}

case "$MODE" in
    region)
        GEOM="$(slurp "${SLURP_OPTS[@]}" 2>/dev/null || true)"
        [[ -z "$GEOM" ]] && exit 0
        grim -g "$GEOM" "$OUT"
        wl-copy --type image/png < "$OUT"
        notify_saved "$OUT" "Región"
        ;;

    edit)
        GEOM="$(slurp "${SLURP_OPTS[@]}" 2>/dev/null || true)"
        [[ -z "$GEOM" ]] && exit 0
        grim -g "$GEOM" - | swappy -f - -o "$OUT"
        if [[ -s "$OUT" ]]; then
            wl-copy --type image/png < "$OUT"
            notify_saved "$OUT" "Editada"
        fi
        ;;

    output)
        MON="$(hyprctl -j monitors | jq -r 'first(.[] | select(.focused == true)) | .name')"
        if [[ -n "$MON" ]]; then
            grim -o "$MON" "$OUT"
        else
            grim "$OUT"
        fi
        wl-copy --type image/png < "$OUT"
        notify_saved "$OUT" "Pantalla completa"
        ;;

    window)
        BOXES="$(python3 - <<'PY'
import json, subprocess
monitors = json.loads(subprocess.check_output(["hyprctl", "-j", "monitors"]))
clients = json.loads(subprocess.check_output(["hyprctl", "-j", "clients"]))
active_ws = {m["activeWorkspace"]["id"] for m in monitors}
bounds = []
for m in monitors:
    sc = m.get("scale", 1.0) or 1.0
    w = m["width"] / sc
    h = m["height"] / sc
    if m.get("transform", 0) % 2 == 1:
        w, h = h, w
    bounds.append((m["x"], m["y"], m["x"] + w, m["y"] + h))

min_x = min(b[0] for b in bounds)
min_y = min(b[1] for b in bounds)
max_x = max(b[2] for b in bounds)
max_y = max(b[3] for b in bounds)

for c in clients:
    if c.get("hidden") or not c.get("mapped"):
        continue
    if c.get("workspace", {}).get("id") not in active_ws:
        continue
    x, y = c["at"]
    w, h = c["size"]
    x1 = max(min_x, x)
    y1 = max(min_y, y)
    x2 = min(max_x, x + w)
    y2 = min(max_y, y + h)
    cw, ch = int(round(x2 - x1)), int(round(y2 - y1))
    if cw > 1 and ch > 1:
        print(f"{int(round(x1))},{int(round(y1))} {cw}x{ch}")
PY
)"
        [[ -z "$BOXES" ]] && exit 0
        GEOM="$(slurp -r "${SLURP_OPTS[@]}" <<< "$BOXES" 2>/dev/null || true)"
        [[ -z "$GEOM" ]] && exit 0
        grim -g "$GEOM" "$OUT"
        wl-copy --type image/png < "$OUT"
        notify_saved "$OUT" "Ventana"
        ;;

    *)
        echo "Uso: $0 {region|output|window|edit}" >&2
        exit 1
        ;;
esac
