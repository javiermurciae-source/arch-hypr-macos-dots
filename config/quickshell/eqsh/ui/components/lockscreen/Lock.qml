import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs
import qs.ui.controls.auxiliary

Scope {
	id: root
	signal lock()
	signal unlock()
	signal unlocking()
    LazyLoader {
		id: loader
		onActiveChanged: {
			if (!active) {
				activeAsync = false;
				root.unlock();
			}
		}
		ShellRoot {
			LockContext {
				id: lockContext

				Connections {
					target: root
					function onUnlock() {
						lock.locked = false;
					}
				}

				onUnlocked: {
					lock.locked = false;
					loader.active = false;
					loader.activeAsync = false;
					root.unlock();
				}
			}

			WlSessionLock {
				id: lock
				locked: true
				onLockedChanged: {
					if (!locked) {
						loader.active = false;
						loader.activeAsync = false;
						root.unlock();
					}
				}
				WlSessionLockSurface {
					id: lockSurface
					color: "transparent"
					LockSurface {
						id: locksur
						anchors.fill: parent
						context: lockContext
						screen: lockSurface.screen
						Connections {
							target: lockContext
							function onUnlocking() {
								root.unlocking();
								locksur.unlock();
							}
						}
					}
				}
			}
		}
    }

	Component.onCompleted: {
		Ipc.mixin("eqdesktop.lock", "lock", () => {
			root.lockScreen();
		});
		Ipc.mixin("eqdesktop.lock", "unlock", () => {
			root.unlock();
		});
		Ipc.mixin("eqdesktop.lock", "isLoaded", () => {
			return loader.active;
		});
	}

	function lockScreen() {
		if (loader.active) return;
		root.lock();
		loader.activeAsync = false;
		loader.active = true;
	}
}