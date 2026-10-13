import contextlib
import io
import unittest

from oracle.ui import Console, ScriptedConsole

TEXT = ("The stairs stop. One whole flight is simply not there, and across the gap someone has laid planks "
        "no thicker than playing cards.\n\nA painted hand points down a corridor: THE LONG WAY ROUND.")


class ConsoleTests(unittest.TestCase):
    def capture(self, fn, width=40):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            console = Console(fast=True, plain=True, width=width)
            fn(console)
        return out.getvalue()

    def test_streamed_text_is_wrapped_as_it_arrives(self):
        def run(console):
            console.stream_begin()
            for i in range(0, len(TEXT), 3):
                console.stream_text(TEXT[i:i + 3])
            console.stream_end()

        shown = self.capture(run)
        lines = shown.splitlines()
        self.assertTrue(all(len(line) <= 40 for line in lines), lines)
        self.assertEqual(shown.split(), TEXT.split())            # every word, in order
        self.assertIn("", lines[1:-1])                           # the paragraph break survives

    def test_narration_is_wrapped_and_plain_without_a_terminal(self):
        shown = self.capture(lambda console: console.narrate(TEXT))
        self.assertTrue(all(len(line) <= 40 for line in shown.splitlines()))
        self.assertNotIn("\033", shown)
        self.assertEqual(shown.split(), TEXT.split())

    def test_dev_lines_only_when_asked(self):
        quiet = self.capture(lambda console: console.dev("obs #1"))
        self.assertEqual(quiet, "")

    def test_scripted_console_feeds_inputs_and_keeps_output(self):
        ui = ScriptedConsole(["look", "go"])
        ui.narrate("A room.")
        self.assertEqual(ui.ask(), "look")
        self.assertEqual(ui.ask(), "go")
        with self.assertRaises(EOFError):
            ui.ask()
        self.assertEqual(ui.text(), "A room.")
        self.assertFalse(ui.confirm("PLAY? "))


if __name__ == "__main__":
    unittest.main()
