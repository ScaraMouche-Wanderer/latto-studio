# Codex in Latto

Open Latto and select the keyboard-shaped **Codex** tab, or run `latto open codex`.
There is no separate keyboard switch: click a text field to edit the prompt, or
use the capture and typing buttons directly. The helper runs in the background.

1. Set the request, or keep the default instructions, then click **Capture & ask**.
   Latto captures the screen and sends the image to Codex. The response appears in
   the preview; capture never types it automatically.
2. Review the answer, focus the intended multiline editor, then click **Type answer**.
   Smart indentation is always used. Latto releases its keyboard mode, remembers
   the focused application, and starts typing after a one-second countdown. Keep
   the same application focused. A change of application stops insertion.
   This uses ydotool, which is also CodeWriter's input backend; neither Codex's
   terminal UI nor CodeWriter's window needs to open.
4. **Cancel** stops capture, a pending model request, or typing. At most the short
   input chunk already in progress can finish; text already inserted stays put.

Loading or refreshing an old saved answer never types it automatically. Typing
only starts after the explicit **Type answer** click.

Screen capture uses the ordinary XDG desktop portal. The desktop may show a
permission prompt or capture indicator. Latto does not suppress these. It does
not guarantee undetectable interaction, bypass test monitoring, or change browser
focus/visibility APIs. Use assistance where it is permitted.

## Requirements

- Installed Codex CLI, authenticated using `codex login`. Inspect authentication
  with `codex login status`.
- Python with GObject/Gio, and a working screenshot portal for the desktop.
- For typing: `ydotool`, its running daemon, and the enabled `latto-shell@voidnode`
  GNOME integration that supplies native focus state. Missing services appear in
  the Codex tab as an availability message. The existing user service can be
  started with `systemctl --user start ydotool`.
- A **US keyboard layout** and ASCII response text. Unsupported characters are
  rejected before input starts. Enter and Tab are actual key events: use a
  multiline editor configured appropriately for code indentation and brackets.
  Newlines may submit a single-line form; Latto cannot identify the focused field.

The tab is included in the default tab list and Latto Studio's tab controls.
Existing configurations must include `"codex"` in `tabs`; this machine's
configuration has been updated with a backup through Latto Studio's config store.

## Behavior and stored data

Only an explicit capture click sends an image to Codex. There is no continuous
capture. Capturing a new question clears the old answer, so a failed capture cannot
type an earlier response.

The answer preview keeps its original indentation. **Smart** strips leading and
trailing whitespace from each transmitted line and leaves blank lines and
spacing inside lines intact. The editor then supplies indentation instead of
adding it to the answer's spaces. This addresses the growing "staircase"
indentation seen when typing preindented code into an auto-indenting editor.

Smart matches CodeWriter's Smart behavior without rewriting bracket characters.
It removes leading and trailing whitespace on each transmitted line. If code
depends on indentation itself, editor auto-indent behavior can change its layout.

Both modes are subject to the ASCII/US-layout and 64,000-byte limits. The model
response has outer code fences and surrounding newlines cleaned before display.
Unsupported characters or whitespace-only answers are rejected before any input;
the answer stays in the preview. Target-editor bracket completion can still
affect the final text.

Codex runs with `codex exec --image`, the saved CLI login, an ephemeral session,
and a read-only sandbox in an isolated temporary directory. User Codex config,
shell tools, apps, plugins, web search, and additional agents are disabled for
these requests. The screenshot is treated as context, not tool instructions.

The current answer and action state live in
`~/.local/state/latto/codex/state.json` (or under `$XDG_STATE_HOME`), in a private
directory with private files. The helper's temporary screenshot copy is removed
after completion, cancellation, or a handled termination. The desktop portal may
retain its own screenshot according to its normal behavior.

Typing checks the focused application before each short chunk and stops if the
application PID changes or Latto owns focus. Automatic insertion also requires
the application selected before capture to remain focused when inference finishes.
This checks application PID; it cannot distinguish fields, browser tabs, or windows
sharing one application PID. It never retries failed input and sends no additional
submit shortcut.

## Verification

`python bin/test-latto-codex.py -v` runs 35 checks covering focus, literal input,
prompt and answer limits, unsupported text, failed-input retry prevention,
cancellation, stale state, concurrent actions, model output validation, deadlines,
subprocess cleanup, and noninteractive Codex invocation. Automatic capture-to-type
tests include explicit insertion, capability checks, focus changes during
inference/countdown, Unicode rejection, failed inference, and cancellation before
or during input. These tests use mocks and a local fake model executable.

`python bin/test-latto-codex-portal.py -v` runs eight screenshot protocol checks,
including success, cancellation, denied requests, missing images, timeouts, and
cleanup. It uses a fake desktop portal without accessing the real session bus.

`python bin/test-latto-codex-formatting.py -v` runs 13 formatting checks, including
nested C++, literal backslashes, blank lines, Smart/Preserve input, unchanged
previews, and a simulated editor that reproduces the growing-indentation defect.
This simulation does not establish compatibility with a particular live editor.

`python bin/test-latto-codex-ui.py` runs offscreen QML lifecycle checks with an
isolated fake helper, including capture-only preview, explicit typing, duplicate
requests, fixed Smart formatting, startup cancellation, and cancellation followed
immediately by a new capture.
QML lint and offscreen renders also cover the tab layout. The existing Latto
Studio model and GUI checks pass. Local checks do not establish compatibility
with a particular assessment or its monitoring configuration. See
[GFG-VALIDATION.md](GFG-VALIDATION.md) for the assessment-specific validation scope
and unresolved live checks.

This workspace cannot access the live ydotool socket or desktop session bus.
Live capture, authenticated model inference, and actual insertion remain to be
verified in the desktop session; no live screenshot or keystroke was sent here.

References: [Codex noninteractive mode](https://learn.chatgpt.com/docs/non-interactive-mode),
[Codex command reference](https://learn.chatgpt.com/docs/developer-commands?surface=cli),
[XDG screenshot portal](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.Screenshot.html),
[ydotool input implementation](https://github.com/ReimuNotMoe/ydotool/blob/master/Client/tool_type.c).
