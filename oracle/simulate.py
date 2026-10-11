"""Simulated players.

Each persona is a set of leanings over the option tags the chambers are
authored with. A persona plays a whole offline night by taking, in each
chamber, the available option that best suits it. This is how the claim "two
different players get two different games" is tested without a human or a
model, and how a change to the content can be checked for its effect on the
profiles that come out.

Personas are caricatures of ways of playing, not of people.
"""

from __future__ import annotations

from .content import Registry
from .engine import Engine
from .offline import available_options
from .session import Session
from .synthesis import synthesize
from .ui import ScriptedConsole

PERSONAS: dict[str, dict] = {
    "cartographer": {
        "about": "reads everything, tests before trusting, finishes sets",
        "tags": {"careful": 3, "examine": 3, "plan": 3, "lore": 2, "explore": 2, "complete": 2, "collect": 2,
                 "system": 1, "numbers": 1, "hoard": 1,
                 "bold": -2, "chaos": -3, "spend": -1, "transgress": -1, "direct": -1},
        "skins": {"aes.orderly_chaotic": -1, "aes.maximal_minimal": 1, "tone.contemplative": 1,
                  "tone.mysterious": 1},
        "linger": 2,
    },
    "firestarter": {
        "about": "presses the button marked NO, then looks for another",
        "tags": {"bold": 3, "transgress": 3, "chaos": 3, "exploit": 2, "play": 2, "funny": 2, "spend": 2,
                 "power": 2, "trick": 1, "fight": 1,
                 "careful": -2, "plan": -2, "wait": -2, "avoid": -1, "hoard": -2},
        "skins": {"aes.orderly_chaotic": 1, "tone.chaotic": 1, "tone.funny": 1, "tone.absurd": 1},
        "linger": 1,
    },
    "speedrunner": {
        "about": "takes the marked door, fails fast, goes again",
        "tags": {"direct": 3, "efficient": 3, "retry": 3, "compete": 2, "power": 1, "bold": 1,
                 "linger": -3, "lore": -2, "examine": -2, "wait": -2, "collect": -1, "explore": -1},
        "skins": {"aes.maximal_minimal": 1, "aes.clean_decayed": -1, "tone.heroic": 1},
        "linger": 0,
    },
    "host": {
        "about": "talks to everyone, keeps the stray, stays for tea",
        "tags": {"social": 3, "talk": 3, "help": 3, "cooperate": 3, "linger": 2, "express": 2, "funny": 1,
                 "lore": 1, "fight": -3, "trick": -1, "exploit": -2, "ignore": -3, "efficient": -1},
        "skins": {"tone.cozy": 1, "aes.cute_severe": -1, "tone.intimate": 1, "aes.familiar_alien": -1},
        "linger": 1,
    },
    "tinkerer": {
        "about": "wants to know how it works, then makes it do something else",
        "tags": {"system": 3, "make": 3, "numbers": 2, "plan": 2, "trick": 2, "exploit": 2, "examine": 1,
                 "retry": 2, "curious": 2, "social": -1, "direct": -1, "refuse": -2, "avoid": -1},
        "skins": {"aes.organic_mechanical": 1, "tone.mysterious": 1, "aes.orderly_chaotic": -1},
        "linger": 1,
    },
}


def _score(option: dict, leanings: dict) -> float:
    return sum(leanings.get(tag, 0) for tag in option.get("tags", []))


def choose_option(seed: dict, scene: dict, world, persona: dict, rng) -> dict:
    options = [o for o in available_options(seed, scene["flags"])
               if not ((o.get("effects") or {}).get("matches", 0) < 0
                       and world.matches + o["effects"]["matches"] < 0)]
    taken = scene.setdefault("sim_taken", [])
    lingering = [o for o in options if not o["resolves"] and o["id"] not in taken
                 and _score(o, persona["tags"]) > 0]
    closing = [o for o in options if o["resolves"]]
    if scene["turns"] < persona["linger"] and lingering:
        pool = lingering
    else:
        pool = closing or options
    best = max(_score(o, persona["tags"]) for o in pool)
    pick = rng.choice([o for o in pool if _score(o, persona["tags"]) == best])
    taken.append(pick["id"])
    return pick


def choose_skin(registry: Registry, skin_ids: list[str], persona: dict, rng) -> str:
    def score(skin_id: str) -> float:
        skin = registry.skins[skin_id]
        total = 0.0
        for key, want in persona["skins"].items():
            if key.startswith("tone."):
                total += 1.0 if key.split(".", 1)[1] in skin["tone"] else 0.0
            elif key in skin["aesthetic"]:
                total += 1.0 if skin["aesthetic"][key] == want else -1.0
        return total

    best = max(score(s) for s in skin_ids)
    return rng.choice([s for s in skin_ids if score(s) == best])


def run_persona(registry: Registry, name: str, *, seed: int = 1, length: str = "standard",
                save: bool = False) -> dict:
    """Play one whole offline night as a persona. Returns the session, model and synthesis."""
    persona = PERSONAS[name]
    session = Session.new({"length": length, "backend": "offline", "backend_used": "offline",
                           "persona": name, "no_save": not save}, seed=seed)
    ui = ScriptedConsole()
    engine = Engine(session, registry, ui, None)
    engine.begin()
    guard_turns = 0
    while not engine.finished and guard_turns < 200:
        guard_turns += 1
        rng = session.rng(f"persona:{name}")
        if session.phase == "threshold":
            engine.turn("@" + choose_skin(registry, session.scene["thresholds"], persona, rng))
        else:
            seed_data = registry.seeds[session.scene["seed"]]
            option = choose_option(seed_data, session.scene, session.world, persona, rng)
            engine.turn("@" + option["id"])
    engine.close_night()
    synthesis = synthesize(registry, engine.model, session, None, ui)
    session.synthesis = synthesis
    session.phase = "done"
    return {"persona": name, "session": session, "model": engine.model, "synthesis": synthesis, "ui": ui}


def summary(run: dict) -> dict:
    design = run["synthesis"]["design"]
    gdv = design["game_design_vector"]
    return {
        "persona": run["persona"],
        "title": design["working_title"],
        "dominant": [s["signal"] for s in design["design_signals"]["dominant"]],
        "secondary": [s["signal"] for s in design["design_signals"]["secondary"]],
        "contradiction": " / ".join(design["design_signals"]["productive_contradiction"].get("between", [])),
        "central_fantasy": gdv["central_fantasy"], "core_verb": gdv["core_verb"],
        "failure_cost": gdv["failure_cost"], "mood": gdv["audiovisual_mood"],
        "unrequested": design["unrequested_feature"]["feature"],
        "turns": run["session"].turn, "observations": len(run["model"].observations),
        "chambers": [s["seed"] for s in run["session"].world.summaries],
    }


def gdv_difference(a: dict, b: dict) -> int:
    """How many Game Design Vector fields differ between two runs."""
    ga = a["synthesis"]["design"]["game_design_vector"]
    gb = b["synthesis"]["design"]["game_design_vector"]
    return sum(1 for key in ga if ga[key] != gb.get(key))
