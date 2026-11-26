#!/usr/bin/env bash
# Revo Shell: lanza una barra Quickshell legacy SOLO si no hay un shell elegido.
# Uso: qs_legacy_guard.sh <ruta-al-qml> [args...]
SEL="$(tr -d '[:space:]' < "$HOME/.config/hypr/.revo_default_shell" 2>/dev/null)"
if [ -n "$SEL" ] && [ "$SEL" != "default" ]; then
    exit 0
fi
exec quickshell -p "$@"
