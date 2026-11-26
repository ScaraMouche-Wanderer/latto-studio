#!/usr/bin/python
"""Launch an installed desktop ID using the desktop's standard launcher."""
import json
import sys

import gi
gi.require_version("Gio", "2.0")
gi.require_version("GioUnix", "2.0")
from gi.repository import Gio, GioUnix


def desktop_info(identifier):
    if (not isinstance(identifier, str) or not identifier or len(identifier) > 512
            or any(c in identifier for c in "/\\\x00\n\r")):
        raise ValueError("Invalid application ID")
    desktop_id = identifier if identifier.endswith(".desktop") else identifier + ".desktop"
    try:
        info = GioUnix.DesktopAppInfo.new(desktop_id)
    except TypeError as error:
        raise ValueError("Application is no longer available") from error
    if info is None or info.get_is_hidden() or info.get_nodisplay():
        raise ValueError("Application is no longer available")
    return info


def main():
    try:
        if len(sys.argv) != 2:
            raise ValueError("Expected one installed application ID")
        info = desktop_info(sys.argv[1])
        if not info.launch([], Gio.AppLaunchContext()):
            raise RuntimeError("Desktop launch request was rejected")
        print(json.dumps({"ok": True}))
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
