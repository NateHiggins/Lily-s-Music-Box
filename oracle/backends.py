"""Where the house gets its voice.

The engine asks for one thing: `complete(system, prompt)` returning text. Four
ways to answer are provided, plus none at all:

- anthropic : the Anthropic API through the official `anthropic` SDK
- claude    : the Claude Code command line (`claude -p`), using its own login
- codex     : the Codex command line (`codex exec`), using its own login
- command   : any program that reads a prompt on stdin and writes text to stdout
- offline   : no model; the authored rooms are played from the page

`auto` tries them in that order and uses the first that answers. A backend that
is installed but not signed in fails its first call and the next one is tried,
so the night starts with whatever actually works on this machine.

With any backend except offline, what the player types is sent to that model to
be answered. The game says so before it starts.
"""

from __future__ import annotations

import glob
import json
import os
import shlex
import shutil
import subprocess
import tempfile
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_ANTHROPIC_MODEL = "claude-opus-5-5"
EFFORT = {"turn": "low", "design": "high", "prophecy": "medium", "repair": "low"}
TIMEOUT = {"turn": 180, "design": 600, "prophecy": 420, "repair": 300}
MAX_TOKENS = {"turn": 6000, "design": 24000, "prophecy": 12000, "repair": 12000}

TEXT_ONLY_PREFACE = (
    "You are being used as a text generator inside another program. Do not run commands, "
    "read files, call tools or ask questions. Reply with the requested output only, in the "
    "exact format the instructions specify.\n\n")


class BackendError(Exception):
    """kind: auth | unavailable | timeout | refused | other"""

    def __init__(self, kind: str, message: str):
        super().__init__(message)
        self.kind = kind


@dataclass
class Completion:
    text: str
    model: str = ""
    usage: dict = field(default_factory=dict)
    latency: float = 0.0
    backend: str = ""


class Backend:
    name = "backend"
    label = "a language model"
    streams = False

    def complete(self, system: str, prompt: str, *, purpose: str = "turn", on_delta=None) -> Completion:
        raise NotImplementedError


# ---------------------------------------------------------------------------
# Running a child process with a deadline
# ---------------------------------------------------------------------------

def _run(cmd: list[str], stdin_text: str, timeout: float, cwd: str | None = None, on_line=None,
         env: dict | None = None) -> tuple[int, str, str, bool]:
    try:
        proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                text=True, encoding="utf-8", errors="replace", cwd=cwd, env=env)
    except (OSError, ValueError) as exc:
        raise BackendError("unavailable", f"could not start {cmd[0]}: {exc}") from exc
    timed_out = threading.Event()

    def kill() -> None:
        timed_out.set()
        try:
            proc.kill()
        except OSError:
            pass

    timer = threading.Timer(timeout, kill)
    timer.start()
    err_chunks: list[str] = []
    err_thread = threading.Thread(target=lambda: err_chunks.append(proc.stderr.read()), daemon=True)
    err_thread.start()

    def feed() -> None:
        try:
            proc.stdin.write(stdin_text)
            proc.stdin.close()
        except (OSError, ValueError):
            pass

    in_thread = threading.Thread(target=feed, daemon=True)
    in_thread.start()
    out_lines: list[str] = []
    try:
        for line in proc.stdout:
            out_lines.append(line)
            if on_line:
                on_line(line)
        proc.wait()
    finally:
        timer.cancel()
    err_thread.join(timeout=5)
    return proc.returncode, "".join(out_lines), "".join(err_chunks), timed_out.is_set()


def _looks_like_auth(text: str) -> bool:
    low = text.lower()
    return any(w in low for w in ("authenticate", "oauth", "not logged in", "login", "log in", "sign in",
                                  "unauthorized", "401", "api key", "credential"))


# ---------------------------------------------------------------------------
# Anthropic API (official SDK)
# ---------------------------------------------------------------------------

