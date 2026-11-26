import QtQuick
import Quickshell
import qs.config
import qs.ui.components.lockscreen
import "./services"
import "./modules/topbar"
import "./modules/island"
import "./modules/spotlight"
import "./modules/dock"
import "./modules/genie"
import "./modules/about"
import "./modules/notification"
import "./modules/session"
import "./modules/controlcenter"
import "./modules/desktop"
import "./modules/settings"
import "./modules/siri"
import "./modules/visualintel"
import "./modules/hotcorners"

ShellRoot {
    id: root

    TopBar { id: topBar }
    IslandWindow { id: islandWindow }
    Loader { active: Config.spotlight.enable; sourceComponent: Spotlight {} }
    Loader { active: Config.dock.enable; sourceComponent: Dock {} }
    Genie {}
    Loader { active: ShellController.aboutOpen; sourceComponent: AboutWindow { parentWindow: topBar } }
    // Notifications are rendered inside IslandWindow (Nusa-style notch)
    // NotificationPopup {}
    Loader { active: ShellController.sessionOpen; sourceComponent: Session {} }
    Loader { active: ShellController.pendingConfirm !== ""; sourceComponent: ConfirmDialog {} }
    Loader { active: ShellController.forceQuitOpen; sourceComponent: ForceQuit {} }
    Loader {
        id: ccLoader
        property bool everOpened: false
        active: everOpened || ShellController.controlCenterOpen
        sourceComponent: ControlCenter {}
        onLoaded: {
            if (ShellController.controlCenterOpen && item) {
                Qt.callLater(() => {
                    ShellController.controlCenterOpen = false;
                    ShellController.controlCenterOpen = true;
                });
            }
        }
        Connections {
            target: ShellController
            function onControlCenterOpenChanged() {
                if (ShellController.controlCenterOpen) ccLoader.everOpened = true;
            }
        }
    }
    Settings {}
    // Siri {}
    VisualIntelligence {}
    // HotCorners {}

    // eqsh LockScreen (ext-session-lock) replaces the old PanelWindow lock
    Loader {
        id: lockLoader
        active: Config.lockScreen.enable
        sourceComponent: Lock {
            id: lockScreen
            onLock: {
                if (!ShellController.locked) ShellController.lock();
            }
            onUnlocking: ShellController.unlock()
            onUnlock: ShellController.unlock()
            Component.onCompleted: Runtime.subscribe("lockscreen", () => lockScreen.lockScreen())
        }
    }

    Connections {
        target: ShellController
        function onOpenRequested(name) {
            if (name === "lock") {
                if (!Runtime.locked) Runtime.locked = true;
                Runtime.run("lockscreen");
            } else if (name === "unlock") {
                if (Runtime.locked) Runtime.locked = false;
            }
        }
        function onLockedChanged() {
            if (!ShellController.locked && Runtime.locked) {
                Runtime.locked = false;
            }
        }
    }

    // eqsh Spotlight reads Runtime.spotlightOpen; macos uses ShellController.spotlightOpen
    Connections {
        target: Runtime
        function onSpotlightOpenChanged() {
            if (ShellController.spotlightOpen !== Runtime.spotlightOpen)
                ShellController.spotlightOpen = Runtime.spotlightOpen;
        }
    }
    Connections {
        target: ShellController
        function onSpotlightOpenChanged() {
            if (Runtime.spotlightOpen !== ShellController.spotlightOpen)
                Runtime.spotlightOpen = ShellController.spotlightOpen;
        }
    }

    Component.onCompleted: { void Apps.ready; }
}
