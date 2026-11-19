"""Mouse and keyboard behavior for the custom-drawn Studio switch."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
import pytest
from PySide6.QtWidgets import QApplication
from PySide6.QtCore import Qt,QPoint
from PySide6.QtTest import QTest
from widgets import Toggle

@pytest.fixture
def toggle():
    app=QApplication.instance() or QApplication([])
    app.setStyle('Fusion')
    widget=Toggle('Use system font');widget.resize(400,30);widget.show();app.processEvents()
    yield widget
    widget.close();widget.deleteLater();app.processEvents()


def test_entire_drawn_label_is_clickable(toggle):
    QTest.mouseClick(toggle,Qt.LeftButton,pos=QPoint(toggle.sizeHint().width()-5,15))
    assert toggle.isChecked()


def test_empty_row_space_does_not_toggle(toggle):
    QTest.mouseClick(toggle,Qt.LeftButton,pos=QPoint(380,15))
    assert not toggle.isChecked()


def test_track_and_keyboard_both_toggle(toggle):
    QTest.mouseClick(toggle,Qt.LeftButton,pos=QPoint(14,15))
    assert toggle.isChecked()
    toggle.setFocus();QTest.keyClick(toggle,Qt.Key_Space)
    assert not toggle.isChecked()


def test_disabled_toggle_ignores_input(toggle):
    toggle.setEnabled(False)
    QTest.mouseClick(toggle,Qt.LeftButton,pos=QPoint(14,15))
    QTest.keyClick(toggle,Qt.Key_Space)
    assert not toggle.isChecked()
