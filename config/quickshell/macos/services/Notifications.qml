pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Hyprland
import "../modules/common"

Singleton {
    id: root

    // ── signals (same as before for backward compat) ──────────────
    signal notify(var notification)
    signal discard(int id)

    // ── K4-style state ────────────────────────────────────────────
    property var list: []
    property var latest: null
    property int count: 0
    property bool toastOpen: false

    // System Settings > Focus / Notifications
    readonly property var _focusCfg: Appearance.cfgGet("focus", ({})) || ({})
    readonly property var _notifCfg: Appearance.cfgGet("notifications", ({})) || ({})
    readonly property bool doNotDisturb: _focusCfg.dnd === true || _focusCfg.sleep === true
    readonly property string previews: _notifCfg.previews !== undefined ? String(_notifCfg.previews) : "When Unlocked"
    readonly property bool allowWhenLocked: _notifCfg.whenLocked !== false

    // recent = reversed tracked list (newest first)
    readonly property var recent: {
        const copy = list.slice()
        copy.reverse()
        return copy
    }

    // ── toast management (from K4 Notifs) ─────────────────────────
    function dismissToast() {
        _toastTimer.stop()
        toastOpen = false
    }

    function holdToast() { _toastTimer.stop() }

    function resumeToast() {
        if (toastOpen) _toastTimer.restart()
    }

    // ── core actions ──────────────────────────────────────────────
    function safeDismiss(notification) {
        if (!notification) return;
        const idx = root.list.indexOf(notification);
        if (idx >= 0) {
            root.list.splice(idx, 1);
            root.count = Math.max(0, root.count - 1);
            if (root.latest === notification) {
                dismissToast();
                root.latest = root.list.length > 0 ? root.list[0] : null;
            }
            try {
                if (typeof notification.dismiss === "function") notification.dismiss();
            } catch (e) {}
            root.discard(notification.id);
        }
    }

    function dismiss(notification) {
        safeDismiss(notification);
    }

    function clearAll() {
        const copy = root.list.slice();
        root.list = [];
        dismissToast();
        root.latest = null;
        root.count = 0;
        for (const n of copy) {
            try {
                if (n && typeof n.dismiss === "function") n.dismiss();
            } catch (e) {}
        }
    }

    function markRead() { count = 0 }

    // ── utility (from K4 Notifs) ──────────────────────────────────
    function iconFor(notification) {
        if (!notification) return "";
        if (notification.image && notification.image.length > 0)
            return notification.image
        const icon = notification.appIcon || "";
        if (icon.length === 0) return ""
        if (icon.startsWith("/") || icon.startsWith("file://") || icon.startsWith("http")) return icon;
        return Quickshell.iconPath(icon, "image-missing");
    }

    function defaultAction(n) {
        if (!n || !n.actions) return null
        for (let i = 0; i < n.actions.length; ++i) {
            if (n.actions[i].identifier === "default")
                return n.actions[i]
        }
        return null
    }

    function buttons(n) {
        if (!n || !n.actions) return []
        return n.actions.filter(function (a) { return a.identifier !== "default" && a.identifier !== "inline-reply" })
    }

    function activate(n) {
        if (!n) return
        const action = defaultAction(n)
        if (action) {
            try { action.invoke() } catch (e) {}
        }
        focusApp(n)
        if (!n.resident) safeDismiss(n)
    }

    function invokeAction(n, action) {
        if (!action) return
        const idLow = String(action.identifier || "").toLowerCase()
        const txtLow = String(action.text || "").toLowerCase()
        try { action.invoke() } catch (e) {}
        const isPassive = /dismiss|close|ignore|mute|delete|mark.?read|cerrar|ignorar|silenciar|descartar/.test(idLow + " " + txtLow)
        if (n && !isPassive) focusApp(n)
        if (n && !n.resident) safeDismiss(n)
    }

    // ── window matching (GUI + CLI apps via focus_notif.py) ───────
    property var destinos: ({})

    readonly property string terminal: "kitty"

    readonly property var aliases: ({
        "claude code": terminal,
        "claude": terminal,
        "codex": terminal,
        "opencode": terminal,
        "oc": terminal,
        "gemini": terminal,
        "gemini cli": terminal,
        "gemini-cli": terminal,
        "agy": terminal,
        "aider": terminal,
        "notify-send": terminal,
        "terminal": terminal,
        "kitty": terminal,
        "bash": terminal,
        "zsh": terminal,
        "fish": terminal,
        "tmux": terminal,
        "nvim": terminal,
        "neovim": terminal,
        "telegram desktop": "org.telegram.desktop",
        "youtube music": "com.github.th-ch.youtube-music",
        "mozilla firefox": "firefox",
        "zapfast": "zapfast"
    })

    function _clave(app, cuerpo) {
        return String(app || "").toLowerCase() + "\n" + String(cuerpo || "")
    }

    function apuntarDestino(app, cuerpo, pid) {
        const p = String(pid || "")
        if (p.length === 0) return
        const d = Object.assign({}, destinos)
        d[_clave(app, cuerpo)] = p
        destinos = d
    }

    function olvidarDestino(app, cuerpo) {
        const k = _clave(app, cuerpo)
        if (destinos[k] === undefined) return
        const d = Object.assign({}, destinos)
        delete d[k]
        destinos = d
    }

    function destinoDe(n) {
        if (!n) return ""
        const p = destinos[_clave(n.appName, n.body)]
        return p === undefined ? "" : p
    }

    function clasesDe(n) {
        const raw = (n && n.desktopEntry && n.desktopEntry.length > 0
                     ? n.desktopEntry : (n ? n.appName : "")) || ""
        if (raw.length === 0) return []
        const bajo = raw.toLowerCase()
        if (aliases[bajo] !== undefined)
            return [String(aliases[bajo]).toLowerCase()]
        const salida = [bajo]
        const anotar = function (v) {
            const s = String(v || "").toLowerCase().replace(/\.desktop$/, "")
            if (s.length > 0 && salida.indexOf(s) < 0) salida.push(s)
        }
        const pelado = bajo.replace(/\.desktop$/, "")
        const apps = DesktopEntries.applications.values
        for (let i = 0; i < apps.length; ++i) {
            const a = apps[i]
            const id = String(a.id || "").toLowerCase().replace(/\.desktop$/, "")
            if (id !== pelado && String(a.name || "").toLowerCase() !== bajo) continue
            anotar(a.startupClass)
            anotar(id)
        }
        return salida
    }

    function focusByMeta(appName, desktopEntry, summary, body, pid) {
        const a = String(appName || "").trim()
        const de = String(desktopEntry || "").trim()
        const s = String(summary || "").replace(/[\r\n]+/g, " ").trim()
        const b = String(body || "").replace(/[\r\n]+/g, " ").trim()
        const p = String(pid || "").trim()
        if (a.length === 0 && de.length === 0 && p.length === 0) return
        Quickshell.execDetached([
            "python3",
            Quickshell.env("HOME") + "/.config/quickshell/macos/services/focus_notif.py",
            a, de, s, b, p
        ])
    }

    function focusApp(n) {
        if (!n) return
        focusByMeta(n.appName, n.desktopEntry, n.summary, n.body, destinoDe(n))
    }

    function casa(clases, cls, initial) {
        for (let i = 0; i < clases.length; ++i)
            if (clases[i] === cls || clases[i] === initial) return true
        return false
    }

    function launchEntry(n) {
        const id = (n.desktopEntry || "").toLowerCase()
        if (id.length === 0) return false
        const apps = DesktopEntries.applications.values
        for (let i = 0; i < apps.length; ++i) {
            const app = apps[i]
            const appId = String(app.id || "").toLowerCase()
            if (appId === id || appId === id + ".desktop"
                || appId.replace(/\.desktop$/, "") === id) {
                app.execute()
                return true
            }
        }
        return false
    }

    function descartarDeVentana(t) {
        const d = t && t.lastIpcObject ? t.lastIpcObject : null
        if (!d) return
        const cls = String(d.class || "").toLowerCase()
        const initial = String(d.initialClass || "").toLowerCase()
        if (cls.length === 0 && initial.length === 0) return
        const listCopy = root.list.slice()
        for (let i = 0; i < listCopy.length; ++i) {
            if (!casa(clasesDe(listCopy[i]), cls, initial)) continue
            safeDismiss(listCopy[i])
        }
    }

    function descartarDeApp(app, cuerpo) {
        const quien = String(app || "").toLowerCase()
        if (quien.length === 0) return
        const texto = cuerpo === undefined ? null : String(cuerpo)
        const listCopy = root.list.slice()
        for (let i = 0; i < listCopy.length; ++i) {
            const n = listCopy[i]
            if (String(n.appName || "").toLowerCase() !== quien) continue
            if (texto !== null && String(n.body || "") !== texto) continue
            safeDismiss(n)
        }
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            root.descartarDeVentana(Hyprland.activeToplevel)
        }
    }

    // ── notification server ───────────────────────────────────────
    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        inlineReplySupported: true

        onNotification: function (notification) {
            notification.tracked = true;
            root.list.unshift(notification);
            if (root.list.length > 80) root.list.pop();
            root.latest = notification
            root.count += 1
            // Focus silences banners; they still land in Notification Center
            const silenced = root.doNotDisturb
                || (!root.allowWhenLocked && ShellController.locked);
            if (!silenced) {
                root.toastOpen = true
                _toastTimer.restart()
            }
            root.notify(notification);
        }
    }

    Timer {
        id: _toastTimer
        interval: 5000
        onTriggered: root.dismissToast()
    }
}
