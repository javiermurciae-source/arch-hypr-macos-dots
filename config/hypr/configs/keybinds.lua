local terminal = "kitty"
local fileManager = "nautilus"
local clipboard = "cliphist list"
local shiftMod = "SHIFT"
local mainMod = "SUPER"

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nautilus"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/macos_lock.sh"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("antigravity"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("firefox"))

hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("/usr/bin/python3 " .. (os.getenv("HOME") or "") .. "/.config/hypr/scripts/minimize_window.py min"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("/usr/bin/python3 " .. (os.getenv("HOME") or "") .. "/.config/hypr/scripts/minimize_window.py restore"))
hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))
if hl.dsp.window.fullscreen then
    hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen())
end

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))
hl.bind(mainMod .. " + CTRL + left", hl.dsp.focus({ workspace = "-1" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "+1" }))

hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ workspace = "-1" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ workspace = "+1" }))

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"), { locked = true, repeating = true })

-- Capturas de pantalla (guardar en ~/Imágenes + copiar al portapapeles)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/capture.sh region"))
hl.bind("PRINT", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/capture.sh output"))
hl.bind("ALT + PRINT", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/capture.sh window"))
hl.bind("CTRL + PRINT", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/capture.sh edit"))
hl.bind(mainMod .. " + minus", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/capture.sh window"))

-- Grabación de pantalla (gpu-screen-recorder)
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/record_screen.sh screen"))
hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/record_screen.sh region"))

hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("qs ipc -p " .. (os.getenv("HOME") or "") .. "/.config/quickshell/macos call spotlight toggle"))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("zapfast"))
hl.bind(mainMod .. " + ALT + L", hl.dsp.exec_cmd("localsend"))
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_cmd("gnome-calculator"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("bash -c 'echo powermenu > ${XDG_RUNTIME_DIR}/skwd/cmd'"))
-- hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/toggle_waffle.sh"))
hl.bind(mainMod .. " + N", hl.dsp.global("quickshell:wallpaperSelectorToggle"))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd((os.getenv("HOME") or "") .. "/.local/bin/systemsettings"))

-- Audio / Media controls (playerctl)
hl.bind(mainMod .. " + ALT + left", hl.dsp.exec_cmd("playerctl previous"))
hl.bind(mainMod .. " + ALT + right", hl.dsp.exec_cmd("playerctl next"))
hl.bind(mainMod .. " + ALT + P", hl.dsp.exec_cmd("playerctl play-pause"))

-- Apps opcionales (descomenta cuando las instales)
-- hl.bind(mainMod .. " + ALT + T", hl.dsp.exec_cmd("telegram-desktop"))
-- hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd("stremio"))
-- hl.bind(mainMod .. " + ALT + A", hl.dsp.exec_cmd("rog-control-center"))
-- hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd("wps"))
-- hl.bind(mainMod .. " + ALT + O", hl.dsp.exec_cmd("obsidian --ozone-platform=x11"))
-- hl.bind(mainMod .. " + ALT + N", hl.dsp.exec_cmd("kitty -e nvim"))
-- hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd("brave"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("~/.config/hypr/scripts/qs_manager.sh toggle movies"))
hl.bind(mainMod .. " + J", hl.dsp.exec_cmd("~/.config/hypr/scripts/qs_manager.sh toggle anime"))
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/qs_manager.sh toggle focustime"))
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("quickshell -p ~/.config/quickshell/TypewriterSplash.qml"))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("qs ipc -p " .. (os.getenv("HOME") or "") .. "/.config/quickshell/macos call spotlight toggle"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("qs ipc -p " .. (os.getenv("HOME") or "") .. "/.config/quickshell/macos call visualintel open"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/quickshell/toggle_screenshot_browser.sh"))
-- hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/toggle_macos.sh"))
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/macos_lock.sh"), { locked = true })
-- زر للتبديل السريع بين الـ 2D التقليدي وعالم الـ 3D الحر
hl.bind(mainMod .. " + BackSpace", hl.dsp.exec_cmd("hyprctl hypr3d"))
if hl.plugin and hl.plugin.hypr3d and hl.plugin.hypr3d.toggle then
    
end

-- Siri desactivado
-- hl.bind(mainMod .. " + ALT + Space", hl.dsp.exec_cmd("qs ipc -p " .. (os.getenv("HOME") or "") .. "/.config/quickshell/macos call siri listen"))
-- pcall(require, "configs.siri")

-- Trackpad gestures (System Settings › Trackpad)
pcall(require, "configs.gestures")
