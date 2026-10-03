"""The house with a model behind it.

One model call per turn. The model is given the fiction, the dimension list,
the state of the night and a directive for this scene, and returns two blocks:
the narration the player reads, and the Reader's private notes as JSON. This
module builds that prompt, shows only the narration as it streams, and reads
the notes back tolerantly: a reply with broken notes still gives the player
their narration, and the turn is noted as unread rather than guessed at.
"""

from __future__ import annotations

import json
import re

from .backends import Backend, BackendError
from .content import Registry
from .offline import TurnResult, stage_text
from .session import EXCHANGE_MEMORY, Session

OPEN_TAG, CLOSE_TAG, NOTES_TAG = "<narration>", "</narration>", "<oracle>"


def system_prompt(registry: Registry) -> str:
    text = registry.texts["narrator_system"]
    return (text.replace("{{SETTING}}", registry.texts["setting"].strip())
                .replace("{{DIMENSIONS}}", registry.dimension_prompt())
                .replace("{{SIGNALS}}", registry.signal_prompt()))


# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------

def state_block(session: Session, registry: Registry) -> str:
    w = session.world
    total = session.chamber_target + 2
    lines = [f"Chamber {min(session.chamber_index + 1, total)} of {total} "
             f"(the counter was the first; the Reading Room is the last).",
             f"The bearer carries: {w.carrying()}."]
    if w.companion:
        lines.append(f"Travelling with the bearer: {w.companion.get('name', 'a companion')} "
                     f"({w.companion.get('kind', '')}).")
    if w.npcs:
        lines.append("People met: " + "; ".join(
            f"{n.get('name', '?')} ({n.get('attitude', '')}: {n.get('note', '')})" for n in w.npcs[-6:]))
    if w.threads:
        lines.append("Things the bearer walked past, promised or left unresolved: " + "; ".join(w.threads[-6:]))
    if w.cards:
        lines.append("Cards that have taken a face: " + ", ".join(c["title"] for c in w.cards))
    if w.failures:
        lines.append(f"Failures so far tonight: {w.failures}.")
    wearing = w.flags.get("wearing")
    if wearing:
        lines.append(f"The bearer is wearing: {wearing}.")
    if w.summaries:
        lines.append("The night so far:")
        lines.extend(f"- {s['title']}: {s['line']}" for s in w.summaries[-8:])
    return "\n".join(lines)


def exchange_block(session: Session) -> str:
    lines = []
    for ex in session.scene.get("exchange", [])[-EXCHANGE_MEMORY:]:
        if ex.get("player"):
            lines.append(f"BEARER: {ex['player']}")
        if ex.get("house"):
            lines.append(f"HOUSE: {ex['house']}")
    return "\n".join(lines) if lines else "(the scene has just opened)"


def _ways(registry: Registry, skin_ids: list[str], field: str) -> str:
    return "\n".join(f"  {'ABC'[i]}) {registry.skins[s][field]}" for i, s in enumerate(skin_ids))


def chamber_prompt(session: Session, registry: Registry, text: str, *, soft: bool, must_close: bool,
                   last_chamber: bool, finale: bool, soft_cap: int, hard_cap: int) -> str:
    scene = session.scene
    seed = registry.seeds[scene["seed"]]
    skin = registry.skins.get(scene.get("skin") or "")
    d = [f'Chamber: "{seed["title"]}" (a {seed["kind"]} scene).']
    if skin:
        d.append(f"It is dressed in this manner: {skin['manner']}")
    d.append(f"Premise: {seed['premise']}")
    d.append("What to watch for here (cues for your notes, never text to show):")
    d.extend(f"- {r}" for r in seed["reads"])
    if scene.get("flags"):
        d.append(f"Already true in this chamber: {json.dumps(scene['flags'])}")
    d.append(f"This is the bearer's turn {scene['turns']} of at most {hard_cap} in this chamber.")
    if must_close:
        d.append(f'This reply MUST close the chamber. Resolve the situation in the fiction now (for example: '
                 f'{seed["close"]}) and set scene.status to "resolved".')
    elif soft:
        d.append(f"The chamber has run long enough. Let this action bring it to a close if it plausibly can; "
                 f"otherwise have the house make finishing easy (for example: {seed['nudge']}).")
    else:
        d.append('Let the chamber breathe. If the bearer\'s action settles the situation, close it '
                 '(scene.status "resolved"); otherwise keep it open.')
    if finale:
        d.append("When the scene closes, end with the Proprietor saying 'Then sit' and squaring the deck. "
                 "Do not begin the reading and do not explain the cards.")
    elif last_chamber:
        d.append("When (and only when) this reply closes the chamber, end with the bearer climbing a last narrow "
                 "stair toward a door with lamplight under it. Do not describe what is behind the door.")
    else:
        d.append("When (and only when) this reply closes the chamber, end the narration at a threshold offering "
                 "these ways onward, each described in a clause of your own words, without letters or numbers, "
                 "and stop there:\n" + _ways(registry, scene["thresholds"], "threshold"))
    if scene.get("card_given"):
        d.append("A card has already warmed in this chamber: card must be null.")
    return _assemble(session, registry, "\n".join(d), text)


