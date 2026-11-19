"""Open Latto Studio with a temporary configuration and no shell controls."""

import json
from pathlib import Path
from tempfile import TemporaryDirectory

from PySide6.QtWidgets import QApplication

from model import PRESETS
from studio import STYLE, Studio


def main():
    app = QApplication([])
    app.setApplicationName("Latto Studio")
    app.setStyle("Fusion")
    app.setStyleSheet(STYLE)

    with TemporaryDirectory(prefix="latto-studio-demo-") as directory:
        root = Path(directory)
        config = root / "config.json"
        config.write_text(
            json.dumps({**PRESETS["Aurora Rush"], "expandedLayout": "summary"}),
            encoding="utf-8",
        )
        window = Studio(config, root / "backups", demo=True)
        window.setWindowTitle("Latto Studio — Demo")
        window.live.setChecked(False)
        preview_buttons = window.preview_modes.buttons()
        next(button for button in preview_buttons if button.text() == "Expanded").click()
        stage_buttons = window.stage_buttons.buttons()
        next(button for button in stage_buttons if button.text() == "Night").click()
        window.show()
        return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
