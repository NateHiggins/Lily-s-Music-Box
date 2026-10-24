"""One night in the house: world state, session state, and persistence.

Everything a session knows is one JSON file under the data directory
(`~/.blank-deck` unless ORACLE_HOME says otherwise), with the prompt the night
ended in beside it. Nothing else is written anywhere unless the player names a
place. `forget` removes it. Saves are atomic: a crash leaves the previous file.
"""

from __future__ import annotations

import json
import os
import random
import re
import shutil
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path

from . import PROFILE_VERSION, __version__

LENGTHS = {"short": 4, "standard": 6, "long": 8}     # chambers between the counter and the Reading Room
SOFT_CAP, HARD_CAP = 3, 5                             # player turns in one chamber
READING_SOFT_CAP, READING_HARD_CAP = 1, 2
EXCHANGE_MEMORY = 4                                   # exchanges of the current scene shown to the narrator


def data_dir() -> Path:
    return Path(os.environ.get("ORACLE_HOME") or (Path.home() / ".blank-deck"))


def sessions_dir() -> Path:
    return data_dir() / "sessions"


def prompts_dir() -> Path:
    return data_dir() / "prompts"


# Folders written by the first version of this program, which made a packet and could start a
# builder. Nothing writes them now; `forget` still clears them.
LEGACY_DIRS = ("packets", "games")


@dataclass
class World:
    matches: int = 3
    joker: str = "kept"                 # kept | played | spent
    joker_chamber: int | None = None    # chamber index when it left the bearer's hand
    joker_wish: str = ""
    ribbon_untied: bool = False
    inventory: list[str] = field(default_factory=list)
    companion: dict | None = None
    npcs: list[dict] = field(default_factory=list)
    flags: dict = field(default_factory=dict)
    threads: list[str] = field(default_factory=list)            # passed over, promised, unresolved
    threads_resolved: list[str] = field(default_factory=list)
    failures: int = 0
    cards: list[dict] = field(default_factory=list)             # faces the deck has taken
    moments: list[dict] = field(default_factory=list)           # things to read back at the table
    focus: dict = field(default_factory=dict)
    ignored: list[str] = field(default_factory=list)
    attempted: list[str] = field(default_factory=list)          # tried, and only partly honoured
    summaries: list[dict] = field(default_factory=list)         # one line per chamber
    signals: dict = field(default_factory=dict)                 # universal signal id -> times seen

    def carrying(self) -> str:
        deck = ("the deck of blank cards (ribbon untied)" if self.ribbon_untied
                else "the deck of blank cards, tied in ribbon")
        joker = "the Joker (unplayed)" if self.joker == "kept" else ""
        matches = {0: "no matches", 1: "1 match"}.get(self.matches, f"{self.matches} matches")
        parts = [deck, joker, matches] + list(self.inventory)
        return "; ".join(p for p in parts if p)


