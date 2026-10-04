"""The build prompt: the one thing the night hands over.

A single message in plain Markdown, written for its owner to paste into an AI
coding agent that has THE AI STUDIO MANUAL in its working folder. It carries the
whole game description: what the design stands on and the behaviour each signal
was seen in, the Game Design Vector, the laws, the echoes of the night, what is
not known, the reading as acceptance criteria, the scope, and a scoped grant.

The wording that never changes lives in `content/build_prompt.md`; everything
here is the part that comes from one night. Each fact is said once and pointed
to by a short label (S1, X, L3, E2), because the reader pays for every word.

It names no file of this program's. Nothing but the manual has to travel with it.
"""

from __future__ import annotations

import re
import time
from importlib import resources
from pathlib import Path

from . import __version__
from .content import Registry
from .model import PlayerModel
from .session import Session, prompts_dir

MANUAL_NAME = "AI_GAME_DEVELOPMENT_MANUAL.md"
REFERENCE_DIR = "manual"           # the manual's reference files, in a folder beside its core
CHECKER = "check_manual.py"        # the manual's own checker, which travels with it
PROMPT_FILE = "ORACLE_PROMPT.md"   # the prompt's name inside a prepared project folder
KIT_DIR = "manual_kit"             # where the single-file build carries its copy of the manual

BLANK = "nothing was seen here: these are the DEFAULT rows, where you choose and say so"
_AT_ROOM = re.compile(r"^at ([^:]+): (.+)$")            # "at The Bridge of Maybe: test the plank"
_DIM_ID = re.compile(r" \([a-z_.]+\)")                 # " (optimization_expression)"
_NOT_SEEN = re.compile(r"^Whether this player wants (.+) \(([a-z_.]+)\) was not observed\.")
_TAIL = " Nothing in the design depends on it."


class PromptError(Exception):
    """The prompt or its project folder could not be written as asked."""


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

def _first_sentence(text: str) -> str:
    cut = text.find(". ")
    return text if cut < 0 else text[:cut + 1]


def _cell(value) -> str:
    return " ".join(str(value).replace("|", "/").split())


def _stop(text: str) -> str:
    text = str(text).strip()
    return text if text.endswith((".", "!", "?")) else text + "."


def _third(text: str) -> str:
    """Second person to third, for a line that came out of the house's own narration."""
    for old, new in ((r"\byourself\b", "themselves"), (r"\byours\b", "theirs"), (r"\byour\b", "their"),
                     (r"\byou\b", "they")):
        text = re.sub(old, new, text, flags=re.IGNORECASE)
    return text


def _plain(text) -> str:
    """One line of evidence, safe to set inside a sentence: no line breaks, no code marks."""
    return " ".join(str(text).replace("`", "'").split()).rstrip(".")


def _seen(evidence, limit: int = 3) -> str:
    """What the player did, as past-tense phrases that follow "Seen when they:".

    Authored acts and moments are already written that way ("mapped the switchboard one switch
    at a time"). A line kept as "at <room>: <what the narration said they do>" is an older or a
    model-narrated record: it is turned round, and put after the others."""
    told, turned, bare = [], [], []
    for item in evidence or []:
        text = _plain(item)
        if not text:
            continue
        found = _AT_ROOM.match(text)
        if not found:
            told.append(text)
            continue
        room, act = found.group(1), _third(found.group(2))
        negative = re.match(r"(?:do not|don't) (.+)", act, flags=re.IGNORECASE)
        if negative:
            turned.append(f"chose not to {negative.group(1)} ({room})")
        elif len(act.split()) >= 3:
            turned.append(f"chose to {act} ({room})")
        else:
            bare.append(f"{act}, at {room}")              # only an option's name: the least telling
    return "; ".join((told + turned or bare)[:limit])


def slug(title: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:48] or "game"


def word_count(text: str) -> int:
    return len(text.split())


# ---------------------------------------------------------------------------
# The parts that come from the night
# ---------------------------------------------------------------------------