class AnthropicBackend(Backend):
    name = "anthropic"
    label = "Claude, through the Anthropic API"
    streams = True

    def __init__(self, model: str | None = None):
        try:
            import anthropic
        except ImportError as exc:
            raise BackendError("unavailable", "the anthropic package is not installed "
                                              "(pip install anthropic)") from exc
        self._sdk = anthropic
        self.model = model or DEFAULT_ANTHROPIC_MODEL
        try:
            self.client = anthropic.Anthropic()
        except Exception as exc:                    # no credentials in the environment
            raise BackendError("auth", f"no Anthropic credentials: {exc}") from exc

    def complete(self, system, prompt, *, purpose="turn", on_delta=None) -> Completion:
        sdk = self._sdk
        started = time.time()
        chunks: list[str] = []

        def consume(stream):
            for text in stream.text_stream:
                chunks.append(text)
                if on_delta:
                    on_delta(text)
            return stream.get_final_message()

        base = dict(
            model=self.model,
            max_tokens=MAX_TOKENS.get(purpose, 6000),
            # The system prompt is identical on every turn of a night, so it is cached.
            system=[{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}],
            messages=[{"role": "user", "content": prompt}],
        )
        try:
            try:
                # Thinking is adaptive by default on current models; depth is set with effort.
                # A declined request is re-run on Anthropic's recommended fallback model.
                with self.client.beta.messages.stream(
                        **base, output_config={"effort": EFFORT.get(purpose, "medium")},
                        betas=["server-side-fallback-2026-07-01"],
                        extra_body={"fallbacks": "default"}) as stream:
                    final = consume(stream)
            except sdk.BadRequestError:
                if chunks:
                    raise
                # An older model or platform that rejects effort or fallbacks: ask plainly.
                with self.client.messages.stream(**base) as stream:
                    final = consume(stream)
        except sdk.AuthenticationError as exc:
            raise BackendError("auth", str(exc)) from exc
        except sdk.PermissionDeniedError as exc:
            raise BackendError("auth", str(exc)) from exc
        except sdk.RateLimitError as exc:
            raise BackendError("unavailable", str(exc)) from exc
        except sdk.APIConnectionError as exc:
            raise BackendError("unavailable", str(exc)) from exc
        except sdk.APIStatusError as exc:
            kind = "unavailable" if getattr(exc, "status_code", 500) >= 500 else "other"
            raise BackendError(kind, str(exc)) from exc
        if final.stop_reason == "refusal":
            raise BackendError("refused", "the model declined this request")
        text = "".join(block.text for block in final.content if block.type == "text")
        usage = {}
        if getattr(final, "usage", None) is not None:
            usage = {k: getattr(final.usage, k, None)
                     for k in ("input_tokens", "output_tokens", "cache_read_input_tokens",
                               "cache_creation_input_tokens")}
        return Completion(text=text, model=getattr(final, "model", self.model), usage=usage,
                          latency=time.time() - started, backend=self.name)


# ---------------------------------------------------------------------------
# Claude Code command line
# ---------------------------------------------------------------------------

def find_claude_binaries() -> list[str]:
    found: list[str] = []
    override = os.environ.get("ORACLE_CLAUDE_BIN")
    if override:
        return [override]
    patterns = []
    local = os.environ.get("LOCALAPPDATA")
    roaming = os.environ.get("APPDATA")
    if local:
        patterns.append(os.path.join(local, "Packages", "Claude_*", "LocalCache", "Roaming", "Claude",
                                     "claude-code", "*", "*", "claude.exe"))
    if roaming:
        patterns.append(os.path.join(roaming, "Claude", "claude-code", "*", "*", "claude.exe"))
    patterns.append(os.path.expanduser("~/.claude/local/claude"))
    patterns.append(os.path.expanduser("~/.local/bin/claude"))
    bundled: list[str] = []
    for pattern in patterns:
        bundled.extend(glob.glob(pattern))
    bundled.sort(key=lambda p: os.path.getmtime(p) if os.path.exists(p) else 0, reverse=True)
    on_path = shutil.which("claude")
    for candidate in ([on_path] if on_path else []) + bundled:
        if candidate and candidate not in found:
            found.append(candidate)
    return found


