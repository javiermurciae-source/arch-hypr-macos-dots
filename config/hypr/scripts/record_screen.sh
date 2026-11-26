#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-screen}" # screen | region
STATE_FILE="$HOME/.cache/gsr_current_file"
START_TS_FILE="$HOME/.cache/gsr_start_ts"
LAST_SAVED_FILE="$HOME/.cache/gsr_last_saved"
LOG_FILE="$HOME/.cache/gsr_last.log"

if ! command -v gpu-screen-recorder >/dev/null 2>&1; then
    notify-send -a "Screen Recorder" "gpu-screen-recorder no instalado" "Instálalo con: sudo pacman -S gpu-screen-recorder" -t 5000
    exit 1
fi

# Helper: "gpu-screen-recorder" tiene 19 caracteres (>15 limite de /proc/*/comm),
# así que usamos pidof (o comm truncado gpu-screen-reco) en lugar de pgrep -x.
find_gsr_pid() {
    pidof -s gpu-screen-recorder 2>/dev/null || pgrep -x gpu-screen-reco 2>/dev/null | head -n1 || true
}

# ── SI YA ESTÁ GRABANDO: DETENER Y GUARDAR LIMPIAMENTE ──────────
EXISTING_PID="$(find_gsr_pid)"
if [[ -n "$EXISTING_PID" ]]; then
    OUT_FILE="$(cat "$STATE_FILE" 2>/dev/null || true)"
    if [[ -n "$OUT_FILE" ]]; then
        echo "$OUT_FILE" > "$LAST_SAVED_FILE"
    fi
    kill -SIGINT "$EXISTING_PID" 2>/dev/null || true

    # Esperar hasta que cierre el archivo MP4 limpiamente
    for _ in $(seq 1 40); do
        kill -0 "$EXISTING_PID" 2>/dev/null || break
        sleep 0.15
    done
    rm -f "$STATE_FILE" "$START_TS_FILE"

    if [[ -n "$OUT_FILE" && -s "$OUT_FILE" ]]; then
        echo "$OUT_FILE" > "$LAST_SAVED_FILE"
    fi
    exit 0
fi

# ── INICIAR NUEVA GRABACIÓN ─────────────────────────────────────
VID_DIR="$(xdg-user-dir VIDEOS 2>/dev/null || true)"
if [[ -z "$VID_DIR" || "$VID_DIR" == "$HOME" ]]; then
    VID_DIR="$HOME/Videos"
fi
SAVE_DIR="$VID_DIR/Grabaciones"
mkdir -p "$SAVE_DIR"

OUT_FILE="$SAVE_DIR/Grabacion_$(date +'%Y-%m-%d_%H-%M-%S').mp4"

TARGET_ARGS=()
LABEL="Pantalla completa"

if [[ "$MODE" == "region" ]]; then
    if pgrep -x slurp >/dev/null 2>&1; then
        exit 0
    fi
    REG="$(slurp -d -b 00000077 -c ff3b30ff -s ff3b3018 -w 2 -f '%wx%h+%x+%y' 2>/dev/null || true)"
    [[ -z "$REG" ]] && exit 0
    TARGET_ARGS=(-w region -region "$REG")
    LABEL="Región"
else
    MON="$(hyprctl -j monitors 2>/dev/null | jq -r 'first(.[] | select(.focused == true)) | .name' || true)"
    TARGET_ARGS=(-w "${MON:-screen}")
fi

echo "$OUT_FILE" > "$STATE_FILE"
echo "$OUT_FILE" > "$LAST_SAVED_FILE"
date +%s > "$START_TS_FILE"
: > "$LOG_FILE"

# Grabar a 60fps, solo audio del sistema (sin micrófono).
# eDP-1 va conectado a la iGPU Intel (card1): forzamos LIBVA_DRIVER_NAME=iHD para
# evitar que LIBVA_DRIVER_NAME=nvidia de env.lua rompa VA-API, con respaldo en CPU
# si aún no está instalado intel-media-driver.
setsid -f env -u __GLX_VENDOR_LIBRARY_NAME LIBVA_DRIVER_NAME=iHD \
    gpu-screen-recorder \
    "${TARGET_ARGS[@]}" \
    -f 60 \
    -q very_high \
    -k auto \
    -fallback-cpu-encoding yes \
    -a "default_output" \
    -o "$OUT_FILE" >"$LOG_FILE" 2>&1

sleep 0.6
if [[ -z "$(find_gsr_pid)" ]]; then
    rm -f "$STATE_FILE" "$START_TS_FILE"
    ERR="$(tail -n 3 "$LOG_FILE" 2>/dev/null | tr '\n' ' ' | cut -c1-140)"
    notify-send -a "Screen Recorder" "Error al iniciar grabación" "${ERR:-Revisa ~/.cache/gsr_last.log}" -t 5000
    exit 1
fi