def threshold_prompt(session: Session, registry: Registry, text: str, *, next_seed: dict,
                     force_index: int | None) -> str:
    scene = session.scene
    skins = scene["thresholds"]
    d = ["The bearer stands at a threshold between chambers. The ways onward:",
         _ways(registry, skins, "threshold"),
         "If the bearer's input takes one of the ways, however they phrase it: set scene.threshold_choice to "
         'its letter and scene.status to "open", narrate the passage in a sentence, then stage the next chamber '
         "(below) in the same reply, dressed in the manner of the way they took, and end on something the "
         "bearer can act on.",
         'If the bearer does something else, answer in the fiction, keep scene.status "threshold" and set '
         'scene.threshold_choice to "other".']
    if force_index is not None:
        letter = "ABC"[force_index]
        d.append(f"The bearer has lingered here. If this input still does not take a way, the house chooses: "
                 f"way {letter} opens of its own accord and takes them through. In that case set "
                 f'scene.threshold_choice to "{letter}", stage the next chamber, and add "house_chose": true '
                 f"inside scene.")
    d.append("The manner of each way:\n" + _ways(registry, skins, "manner"))
    d.append(f'Next chamber: "{next_seed["title"]}" (a {next_seed["kind"]} scene).')
    d.append(f"Premise: {next_seed['premise']}")
    d.append(f"Opening image to adapt (keep its objects and its tension; change its dress to the manner): "
             f"{next_seed['intro']}")
    d.append("What to watch for there:")
    d.extend(f"- {r}" for r in next_seed["reads"])
    return _assemble(session, registry, "\n".join(d), text)


def _assemble(session: Session, registry: Registry, directive: str, text: str) -> str:
    return (f"## State of the night\n{state_block(session, registry)}\n\n"
            f"## Scene directive\n{directive}\n\n"
            f"## Recent exchange\n{exchange_block(session)}\n\n"
            f"## The bearer now types\n{text.strip()}\n\n"
            f"Reply with the <narration> block, then the <oracle> block, and nothing else.")


# ---------------------------------------------------------------------------
# Reading the reply
# ---------------------------------------------------------------------------

class NarrationStream:
    """Passes on only the text inside <narration> while a reply streams in."""

    def __init__(self, emit):
        self.emit, self.buf, self.state, self.emitted = emit, "", 0, False
        self._held = ""                     # trailing whitespace, kept back until more text follows

    def feed(self, delta: str) -> None:
        self.buf += delta
        if self.state == 0:
            i = self.buf.find(OPEN_TAG)
            if i < 0:
                self.buf = self.buf[-(len(OPEN_TAG) - 1):]
                return
            self.buf = self.buf[i + len(OPEN_TAG):]
            self.state = 1
        if self.state == 1:
            ends = [i for i in (self.buf.find(CLOSE_TAG), self.buf.find(NOTES_TAG)) if i >= 0]
            if ends:
                self._out(self.buf[:min(ends)], final=True)
                self.buf, self.state = "", 2
                return
            lt = self.buf.rfind("<")
            if lt >= 0 and (CLOSE_TAG.startswith(self.buf[lt:]) or NOTES_TAG.startswith(self.buf[lt:])):
                out, self.buf = self.buf[:lt], self.buf[lt:]
            else:
                out, self.buf = self.buf, ""
            self._out(out, final=False)

    def _out(self, text: str, final: bool) -> None:
        text = self._held + text
        if not self.emitted:
            text = text.lstrip()
        body = text.rstrip()
        self._held = "" if final else text[len(body):]
        if body:
            self.emitted = True
            self.emit(body)


def _json_from(text: str):
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text)
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end <= start:
        return None
    body = text[start:end + 1]
    for attempt in (body,
                    re.sub(r",\s*([}\]])", r"\1", body),
                    re.sub(r",\s*([}\]])", r"\1", body.replace("“", '"').replace("”", '"')
                           .replace("‘", "'").replace("’", "'"))):
        try:
            data = json.loads(attempt)
            return data if isinstance(data, dict) else None
        except json.JSONDecodeError:
            continue
    return None


def parse_json_reply(text: str):
    """A JSON object from a model reply that was asked for JSON only."""
    return _json_from(text)


def parse_reply(text: str) -> tuple[str, dict, list[str]]:
    """Split a reply into (narration, notes, problems)."""
    problems: list[str] = []
    m = re.search(r"<narration>(.*?)</narration>", text, re.DOTALL)
    notes_at = text.find(NOTES_TAG)
    if m:
        narration = m.group(1)
    elif notes_at >= 0:
        narration = text[:notes_at].replace(OPEN_TAG, "")
        problems.append("narration_tag_missing")
    else:
        narration = text.replace(OPEN_TAG, "").replace(CLOSE_TAG, "")
        problems.append("oracle_block_missing")
    notes: dict = {}
    if notes_at >= 0:
        body = text[notes_at + len(NOTES_TAG):]
        body = body.split("</oracle>")[0]
        data = _json_from(body)
        if data is None:
            problems.append("oracle_json_invalid")
        else:
            notes = data
    return narration.strip(), notes, problems