class ClaudeCliBackend(Backend):
    name = "claude"
    label = "Claude, through the Claude Code command line"
    streams = True

    def __init__(self, model: str | None = None, binaries: list[str] | None = None):
        self.model = model
        self.binaries = binaries if binaries is not None else find_claude_binaries()
        if not self.binaries:
            raise BackendError("unavailable", "no claude command found")

    def complete(self, system, prompt, *, purpose="turn", on_delta=None) -> Completion:
        last: BackendError | None = None
        for binary in list(self.binaries):
            try:
                return self._complete_with(binary, system, prompt, purpose, on_delta)
            except BackendError as exc:
                last = exc
                if exc.kind == "unavailable" and len(self.binaries) > 1:
                    self.binaries.remove(binary)        # a broken install; try the next one
                    continue
                raise
        raise last or BackendError("unavailable", "no claude command worked")

    def _complete_with(self, binary, system, prompt, purpose, on_delta) -> Completion:
        started = time.time()
        with tempfile.TemporaryDirectory(prefix="blankdeck-") as tmp:
            sysfile = Path(tmp) / "system.md"
            sysfile.write_text(system, encoding="utf-8")
            cmd = [binary, "-p", "--output-format", "stream-json", "--verbose",
                   "--include-partial-messages", "--no-session-persistence", "--safe-mode",
                   "--tools", "", "--system-prompt-file", str(sysfile),
                   "--effort", EFFORT.get(purpose, "medium")]
            if self.model:
                cmd += ["--model", self.model]
            result: dict = {}
            streamed: list[str] = []

            def on_line(line: str) -> None:
                line = line.strip()
                if not line.startswith("{"):
                    return
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    return
                if event.get("type") == "stream_event":
                    delta = (event.get("event") or {}).get("delta") or {}
                    if delta.get("type") == "text_delta" and delta.get("text"):
                        streamed.append(delta["text"])
                        if on_delta:
                            on_delta(delta["text"])
                elif event.get("type") == "result":
                    result.update(event)

            code, out, err, timed_out = _run(cmd, prompt, TIMEOUT.get(purpose, 180), cwd=tmp, on_line=on_line)
        if timed_out:
            raise BackendError("timeout", "the claude command took too long")
        if not result:
            # It never spoke the protocol: a broken or incompatible install, unless it says it
            # wants a login. Either way this binary cannot narrate; another one might.
            detail = (err or out).strip()[-400:]
            raise BackendError("auth" if _looks_like_auth(detail) else "unavailable",
                               detail or f"claude exited with code {code}")
        if result.get("is_error"):
            message = str(result.get("result", ""))
            raise BackendError("auth" if _looks_like_auth(message) else "other", message)
        text = result.get("result") or "".join(streamed)
        return Completion(text=text, model=self.model or "", usage=result.get("usage") or {},
                          latency=time.time() - started, backend=self.name)


# ---------------------------------------------------------------------------
# Codex command line
# ---------------------------------------------------------------------------

def find_codex_binaries() -> list[str]:
    override = os.environ.get("ORACLE_CODEX_BIN")
    if override:
        return [override]
    found: list[str] = []
    on_path = shutil.which("codex")
    bundled: list[str] = []
    local = os.environ.get("LOCALAPPDATA")
    if local:
        bundled.extend(glob.glob(os.path.join(local, "OpenAI", "Codex", "bin", "*", "codex.exe")))
    bundled.sort(key=lambda p: os.path.getmtime(p) if os.path.exists(p) else 0, reverse=True)
    for candidate in ([on_path] if on_path else []) + bundled:
        if candidate and candidate not in found:
            found.append(candidate)
    return found


class CodexCliBackend(Backend):
    name = "codex"
    label = "the Codex command line"
    streams = False
    # The narrator needs quick, light turns; the user's own Codex defaults may be set for
    # long engineering work, so effort and sandbox are stated on every call.
    effort = {"turn": "low", "design": "medium", "prophecy": "low", "repair": "low"}

    def __init__(self, model: str | None = None, binaries: list[str] | None = None):
        self.model = model
        self.binaries = binaries if binaries is not None else find_codex_binaries()
        if not self.binaries:
            raise BackendError("unavailable", "no codex command found")

    def complete(self, system, prompt, *, purpose="turn", on_delta=None) -> Completion:
        started = time.time()
        binary = self.binaries[0]
        with tempfile.TemporaryDirectory(prefix="blankdeck-") as tmp:
            outfile = Path(tmp) / "last_message.txt"
            cmd = [binary, "exec", "--skip-git-repo-check", "--ephemeral", "--sandbox", "read-only",
                   "--color", "never", "-c", f'model_reasoning_effort="{self.effort.get(purpose, "low")}"',
                   "-C", tmp, "-o", str(outfile)]
            if self.model:
                cmd += ["-m", self.model]
            cmd.append("-")
            full = f"{TEXT_ONLY_PREFACE}{system}\n\n---\n\n{prompt}"
            code, out, err, timed_out = _run(cmd, full, TIMEOUT.get(purpose, 180), cwd=tmp)
            text = outfile.read_text(encoding="utf-8", errors="replace") if outfile.is_file() else ""
        if timed_out:
            raise BackendError("timeout", "the codex command took too long")
        if code != 0 or not text.strip():
            detail = (err or out).strip()[-400:]
            raise BackendError("auth" if _looks_like_auth(detail) else "other",
                               detail or f"codex exited with code {code}")
        usage = {}
        for line in (err + "\n" + out).splitlines():
            if line.strip().lower().startswith("tokens used"):
                usage = {"note": line.strip()}
        return Completion(text=text, model=self.model or "", usage=usage,
                          latency=time.time() - started, backend=self.name)


