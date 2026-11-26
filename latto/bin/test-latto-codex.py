"""No live screenshots, model requests, or keyboard events are used by these tests."""

import contextlib
import fcntl
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("latto_codex", Path(__file__).with_name("latto-codex.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
CAPS = {"canCapture": True, "canType": True, "captureReason": "", "typeReason": ""}


class CodexTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.directory = Path(self.folder.name)
        self.capabilities = patch.object(module, "capabilities", return_value=CAPS)
        self.capabilities.start()
        self.addCleanup(self.capabilities.stop)
        self.addCleanup(self.folder.cleanup)
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()
        self.addCleanup(self.output.__exit__, None, None, None)

    def action(self, answer=""):
        module.atomic_write(self.directory / "state.json", json.dumps({"phase": "ready", "answer": answer}))
        return module.Action(self.directory)

    def model_program(self, answer="", exit_code=0, create_answer=True):
        program = self.directory / "fake-codex"
        program.write_text(
            "#!/usr/bin/python\nimport pathlib, sys\n"
            "args = sys.argv[1:]\n"
            "sys.stdin.read()\n"
            + ("pathlib.Path(args[args.index('--output-last-message') + 1]).write_text(" + repr(answer) + ")\n" if create_answer else "")
            + "raise SystemExit(" + repr(exit_code) + ")\n"
        )
        program.chmod(0o700)
        return program

    def test_focus_is_required_and_latto_is_rejected(self):
        for state in ({"available": True}, {"available": True, "foreground": {"pid": 8}, "windows": [{"focused": True}]}):
            with self.subTest(state=state), patch.object(module, "native_state", return_value=state):
                with self.assertRaises(ValueError):
                    module.focused_application()
        with patch.object(module, "native_state", return_value={"available": True, "foreground": {"pid": 8}}):
            self.assertEqual(module.focused_application(), 8)

    def test_typing_passes_literal_code_on_stdin(self):
        text = 'print("\\n", "$HOME", "`id`")\n'
        action = self.action(text)
        with patch.object(action, "pause"), patch.object(module, "focused_application", return_value=9), \
                patch.object(module, "daemon_socket", return_value="/tmp/fake-socket"), \
                patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
            module.type_answer(action)
        self.assertEqual(b"".join(call.kwargs["input"] for call in run.call_args_list), text.encode())
        for call in run.call_args_list:
            self.assertEqual(call.args[0][-2:], ["--file", "-"])
            self.assertNotIn(text, call.args[0])
        self.assertEqual(action.state["phase"], "ready")

    def test_typing_stops_before_next_chunk_when_app_changes(self):
        action = self.action("abcdefghijklmnop")
        with patch.object(action, "pause"), patch.object(module, "focused_application", side_effect=[9, 9, 10]), \
                patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
            with self.assertRaisesRegex(ValueError, "focus changed"):
                module.type_answer(action)
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.kwargs["input"], b"abcdefgh")

    def test_failed_typing_is_never_retried(self):
        action = self.action("abcdefghijklmnop")
        with patch.object(action, "pause"), patch.object(module, "focused_application", return_value=9), \
                patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 1)) as run:
            with self.assertRaises(ValueError):
                module.type_answer(action)
        self.assertEqual(run.call_count, 1)

    def test_unicode_controls_and_empty_text_fail_before_any_input(self):
        for text in ("", "café", "\x1b[A", "\x00", "\r"):
            with self.subTest(text=repr(text)), patch.object(module.subprocess, "run") as run:
                with self.assertRaises(ValueError):
                    module.type_answer(self.action(text))
                run.assert_not_called()

    def test_cancel_is_specific_to_operation(self):
        action = self.action("answer")
        (self.directory / "cancel").write_text("old-operation")
        action.check()
        (self.directory / "cancel").write_text(action.operation)
        with self.assertRaises(module.Cancelled):
            action.check()

    def test_cancel_before_worker_start_is_honored(self):
        (self.directory / "cancel").write_text("ui-request-1")
        with patch.object(module, "capture_screen") as screen:
            self.assertEqual(module.run_action(self.directory, "capture", "request", "ui-request-1"), 0)
        screen.assert_not_called()
        self.assertEqual(module.read_state(self.directory)["message"], "Capture cancelled.")

    def test_signal_cancellation_waits_until_check(self):
        action = self.action()
        with patch.object(module, "TERMINATION_REQUESTED", False):
            module.terminate(15, None)
            with self.assertRaises(module.Cancelled):
                action.check()

    def test_stale_busy_state_does_not_get_stuck(self):
        action = self.action()
        action.update(phase="thinking")
        self.assertEqual(module.status(self.directory)["phase"], "error")
        with (self.directory / "action.lock").open("a+") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertTrue(module.status(self.directory)["busy"])
            self.assertEqual(module.run_action(self.directory, "capture", "prompt"), 1)

    def test_failed_new_capture_clears_previous_answer(self):
        self.action("old answer")
        with patch.object(module, "capture_screen", side_effect=ValueError("denied")):
            self.assertEqual(module.run_action(self.directory, "capture", "request"), 1)
        state = module.read_state(self.directory)
        self.assertEqual(state["answer"], "")
        self.assertEqual(state["error"], "denied")
        self.assertFalse(state["busy"])

    def test_cancelled_capture_releases_lock_and_can_start_again(self):
        self.action()
        with patch.object(module, "capture_screen", side_effect=module.Cancelled):
            self.assertEqual(module.run_action(self.directory, "capture", "request"), 0)
        self.assertFalse(module.locked(self.directory))
        self.assertEqual(module.read_state(self.directory)["phase"], "idle")

    def test_codex_uses_noninteractive_image_and_preserves_code_indent(self):
        action = self.action()
        program = self.directory / "fake-codex"
        program.write_text('''#!/usr/bin/python
import json, pathlib, sys
args = sys.argv[1:]
pathlib.Path("invocation.json").write_text(json.dumps({"args": args, "prompt": sys.stdin.read()}))
pathlib.Path(args[args.index("--output-last-message") + 1]).write_text("    return 42\\n")
''')
        program.chmod(0o700)
        with patch.object(module.shutil, "which", return_value=str(program)):
            answer = module.codex_answer(action, self.directory / "image.png", "Explain $HOME and `id`", self.directory)
        self.assertEqual(answer, "    return 42")
        invocation = json.loads((self.directory / "invocation.json").read_text())
        self.assertIn("--image", invocation["args"])
        self.assertIn("read-only", invocation["args"])
        self.assertNotIn("Explain $HOME and `id`", invocation["args"])
        self.assertIn("Explain $HOME and `id`", invocation["prompt"])

    def test_codex_cancellation_terminates_child(self):
        action = self.action()
        program = self.directory / "fake-codex"
        program.write_text("#!/usr/bin/python\nimport time\ntime.sleep(20)\n")
        program.chmod(0o700)
        popen = subprocess.Popen
        children = []

        def launch(*args, **kwargs):
            child = popen(*args, **kwargs)
            children.append(child)
            return child

        with patch.object(module.shutil, "which", return_value=str(program)), \
                patch.object(module.subprocess, "Popen", side_effect=launch), \
                patch.object(action, "pause", side_effect=module.Cancelled):
            with self.assertRaises(module.Cancelled):
                module.codex_answer(action, self.directory / "image.png", "request", self.directory)
        self.assertIsNotNone(children[0].poll())

    def test_capture_rejects_empty_and_oversized_prompt_before_desktop_access(self):
        for prompt in ("", " \n\t", "a" * 8001):
            with self.subTest(length=len(prompt)), patch.object(module, "capture_screen") as screen:
                with self.assertRaisesRegex(ValueError, "1 and 8000"):
                    module.capture(self.action(), prompt)
                screen.assert_not_called()

    def test_capture_accepts_maximum_prompt_and_removes_temporary_image_copy(self):
        action = self.action()
        screenshots = []

        def screen(_action, destination):
            screenshots.append(destination)
            destination.write_bytes(b"synthetic image fixture")

        with patch.object(module, "capture_screen", side_effect=screen), \
                patch.object(module, "codex_answer", return_value="answer") as model:
            module.capture(action, "a" * 8000)
        self.assertEqual(model.call_args.args[2], "a" * 8000)
        self.assertFalse(screenshots[0].exists())
        self.assertFalse(screenshots[0].parent.exists())
        self.assertEqual(action.state["answer"], "answer")
        self.assertEqual(action.state["phase"], "ready")

    def test_typing_size_boundary_rejects_oversized_text_before_input(self):
        module.validate_typing("a" * module.MAX_ANSWER)
        with patch.object(module.subprocess, "run") as run:
            with self.assertRaises(ValueError):
                module.type_answer(self.action("a" * (module.MAX_ANSWER + 1)))
        run.assert_not_called()

    def test_missing_typing_service_fails_before_focus_handoff_or_input(self):
        action = self.action("answer")
        action.state.update(canType=False, typeReason="Input service unavailable")
        with patch.object(module, "focused_application") as focus, patch.object(module.subprocess, "run") as run:
            with self.assertRaisesRegex(ValueError, "Input service unavailable"):
                module.type_answer(action)
        focus.assert_not_called()
        run.assert_not_called()

    def test_missing_capture_service_fails_before_desktop_access(self):
        action = self.action()
        action.state.update(canCapture=False, captureReason="Model service unavailable")
        with patch.object(module, "capture_screen") as screen:
            with self.assertRaisesRegex(ValueError, "Model service unavailable"):
                module.capture(action, "request")
        screen.assert_not_called()

    def test_focus_service_failure_blocks_typing(self):
        with patch.object(module, "native_state", side_effect=RuntimeError("unavailable")):
            with self.assertRaisesRegex(ValueError, "check app focus"):
                module.focused_application()

    def test_cancellation_during_countdown_sends_no_input_and_preserves_answer(self):
        self.action("answer")

        def pause(action, duration):
            if duration == 1:
                (self.directory / "cancel").write_text(action.operation)
                action.check()

        with patch.object(module.Action, "pause", new=pause), \
                patch.object(module, "focused_application", return_value=9), \
                patch.object(module.subprocess, "run") as run:
            self.assertEqual(module.run_action(self.directory, "type", ""), 0)
        run.assert_not_called()
        state = module.read_state(self.directory)
        self.assertEqual(state["answer"], "answer")
        self.assertEqual(state["phase"], "ready")
        self.assertIn("Cancelled", state["message"])
        self.assertFalse(module.locked(self.directory))

    def test_cancellation_after_first_typed_chunk_prevents_remaining_chunks(self):
        self.action("abcdefghijklmnop")

        def typed(command, **kwargs):
            state = module.read_state(self.directory)
            (self.directory / "cancel").write_text(state["operationId"])
            return subprocess.CompletedProcess(command, 0)

        with patch.object(module.Action, "pause"), \
                patch.object(module, "focused_application", return_value=9), \
                patch.object(module.subprocess, "run", side_effect=typed) as run:
            self.assertEqual(module.run_action(self.directory, "type", ""), 0)
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.kwargs["input"], b"abcdefgh")
        self.assertIn("Cancelled", module.read_state(self.directory)["message"])

    def test_fenced_model_code_preserves_internal_indentation(self):
        program = self.model_program("```python\n    if ok:\n        return 42\n```\n")
        with patch.object(module.shutil, "which", return_value=str(program)):
            answer = module.codex_answer(self.action(), self.directory / "image.png", "request", self.directory)
        self.assertEqual(answer, "    if ok:\n        return 42")

    def test_model_missing_empty_and_oversized_outputs_are_rejected(self):
        for answer, create, message in (("", False, "supported size"),
                                        (" \n\t", True, "empty answer"),
                                        ("x" * (module.MAX_ANSWER + 1), True, "supported size")):
            with self.subTest(length=len(answer), create=create):
                (self.directory / "answer.txt").unlink(missing_ok=True)
                program = self.model_program(answer, create_answer=create)
                with patch.object(module.shutil, "which", return_value=str(program)):
                    with self.assertRaisesRegex(ValueError, message):
                        module.codex_answer(self.action(), self.directory / "image.png", "request", self.directory)

    def test_model_nonzero_exit_is_rejected_even_when_answer_file_exists(self):
        program = self.model_program("partial answer", exit_code=1)
        with patch.object(module.shutil, "which", return_value=str(program)):
            with self.assertRaisesRegex(ValueError, "Codex failed"):
                module.codex_answer(self.action(), self.directory / "image.png", "request", self.directory)

    def test_model_deadline_terminates_child(self):
        program = self.directory / "fake-codex"
        program.write_text("#!/usr/bin/python\nimport sys, time\nsys.stdin.read()\ntime.sleep(20)\n")
        program.chmod(0o700)
        popen = subprocess.Popen
        children = []

        def launch(*args, **kwargs):
            child = popen(*args, **kwargs)
            children.append(child)
            return child

        with patch.object(module.shutil, "which", return_value=str(program)), \
                patch.object(module.subprocess, "Popen", side_effect=launch), \
                patch.object(module.time, "monotonic", side_effect=[0, 241]), \
                patch.object(module.Action, "pause"):
            with self.assertRaisesRegex(ValueError, "timed out"):
                module.codex_answer(self.action(), self.directory / "image.png", "request", self.directory)
        self.assertIsNotNone(children[0].poll())

    def test_auto_capture_types_complete_new_answer_in_same_request(self):
        self.action("old answer")
        answer = 'def example():\n    return "\\n $HOME `id`"\n'
        with patch.object(module.Action, "pause"), \
                patch.object(module, "focused_application", return_value=9), \
                patch.object(module, "capture_screen"), \
                patch.object(module, "codex_answer", return_value=answer), \
                patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
            self.assertEqual(module.run_action(self.directory, "capture", "request", "auto-1", auto_type=True, typing_mode="preserve"), 0)
        self.assertEqual(b"".join(call.kwargs["input"] for call in run.call_args_list), answer.encode())
        state = module.read_state(self.directory)
        self.assertEqual(state["operationId"], "auto-1")
        self.assertEqual(state["answer"], answer)
        self.assertEqual(state["phase"], "ready")
        self.assertIn("typed", state["message"])
        self.assertFalse(module.locked(self.directory))

    def test_manual_capture_never_starts_typing(self):
        with patch.object(module, "capture_screen"), \
                patch.object(module, "codex_answer", return_value="new answer"), \
                patch.object(module, "type_answer") as type_answer:
            self.assertEqual(module.run_action(self.directory, "capture", "request"), 0)
        type_answer.assert_not_called()

    def test_auto_capture_requires_typing_service_before_capturing(self):
        with patch.object(module, "capabilities", return_value={**CAPS, "canType": False, "typeReason": "Input unavailable"}), \
                patch.object(module, "capture_screen") as screen, \
                patch.object(module.subprocess, "run") as run:
            self.assertEqual(module.run_action(self.directory, "capture", "request", auto_type=True), 1)
        screen.assert_not_called()
        run.assert_not_called()
        self.assertEqual(module.read_state(self.directory)["error"], "Input unavailable")

    def test_auto_capture_requires_focused_editor_before_capturing(self):
        with patch.object(module.Action, "pause"), \
                patch.object(module, "focused_application", side_effect=ValueError("Focus an editor")), \
                patch.object(module, "capture_screen") as screen:
            self.assertEqual(module.run_action(self.directory, "capture", "request", auto_type=True), 1)
        screen.assert_not_called()

    def test_auto_capture_does_not_type_if_focus_changed_during_inference(self):
        with patch.object(module.Action, "pause"), \
                patch.object(module, "focused_application", side_effect=[9, 10]), \
                patch.object(module, "capture_screen"), \
                patch.object(module, "codex_answer", return_value="new answer"), \
                patch.object(module.subprocess, "run") as run:
            self.assertEqual(module.run_action(self.directory, "capture", "request", auto_type=True), 1)
        run.assert_not_called()
        state = module.read_state(self.directory)
        self.assertEqual(state["answer"], "new answer")
        self.assertIn("focus changed", state["error"])

    def test_auto_capture_does_not_type_if_focus_changed_during_countdown(self):
        with patch.object(module.Action, "pause"), \
                patch.object(module, "focused_application", side_effect=[9, 9, 10]), \
                patch.object(module, "capture_screen"), \
                patch.object(module, "codex_answer", return_value="new answer"), \
                patch.object(module.subprocess, "run") as run:
            self.assertEqual(module.run_action(self.directory, "capture", "request", auto_type=True), 1)
        run.assert_not_called()

    def test_auto_capture_failure_never_types_previous_answer(self):
        self.action("old answer")
        with patch.object(module.Action, "pause"), \
                patch.object(module, "focused_application", return_value=9), \
                patch.object(module, "capture_screen"), \
                patch.object(module, "codex_answer", side_effect=ValueError("Model unavailable")), \
                patch.object(module.subprocess, "run") as run:
            self.assertEqual(module.run_action(self.directory, "capture", "request", auto_type=True), 1)
        run.assert_not_called()
        self.assertEqual(module.read_state(self.directory)["answer"], "")

    def test_auto_capture_unsupported_answer_is_kept_without_partial_input(self):
        with patch.object(module.Action, "pause"), \
                patch.object(module, "focused_application", return_value=9), \
                patch.object(module, "capture_screen"), \
                patch.object(module, "codex_answer", return_value="Unicode: café"), \
                patch.object(module.subprocess, "run") as run:
            self.assertEqual(module.run_action(self.directory, "capture", "request", auto_type=True), 1)
        run.assert_not_called()
        state = module.read_state(self.directory)
        self.assertEqual(state["answer"], "Unicode: café")
        self.assertIn("ASCII", state["error"])

    def test_auto_capture_can_be_cancelled_during_typing_countdown(self):
        def pause(action, duration):
            if duration == 1:
                (self.directory / "cancel").write_text(action.operation)
                action.check()

        with patch.object(module.Action, "pause", new=pause), \
                patch.object(module, "focused_application", return_value=9), \
                patch.object(module, "capture_screen"), \
                patch.object(module, "codex_answer", return_value="new answer"), \
                patch.object(module.subprocess, "run") as run:
            self.assertEqual(module.run_action(self.directory, "capture", "request", auto_type=True), 0)
        run.assert_not_called()
        state = module.read_state(self.directory)
        self.assertEqual(state["answer"], "new answer")
        self.assertIn("Cancelled", state["message"])
        self.assertFalse(module.locked(self.directory))

    def test_auto_capture_cancel_after_first_chunk_stops_remaining_input(self):
        def typed(command, **kwargs):
            state = module.read_state(self.directory)
            (self.directory / "cancel").write_text(state["operationId"])
            return subprocess.CompletedProcess(command, 0)

        with patch.object(module.Action, "pause"), \
                patch.object(module, "focused_application", return_value=9), \
                patch.object(module, "capture_screen"), \
                patch.object(module, "codex_answer", return_value="abcdefghijklmnop"), \
                patch.object(module.subprocess, "run", side_effect=typed) as run:
            self.assertEqual(module.run_action(self.directory, "capture", "request", auto_type=True), 0)
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.kwargs["input"], b"abcdefgh")
        self.assertIn("Some text may already be entered", module.read_state(self.directory)["message"])


if __name__ == "__main__":
    unittest.main()
