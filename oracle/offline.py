"""The house with no model behind it.

Every chamber is authored with options, outcomes and evidence, so the night can
be played from the page: the player's line is matched against each option's
keywords, the authored outcome is shown, and the authored evidence is recorded.
It is a narrower game than the one a model narrates (it cannot improvise), but
it is a complete one, it needs nothing installed, and it is what the tests and
the simulated players run on. It is also where a live night lands if the model
stops answering.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from .content import Registry

GENERIC = {"look", "examine", "inspect", "search", "ask", "?", "go", "take", "no", "yes", "open", "leave",
           "wait", "read", "why", "where", "around", "room", "play", "nothing", "again", "up", "down"}

CARD_LINES = (
    "Inside your coat, one of the cards has grown warm.",
    "Against your ribs, a card shifts, like something settling.",
    "One card in the deck is warm now. You can tell which without looking.",
)

LAST_STAIR = "A last narrow stair goes up from here, to a door with lamplight under it. You climb."
NOT_ENOUGH_MATCHES = ("You count your matches, twice. Not enough for that. The house does not give credit. "
                      "It waits to see what you will do instead.")
JOKER_ANYWHERE = ("You lay the Joker down and say what you want. For the length of one breath the house is "
                  "silent. Then it is so. What you said, goes: the room gives way before you as if it had "
                  "only been waiting to be told. The Joker is gone from your hand, and the air smells of a "
                  "struck match.")


@dataclass
class TurnResult:
    """What one reply did. Both the live narrator and this one produce it."""
    narration: str
    status: str = "open"                    # open | resolved | threshold
    threshold_choice: int | None = None     # index into the scene's thresholds
    house_chose: bool = False               # the bearer did not pick; no evidence in the pick
    summary: str = ""
    state: dict = field(default_factory=dict)
    observations: list[dict] = field(default_factory=list)
    focus: list[str] = field(default_factory=list)
    ignored: list[str] = field(default_factory=list)
    attempted: str | None = None
    card: dict | None = None
    moment: str | None = None
    source: str = "offline"
    option: str | None = None
    shown: bool = False                     # the narration has already been streamed to the player
    addendum: str = ""                      # text the engine must still show after the narration
    problems: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Text shared by both narrators
# ---------------------------------------------------------------------------

def short_way(skin: dict) -> str:
    """'a brass hatch, warm to the touch...' -> 'the brass hatch'."""
    head = re.split(r"[,;]", skin["threshold"], maxsplit=1)[0].strip()
    if head.startswith("an "):
        return "the " + head[3:]
    if head.startswith("a "):
        return "the " + head[2:]
    return head


def thresholds_text(registry: Registry, skin_ids: list[str]) -> str:
    places = ["To the left, ", "Ahead, ", "To the right, "] if len(skin_ids) >= 3 else ["To the left, ", "To the right, "]
    parts = [f"{places[i]}{registry.skins[s]['threshold']}." for i, s in enumerate(skin_ids[:3])]
    return "The way on divides. " + " ".join(parts)


def thresholds_present(registry: Registry, narration: str, skin_ids: list[str]) -> bool:
    """Did the narration actually describe each way? (A model can forget.)"""
    low = narration.lower()
    return all(any(_contains(low, kw) for kw in registry.skins[s]["keywords"]) for s in skin_ids)


def stage_text(registry: Registry, seed: dict, skin: dict | None, world, *, house_chose: bool = False) -> str:
    """How a chamber opens when read from the page."""
    parts = []
    if skin is not None:
        manner = skin["manner"][0].lower() + skin["manner"][1:]
        if house_chose:
            parts.append(f"While you consider, {short_way(skin)} opens of its own accord, and the house, "
                         f"tired of waiting, takes you through. On this side, the house is {manner}")
        else:
            parts.append(f"You take {short_way(skin)}. On this side, the house is {manner}")
    intro = seed["intro"]
    if seed.get("role") == "callback" and world.threads:
        intro += f" What the glass holds, exactly as you left it: {world.threads[0]}."
    parts.append(intro)
    return "\n\n".join(parts)


def _contains(text: str, keyword: str) -> bool:
    keyword = keyword.lower()
    if keyword == "?":
        return "?" in text
    if re.fullmatch(r"[\w' -]+", keyword):
        return re.search(r"(?<!\w)" + re.escape(keyword) + r"(?!\w)", text) is not None
    return keyword in text


def _describe(seed: dict, option: dict, outcome: str) -> str:
    """A plain account of what the bearer did, for the evidence lists."""
    first = re.split(r"(?<=[.!?])\s", outcome.strip(), maxsplit=1)[0].rstrip(".!?")
    if first.startswith("You ") and len(first) <= 150:
        return f"at {seed['title']}: {first[4:]}"
    return f"at {seed['title']}: {option['id'].replace('_', ' ')}"


def _when_ok(option: dict, flags: dict) -> bool:
    when = option.get("when") or {}
    if "flag" in when and not flags.get(when["flag"]):
        return False
    if "not_flag" in when and flags.get(when["not_flag"]):
        return False
    return True


def available_options(seed: dict, flags: dict) -> list[dict]:
    return [o for o in seed["options"] if _when_ok(o, flags)]


def match_option(seed: dict, flags: dict, text: str) -> tuple[dict | None, float]:
    """The authored option this line most plausibly means, or None."""
    low = text.lower().strip()
    if low.startswith("@"):                       # exact selection, used by simulated players
        wanted = low[1:].strip()
        for option in available_options(seed, flags):
            if option["id"] == wanted:
                return option, 99.0
        return None, 0.0
    best, best_score = None, 0.0
    for option in available_options(seed, flags):
        score = 0.0
        for keyword in option["match"]:
            if _contains(low, keyword):
                kw = keyword.lower()
                score += 0.6 if kw in GENERIC else 1.0 + 0.5 * kw.count(" ")
        if score > best_score:
            best, best_score = option, score
    return best, best_score


def match_threshold(registry: Registry, skin_ids: list[str], text: str) -> int | None:
    """Which way the line takes, by what it names or where it points."""
    low = text.lower().strip()
    if low.startswith("@"):
        wanted = low[1:].strip()
        return skin_ids.index(wanted) if wanted in skin_ids else None
    scores = []
    for sid in skin_ids:
        scores.append(sum(1 for kw in registry.skins[sid]["keywords"] if _contains(low, kw)))
    top = max(scores) if scores else 0
    if top > 0 and scores.count(top) == 1:
        return scores.index(top)
    n = len(skin_ids)
    last = n - 1
    bare = {"a": 0, "1": 0, "b": 1, "2": 1, "c": 2, "3": 2}
    if low in bare and bare[low] < n:
        return bare[low]
    positional = [("left", 0), ("first", 0), ("right", last), ("last", last), ("third", 2),
                  ("ahead", 1), ("middle", 1), ("second", 1), ("centre", 1), ("center", 1), ("straight", 1)]
    for word, index in positional:
        if _contains(low, word) and index < n:
            if n == 2 and word in ("ahead", "middle", "centre", "center", "straight"):
                continue
            return index
    return None


# ---------------------------------------------------------------------------
# The offline narrator
# ---------------------------------------------------------------------------

class OfflineNarrator:
    def __init__(self, registry: Registry):
        self.registry = registry

    # ---- chambers ----------------------------------------------------
    def chamber(self, session, text: str, *, soft: bool, must_close: bool, last_chamber: bool,
                finale: bool) -> TurnResult:
        scene, world = session.scene, session.world
        seed = self.registry.seeds[scene["seed"]]
        flags = scene["flags"]
        option, score = match_option(seed, flags, text)
        if option is not None and score < 1.0 and self._plain_signal(text) is not None:
            option = None            # only a generic word matched; the line is really a universal one
        result: TurnResult

        if option is None and _contains(text.lower(), "joker") and world.joker == "kept" and not finale:
            result = TurnResult(
                narration=JOKER_ANYWHERE, status="resolved", option="joker_anywhere",
                state={"joker": "played"},
                moment=f"played the Joker in {seed['title']}",
                observations=[{"action": f"played the Joker in {seed['title']}", "kind": "behavioral",
                               "strength": "moderate", "context": "a single-use power, spent to end a room",
                               "hypotheses": [{"dim": "reward.power", "dir": 1, "share": 0.4},
                                              {"dim": "risk", "dir": 1, "share": 0.3},
                                              {"dim": "friction", "dir": -1, "share": 0.2}]}])
        elif option is not None:
            cost = (option.get("effects") or {}).get("matches", 0)
            if cost < 0 and world.matches + cost < 0:
                result = TurnResult(narration=NOT_ENOUGH_MATCHES, option=None)
            else:
                result = self._take(seed, scene, option, text)
        else:
            result = self._unmatched(seed, scene, text, world)

        if finale and option is None and result.option is None:
            result.status = "resolved"       # at the reading table anything at all is the last free act
        if result.status != "resolved":
            if must_close:
                result.narration += "\n\n" + seed["close"]
                result.status = "resolved"
            elif soft:
                result.narration += "\n\n" + seed["nudge"]
        if result.card:
            line = CARD_LINES[len(world.cards) % len(CARD_LINES)]
            result.narration += "\n\n" + line
        if result.status == "resolved" and not finale:
            if last_chamber:
                result.narration += "\n\n" + LAST_STAIR
            elif scene.get("thresholds"):
                result.narration += "\n\n" + thresholds_text(self.registry, scene["thresholds"])
        return result

    def _take(self, seed: dict, scene: dict, option: dict, text: str) -> TurnResult:
        if "outcomes" in option:
            counters = scene.setdefault("counters", {})
            n = counters.get(option["counter"], 0)
            outcome = option["outcomes"][min(n, len(option["outcomes"]) - 1)]
            counters[option["counter"]] = n + 1
        else:
            outcome = option["outcome"]
        action = option.get("moment") or _describe(seed, option, outcome)
        observations = []
        if option.get("obs"):
            observations.append({
                "action": action, "kind": "behavioral", "strength": option.get("strength", "moderate"),
                "context": seed["title"],
                "hypotheses": [{"dim": d, "dir": direction, "share": share} for d, direction, share in option["obs"]],
            })
        effects = dict(option.get("effects") or {})
        state = {k: v for k, v in effects.items() if k != "matches"}
        if "matches" in effects:
            state["matches_delta"] = effects["matches"]
        return TurnResult(
            narration=outcome, status="resolved" if option["resolves"] else "open",
            state=state, observations=observations, card=option.get("card"), moment=option.get("moment"),
            option=option["id"], focus=[option["id"]],
            summary=option.get("moment") or f"{option['id'].replace('_', ' ')}")

    def _plain_signal(self, text: str) -> dict | None:
        """A universal signal named outright by a phrase of two words or more."""
        low = text.lower()
        for signal in self.registry.signals.values():
            if signal["obs"] and any(" " in kw and _contains(low, kw) for kw in signal.get("detect", [])):
                return signal
        return None

    def _unmatched(self, seed: dict, scene: dict, text: str, world=None) -> TurnResult:
        low = text.lower()
        scene["unmatched"] = scene.get("unmatched", 0) + 1
        for signal in self.registry.signals.values():
            if any(_contains(low, kw) for kw in signal.get("detect", [])) and signal["obs"]:
                narration = signal.get("generic_outcome") or seed["fallback"]
                if signal["id"] == "checks_inventory" and world is not None:
                    narration = f"You take stock. You are carrying: {world.carrying()}."
                elif scene["unmatched"] >= 2:
                    narration += " " + seed["hint"]
                return TurnResult(
                    narration=narration, option=None,
                    observations=[{"action": signal["desc"], "kind": signal.get("kind", "behavioral"),
                                   "strength": signal.get("strength", "weak"), "context": seed["title"],
                                   "signal": signal["id"],
                                   "hypotheses": [{"dim": d, "dir": direction, "share": share}
                                                  for d, direction, share in signal["obs"]]}])
        narration = seed["fallback"]
        if scene["unmatched"] >= 2:
            narration += " " + seed["hint"]
        result = TurnResult(narration=narration, option=None)
        if len(text.split()) >= 3:
            novel = self.registry.signals["novel_command"]
            result.attempted = " ".join(text.split())[:90]
            result.observations.append({
                "action": f'tried something the room had not offered: "{result.attempted[:60]}"',
                "kind": "behavioral", "strength": "weak", "context": seed["title"], "signal": "novel_command",
                "hypotheses": [{"dim": d, "dir": direction, "share": share} for d, direction, share in novel["obs"]]})
        return result

    # ---- thresholds --------------------------------------------------
    def threshold(self, session, text: str, *, force: bool, next_seed: dict) -> TurnResult:
        scene, world = session.scene, session.world
        skins = scene["thresholds"]
        index = match_threshold(self.registry, skins, text)
        house_chose = False
        if index is None:
            if not force:
                return TurnResult(narration="The ways wait, each as it was. " + thresholds_text(self.registry, skins)
                                  .replace("The way on divides. ", ""), status="threshold")
            index = session.rng("house-picks").randrange(len(skins))
            house_chose = True
        skin = self.registry.skins[skins[index]]
        return TurnResult(
            narration=stage_text(self.registry, next_seed, skin, world, house_chose=house_chose),
            status="open", threshold_choice=index, house_chose=house_chose,
            summary=f"took {short_way(skin)}")