# ---------------------------------------------------------------------------
# Any command
# ---------------------------------------------------------------------------

class CommandBackend(Backend):
    name = "command"
    label = "a command you configured"

    def __init__(self, command: str):
        if not command:
            raise BackendError("unavailable", "--backend command needs --backend-cmd")
        self.cmd = [p[1:-1] if len(p) >= 2 and p[0] == p[-1] and p[0] in "\"'" else p
                    for p in shlex.split(command, posix=(os.name != "nt"))]

    def complete(self, system, prompt, *, purpose="turn", on_delta=None) -> Completion:
        started = time.time()
        code, out, err, timed_out = _run(self.cmd, f"{system}\n\n---\n\n{prompt}", TIMEOUT.get(purpose, 180))
        if timed_out:
            raise BackendError("timeout", "the command took too long")
        if code != 0 or not out.strip():
            raise BackendError("other", (err or out).strip()[-400:] or f"exit code {code}")
        return Completion(text=out, latency=time.time() - started, backend=self.name)


# ---------------------------------------------------------------------------
# Choosing
# ---------------------------------------------------------------------------

def _anthropic_ready() -> tuple[bool, str]:
    try:
        import anthropic  # noqa: F401
    except ImportError:
        return False, "the anthropic package is not installed"
    if not (os.environ.get("ANTHROPIC_API_KEY") or os.environ.get("ANTHROPIC_AUTH_TOKEN")):
        return False, "no ANTHROPIC_API_KEY in the environment"
    return True, "SDK installed and credentials present"


def detect() -> list[dict]:
    """What is installed on this machine. Signed-in state is only known by trying."""
    ok, detail = _anthropic_ready()
    claude, codex = find_claude_binaries(), find_codex_binaries()
    return [
        {"name": "anthropic", "available": ok, "detail": detail},
        {"name": "claude", "available": bool(claude), "detail": claude[0] if claude else "not found"},
        {"name": "codex", "available": bool(codex), "detail": codex[0] if codex else "not found"},
        {"name": "offline", "available": True, "detail": "no model; authored rooms only"},
    ]


def make_backend(name: str, model: str | None = None, command: str | None = None) -> Backend | None:
    """Build one named backend. `offline` is None."""
    if name == "offline":
        return None
    if name == "anthropic":
        return AnthropicBackend(model)
    if name == "claude":
        return ClaudeCliBackend(model)
    if name == "codex":
        return CodexCliBackend(model)
    if name == "command":
        return CommandBackend(command or "")
    raise BackendError("unavailable", f"unknown backend {name!r}")


class AutoBackend(Backend):
    """Tries each installed backend in order and settles on the first that answers."""

    name = "auto"

    def __init__(self, model: str | None = None):
        self.chain: list[Backend] = []
        self.skipped: list[dict] = []
        if _anthropic_ready()[0]:
            self._try_add("anthropic", model)
        self._try_add("claude", model)
        self._try_add("codex", model)
        self.settled = False

    def _try_add(self, name: str, model: str | None) -> None:
        try:
            backend = make_backend(name, model)
        except BackendError as exc:
            self.skipped.append({"backend": name, "kind": exc.kind, "detail": str(exc)[:200]})
            return
        if backend is not None:
            self.chain.append(backend)

    @property
    def current(self) -> Backend | None:
        return self.chain[0] if self.chain else None

    @property
    def label(self) -> str:
        return self.current.label if self.current else "no model"

    @property
    def streams(self) -> bool:
        return bool(self.current and self.current.streams)

    def complete(self, system, prompt, *, purpose="turn", on_delta=None) -> Completion:
        while self.chain:
            backend = self.chain[0]
            try:
                done = backend.complete(system, prompt, purpose=purpose, on_delta=on_delta)
                self.settled = True
                return done
            except BackendError as exc:
                # Once a backend has answered, a single bad turn is not a reason to change voice.
                if self.settled and exc.kind in ("timeout", "refused", "other"):
                    raise
                self.skipped.append({"backend": backend.name, "kind": exc.kind, "detail": str(exc)[:200]})
                self.chain.pop(0)
                self.settled = False
        raise BackendError("unavailable", "no model backend answered")
