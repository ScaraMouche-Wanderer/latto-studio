#!/usr/bin/env python3
"""Send the desktop shortcut straight to the running island."""
import os
from pathlib import Path
import socket

runtime = Path(os.environ.get('XDG_RUNTIME_DIR') or '/run/user/' + str(os.getuid()))
with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
    client.settimeout(.25)
    try:
        client.connect(str(runtime / 'latto-fluid.sock'))
    except OSError:
        # Preserve the regular control path if an older instance is running.
        os.execv('/usr/bin/qs', ['qs', '-p', str(Path(__file__).resolve().parents[1]),
                                'ipc', 'call', 'island', 'toggle'])
    client.sendall(b'toggle\n')
