local inFocusOpacity = 0.9
local notInFocusOpacity = 0.7

hl.window_rule({
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    match = { class = "^(systemsettings)$" },
    float = true,
    center = true,
    size = "715 700",
    no_shadow = true,
    opacity = "1 1",
})

hl.window_rule({
    match = { class = ".*" },
    opacity = tostring(inFocusOpacity) .. " " .. tostring(notInFocusOpacity),
})

hl.window_rule({
    match = { class = "^kitty$" },
    opacity = "0.72 0.62",
})

hl.window_rule({
    match = { class = "^(zapfast|ZapFast)$" },
    opacity = "0.78 0.68",
})

hl.window_rule({
    match = { class = "^(firefox|brave|chromium|librewolf|qutebrowser|zen-browser)$" },
    opacity = tostring(inFocusOpacity) .. " " .. tostring(notInFocusOpacity),
})

hl.window_rule({
    match = { title = ".*Spotify.*" },
    opacity = tostring(inFocusOpacity) .. " " .. tostring(notInFocusOpacity),
})

hl.window_rule({
    match = { title = ".*Discord.*" },
    opacity = tostring(inFocusOpacity) .. " " .. tostring(notInFocusOpacity),
})

hl.window_rule({
    match = { class = "^(org\\.telegram\\.desktop|telegramdesktop)$" },
    opacity = "0.78 0.68",
})

hl.window_rule({
    match = { title = ".*Code.*" },
    opacity = tostring(inFocusOpacity) .. " " .. tostring(notInFocusOpacity),
})

hl.window_rule({
    match = { title = ".*(Thunar|nemo).*" },
    opacity = tostring(inFocusOpacity) .. " " .. tostring(notInFocusOpacity),
})

hl.window_rule({
    match = { class = "^(gamescope)$" },
    immediate = true,
    fullscreen = true,
})

hl.window_rule({
    match = { class = "^(pearos-settings-app)$" },
    float = true,
    center = true,
    size = "700 600",
    no_shadow = true,
    tag = "+hyprglass_preset_liquid_true",
})

hl.window_rule({
    match = { class = "^(org\\.gnome\\.Nautilus)$" },
    opacity = "0.95 0.86",
    rounding = 14,
})
hl.window_rule({
    match = {
        class = "^(pcmanfm)$",
        title = "^(Desktop)$"
    },
    float = true,
    fullscreen = false,
    pin = true,
    no_focus = true,
    -- إعدادات إضافية لجعلها ثابتة تماماً بالخلفية بدون تأثيرات شفافة تزعجك
    suppress_event = "maximize",
})
-- إجبار نافذة بث الآيفون على أخذ خصائص ثيم الآيفون المدمج في eqSh
hl.window_rule({
    match = { class = "^(uxplay)$" },
    float = true,
    center = true,
    size = "360 780",
    opacity = "1 1",             
    tag = "+hyprglass_preset_liquid_true", 
    border_size = 0,
    rounding = 20
})

-- Evitar que la animación fade-out de slurp salga dentro de las capturas de pantalla
hl.layer_rule({
    name = "slurp-selection-noanim",
    match = { namespace = "^selection$" },
    no_anim = true,
})

