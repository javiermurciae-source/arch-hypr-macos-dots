-- ملف إعدادات الشاشة monitors.lua
-- تفعيل الدقة القصوى (120Hz) مع عمق ألوان 10-bit، والـ HDR، والـ VRR تلقائياً

hl.monitor({
    output         = "eDP-1",
    mode           = "1920x1080@144",
    position       = "auto",
    scale          = 0.75,
    vrr            = 2,
})

