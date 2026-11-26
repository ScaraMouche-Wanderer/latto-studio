#!/usr/bin/env python3
"""Regression tests for temporary Pomodoro Do Not Disturb ownership."""
import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "notification_inbox", Path(__file__).with_name("notification-inbox.py")
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SettingsStub:
    def __init__(self, inbox, banners):
        self.inbox = inbox
        self.banners = banners
        self.writable = True
        self.writes = []

    def get_boolean(self, _key):
        return self.banners

    def is_writable(self, _key):
        return self.writable

    def set_boolean(self, _key, value):
        self.writes.append(value)
        self.banners = value
        self.inbox.preferences()
        return True


class FocusQuietTests(unittest.TestCase):
    def inbox(self, banners=True):
        inbox = module.DesktopInbox.__new__(module.DesktopInbox)
        module.Inbox.__init__(inbox, lambda _snapshot: None)
        inbox.connected = True
        inbox.locked = False
        inbox.focus_dnd_owned = False
        inbox.settings = SettingsStub(inbox, banners)
        inbox.preferences()
        return inbox

    def test_focus_restores_banners_only_when_it_disabled_them(self):
        inbox = self.inbox()
        inbox.command({"action": "focus-dnd", "on": True})
        self.assertFalse(inbox.banners)
        inbox.command({"action": "focus-dnd", "on": False})
        self.assertTrue(inbox.banners)
        self.assertEqual(inbox.settings.writes, [False, True])

    def test_existing_do_not_disturb_outlasts_focus(self):
        inbox = self.inbox(banners=False)
        inbox.focus_dnd(True)
        inbox.focus_dnd(False)
        self.assertFalse(inbox.banners)
        self.assertEqual(inbox.settings.writes, [])

    def test_explicit_do_not_disturb_takes_over_active_focus(self):
        inbox = self.inbox()
        inbox.focus_dnd(True)
        inbox.command({"action": "dnd", "on": True})
        inbox.focus_dnd(False)
        self.assertFalse(inbox.banners)

    def test_external_changes_take_over_active_focus(self):
        inbox = self.inbox()
        inbox.focus_dnd(True)
        inbox.settings.set_boolean("show-banners", True)
        inbox.settings.set_boolean("show-banners", False)
        inbox.focus_dnd(False)
        self.assertFalse(inbox.banners)
        self.assertEqual(inbox.settings.writes, [False, True, False])

    def test_focus_can_restore_while_locked(self):
        inbox = self.inbox()
        inbox.focus_dnd(True)
        inbox.locked = True
        inbox.command({"action": "focus-dnd", "on": False})
        inbox.command({"action": "dnd", "on": True})
        self.assertTrue(inbox.banners)

    def test_managed_desktop_pref_remains_unchanged(self):
        inbox = self.inbox()
        inbox.settings.writable = False
        inbox.focus_dnd(True)
        inbox.focus_dnd(False)
        self.assertTrue(inbox.banners)
        self.assertFalse(inbox.focus_dnd_owned)
        self.assertEqual(inbox.settings.writes, [])

    def test_unavailable_backend_does_not_change_desktop_preferences(self):
        inbox = self.inbox()
        inbox.settings = None
        inbox.focus_dnd(True)
        self.assertFalse(inbox.set_dnd(True))
        self.assertTrue(inbox.banners)


if __name__ == "__main__":
    unittest.main()
