#!/usr/bin/env python3
"""Activate the X11 island on request; return focus after it folds away.

GNOME keeps a focused dock active when its WM_HINTS input flag becomes false.
A closed, nonfocusable island can be unmapped/remapped in one server round
trip to let Mutter choose its previous application, including Wayland apps.
GNOME integration restores the previous app without withdrawing the island.
The fallback touches only this process’s own active window.
"""

import ctypes
import json
import time
import os
import re
import subprocess
import sys


class WMHints(ctypes.Structure):
    _fields_ = [
        ("flags", ctypes.c_long), ("input", ctypes.c_int),
        ("initial_state", ctypes.c_int), ("icon_pixmap", ctypes.c_ulong),
        ("icon_window", ctypes.c_ulong), ("icon_x", ctypes.c_int),
        ("icon_y", ctypes.c_int), ("icon_mask", ctypes.c_ulong),
        ("window_group", ctypes.c_ulong),
    ]


def output(*args):
    return subprocess.check_output(args, text=True, timeout=2,
                                   stderr=subprocess.DEVNULL)


def shell_focus(mode, pid):
    """GNOME owns Wayland focus and actor order; no unmap/remap is needed."""
    try:
        import gi
        from gi.repository import Gio, GLib
        connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        def call(method):
            return connection.call_sync(
                "org.gnome.Shell", "/org/gnome/Shell/Extensions/Latto",
                "org.voidnode.LattoShell1", method, GLib.Variant("(u)", (pid,)),
                None, Gio.DBusCallFlags.NO_AUTO_START, 700, None).unpack()[0]
        accepted = bool(call("Activate" if mode == "activate" else "Release"))
        if not accepted or mode == "release":
            return accepted
        for _ in range(8):
            state = json.loads(call("State"))
            if any(window.get("focused") for window in state.get("windows", [])):
                return True
            time.sleep(.025)
        return False
    except (ImportError, OSError, ValueError, RuntimeError):
        return None
    except Exception:
        # The optional extension is absent on non-GNOME desktops.
        return None


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("activate", "release"):
        return
    if not os.environ.get("DISPLAY"):
        return
    mode, pid = sys.argv[1], int(sys.argv[2])
    windows = []
    for line in output("wmctrl", "-lpG").splitlines():
        fields = line.split(None, 8)
        if len(fields) >= 8 and int(fields[2]) == pid:
            windows.append(fields[0])
    if not windows:
        return

    x11 = ctypes.CDLL("libX11.so.6")
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    x11.XGetWMHints.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
    x11.XGetWMHints.restype = ctypes.POINTER(WMHints)
    x11.XFree.argtypes = [ctypes.c_void_p]
    x11.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
    for name in ("XUnmapWindow", "XMapWindow"):
        getattr(x11, name).argtypes = [ctypes.c_void_p, ctypes.c_ulong]
    # Another window can disappear between the list and the hints request.
    error_handler_type = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p,
                                          ctypes.c_void_p)
    error_handler = error_handler_type(lambda *_: 0)
    x11.XSetErrorHandler.argtypes = [error_handler_type]
    x11.XSetErrorHandler(error_handler)
    display = x11.XOpenDisplay(None)
    if not display:
        return
    try:
        if mode == "release":
            active = re.search(r"0x[0-9a-fA-F]+", output(
                "xprop", "-root", "_NET_ACTIVE_WINDOW"))
            windows = [w for w in windows
                       if active and int(w, 16) == int(active[0], 16)]
        for window in windows:
            native_id = int(window, 16)
            hints = x11.XGetWMHints(display, native_id)
            if not hints:
                continue
            accepts_input = not (hints.contents.flags & 1) or bool(hints.contents.input)
            x11.XFree(hints)
            if mode == "activate" and accepts_input:
                granted = shell_focus(mode, pid)
                if granted is not None:
                    return granted
                subprocess.run(["wmctrl", "-i", "-a", window], check=True,
                               timeout=2, stderr=subprocess.DEVNULL)
                active = re.search(r"0x[0-9a-fA-F]+", output("xprop", "-root", "_NET_ACTIVE_WINDOW"))
                return bool(active and int(active[0],16)==native_id)
            if mode == "release" and not accepts_input:
                granted = shell_focus(mode, pid)
                if granted is not None:
                    return granted
                # No delay between requests, no surface resize, and no change
                # to the window's shape, properties or QML visibility.
                x11.XUnmapWindow(display, native_id)
                x11.XSync(display, False)
                x11.XMapWindow(display, native_id)
                x11.XSync(display, False)
                # Mutter removes ABOVE when a dock withdraws. Our explicit
                # focus handoff bypasses Qt's map path, so reassert the panel
                # state after mapping without activating or resizing it.
                subprocess.run(["wmctrl", "-i", "-r", window, "-b", "add,above"],
                               check=True, timeout=2, stderr=subprocess.DEVNULL)
        return mode == "release"
    finally:
        x11.XCloseDisplay(display)


if __name__ == "__main__":
    try:
        print(json.dumps({"ok": bool(main())}))
    except (OSError, ValueError, subprocess.SubprocessError):
        # Optional integration: the island remains usable with the pointer
        # when X11 tooling is unavailable or its service is stopping.
        print(json.dumps({"ok": False}))