def _signals(design: dict) -> tuple[str, dict[str, str], dict[str, str]]:
    """The signals and the contradiction, each said once.

    Returns the text, a map from dimension id to the label that speaks for it, and a map
    from a design consequence to its label (how a vision finds what makes it true)."""
    sig = design["design_signals"]
    lines: list[str] = []
    by_dim: dict[str, str] = {}
    by_text: dict[str, str] = {}
    n = 0
    for rank in ("dominant", "secondary"):
        for entry in sig.get(rank) or []:
            n += 1
            label = f"S{n}"
            for dim in entry.get("dims") or []:
                by_dim.setdefault(dim, label)
            consequence = str(entry.get("design_consequence", "")).strip()
            by_text[consequence] = label
            by_text[_first_sentence(consequence)] = label
            lines.append(f"**{label} ({rank}): the player {_stop(entry.get('signal', ''))}**")
            seen = _seen(entry.get("evidence"), 3 if rank == "dominant" else 2)
            if seen:
                lines.append(f"- Seen when they: {_stop(seen)}")
            lines.append(f"- So: {consequence}")
            lines.append("")
    if not n:
        lines += ["The night gave too little evidence for any signal. Say so in your first report, build from "
                  "the defaults below, and let the first play decide.", ""]
    pc = sig.get("productive_contradiction") or {}
    resolution = str(pc.get("resolution", "")).strip()
    if pc.get("between"):
        by_text[resolution] = "X"
        lines.append(f"**X (the productive contradiction): {pc['between'][0]}, against {pc['between'][-1]}.**")
        seen = _seen(pc.get("evidence"))
        if seen:
            lines.append(f"- Seen when they: {_stop(seen)}")
        lines.append(f"- So: {resolution}")
    else:
        lines.append(f"**X (the productive contradiction):** none was seen. {resolution}")
    return "\n".join(lines), by_dim, by_text


def _quiet(design: dict, said: dict[str, str]) -> str:
    rest = [str(i).strip() for i in design.get("design_implications") or [] if str(i).strip() not in said]
    return "\n".join(f"- {i}" for i in rest) if rest else "- (none)"


def _vector(registry: Registry, design: dict, synthesis: dict, by_dim: dict[str, str]) -> str:
    """Every field, its value, and whether the night decided it. A field left at its
    authored default, or one that says it is unknown, is the builder's to choose."""
    fields = {f["id"]: f for f in registry.implications["gdv_fields"]}
    by_rules = str(synthesis["source"]["design"]).startswith("rules")
    sources = (synthesis.get("draft") or {}).get("gdv_sources", {}) if by_rules else {}
    rows = ["| Field | Value | Basis |", "|---|---|---|"]
    for key, value in design["game_design_vector"].items():
        info = fields.get(key, {"label": key, "default": ""})
        text = str(value).strip()
        if text == info["default"].strip() or text.lower().startswith("unknown"):
            basis = "SCOPE" if info.get("scope") else "DEFAULT"      # a default the scope already holds
        else:
            source = sources.get(key, "")
            label = by_dim.get(source.rstrip("+-"))
            if label:
                basis = f"FROM PLAY ({label})"
            elif source == "thresholds taken":
                basis = "FROM PLAY (the ways taken between rooms)"
            elif by_rules:
                basis = "FAINT"                        # set by a signal too weak to be one of the five
            else:
                basis = "FROM PLAY"
        rows.append(f"| {info['label']} | {_cell(text)} | {basis} |")
    return "\n".join(rows)


def _laws(design: dict) -> tuple[str, dict[str, str]]:
    laws = [str(n).strip() for n in design.get("negative_constraints") or []]
    by_text = {law: f"L{i}" for i, law in enumerate(laws, 1)}
    text = "\n".join(f"- **L{i}.** {law}" for i, law in enumerate(laws, 1))
    return text or "- (none were evidenced)", by_text


def _echoes(design: dict) -> tuple[str, dict[str, str]]:
    lines: list[str] = []
    by_text: dict[str, str] = {}
    n = 0
    for cb in design.get("personal_callbacks") or []:
        n += 1
        becomes = str(cb.get("becomes", "")).strip()
        by_text[becomes] = f"E{n}"
        lines.append(f"- **E{n}.** They {_stop(_plain(cb.get('from', '')))} In the game: {_stop(becomes)}")
    un = design.get("unrequested_feature") or {}
    if un.get("feature"):
        n += 1
        lines.append(f"- **E{n}, the feature nobody asked for.** {_stop(un['feature'])} "
                     f"It follows from what they did: {_stop(un.get('follows_from', ''))}")
    return "\n".join(lines) or "- (none)", by_text


