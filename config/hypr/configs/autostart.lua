hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})

local HOME_DIR = os.getenv("HOME") or ""

-- Shell chosen by the installer (marker: ~/.config/hypr/.revo_default_shell).
-- nil → no explicit choice, fall back to the legacy shells further down.
local function read_default_shell()
    local ok, fh = pcall(io.open, HOME_DIR .. "/.config/hypr/.revo_default_shell", "r")
    if not ok or not fh then
        return nil
    end
    local id = (fh:read("*l") or ""):match("^%s*(.-)%s*$")
    fh:close()
    if id == "" or id == "default" then
        return nil
    end
    return id
end

hl.on("hyprland.start", function()
    local shell = read_default_shell()

    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    -- Requerido por ZapFast (org.freedesktop.secrets)
    hl.exec_cmd("/usr/bin/ksecretd")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("awww-daemon")

    -- selected shell (installer marker) vs. the legacy rice shells
    if shell then
        hl.exec_cmd("bash " .. HOME_DIR .. "/.config/hypr/scripts/toggle_qs_dots.sh " .. shell .. " &")
    else
        hl.exec_cmd("quickshell -p ~/.config/hypr/scripts/quickshell/Main.qml")
        hl.exec_cmd("quickshell -p ~/.config/hypr/scripts/quickshell/TopBar.qml")
    end

    hl.exec_cmd("hyprctl setcursor QingyiBLZ 24")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'QingyiBLZ'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")

    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    -- Hypr3D se activa solo con SUPER + F12 (antes se togglebaba aqui y rompia las ventanas)

    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-desktop-portal")
end)
