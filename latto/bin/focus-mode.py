#!/usr/bin/python
"""Choose Latto's native input mode. Does not change browser settings."""
import json
import os
from pathlib import Path
import stat
import sys
import tempfile


def config_path():
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "latto/config.json"


def configure(mode, path=None):
    path = path or config_path()
    if mode not in ("passive", "normal", "status"):
        raise ValueError("Usage: latto-focus passive|normal|status")
    if path.exists() and path.stat().st_size > 256 * 1024:
        raise ValueError("Latto configuration is too large")
    data = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(data, dict):
        raise ValueError("Invalid Latto configuration")
    if mode == "status":
        return "passive" if data.get("preserveAppFocus") is True else "normal"
    data["preserveAppFocus"] = mode == "passive"
    permissions = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor, temporary = tempfile.mkstemp(prefix=".focus-mode-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as stream:
            os.fchmod(stream.fileno(), permissions)
            json.dump(data, stream, indent=2, ensure_ascii=False, allow_nan=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return mode


def main():
    try:
        if len(sys.argv) > 2:
            raise ValueError("Usage: latto-focus passive|normal|status")
        mode = configure(sys.argv[1] if len(sys.argv) == 2 else "status")
        print("Latto focus mode: " + mode)
        if mode == "passive":
            print("Mouse controls keep the current app focused. Click a text field to enable typing in Latto.")
    except (ValueError, OSError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
