#!/usr/bin/env bash
# ==============================================================================
# Arch Linux + Hyprland (Lua) + Quickshell macOS Minimal Autoinstaller
# Idempotent, modular, safe (backs up existing ~/.config before touching files).
# ==============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)"

SKIP_CACHYOS=false
SKIP_PKGS=false
SKIP_AUR=false
SKIP_SYSTEM=false
DRY_RUN=false

usage() {
    cat <<EOF
Uso: ./install.sh [opciones]

Opciones:
  --skip-cachyos   No agregar los repositorios optimizados de CachyOS (x86-64-v3)
  --skip-pkgs      Omitir instalación de paquetes oficiales (pacman)
  --skip-aur       Omitir instalación de paquetes AUR (yay)
  --skip-system    Omitir cambios en /etc (SDDM Wayland, ZRAM, /etc/environment)
  --dotfiles-only  Equivalente a --skip-cachyos --skip-pkgs --skip-aur --skip-system
  --dry-run        Muestra qué pasos se ejecutarían sin modificar nada
  -h, --help       Muestra esta ayuda
EOF
}

for arg in "$@"; do
    case "$arg" in
        --skip-cachyos) SKIP_CACHYOS=true ;;
        --skip-pkgs)    SKIP_PKGS=true ;;
        --skip-aur)     SKIP_AUR=true ;;
        --skip-system)  SKIP_SYSTEM=true ;;
        --dotfiles-only)
            SKIP_CACHYOS=true; SKIP_PKGS=true; SKIP_AUR=true; SKIP_SYSTEM=true ;;
        --dry-run)      DRY_RUN=true ;;
        -h|--help)      usage; exit 0 ;;
        *)              echo "Opción desconocida: $arg"; usage; exit 1 ;;
    esac
done

if [ "$EUID" -eq 0 ]; then
    echo "[ERROR] No ejecutes este script como root; se pedirá sudo solo cuando haga falta."
    exit 1
fi

c_ok="\033[1;32m==>\033[0m"
c_info="\033[1;36m  ->\033[0m"
c_warn="\033[1;33m[WARN]\033[0m"

log()  { printf "%b %s\n" "$c_ok" "$*"; }
info() { printf "%b %s\n" "$c_info" "$*"; }
warn() { printf "%b %s\n" "$c_warn" "$*"; }

run_cmd() {
    if $DRY_RUN; then
        printf "  [dry-run] %s\n" "$*"
    else
        eval "$@"
    fi
}

read_pkg_list() {
    grep -vE '^\s*(#|$)' "$1" | tr '\n' ' '
}

# ------------------------------------------------------------------------------
# 1. Repositorios CachyOS x86-64-v3 (opcional, solo si la CPU los soporta)
# ------------------------------------------------------------------------------
setup_cachyos_repos() {
    $SKIP_CACHYOS && { info "Omitiendo repos CachyOS (--skip-cachyos)"; return; }
    if grep -q '^\[cachyos-v3\]' /etc/pacman.conf 2>/dev/null; then
        info "Repositorios CachyOS ya configurados en /etc/pacman.conf"
        return
    fi
    if ! /lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q 'x86-64-v3 (supported, searched)'; then
        warn "Esta CPU no reporta soporte x86-64-v3; omitiendo repos CachyOS."
        return
    fi
    log "Configurando repositorios CachyOS (x86-64-v3)..."
    if $DRY_RUN; then
        info "[dry-run] Descargaría e instalaría cachyos-repo.tar.xz"
        return
    fi
    local tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN
    curl -fsSL https://mirror.cachyos.org/cachyos-repo.tar.xz -o "$tmp/cachyos-repo.tar.xz"
    tar -xf "$tmp/cachyos-repo.tar.xz" -C "$tmp"
    sudo pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key F3B607488DB35A47
    local mirror="https://mirror.cachyos.org/repo/x86_64/cachyos"
    sudo pacman -U --noconfirm \
        "${mirror}/cachyos-keyring-20240331-1-any.pkg.tar.zst" \
        "${mirror}/cachyos-mirrorlist-27-1-any.pkg.tar.zst" \
        "${mirror}/cachyos-v3-mirrorlist-27-1-any.pkg.tar.zst" \
        "${mirror}/cachyos-v4-mirrorlist-27-1-any.pkg.tar.zst"
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak
    sudo gawk -i inplace -f "$tmp/cachyos-repo/install-repo.awk" /etc/pacman.conf || true
    sudo pacman -Sy
}

