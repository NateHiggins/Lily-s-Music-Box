"""Handing the packet to an AI engineer, and telling the player the truth
about the build.

The builder is a separate program (Codex, Claude Code, or any command) started
in a fresh project directory that contains the packet. It is asked to append
one JSON line to `oracle_events.jsonl` each time something has actually
happened. This module tails that file and shows the player one line of the
fiction per real event:

    project_created  ->  A WORLD IS FORMING.
    test_failed      ->  THE WORLD HAS DIED.
    fixed            ->  THE WORLD IS BEING BORN AGAIN.

Nothing is shown on a timer and no stage is invented. An event that names a
proof file is withheld unless that file exists inside the project; events that
must have a proof are withheld without one; `fixed` is withheld unless a
failure was reported first; a fulfilled vision must name a card that was
actually dealt. What the builder reports without proof is shown on the
builder's word, and the build log is kept so that word can be checked.

A build is never started unless the player asks for one, and the finished game
is never launched without the player saying yes to the exact command.
"""

from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
import time
from pathlib import Path

from .backends import find_claude_binaries, find_codex_binaries
from .session import Session, games_dir

EVENTS_FILE = "oracle_events.jsonl"
RESULT_FILE = "BUILD_RESULT.json"
LOG_FILE = "oracle_build.log"

EVENT_LINES = {
    "packet_read": "OTHER HANDS HAVE TAKEN UP THE CARDS.",
    "covenant_written": "ITS LAWS ARE BEING WRITTEN.",
    "project_created": "A WORLD IS FORMING.",
    "first_run": "THE WORLD HAS OPENED ITS EYES.",
    "core_verb_playable": "THE CREATURES HAVE LEARNED HOW TO MOVE.",
    "loop_complete": "ONE WHOLE DAY HAS PASSED IN IT.",
    "test_failed": "THE WORLD HAS DIED.",
    "fixed": "THE WORLD IS BEING BORN AGAIN.",
    "tests_passing": "THE FUTURE NOW RUNS WITHOUT ERROR.",
    "vision_fulfilled": "A CARD HAS COME TRUE: {card}.",
    "done": "IT IS FINISHED.",
}
NEEDS_PROOF = {"covenant_written", "project_created", "first_run", "tests_passing"}
REPEATABLE = {"test_failed", "fixed", "vision_fulfilled"}
FAILED_LINE = "THE WORLD DID NOT HOLD."


class BuildError(Exception):
    pass


def builder_command(preset: str, project: Path, command: str | None = None) -> tuple[list[str], str]:
    """The command line for a builder, and a plain statement of what it is allowed to do."""
    if preset == "codex":
        binaries = find_codex_binaries()
        if not binaries:
            raise BuildError("no codex command found")
        return ([binaries[0], "exec", "--skip-git-repo-check", "--sandbox", "workspace-write",
                 "--color", "never", "-C", str(project), "-"],
                "Codex, sandboxed to write only inside the project directory")
    if preset == "claude":
        binaries = find_claude_binaries()
        if not binaries:
            raise BuildError("no claude command found")
        return ([binaries[0], "-p", "--permission-mode", "acceptEdits",
                 "--allowedTools", "Read Edit Write Glob Grep Bash"],
                "Claude Code, allowed to edit files and run commands in the project directory")
    if preset == "command":
        if not command:
            raise BuildError("--build command needs --builder-cmd")
        parts = [p[1:-1] if len(p) >= 2 and p[0] == p[-1] and p[0] in "\"'" else p
                 for p in shlex.split(command, posix=(os.name != "nt"))]
        return ([p.replace("{project}", str(project)) for p in parts], "the command you configured")
    raise BuildError(f"unknown builder {preset!r}")