def result_from_notes(narration: str, notes: dict, problems: list[str], thresholds: list[str]) -> TurnResult:
    scene = notes.get("scene") if isinstance(notes.get("scene"), dict) else {}
    status = scene.get("status") if scene.get("status") in ("open", "resolved", "threshold") else "open"
    choice = scene.get("threshold_choice")
    index = None
    if isinstance(choice, str) and choice.strip().upper() in ("A", "B", "C"):
        i = "ABC".index(choice.strip().upper())
        if i < len(thresholds):
            index = i
    observations = [o for o in (notes.get("observations") or []) if isinstance(o, dict)][:5]
    card = notes.get("card") if isinstance(notes.get("card"), dict) else None
    if card and not (card.get("title") and card.get("image")):
        card = None
    moment = notes.get("moment") if isinstance(notes.get("moment"), str) and notes.get("moment").strip() else None
    attempted = notes.get("attempted_beyond")
    return TurnResult(
        narration=narration, status=status, threshold_choice=index,
        house_chose=bool(scene.get("house_chose")),
        summary=str(scene.get("summary") or "")[:200],
        state=notes.get("state") if isinstance(notes.get("state"), dict) else {},
        observations=observations,
        focus=[str(x)[:60] for x in (notes.get("focus") or []) if isinstance(x, (str, int))][:6],
        ignored=[str(x)[:80] for x in (notes.get("ignored") or []) if isinstance(x, (str, int))][:6],
        attempted=str(attempted)[:120] if isinstance(attempted, str) and attempted.strip() else None,
        card=card, moment=moment, source="llm", problems=problems)


# ---------------------------------------------------------------------------
# The live narrator
# ---------------------------------------------------------------------------

class LiveNarrator:
    def __init__(self, registry: Registry, backend: Backend, ui):
        self.registry, self.backend, self.ui = registry, backend, ui
        self.system = system_prompt(registry)
        self.failures = 0

    def _call(self, session: Session, prompt: str, purpose: str = "turn") -> tuple[str, bool]:
        """Returns (reply text, whether narration was already shown)."""
        ui = self.ui
        began = {"on": False}
        spinner = ui.waiting("the house considers")

        def emit(text: str) -> None:
            if not began["on"]:
                spinner.stop()
                ui.stream_begin()
                began["on"] = True
            ui.stream_text(text)

        stream = NarrationStream(emit)
        entry = {"turn": session.turn, "purpose": purpose, "backend": getattr(self.backend, "name", "?")}
        try:
            with spinner:
                done = self.backend.complete(self.system, prompt, purpose=purpose,
                                             on_delta=stream.feed if self.backend.streams else None)
        except BackendError as exc:
            if began["on"]:
                ui.stream_end()
            entry.update({"error": exc.kind, "detail": str(exc)[:300]})
            session.backend_log.append(entry)
            raise
        if began["on"]:
            ui.stream_end()
        entry.update({"latency": round(done.latency, 2), "usage": done.usage, "model": done.model,
                      "served_by": done.backend, "prompt_chars": len(prompt), "reply_chars": len(done.text)})
        session.backend_log.append(entry)
        return done.text, stream.emitted

    def chamber(self, session: Session, text: str, **kw) -> TurnResult:
        prompt = chamber_prompt(session, self.registry, text, **kw)
        reply, shown = self._call(session, prompt)
        narration, notes, problems = parse_reply(reply)
        result = result_from_notes(narration, notes, problems, session.scene.get("thresholds") or [])
        result.shown = shown
        if kw.get("must_close"):
            result.status = "resolved"
        elif result.status == "threshold":
            result.status = "open"
        return result

    def threshold(self, session: Session, text: str, *, next_seed: dict, force_index: int | None) -> TurnResult:
        prompt = threshold_prompt(session, self.registry, text, next_seed=next_seed, force_index=force_index)
        reply, shown = self._call(session, prompt)
        narration, notes, problems = parse_reply(reply)
        skins = session.scene["thresholds"]
        result = result_from_notes(narration, notes, problems, skins)
        result.shown = shown
        if result.threshold_choice is None:
            result.status = "threshold"
            if force_index is not None:
                # The house was told to choose and the notes do not say it did: hold it to its
                # word, and stage the chamber from the page.
                result.threshold_choice, result.house_chose, result.status = force_index, True, "open"
                result.addendum = stage_text(self.registry, next_seed, self.registry.skins[skins[force_index]],
                                             session.world, house_chose=True)
        else:
            result.status = "open"
        return result