# ------------------------------------------------------------------------------
# 2. Paquetes oficiales + AUR
# ------------------------------------------------------------------------------
install_packages() {
    if ! $SKIP_PKGS; then
        log "Instalando paquetes oficiales (pacman)..."
        local pkgs
        pkgs="$(read_pkg_list "$REPO_DIR/packages/official.txt")"
        run_cmd "sudo pacman -S --needed --noconfirm $pkgs"
    else
        info "Omitiendo paquetes oficiales (--skip-pkgs)"
    fi

    if ! $SKIP_AUR; then
        # Instalar makepkg.conf rápido antes de compilar paquetes AUR
        mkdir -p "$HOME/.config/pacman"
        if ! $DRY_RUN && [ -f "$REPO_DIR/config/pacman/makepkg.conf" ]; then
            cp -a "$REPO_DIR/config/pacman/makepkg.conf" "$HOME/.config/pacman/makepkg.conf"
        fi

        if ! command -v yay >/dev/null 2>&1; then
            log "Instalando yay-bin desde AUR..."
            if ! $DRY_RUN; then
                local tmp_yay
                tmp_yay=$(mktemp -d)
                git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp_yay/yay-bin"
                (cd "$tmp_yay/yay-bin" && makepkg -si --noconfirm)
                rm -rf "$tmp_yay"
            fi
        fi

        log "Instalando paquetes AUR (yay)..."
        local aur_pkgs
        aur_pkgs="$(read_pkg_list "$REPO_DIR/packages/aur.txt")"
        run_cmd "yay -S --needed --noconfirm --answerdiff None --answerclean None $aur_pkgs"
    else
        info "Omitiendo paquetes AUR (--skip-aur)"
    fi
}

