hl.env("XCURSOR_THEME", "QingyiBLZ")
hl.env("XCURSOR_SIZE", 24)
hl.env("HYPRCURSOR_SIZE", 24)
hl.env("HYPRCURSOR_THEME", "QingyiBLZ")
hl.env("PATH", (os.getenv("HOME") or "") .. "/.local/bin:" .. os.getenv("PATH"))
-- Usar Intel Iris Xe por defecto para ahorrar bateria (RTX 3050 duerme en D3cold; usar prime-run para juegos)
-- AQ_DRM_DEVICES se separa con ':' y el symlink by-path contiene ':' (pci-0000:00:02.0-card),
-- por eso aquamarine no encontraba GPU y Hyprland abortaba con "CBackend::create() failed!".
-- Resolvemos el symlink de la iGPU a su nodo real (sin ':'), así funciona aunque cambie cardN.
local igpu = "/dev/dri/card1"
local popen = io and io.popen
if popen then
    local okp, f = pcall(popen, "readlink -f /dev/dri/by-path/pci-0000:00:02.0-card 2>/dev/null")
    if okp and f then
        local real = f:read("*l")
        f:close()
        if real and real:match("^/dev/dri/card%d+$") then
            igpu = real
        end
    end
end
hl.env("AQ_DRM_DEVICES", igpu)
hl.env("LIBVA_DRIVER_NAME", "iHD")
hl.env("OMARCHY_LOOKING_GLASS", 1)
hl.env("IVSHMEM_KEY", "omarchy-win-vm")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("SCREENSHOT_PROVIDER", "ext-image-copy-capture-v1")
-- Render Qt a 4/3; con scale 0.75 en el monitor queda 1:1 y mas compacto/nitido
hl.env("QT_SCALE_FACTOR", "1.333")
hl.env("WEBRTC_FORCE_HW_CODEC", "1")
-- Temas inexistentes (MacTahoe-*) forzaban el modo claro en GTK; usamos los de Adwaita
hl.env("GTK_THEME", "Adwaita-dark")
hl.env("QS_ICON_THEME", "Adwaita")
