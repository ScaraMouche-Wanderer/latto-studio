pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// UI state shared between views, the island windows and the outside world.
//  - A view that needs the island to stay open (a password field being typed
//    into) calls holdOpen(); the island ignores the pointer leaving until
//    release().
//  - openRequested / closeRequested open the island on a tab, or close it,
//    from a keybind or script:
//        qs -p <latto> ipc call island open notifications
//        qs -p <latto> ipc call island close
QtObject {
    id: root

    property int holds: 0
    readonly property bool heldOpen: holds > 0

    // tab is a tab name (media, notifications, stats, ...) or "" for the current one.
    signal openRequested(string tab)
    signal closeRequested()
    signal toggleRequested()
    signal keyboardFocusRequested(bool enabled)
    signal textEntryRequested(var target)

    // Keep the desktop shortcut off the slower command-discovery path.
    // The socket lives inside this user's private, session-only runtime dir.
    readonly property string shortcutSocketPath: Quickshell.env("XDG_RUNTIME_DIR")
        ? Quickshell.env("XDG_RUNTIME_DIR") + "/latto-fluid.sock" : ""
    property SocketServer shortcutSocket: SocketServer {
        path: root.shortcutSocketPath
        active: path !== ""
        handler: Socket {
            parser: SplitParser {
                onRead: message => { if (message === "toggle") root.toggleRequested(); }
            }
        }
    }

    function holdOpen() {
        holds++;
    }

    function release() {
        holds = Math.max(0, holds - 1);
    }

    property IpcHandler ipc: IpcHandler {
        target: "island"

        function open(tab: string): void { root.openRequested(tab); }
        function close(): void { root.closeRequested(); }
        function toggle(): void { root.toggleRequested(); }
        function keyboard(enabled: bool): void { root.keyboardFocusRequested(enabled); }
    }
}