def _unknown(design: dict) -> str:
    items = []
    for item in design.get("unknowns") or []:
        text = str(item).strip()
        pair = _NOT_SEEN.match(text)
        if pair:                                         # "pacing: contemplative or relentless"
            items.append(f"- {pair.group(2).replace('_', ' ')}: {pair.group(1)}")
        else:
            items.append("- " + _stop(_DIM_ID.sub("", text.replace(_TAIL, "")).strip()))
    return "\n".join(items) or "- Nothing material."


def _visions(prophecy: dict, said: dict[str, str]) -> str:
    rows = ["| Card | The player was told | Comes true through |", "|---|---|---|"]
    for v in prophecy["visions"]:
        fulfils = str(v.get("fulfils") or "").strip()
        if v.get("card") == "The Blank Card" or fulfils.startswith("Where the profile is unknown"):
            through = BLANK
        else:
            through = said.get(fulfils) or said.get(_first_sentence(fulfils)) or fulfils or "the design as a whole"
        rows.append(f"| {_cell(v['card'])} | {_cell(v['text'])} | {_cell(through)} |")
    return "\n".join(rows)


# ---------------------------------------------------------------------------
# The prompt
# ---------------------------------------------------------------------------

def build_prompt(registry: Registry, model: PlayerModel, session: Session, synthesis: dict,
                 when: float | None = None) -> str:
    """The whole message, ready to paste. Deterministic for a given night."""
    design, prophecy = synthesis["design"], synthesis["prophecy"]
    scope = registry.implications["scope"]
    signals, by_dim, said = _signals(design)
    laws, law_labels = _laws(design)
    echoes, echo_labels = _echoes(design)
    said_all = {**said, **law_labels, **echo_labels}

    states = model.compute()
    axes = [st for st in states.values() if registry.dims[st.id].family == "axis"]
    observed = sum(1 for st in axes if st.status != "unknown")
    rooms = len(session.world.summaries)
    made = time.strftime("%Y-%m-%d", time.localtime(when if when is not None else time.time()))
    source = str(synthesis["source"]["design"])
    how = ("No model was involved: the design follows authored rules." if source.startswith("rules") else
           f"The design was composed by a model ({source}) from the same evidence, and checked.")
    footer = (f"Written by THE BLANK DECK {__version__} on {made} from one night of play: "
              f"{len(model.observations)} observations, {observed} of {len(axes)} core dimensions observed. {how}")
    parts = {
        "TITLE": design["working_title"].strip(),
        "PITCH": design["pitch"].strip(),
        "NIGHT": f"{session.turn} turns in {rooms} rooms",
        "SIGNALS": signals,
        "QUIET": _quiet(design, said),
        "VECTOR": _vector(registry, design, synthesis, by_dim),
        "LAWS": laws,
        "ECHOES": echoes,
        "UNKNOWN": _unknown(design),
        "VISION_COUNT": str(len(prophecy["visions"])),
        "VISIONS": _visions(prophecy, said_all),
        "SCOPE": (scope["summary"] + "\n\n" + "\n".join(f"- {c}" for c in scope["constraints"])
                  + "\n\n" + scope["fixed_summary"] + "\n\n" + "\n".join(f"- {c}" for c in scope["fixed"])),
        "FOOTER": footer,
    }
    # One pass over the fixed wording only: what is put in is never searched for marks of its own,
    # so nothing a player typed during the night can be taken for one.
    text = re.sub(r"\{\{([A-Z_]+)\}\}", lambda found: parts.get(found.group(1), found.group(0)),
                  registry.texts["build_prompt"])
    return text.replace("\r\n", "\n").strip() + "\n"


# ---------------------------------------------------------------------------
# Keeping it
# ---------------------------------------------------------------------------

