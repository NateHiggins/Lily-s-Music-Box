"""Terminal presentation: wrapping, a typewriter, a spinner, and a scripted
stand-in for tests. No dependency beyond the standard library."""

from __future__ import annotations

import itertools
import os
import shutil
import sys
import textwrap
import threading
import time

RESET, DIM, BOLD, ITALIC = "\033[0m", "\033[2m", "\033[1m", "\033[3m"
AMBER, CYAN = "\033[38;5;179m", "\033[38;5;109m"


class Console:
    """The real terminal."""

    def __init__(self, *, fast: bool = False, plain: bool = False, dev: bool = False,
                 width: int | None = None):
        self.fast, self.dev_enabled = fast, dev
        for stream in (sys.stdout, sys.stderr):
            try:
                stream.reconfigure(encoding="utf-8", errors="replace")
            except (AttributeError, ValueError):
                pass
        self.tty = sys.stdout.isatty()
        self.interactive = self.tty and sys.stdin.isatty()     # a person is at the keyboard
        self.color = self.tty and not plain and not os.environ.get("NO_COLOR")
        if self.color and os.name == "nt":
            os.system("")                       # switches the Windows console to ANSI mode
        if not self.tty:
            self.fast = True
        columns = shutil.get_terminal_size((80, 24)).columns
        self.width = width or max(40, min(78, columns - 2))
        self._col = 0

    # ---- primitives --------------------------------------------------
    def _style(self, text: str, style: str) -> str:
        return f"{style}{text}{RESET}" if self.color and style else text

    def _write(self, text: str) -> None:
        sys.stdout.write(text)
        sys.stdout.flush()

    def _type(self, text: str, delay: float, style: str = "") -> None:
        if self.fast or delay <= 0:
            self._write(self._style(text, style))
            return
        if self.color and style:
            self._write(style)
        for ch in text:
            sys.stdout.write(ch)
            sys.stdout.flush()
            time.sleep(delay * (6 if ch in ".!?" else 3 if ch in ",;:" else 1))
        if self.color and style:
            self._write(RESET)

    def _wrap(self, text: str) -> str:
        paragraphs = [p.strip() for p in text.replace("\r", "").split("\n\n")]
        wrapped = [textwrap.fill(" ".join(p.split()), self.width) for p in paragraphs if p]
        return "\n\n".join(wrapped)

    # ---- what the game says ------------------------------------------
    def narrate(self, text: str) -> None:
        """The house speaking."""
        self._write("\n")
        self._type(self._wrap(text), 0.006)
        self._write("\n")

    def proprietor(self, text: str, slow: bool = True) -> None:
        """The reading: slower, and set apart."""
        self._write("\n")
        self._type(self._wrap(text), 0.018 if slow else 0.006, AMBER)
        self._write("\n")

    def card(self, title: str, text: str) -> None:
        self._write("\n")
        self._write(self._style(f"  [ {title.upper()} ]", BOLD + AMBER) + "\n")
        body = textwrap.fill(" ".join(text.split()), self.width - 2, initial_indent="  ", subsequent_indent="  ")
        self._type(body, 0.018, AMBER)
        self._write("\n")

    def banner(self, text: str) -> None:
        self._write("\n")
        self._type(text.center(self.width).rstrip(), 0.05, BOLD + AMBER)
        self._write("\n")

    def note(self, text: str) -> None:
        """Plain words from the program, outside the fiction."""
        self._write("\n" + self._style(self._wrap(text), DIM) + "\n")

    def plain(self, text: str) -> None:
        self._write(text + "\n")

    def raw(self, text: str) -> None:
        """Text that must reach the screen exactly as it is: never wrapped, styled or typed
        out, so that what is selected and copied is what was written."""
        self._write(text if text.endswith("\n") else text + "\n")

    def rule(self, label: str = "") -> None:
        line = f"---- {label} " if label else ""
        self._write("\n" + self._style(line + "-" * max(4, self.width - len(line)), DIM) + "\n")

    def dev(self, text: str) -> None:
        if self.dev_enabled:
            for line in text.splitlines():
                self._write(self._style(f"  . {line}", CYAN) + "\n")

    def pause(self, seconds: float) -> None:
        if not self.fast:
            time.sleep(seconds)

    def ask(self, prompt: str = "> ") -> str:
        self._write("\n")
        try:
            return input(self._style(prompt, BOLD))
        except KeyboardInterrupt:
            self._write("\n")
            raise

    def confirm(self, prompt: str, default: bool = False) -> bool:
        """A yes or no. Enter alone gives the default; anything unreadable gives no."""
        try:
            answer = input(self._style(prompt, BOLD)).strip().lower()
        except (EOFError, KeyboardInterrupt):
            return False
        if not answer:
            return default
        return answer in ("y", "yes")

    def hold(self, prompt: str = "Press Enter to close. ") -> None:
        """Keep a window that belongs to this program open until its reader is done."""
        try:
            input(self._style(prompt, DIM))
        except (EOFError, KeyboardInterrupt):
            pass

    # ---- streaming ---------------------------------------------------
    def stream_begin(self) -> None:
        self._write("\n")
        self._col = 0
        self._pending = ""
        self._newlines = 0

    def stream_text(self, delta: str) -> None:
        """Word-wrap text that arrives a few characters at a time."""
        self._pending += delta.replace("\r", "")
        while True:
            cut = -1
            for i, ch in enumerate(self._pending):
                if ch in " \n":
                    cut = i
                    break
            if cut < 0:
                return
            word, sep = self._pending[:cut], self._pending[cut]
            self._pending = self._pending[cut + 1:]
            self._emit_word(word)
            if sep == "\n":
                self._newlines += 1      # one is only a space; two or more start a paragraph

    def _emit_word(self, word: str) -> None:
        if not word:
            return
        if self._newlines >= 2 and self._col:
            self._write("\n\n")
            self._col = 0
        self._newlines = 0
        if self._col and self._col + 1 + len(word) > self.width:
            self._write("\n")
            self._col = 0
        if self._col:
            self._write(" ")
            self._col += 1
        self._write(word)
        self._col += len(word)

    def stream_end(self) -> None:
        self._emit_word(self._pending.strip())
        self._pending = ""
        self._write("\n")
        self._col = 0

    # ---- waiting -----------------------------------------------------
    def waiting(self, label: str = "") -> "_Spinner":
        return _Spinner(self, label)


