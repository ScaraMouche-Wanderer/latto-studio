# Latto / GFG functional validation — 30 October 2026

**Result: local regression checks pass. Compatibility with the linked GFG
assessment and its monitoring configuration is unverified.**

Target supplied by the user:
[GFG offline assessment 2, slot 12](https://practice.geeksforgeeks.org/contest/offline-assessment-2-slot-12-gfg-x-skit-3247).

The browser tool reported `The browser access host is unavailable`. The web
reader could not access the assessment URL on either `practice.geeksforgeeks.org`
or `www.geeksforgeeks.org`. Its editor, instructions, language template, timer,
fullscreen requirements, and assessment-specific settings were not available for
inspection. No assessment was started, code entered, or answer submitted.

## Verified locally

| Area | Result and scope |
| --- | --- |
| Functional backend | 35 passing tests, using mocks and a fake model executable |
| Screenshot portal | 8 passing protocol tests, using fake Gio/GLib and local image fixtures |
| Typing formatting | 13 passing Smart/Preserve checks, including a simulated C++ auto-indenting editor |
| QML service lifecycle | 32 passing offscreen assertions with an isolated fake backend |
| QML validity | `qmllint` passes for the Codex service/tab, expanded view, and settings |
| Python validity | Helper and test scripts compile |
| Configuration | Codex tab enabled; `preserveAppFocus=true`; `hideInFullscreen=false`; `privacyIndicators=true` |
| Stored response permissions | State directory `0700`; state file `0600` |

The checks cover the following implemented parameters and behaviors:

- Prompt validation: empty/whitespace and over-limit requests are rejected before
  desktop access. The backend accepts up to 8,000 characters; the UI caps editing
  at 4,000 characters.
- Response validation: a 64,000-byte limit, missing/empty/oversized output, model
  failures, Markdown fence removal, and indentation preservation.
- Typing: literal backslashes and punctuation, ASCII/control-character checks,
  app focus rejection, missing input services, and no automatic retry after
  partial failure.
- Cancellation: before helper startup, during the one-second countdown, between
  short input chunks, while waiting for a screenshot, and during model inference.
- Deadlines: the 120-second portal limit and 240-second model limit are exercised
  with a simulated clock; child-process and temporary-file cleanup are checked.
- Portal lifecycle: response subscription, immediate replies, normal success,
  denial, cancellation, unreadable images, request closure, and timer cleanup.
- UI lifecycle: status loading, clearing old answers, disabled actions when
  services are absent, capture/type completion, focus-release signaling,
  matching request IDs, cancellation recovery, and duplicate request prevention.
- Explicit typing: capture generates a preview only. Typing starts only after
  **Type answer** is clicked. Missing input services or a changed application
  block insertion; failed inference and refreshed saved answers never start
  typing. Cancellation and immediately restarting another request are covered.
- Indentation correction: **Smart** is applied by default using CodeWriter's per-line
  whitespace stripping before typing, while preserving the answer preview.
  The simulated editor reproduces the screenshot's growing indentation when
  original spaces are sent, and avoids that cumulative growth with Smart.
  This does not validate a real GFG editor.

The offscreen tests found and reproduced a duplicate-start race: two immediate
capture calls could both launch before the QML button binding updated. The
service now checks mutable busy state directly and keeps a request marked as
submitting until its first response. Capture/type duplication and cancellation
before the first response pass after this fix. A later queued-callback race was
also fixed: cancelling before launch and immediately starting again now invalidates
the cancelled callback rather than launching the earlier request.

## Live checks that remain unresolved

An earlier saved desktop request reported **`Codex timed out. Try again.`** At
the latest check, a newer saved request from 13:02:38 IST reports **Answer ready**,
no error, and a 767-character answer. Its content was not inspected. That request
predates this explicit-click behavior and does not establish live typing works.

A previous fresh CLI diagnostic from this sandbox failed to initialize its
in-process client because Codex's state location is read-only here. No new live
model request or real keyboard input was sent during the automatic-insertion
update; its success cases use mocks and an isolated fake helper.

The current sandbox cannot connect to the live input daemon or validate native
desktop focus. The saved desktop-session capability snapshot had both capture
and typing available; that snapshot is not a fresh hardware test.

Actual GFG editor insertion remains unverified. The typing backend requires a US
keyboard layout and ASCII. Enter and Tab are real key events. Editor indentation,
paired brackets, the selected language template, and the active field can affect
the resulting code. Smart delegates indentation to the editor.
The focus guard checks application PID; it cannot identify
individual fields, browser tabs, or windows sharing a PID.

These tests do not establish that interaction is hidden from the assessment
owner. There is no certification of undetectability or bypass of monitoring.

## Repeat the local checks

```sh
python bin/test-latto-codex.py -v
python bin/test-latto-codex-portal.py -v
python bin/test-latto-codex-formatting.py -v
python bin/test-latto-codex-ui.py
qmllint -I /usr/lib/qt6/qml services/Codex.qml components/tabs/CodexTab.qml components/ExpandedView.qml services/Settings.qml
```

The UI regression uses an offscreen window and isolated temporary runtime,
configuration, cache, state, and helper files. It does not send real desktop input
or start an assessment.