def default_path(session: Session) -> Path:
    title = ((session.synthesis or {}).get("design") or {}).get("working_title", "")
    return prompts_dir() / f"{session.id}-{slug(title)}.md"


def save_prompt(session: Session, text: str, out: str | None = None, keep: bool = True) -> tuple[list[Path], str]:
    """Write the prompt where the night keeps it and, if a place was named, there too.

    Returns the files written and, when one could not be, why. `keep=False` writes only the
    named place: asking for a copy of an old night's prompt must not touch what that night kept."""
    data = text.encode("utf-8")
    paths: list[Path] = []
    problems: list[str] = []
    if keep and not session.config.get("no_save"):
        path = default_path(session)
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            session.prompt_path = str(path)
            paths.append(path)
        except OSError as exc:
            problems.append(f"could not keep the prompt at {path}: {exc}")
    if out:
        target = Path(out)
        if target.is_dir():
            target = target / default_path(session).name
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            paths.append(target)
        except OSError as exc:
            problems.append(f"could not write the prompt to {target}: {exc}")
    return paths, "; ".join(problems)


# ---------------------------------------------------------------------------
# The manual, and a folder ready for a builder
# ---------------------------------------------------------------------------

class Manual:
    """A copy of the manual this program can lay down in a project folder: its operating
    core, and the reference documents in the folder beside it."""

    def __init__(self, where: str, core, reference=None):
        self.where, self._core, self._reference = where, core, reference

    def reference_count(self) -> int:
        """How many reference documents travel with the core. None means the core is alone, and
        the prompt sends the builder to a section that will not be there."""
        return sum(1 for name, _ in self.files() if name.startswith(REFERENCE_DIR + "/") and name.endswith(".md"))

    def files(self) -> list[tuple[str, bytes]]:
        """The core, the reference documents, and the manual's own checker (the core cites it).
        Nothing else that happens to sit in the reference folder travels."""
        out = [(MANUAL_NAME, self._core.read_bytes())]
        if self._reference is not None and self._reference.is_dir():
            for item in sorted(self._reference.iterdir(), key=lambda p: p.name):
                if item.is_file() and (item.name.endswith(".md") or item.name == CHECKER):
                    out.append((f"{REFERENCE_DIR}/{item.name}", item.read_bytes()))
        return out


def find_manual(explicit: str | None = None) -> Manual | None:
    """The manual, if one can be found: where the player said, in the folder the program was
    started from, beside this copy of the program, or inside the single-file build."""
    if explicit:
        path = Path(explicit)
        if path.is_dir():
            path = path / MANUAL_NAME
        return Manual(str(path), path, path.parent / REFERENCE_DIR) if path.is_file() else None
    candidates = [Path.cwd() / "docs", Path.cwd()]
    package = resources.files(__package__)
    if isinstance(package, Path):
        candidates.append(package.parent / "docs")
    for base in candidates:
        core = base / MANUAL_NAME
        if core.is_file():
            return Manual(str(core), core, base / REFERENCE_DIR)
    kit = package / KIT_DIR
    if (kit / MANUAL_NAME).is_file():
        return Manual("the copy carried inside this program", kit / MANUAL_NAME, kit / REFERENCE_DIR)
    return None


def prepare_project(folder: str, text: str, manual: Manual | None) -> dict:
    """Make a folder an AI coder can be opened in: the prompt, and the manual beside it.
    Nothing that is already there is ever replaced."""
    root = Path(folder)
    files = [(PROMPT_FILE, text.encode("utf-8"))] + (manual.files() if manual else [])
    clashes = [name for name, data in files
               if (root / name).exists() and (not (root / name).is_file() or (root / name).read_bytes() != data)]
    if clashes:
        raise PromptError(f"{root} already holds different files with these names: {', '.join(clashes)}. "
                          f"Nothing was written. Name an empty folder.")
    try:
        for name, data in files:
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    except OSError as exc:
        raise PromptError(f"could not write to {root}: {exc}") from exc
    return {"folder": root, "prompt": root / PROMPT_FILE, "manual": manual.where if manual else None,
            "reference": manual.reference_count() if manual else 0, "files": len(files)}