class _Spinner:
    """A quiet mark that something is happening. Only on a real terminal."""

    def __init__(self, console: Console, label: str):
        self.console, self.label = console, label
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._shown = False

    def __enter__(self) -> "_Spinner":
        if self.console.tty and not self.console.fast:
            self._thread = threading.Thread(target=self._run, daemon=True)
            self._thread.start()
        return self

    def _run(self) -> None:
        if self._stop.wait(0.6):
            return
        self._shown = True
        for frame in itertools.cycle(("   ", ".  ", ".. ", "...")):
            text = f"\r  {self.label}{frame}"
            sys.stdout.write(self.console._style(text, DIM))
            sys.stdout.flush()
            if self._stop.wait(0.4):
                break

    def stop(self) -> None:
        """Clear the mark; safe to call more than once (the first streamed word calls it)."""
        if self._stop.is_set():
            return
        self._stop.set()
        if self._thread:
            self._thread.join()
        if self._shown:
            sys.stdout.write("\r" + " " * (len(self.label) + 8) + "\r")
            sys.stdout.flush()

    def __exit__(self, *exc) -> None:
        self.stop()


class ScriptedConsole:
    """A console for tests and simulations: inputs come from a list, output is kept."""

    tty, color, fast, interactive = False, False, True, False

    def __init__(self, inputs=None, dev: bool = False, echo: bool = False, confirms=None):
        self.inputs = list(inputs or [])
        self.confirms = list(confirms or [])        # answers to yes-or-no questions, in order; then no
        self.out: list[tuple[str, str]] = []
        self.dev_enabled, self.echo = dev, echo
        self.width = 78
        self._stream = ""

    def _add(self, kind: str, text: str) -> None:
        self.out.append((kind, text))
        if self.echo:
            print(f"[{kind}] {text}")

    def narrate(self, text): self._add("narrate", text)
    def proprietor(self, text, slow=True): self._add("proprietor", text)
    def card(self, title, text): self._add("card", f"{title}: {text}")
    def banner(self, text): self._add("banner", text)
    def note(self, text): self._add("note", text)
    def plain(self, text): self._add("plain", text)
    def raw(self, text): self._add("raw", text)
    def rule(self, label=""): self._add("rule", label)
    def pause(self, seconds): pass
    def hold(self, prompt=""): pass

    def confirm(self, prompt, default=False):
        self._add("confirm", prompt)
        return self.confirms.pop(0) if self.confirms else False

    def dev(self, text):
        if self.dev_enabled:
            self._add("dev", text)

    def ask(self, prompt: str = "> ") -> str:
        if not self.inputs:
            raise EOFError
        value = self.inputs.pop(0)
        self._add("input", value)
        return value

    def stream_begin(self): self._stream = ""
    def stream_text(self, delta): self._stream += delta
    def stream_end(self): self._add("narrate", self._stream.strip())

    def waiting(self, label: str = ""):
        return _NoSpinner()

    def text(self, kinds=("narrate", "proprietor", "card", "banner")) -> str:
        return "\n".join(t for k, t in self.out if k in kinds)


class _NoSpinner:
    def __enter__(self): return self
    def __exit__(self, *exc): pass
    def stop(self): pass