# ------------------------------------------------------------------------------
# 3. Despliegue de dotfiles (con backup + expansión __USER_HOME__ -> $HOME)
# ------------------------------------------------------------------------------
deploy_dotfiles() {
    log "Desplegando dotfiles en ~/.config (backup previo en $BACKUP_DIR)..."
    if $DRY_RUN; then
        info "[dry-run] Copiaría config/* -> $HOME/.config/ y expandiría __USER_HOME__ -> $HOME"
        return
    fi

    mkdir -p "$HOME/.config" "$HOME/Pictures/Wallpapers" "$HOME/.local/share/TelegramDesktop"

    # Backup de carpetas existentes antes de sobrescribir
    local backed_up=false
    for item in "$REPO_DIR/config"/*; do
        local name
        name="$(basename "$item")"
        if [ -e "$HOME/.config/$name" ]; then
            mkdir -p "$BACKUP_DIR"
            cp -a "$HOME/.config/$name" "$BACKUP_DIR/"
            backed_up=true
        fi
    done
    $backed_up && info "Backup guardado en $BACKUP_DIR"

    # Copiar configuraciones preservando symlinks relativos (macos -> eqsh)
    for item in "$REPO_DIR/config"/*; do
        local name
        name="$(basename "$item")"
        if [ "$name" = "zapfast" ] || [ "$name" = "YouTube Music" ]; then
            mkdir -p "$HOME/.config/$name"
            cp -a "$item/." "$HOME/.config/$name/"
        else
            rm -rf "$HOME/.config/$name"
            cp -a "$item" "$HOME/.config/$name"
        fi
    done

    # Expandir __USER_HOME__ al $HOME real de esta máquina
    python3 - "$HOME/.config" "$HOME" << 'PYEOF'
import os, sys
base, home = sys.argv[1], sys.argv[2]
count = 0
for dirpath, _, files in os.walk(base):
    for fn in files:
        p = os.path.join(dirpath, fn)
        if os.path.islink(p):
            continue
        if not fn.endswith((".qml", ".js", ".lua", ".sh", ".py", ".json", ".conf", ".css", ".fish")):
            continue
        try:
            txt = open(p, "r", encoding="utf-8").read()
            if "__USER_HOME__" in txt:
                open(p, "w", encoding="utf-8").write(txt.replace("__USER_HOME__", home))
                count += 1
        except Exception:
            pass
print(f"  -> Rutas adaptadas a {home} en {count} archivos")
PYEOF

    # Permisos de ejecución en scripts de Hyprland y Quickshell
    find "$HOME/.config/hypr/scripts" "$HOME/.config/quickshell/macos" \
        -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} + 2>/dev/null || true

    # Tema Obsidian Glass de Telegram + Wallpaper por defecto
    [ -f "$REPO_DIR/themes/telegram/Obsidian-Glass.tdesktop-theme" ] && \
        cp -a "$REPO_DIR/themes/telegram/Obsidian-Glass.tdesktop-theme" "$HOME/.local/share/TelegramDesktop/"
    [ -f "$REPO_DIR/wallpapers/abstract.jpg" ] && \
        cp -a "$REPO_DIR/wallpapers/abstract.jpg" "$HOME/Pictures/Wallpapers/"

    # Auto-detectar nodo real /dev/dri/cardN de la iGPU Intel (sin ':' para Aquamarine)
    local igpu_node=""
    igpu_node="$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-card 2>/dev/null || true)"
    if [[ "$igpu_node" =~ ^/dev/dri/card[0-9]+$ ]] && [ -f "$HOME/.config/environment.d/10-igpu.conf" ]; then
        sed -i "s#^AQ_DRM_DEVICES=.*#AQ_DRM_DEVICES=${igpu_node}#" "$HOME/.config/environment.d/10-igpu.conf"
        info "iGPU Intel detectada en $igpu_node (actualizado 10-igpu.conf)"
    fi

    fc-cache -f 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# 4. Ajustes del sistema (/etc: SDDM Wayland + MacSDDM, ZRAM, iGPU, servicios)
# ------------------------------------------------------------------------------
configure_system() {
    $SKIP_SYSTEM && { info "Omitiendo configuración de sistema (--skip-system)"; return; }
    log "Configurando SDDM Wayland (MacSDDM), ZRAM y servicios..."
    if $DRY_RUN; then
        info "[dry-run] Instalaría MacSDDM, /etc/sddm.conf.d/, zram-generator.conf y habilitaría servicios"
        return
    fi

    sudo mkdir -p /etc/sddm.conf.d /usr/share/sddm/themes
    [ -d "$REPO_DIR/themes/sddm/MacSDDM" ] && \
        sudo cp -a "$REPO_DIR/themes/sddm/MacSDDM" /usr/share/sddm/themes/
    sudo cp -a "$REPO_DIR/system/sddm/"*.conf /etc/sddm.conf.d/
    sudo cp -a "$REPO_DIR/system/systemd/zram-generator.conf" /etc/systemd/zram-generator.conf

    # Fijar AQ_DRM_DEVICES solo si existe una iGPU Intel en 0000:00:02.0 (siempre nodo /dev/dri/cardN, nunca by-path)
    local igpu_node=""
    igpu_node="$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-card 2>/dev/null || true)"
    if [[ "$igpu_node" =~ ^/dev/dri/card[0-9]+$ ]]; then
        if grep -q '^AQ_DRM_DEVICES=' /etc/environment 2>/dev/null; then
            sudo sed -i "s#^AQ_DRM_DEVICES=.*#AQ_DRM_DEVICES=${igpu_node}#" /etc/environment
        else
            echo "AQ_DRM_DEVICES=${igpu_node}" | sudo tee -a /etc/environment >/dev/null
        fi
        info "/etc/environment actualizado con AQ_DRM_DEVICES=${igpu_node}"
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable sddm NetworkManager bluetooth upower 2>/dev/null || true
    sudo systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
    systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
}

main() {
    log "Iniciando autoinstall de Arch + Hyprland + Quickshell macOS Minimal"
    setup_cachyos_repos
    install_packages
    deploy_dotfiles
    configure_system
    log "¡Instalación completada!"
    info "Reinicia para activar SDDM Wayland (MacSDDM), ZRAM y la sesión Hyprland."
    info "En ZapFast selecciona el tema 'Obsidian Glass' y en Telegram abre ~/.local/share/TelegramDesktop/Obsidian-Glass.tdesktop-theme."
}

main
