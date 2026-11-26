"""Formatting regressions with mocked input and a small simulated editor.

No live editor, screen capture, model request, or keyboard event is used here.
The simulation models one conventional C++ autoindent behavior; it does not
establish compatibility with any particular website's editor.
"""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("latto_codex", Path(__file__).with_name("latto-codex.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
CAPABILITIES = {"canCapture": True, "canType": True, "captureReason": "", "typeReason": ""}

CPP = (
    "class Solution {\n"
    "public:\n"
    "    int solve(int x) {\n"
    "        if (x) {\n"
    "            return x;\n"
    "        }\n"
    "        return 0;\n"
    "    }\n"
    "};\n"
)
SMART_CPP = (
    "class Solution {\n"
    "public:\n"
    "int solve(int x) {\n"
    "if (x) {\n"
    "return x;\n"
    "}\n"
    "return 0;\n"
    "}\n"
    "};\n"
)


def simulated_cpp_editor(characters):
    """Simulate copied indentation plus indent/outdent around C++ braces.

    Assumptions: Enter copies the current line's indentation, adds four spaces
    after an opening brace, and a closing brace on an otherwise blank line
    removes one indent level. Bracket insertion and field focus are not modeled.
    """
    lines = [""]
    for character in characters:
        if character == "\n":
            previous = lines[-1]
            indentation = previous[:len(previous) - len(previous.lstrip(" "))]
            if previous.rstrip().endswith("{"):
                indentation += "    "
            lines.append(indentation)
        else:
            if character == "}" and not lines[-1].strip():
                lines[-1] = lines[-1][:-4]
            lines[-1] += character
    return "\n".join(lines)


class FormattingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = Path(self.temporary.name)
        self.addCleanup(self.temporary.cleanup)
        capabilities = patch.object(module, "capabilities", return_value=CAPABILITIES)
        capabilities.start()
        self.addCleanup(capabilities.stop)
        output = contextlib.redirect_stdout(io.StringIO())
        output.__enter__()
        self.addCleanup(output.__exit__, None, None, None)

    def action(self, answer):
        module.atomic_write(self.directory / "state.json", json.dumps({"phase": "ready", "answer": answer}))
        return module.Action(self.directory)

    def input_patches(self):
        stack = contextlib.ExitStack()
        stack.enter_context(patch.object(module.Action, "pause"))
        stack.enter_context(patch.object(module, "focused_application", return_value=9))
        stack.enter_context(patch.object(module, "daemon_socket", return_value="/tmp/fake-input"))
        run = stack.enter_context(patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)))
        return stack, run

    def assert_input(self, run, expected):
        self.assertEqual(b"".join(call.kwargs["input"] for call in run.call_args_list), expected.encode("ascii"))
        for call in run.call_args_list:
            self.assertEqual(call.args[0][-2:], ["--file", "-"])

    def test_smart_removes_per_line_indentation_from_nested_cpp(self):
        self.assertEqual(module.prepare_typing_text(CPP), SMART_CPP)

    def test_smart_preserves_blank_lines_and_final_newline(self):
        self.assertEqual(module.prepare_typing_text("    a;   \n\n \t \n    b;\t\n"), "a;\n\n\nb;\n")
        self.assertEqual(module.prepare_typing_text(""), "")

    def test_smart_strips_mixed_indentation_but_retains_internal_spacing(self):
        self.assertEqual(module.prepare_typing_text("\t  int  x =  1;\t\n    \treturn  x;  "), "int  x =  1;\nreturn  x;")

    def test_smart_keeps_literals_backslashes_and_brackets(self):
        source = '    const char *s = "two  spaces \\n \\t $HOME `id`";  \n    foo(); arr = {};\n'
        expected = 'const char *s = "two  spaces \\n \\t $HOME `id`";\nfoo(); arr = {};\n'
        self.assertEqual(module.prepare_typing_text(source), expected)

    def test_preserve_keeps_python_dedents_and_multiline_string_whitespace(self):
        source = 'def f():\n    if ok:\n        return 1\n    return """\n  meaningful trailing spaces  \n    """\n'
        self.assertEqual(module.prepare_typing_text(source, "preserve"), source)

    def test_unknown_mode_is_rejected(self):
        with self.assertRaises(ValueError):
            module.prepare_typing_text(CPP, "unknown")

    def test_simulated_autoindent_reproduces_and_avoids_staircase(self):
        duplicated = simulated_cpp_editor(CPP)
        smart = simulated_cpp_editor(module.prepare_typing_text(CPP))
        duplicate_return = next(line for line in duplicated.splitlines() if "return x;" in line)
        smart_return = next(line for line in smart.splitlines() if "return x;" in line)
        self.assertEqual(smart_return, "            return x;")
        self.assertGreater(len(duplicate_return) - len(duplicate_return.lstrip()), 12)
        self.assertIn("    int solve(int x) {\n        if (x) {", smart)
        self.assertTrue(smart.endswith("};\n"))

    def test_manual_smart_typing_uses_transformed_stdin_and_original_preview(self):
        action = self.action(CPP)
        stack, run = self.input_patches()
        with stack:
            module.type_answer(action)
        self.assert_input(run, SMART_CPP)
        self.assertEqual(action.state["answer"], CPP)
        self.assertEqual(module.read_state(self.directory)["answer"], CPP)

    def test_manual_preserve_typing_sends_every_original_space(self):
        source = 'def f():\n    return "\\n"\n'
        action = self.action(source)
        stack, run = self.input_patches()
        with stack:
            module.type_answer(action, typing_mode="preserve")
        self.assert_input(run, source)
        self.assertEqual(action.state["answer"], source)

    def test_manual_request_routes_selected_typing_mode(self):
        for mode, expected in (("smart", SMART_CPP), ("preserve", CPP)):
            with self.subTest(mode=mode):
                self.action(CPP)
                stack, run = self.input_patches()
                with stack:
                    self.assertEqual(module.run_action(self.directory, "type", "", typing_mode=mode), 0)
                self.assert_input(run, expected)

    def test_automatic_capture_routes_selected_mode_and_preserves_preview(self):
        for mode, expected in (("smart", SMART_CPP), ("preserve", CPP)):
            with self.subTest(mode=mode):
                stack, run = self.input_patches()
                with stack, patch.object(module, "capture_screen"), patch.object(module, "codex_answer", return_value=CPP):
                    self.assertEqual(module.run_action(self.directory, "capture", "request", auto_type=True, typing_mode=mode), 0)
                self.assert_input(run, expected)
                self.assertEqual(module.read_state(self.directory)["answer"], CPP)

    def test_smart_cannot_hide_invalid_control_characters_before_validation(self):
        action = self.action("    int x;\n\x0b")
        stack, run = self.input_patches()
        with stack, self.assertRaises(ValueError):
            module.type_answer(action)
        run.assert_not_called()

    def test_whitespace_only_smart_output_sends_no_input(self):
        action = self.action(" \t \n ")
        stack, run = self.input_patches()
        with stack, self.assertRaises(ValueError):
            module.type_answer(action)
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