@dataclass
class Session:
    id: str
    created: float
    updated: float
    config: dict
    rng_seed: int
    version: str = __version__
    profile_version: str = PROFILE_VERSION
    turn: int = 0
    phase: str = "new"                  # new | chamber | threshold | reading | reveal | done
    chamber_index: int = 0              # 0 is the counter
    chamber_target: int = LENGTHS["standard"]
    scene: dict = field(default_factory=dict)
    seeds_used: list[str] = field(default_factory=list)
    skins_taken: list[str] = field(default_factory=list)
    skins_offered: list[list[str]] = field(default_factory=list)
    world: World = field(default_factory=World)
    transcript: list[dict] = field(default_factory=list)
    observations: list[dict] = field(default_factory=list)
    snapshots: list[dict] = field(default_factory=list)
    probes: list[dict] = field(default_factory=list)
    guard_events: list[dict] = field(default_factory=list)
    backend_log: list[dict] = field(default_factory=list)
    synthesis: dict | None = None
    prompt: str | None = None           # the build prompt the night ended in, exactly as handed over
    prompt_path: str | None = None      # where it was saved, if it was

    # ---- construction ------------------------------------------------
    @staticmethod
    def new(config: dict, seed: int | None = None) -> "Session":
        now = time.time()
        rng_seed = seed if seed is not None else random.SystemRandom().randrange(1, 2**31)
        sid = time.strftime("%Y%m%d-%H%M%S", time.localtime(now)) + f"-{rng_seed % 10000:04d}"
        length = config.get("length", "standard")
        return Session(id=sid, created=now, updated=now, config=dict(config), rng_seed=rng_seed,
                       chamber_target=LENGTHS.get(length, LENGTHS["standard"]))

    def rng(self, salt: str = "") -> random.Random:
        """A reproducible generator for one decision, so a resumed night deals the same rooms."""
        return random.Random(f"{self.rng_seed}:{self.turn}:{self.chamber_index}:{salt}")

    # ---- transcript --------------------------------------------------
    def say(self, role: str, text: str, **extra) -> None:
        self.transcript.append({"turn": self.turn, "role": role, "text": text,
                                "scene": self.scene.get("key", ""), **extra})

    def scene_key(self) -> str:
        return self.scene.get("key", "")

    # ---- persistence -------------------------------------------------
    def path(self) -> Path:
        return sessions_dir() / f"{self.id}.json"

    def to_dict(self) -> dict:
        return asdict(self)

    def save(self) -> Path | None:
        if self.config.get("no_save"):
            return None
        self.updated = time.time()
        path = self.path()
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(self.to_dict(), ensure_ascii=False, indent=1), encoding="utf-8")
        os.replace(tmp, path)
        return path

    @staticmethod
    def from_dict(data: dict) -> "Session":
        data = dict(data)
        world_fields = World.__dataclass_fields__
        world = World(**{k: v for k, v in (data.pop("world", None) or {}).items() if k in world_fields})
        known = {k: v for k, v in data.items() if k in Session.__dataclass_fields__}
        return Session(world=world, **known)

    @staticmethod
    def load(session_id: str) -> "Session":
        path = sessions_dir() / f"{session_id}.json"
        return Session.from_dict(json.loads(path.read_text(encoding="utf-8")))


def list_sessions() -> list[dict]:
    """Newest first: id, phase, turns, updated."""
    out: list[dict] = []
    if not sessions_dir().is_dir():
        return out
    for path in sessions_dir().glob("*.json"):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        out.append({"id": data.get("id", path.stem), "phase": data.get("phase", "?"),
                    "turn": data.get("turn", 0), "updated": data.get("updated", 0.0),
                    "backend": (data.get("config") or {}).get("backend_used", ""),
                    "title": ((data.get("synthesis") or {}).get("design") or {}).get("working_title", ""),
                    "prompt_path": data.get("prompt_path")})
    return sorted(out, key=lambda s: s["updated"], reverse=True)


def latest_session(unfinished_only: bool = False) -> str | None:
    for s in list_sessions():
        if not unfinished_only or s["phase"] != "done":
            return s["id"]
    return None


def forget(session_id: str | None = None) -> list[str]:
    """Erase one night, or every night, from the data directory. Returns what was removed.
    A prompt or a project folder written to a place the player chose with --out or
    --project is theirs and is not touched."""
    removed: list[str] = []
    devview = data_dir() / "devview"
    legacy = [data_dir() / name for name in LEGACY_DIRS]
    if session_id is None:
        for sub in (sessions_dir(), prompts_dir(), devview, *legacy):
            if sub.is_dir():
                shutil.rmtree(sub)
                removed.append(str(sub))
        return removed
    if not re.fullmatch(r"\d{8}-\d{6}-\d{4}", session_id):
        return removed                  # not a night's id: a partial one must never match other nights' files
    targets = [sessions_dir() / f"{session_id}.json", devview / f"{session_id}.html"]
    targets += sorted(prompts_dir().glob(f"{session_id}-*.md")) if prompts_dir().is_dir() else []
    targets += [base / session_id for base in legacy]
    for target in targets:
        if target.is_dir():
            shutil.rmtree(target)
            removed.append(str(target))
        elif target.is_file():
            target.unlink()
            removed.append(str(target))
    return removed