class EventReader:
    """Reads the builder's event file and decides which lines the player may be shown."""

    def __init__(self, project: Path, cards: list[str]):
        self.project = project.resolve()
        self.cards = {c.lower().strip(): c for c in cards}
        self.offset = 0
        self.shown: list[dict] = []
        self.withheld: list[dict] = []
        self._seen: set[str] = set()
        self._failures_open = 0

    def _proof_ok(self, proof) -> bool:
        if not isinstance(proof, str) or not proof.strip():
            return False
        try:
            target = (self.project / proof).resolve()
            target.relative_to(self.project)
        except (ValueError, OSError):
            return False
        return target.exists()

    def poll(self) -> list[str]:
        """New lines to show, in order."""
        path = self.project / EVENTS_FILE
        if not path.is_file():
            return []
        with path.open("rb") as fh:
            fh.seek(self.offset)
            data = fh.read()
        if not data.endswith(b"\n"):                     # a line still being written
            data = data[:data.rfind(b"\n") + 1]
        self.offset += len(data)
        lines = []
        for raw in data.decode("utf-8", errors="replace").splitlines():
            raw = raw.strip()
            if not raw:
                continue
            try:
                event = json.loads(raw)
            except json.JSONDecodeError:
                self.withheld.append({"raw": raw[:200], "why": "not JSON"})
                continue
            line = self._judge(event)
            if line:
                lines.append(line)
        return lines

    def _judge(self, event) -> str | None:
        name = event.get("event") if isinstance(event, dict) else None
        if name not in EVENT_LINES:
            self.withheld.append({"event": event, "why": "unrecognised event"})
            return None
        if name not in REPEATABLE and name in self._seen:
            self.withheld.append({"event": event, "why": "already shown"})
            return None
        if "proof" in event or name in NEEDS_PROOF:
            if not self._proof_ok(event.get("proof")):
                self.withheld.append({"event": event, "why": "proof file missing"})
                return None
        if name == "test_failed":
            self._failures_open += 1
        if name == "fixed":
            if self._failures_open <= 0:
                self.withheld.append({"event": event, "why": "nothing had failed"})
                return None
            self._failures_open -= 1
        if name == "done" and not (self.project / RESULT_FILE).is_file():
            self.withheld.append({"event": event, "why": f"{RESULT_FILE} not written"})
            return None
        text = EVENT_LINES[name]
        if name == "vision_fulfilled":
            card = self.cards.get(str(event.get("card", "")).lower().strip())
            if not card or f"vision:{card}" in self._seen:
                self.withheld.append({"event": event, "why": "not a card that was dealt, or already shown"})
                return None
            self._seen.add(f"vision:{card}")
            text = text.replace("{card}", card.upper())
        self._seen.add(name)
        self.shown.append({"event": event, "line": text, "at": time.time()})
        return text


def read_result(project: Path) -> dict | None:
    path = project / RESULT_FILE
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def run_build(session: Session, ui, *, preset: str, command: str | None = None,
              project_dir: str | None = None, timeout_minutes: float = 120.0,
              poll_seconds: float = 1.0) -> dict:
    """Start the builder on the packet and show its real progress. Returns a record."""
    if not session.packet_dir or not Path(session.packet_dir).is_dir():
        raise BuildError("there is no packet to build from; finish a night first")
    project = Path(project_dir) if project_dir else games_dir() / session.id
    project.mkdir(parents=True, exist_ok=True)
    shutil.copytree(session.packet_dir, project / "oracle_packet", dirs_exist_ok=True)
    prompt = (project / "oracle_packet" / "BUILDER_PROMPT.md").read_text(encoding="utf-8")
    cmd, authority = builder_command(preset, project, command)
    cards = [v["card"] for v in (session.synthesis or {}).get("prophecy", {}).get("visions", [])]
    reader = EventReader(project, cards)
    log_path = project / LOG_FILE
    ui.note(f"The deck goes to the builder: {authority}. Project: {project}. Build log: {log_path}. "
            f"Lines in capitals below are things the builder reports as done; nothing is shown on a timer.")
    started = time.time()
    record = {"preset": preset, "command": cmd, "project": str(project), "log": str(log_path),
              "prompt": prompt, "started": started}
    with log_path.open("w", encoding="utf-8", errors="replace") as log:
        try:
            proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=log, stderr=subprocess.STDOUT,
                                    cwd=str(project), text=True, encoding="utf-8", errors="replace")
        except (OSError, ValueError) as exc:
            raise BuildError(f"could not start the builder: {exc}") from exc
        try:
            proc.stdin.write(prompt)
            proc.stdin.close()
        except (OSError, ValueError):
            pass
        last_note = started
        timed_out = False
        while True:
            for line in reader.poll():
                ui.banner(line)
            if proc.poll() is not None:
                break
            now = time.time()
            if now - started > timeout_minutes * 60:
                proc.kill()
                timed_out = True
                break
            if now - last_note > 300:
                ui.note(f"The builder is still at work ({int((now - started) / 60)} minutes).")
                last_note = now
            time.sleep(poll_seconds)
        proc.wait()
        for line in reader.poll():
            ui.banner(line)
    result = read_result(project)
    ok = bool(result and result.get("status") == "ok" and result.get("play_command")) and not timed_out
    record.update({
        "finished": time.time(), "returncode": proc.returncode, "timed_out": timed_out,
        "events_shown": reader.shown, "events_withheld": reader.withheld, "result": result,
        "status": "ok" if ok else ("timeout" if timed_out else "failed"),
    })
    session.build = record
    session.save()
    return record


def offer_play(record: dict, ui) -> bool:
    """Launch the finished game, only if the player agrees to the exact command."""
    result = record.get("result") or {}
    cmd = result.get("play_command")
    if not (isinstance(cmd, list) and cmd and all(isinstance(c, str) for c in cmd)):
        return False
    ui.note(f"The builder says the game starts with: {' '.join(cmd)}   (run from {record['project']})")
    if not ui.confirm("PLAY? [y/N] "):
        return False
    try:
        subprocess.run(cmd, cwd=record["project"], check=False)
    except OSError as exc:
        ui.note(f"It would not start: {exc}")
        return False
    return True
