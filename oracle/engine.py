"""The night itself: the turn loop that joins the narrator, the world, the
player model and the probe selector.

The shape of a night:

    the counter -> threshold -> chamber -> threshold -> ... -> the Reading Room -> the reading

In a chamber the player types what they do and the narrator answers. When the
chamber closes, the house offers two or three ways onward. The way the player
takes dresses the next chamber, and which chamber that is was decided, when
the last one closed, by what the model still did not know.

Deterministic code owns everything that must be exact: state, evidence
bookkeeping, pacing, what is dealt next, persistence. The narrator, live or
offline, only ever returns a `TurnResult`.
"""

from __future__ import annotations

from . import guard, probes
from .backends import Backend, BackendError
from .content import Registry
from .model import PlayerModel
from .narrator import LiveNarrator
from .offline import OfflineNarrator, TurnResult, thresholds_present, thresholds_text
from .session import (EXCHANGE_MEMORY, HARD_CAP, READING_HARD_CAP, READING_SOFT_CAP, SOFT_CAP, Session)

QUIET_NOTE = ("The house's voice has gone quiet: the model did not answer. The night goes on from the page, "
              "with shorter answers and the same house.")
STUMBLE_NOTE = "The house loses its thread for a moment, and goes on."


def _strings(value, limit: int = 8) -> list[str]:
    if isinstance(value, str):
        value = [value]
    if not isinstance(value, list):
        return []
    return [str(v).strip() for v in value if isinstance(v, (str, int, float)) and str(v).strip()][:limit]


class Engine:
    def __init__(self, session: Session, registry: Registry, ui, backend: Backend | None = None):
        self.s, self.r, self.ui = session, registry, ui
        self.model = PlayerModel.from_list(registry, session.observations)
        self.offline = OfflineNarrator(registry)
        self.backend = backend
        self.live = LiveNarrator(registry, backend, ui) if backend is not None else None
        self._live_failures = 0

    # ------------------------------------------------------------------
    @property
    def finished(self) -> bool:
        return self.s.phase in ("reveal", "done")

    def begin(self) -> None:
        s = self.s
        if s.phase == "new":
            opener = self.r.opener()
            self._start_scene(opener["id"], None, opener["intro"])
            s.phase = "chamber"
            self.ui.narrate(opener["intro"])
            s.say("house", opener["intro"], source="page")
            s.save()
            return
        last = next((t["text"] for t in reversed(s.transcript) if t["role"] == "house"), "")
        self.ui.note("The house has kept your place.")
        if last:
            self.ui.narrate(last)

    def turn(self, text: str) -> None:
        s = self.s
        s.turn += 1
        s.say("player", text)
        if s.phase in ("chamber", "reading"):
            self._chamber_turn(text)
        elif s.phase == "threshold":
            self._threshold_turn(text)
        s.snapshots.append({"turn": s.turn, "scene": s.scene.get("key"), "dims": self.model.snapshot()})
        s.observations = self.model.to_list()
        s.save()

    # ---- scenes ------------------------------------------------------
    def _start_scene(self, seed_id: str, skin_id: str | None, staging: str) -> None:
        s = self.s
        seed = self.r.seeds[seed_id]
        index = s.chamber_index
        scene = {"key": f"c{index}:{seed_id}", "n": index, "seed": seed_id, "skin": skin_id, "turns": 0,
                 "flags": {}, "counters": {}, "exchange": [{"house": staging[:1800]}], "thresholds": [],
                 "card_given": False, "unmatched": 0, "threshold_tries": 0, "next_seed": None}
        finale = seed.get("role") == "finale"
        if not finale and index < s.chamber_target:
            skins, record = probes.select_skins(self.r, self.model, taken=s.skins_taken,
                                                offered=s.skins_offered, rng=s.rng("skins"))
            scene["thresholds"] = skins
            s.skins_offered.append(skins)
            record.update(turn=s.turn, after_chamber=index)
            s.probes.append(record)
        if s.world.joker != "kept":
            scene["flags"]["joker_gone"] = True
        s.scene = scene
        if seed_id not in s.seeds_used:
            s.seeds_used.append(seed_id)

    def _chamber_turn(self, text: str) -> None:
        s, scene = self.s, self.s.scene
        scene["turns"] += 1
        seed = self.r.seeds[scene["seed"]]
        finale = seed.get("role") == "finale"
        soft_cap, hard_cap = (READING_SOFT_CAP, READING_HARD_CAP) if finale else (SOFT_CAP, HARD_CAP)
        kw = dict(soft=scene["turns"] >= soft_cap, must_close=scene["turns"] >= hard_cap,
                  last_chamber=(not finale and s.chamber_index >= s.chamber_target), finale=finale)
        result = None
        if self.live is not None:
            try:
                result = self.live.chamber(s, text, soft_cap=soft_cap, hard_cap=hard_cap, **kw)
                self._live_failures = 0
                if any(p in result.problems for p in ("oracle_json_invalid", "oracle_block_missing")):
                    self._borrow_page_reading(result, seed, text)
            except BackendError as exc:
                self._live_failed(exc)
        if result is None:
            result = self.offline.chamber(s, text, **kw)
        self._apply(result, text, frame=seed["kind"], seed_id=seed["id"], scene_key=scene["key"])
        if result.status == "resolved":
            self._close_chamber(result)

    def _borrow_page_reading(self, result: TurnResult, seed: dict, text: str) -> None:
        """The model's notes could not be read. Rather than lose the turn's evidence, use the
        authored reading of the nearest option, when the line clearly means one."""
        from .offline import match_option
        option, score = match_option(seed, self.s.scene["flags"], text)
        self.s.guard_events.append({"guard": "notes_unreadable", "turn": self.s.turn,
                                    "problems": result.problems, "borrowed": bool(option and score >= 1.0)})
        if option and score >= 1.0 and option.get("obs"):
            result.observations = [{
                "action": " ".join(text.split())[:80], "kind": "behavioral",
                "strength": option.get("strength", "moderate"), "context": seed["title"],
                "hypotheses": [{"dim": d, "dir": direction, "share": share} for d, direction, share in option["obs"]]}]
            result.source = "offline"

    def _live_failed(self, exc: BackendError) -> None:
        s = self.s
        self._live_failures += 1
        permanent = exc.kind in ("auth", "unavailable") or self._live_failures >= 2
        s.guard_events.append({"guard": "backend_failure", "turn": s.turn, "kind": exc.kind,
                               "detail": str(exc)[:240], "permanent": permanent})
        if permanent:
            self.live = None
            self.backend = None
            s.config["backend_used"] = "offline (the model stopped answering)"
            self.ui.note(QUIET_NOTE)
        else:
            self.ui.note(STUMBLE_NOTE)

    def _close_chamber(self, result: TurnResult) -> None:
        s, w, scene = self.s, self.s.world, self.s.scene
        seed = self.r.seeds[scene["seed"]]
        line = result.summary or scene.get("last_summary") or "passed through"
        w.summaries.append({"n": scene["n"], "seed": seed["id"], "title": seed["title"],
                            "skin": scene.get("skin"), "line": line, "turns": scene["turns"]})
        if seed.get("role") == "finale":
            s.phase = "reveal"
            return
        if s.chamber_index >= s.chamber_target:
            finale = self.r.finale()
            s.chamber_index += 1
            self._start_scene(finale["id"], None, finale["intro"])
            s.phase = "reading"
            self.ui.narrate(finale["intro"])
            s.say("house", finale["intro"], source="page")
            return
        if result.source == "llm" and not thresholds_present(self.r, result.narration, scene["thresholds"]):
            extra = thresholds_text(self.r, scene["thresholds"])
            self.ui.narrate(extra)
            s.say("house", extra, source="page")
            scene["exchange"].append({"house": extra})
        next_seed, record = probes.select_seed(
            self.r, self.model, used=s.seeds_used, next_chamber=s.chamber_index + 1,
            chamber_target=s.chamber_target, world=w, rng=s.rng("seed"))
        record["turn"] = s.turn
        s.probes.append(record)
        scene["next_seed"] = next_seed
        scene["threshold_tries"] = 0
        s.phase = "threshold"
        self.ui.dev(f"next room: {self.r.seeds[next_seed]['title']}  ({record['why']})")

    def _threshold_turn(self, text: str) -> None:
        s, scene = self.s, self.s.scene
        next_seed = self.r.seeds[scene["next_seed"]]
        skins = scene["thresholds"]
        tries = scene.get("threshold_tries", 0)
        force = tries >= 1
        key = f"t{scene['n']}"
        result = None
        if self.live is not None:
            force_index = s.rng("house-picks").randrange(len(skins)) if force else None
            try:
                result = self.live.threshold(s, text, next_seed=next_seed, force_index=force_index)
                self._live_failures = 0
            except BackendError as exc:
                self._live_failed(exc)
        if result is None:
            result = self.offline.threshold(s, text, force=force, next_seed=next_seed)
        self._apply(result, text, frame="threshold", seed_id=scene["seed"], scene_key=key)
        if result.threshold_choice is None:
            scene["threshold_tries"] = tries + 1
            return
        chosen = skins[result.threshold_choice]
        if not result.house_chose:
            for obs in probes.skin_evidence(self.r, chosen, skins):
                added = self.model.add(turn=s.turn, scene=key, seed=chosen, frame="threshold", source="rule", **obs)
                if added is not None:
                    reading = "  ".join(f"{h.dim}{'+' if h.dir > 0 else '-'}{h.share:.2f}" for h in added.hypotheses)
                    self.ui.dev(f"obs #{added.id} [{added.strength}, rule] {added.action[:60]} -> {reading}")
        s.skins_taken.append(chosen)
        s.chamber_index += 1
        staging = result.narration + ("\n\n" + result.addendum if result.addendum else "")
        self._start_scene(next_seed["id"], chosen, staging)
        s.phase = "chamber"

    # ---- applying a reply --------------------------------------------
    def _apply(self, result: TurnResult, text: str, *, frame: str, seed_id: str, scene_key: str) -> None:
        s, w, scene = self.s, self.s.world, self.s.scene
        log = s.guard_events
        if not result.shown:
            self.ui.narrate(result.narration)
        if result.addendum:
            self.ui.narrate(result.addendum)
        full = result.narration + ("\n\n" + result.addendum if result.addendum else "")
        s.say("house", full, source=result.source, option=result.option)
        if result.source == "llm":
            leaks = guard.narration_leaks(result.narration)
            if leaks:
                log.append({"guard": "narration_leak", "turn": s.turn, "phrases": leaks})
            if result.problems:
                log.append({"guard": "reply_problems", "turn": s.turn, "problems": result.problems})

        before = (w.matches, w.joker)
        self._apply_state(result.state)

        recorded = []
        for o in result.observations:
            hyps = []
            for h in o.get("hypotheses") or []:
                if isinstance(h, dict):
                    h = dict(h)
                    h["why"] = guard.scrub(str(h.get("why", ""))[:160], log, "hypothesis", s.turn)
                    hyps.append(h)
            signal = str(o.get("signal", ""))
            obs = self.model.add(
                turn=s.turn, scene=scene_key, seed=seed_id, frame=frame,
                action=guard.scrub(str(o.get("action", ""))[:200], log, "observation", s.turn),
                context=guard.scrub(str(o.get("context", ""))[:200], log, "observation", s.turn),
                hypotheses=hyps, kind=str(o.get("kind", "behavioral")), strength=str(o.get("strength", "weak")),
                source=result.source, signal=signal if signal in self.r.signals else "")
            if obs is not None:
                recorded.append(obs)
                if obs.signal:
                    w.signals[obs.signal] = w.signals.get(obs.signal, 0) + 1

        if result.card and not scene.get("card_given"):
            title = guard.scrub(str(result.card.get("title", ""))[:60], log, "card", s.turn)
            image = guard.scrub(str(result.card.get("image", ""))[:160], log, "card", s.turn)
            if not guard.removed(title) and not guard.removed(image):
                dims = [f"{h.dim}{'+' if h.dir > 0 else '-'}" for obs in recorded for h in obs.hypotheses]
                w.cards.append({"title": title, "image": image, "turn": s.turn, "seed": seed_id, "dims": dims[:5]})
                scene["card_given"] = True
        if result.moment:
            moment = guard.scrub(str(result.moment)[:180], log, "moment", s.turn)
            if not guard.removed(moment):
                w.moments.append({"text": moment, "turn": s.turn, "seed": seed_id})
        for item in result.focus:
            w.focus[item] = w.focus.get(item, 0) + 1
        for item in result.ignored:
            item = guard.scrub(item, log, "ignored", s.turn)
            if item not in w.ignored and not guard.removed(item):
                w.ignored.append(item)
        if result.attempted:
            attempted = guard.scrub(result.attempted, log, "attempted", s.turn)
            if not guard.removed(attempted):
                w.attempted.append(attempted)

        scene.setdefault("exchange", []).append({"player": text[:400], "house": full[:1800]})
        scene["exchange"] = scene["exchange"][-(EXCHANGE_MEMORY + 1):]
        if result.summary:
            scene["last_summary"] = guard.scrub(result.summary, log, "summary", s.turn)

        if getattr(self.ui, "dev_enabled", False):
            for obs in recorded:
                reading = "  ".join(f"{h.dim}{'+' if h.dir > 0 else '-'}{h.share:.2f}" for h in obs.hypotheses)
                self.ui.dev(f"obs #{obs.id} [{obs.strength}, {obs.source}] {obs.action[:60]} -> {reading}")
            if before != (w.matches, w.joker):
                self.ui.dev(f"state: matches {before[0]}->{w.matches}, joker {before[1]}->{w.joker}")
            if not recorded:
                self.ui.dev("no evidence recorded this turn")

    def _apply_state(self, state: dict) -> None:
        if not isinstance(state, dict) or not state:
            return
        s, w, scene = self.s, self.s.world, self.s.scene
        log = s.guard_events
        for item in _strings(state.get("inventory_add")):
            item = guard.scrub(item[:90], log, "inventory", s.turn)
            if item not in w.inventory and not guard.removed(item):
                w.inventory.append(item)
        for item in _strings(state.get("inventory_remove")):
            low = item.lower()
            match = next((x for x in w.inventory if x.lower() == low or low in x.lower() or x.lower() in low), None)
            if match:
                w.inventory.remove(match)
        delta = state.get("matches_delta", state.get("matches"))
        if isinstance(delta, (int, float)) and not isinstance(delta, bool) and delta:
            w.matches = max(0, min(12, w.matches + int(max(-3, min(3, delta)))))
        joker = state.get("joker")
        if joker in ("played", "spent") and w.joker == "kept":
            w.joker, w.joker_chamber = joker, s.chamber_index
            scene["flags"]["joker_gone"] = True
        comp = state.get("companion")
        if isinstance(comp, dict) and comp.get("name"):
            w.companion = {"name": guard.scrub(str(comp["name"])[:40], log, "companion", s.turn),
                           "kind": guard.scrub(str(comp.get("kind", ""))[:90], log, "companion", s.turn),
                           "since": s.chamber_index}
        elif comp in ("gone", "lost", "left", False) and w.companion:
            w.flags["companion_lost"] = w.companion.get("name", True)
            w.companion = None
        for npc in state.get("npcs") or []:
            if not (isinstance(npc, dict) and npc.get("name")):
                continue
            entry = {"name": guard.scrub(str(npc["name"])[:40], log, "npc", s.turn),
                     "attitude": guard.scrub(str(npc.get("attitude", ""))[:40], log, "npc", s.turn),
                     "note": guard.scrub(str(npc.get("note", ""))[:140], log, "npc", s.turn)}
            existing = next((n for n in w.npcs if n["name"].lower() == entry["name"].lower()), None)
            if existing:
                existing.update(entry)
            else:
                w.npcs.append(entry)
        flags = state.get("flags")
        if isinstance(flags, dict):
            for key, value in list(flags.items())[:8]:
                if isinstance(key, str) and isinstance(value, (bool, int, float, str)):
                    value = value[:60] if isinstance(value, str) else value
                    scene["flags"][key[:40]] = value
                    w.flags[key[:40]] = value
            if any(value and isinstance(key, str) and ("ribbon" in key.lower() or "shuffl" in key.lower())
                   for key, value in flags.items()):
                w.ribbon_untied = True
        for thread in _strings(state.get("threads_add")):
            thread = guard.scrub(thread[:160], log, "thread", s.turn)
            if thread not in w.threads and not guard.removed(thread):
                w.threads.append(thread)
        for thread in _strings(state.get("threads_resolve")):
            low = thread.lower()
            if thread == "*first*":
                match = w.threads[0] if w.threads else None
            else:
                match = next((x for x in w.threads if x.lower() == low or low in x.lower() or x.lower() in low), None)
            if match:
                w.threads.remove(match)
                w.threads_resolved.append(match)
        failures = state.get("failures")
        if isinstance(failures, (int, float)) and not isinstance(failures, bool) and failures > 0:
            w.failures += int(min(failures, 3))
            scene["failed"] = True

    # ---- the end of the night ----------------------------------------
    def close_night(self) -> None:
        """Evidence that only exists once the whole night can be seen: what was kept,
        what was spent, what was carried to the end."""
        s, w = self.s, self.s.world
        if w.flags.get("_night_closed"):
            return

        def add(tag: str, action: str, hypotheses, strength="moderate", context="the whole night") -> None:
            self.model.add(turn=s.turn, scene=f"night:{tag}", seed="night", frame="aggregate", action=action,
                           context=context, hypotheses=hypotheses, strength=strength, source="aggregate")

        # Not using something is weak evidence: it is also what happens when a player simply
        # forgets they have it. A refusal made when spending would have helped is recorded,
        # with its proper strength, in the room where it happened.
        if w.joker == "kept":
            add("joker", "kept the Joker unplayed to the end of the night",
                [("solve.resource", 1, 0.5), ("risk", -1, 0.2)], "weak",
                "a power that could have ended any room, never spent")
        elif w.joker == "played" and (w.joker_chamber or 0) <= 2:
            add("joker", "played the Joker early in the night",
                [("risk", 1, 0.4), ("reward.power", 1, 0.3), ("pacing", 1, 0.2)])
        if w.matches >= 3:
            add("matches", f"finished the night with {w.matches} matches unspent",
                [("solve.resource", 1, 0.4), ("risk", -1, 0.2)], "weak")
        elif w.matches == 0:
            add("matches", "spent every match", [("risk", 1, 0.3), ("solve.resource", -1, 0.3),
                                                 ("friction", -1, 0.2)], "weak")
        if any("doorknob" in item.lower() for item in w.inventory):
            add("doorknob", "carried a useless doorknob all night",
                [("reward.collection", 1, 0.4), ("optimization_expression", 1, 0.3)], "weak")
        if w.companion:
            add("companion", f"kept {w.companion.get('name', 'a companion')} with them to the end",
                [("soc.companions", 1, 0.6), ("reward.cooperation", 1, 0.3)])
        if w.flags.get("seedling"):
            add("seedling", "carried a seedling to the Reading Room",
                [("session_rhythm", 1, 0.5), ("reward.cooperation", 1, 0.3)])
        if w.flags.get("wearing"):
            add("costume", f"wore the {w.flags['wearing']} for the rest of the night",
                [("reward.expression", 1, 0.5), ("story.character", 1, 0.3)], "weak")
        if len(w.threads) >= 3:
            add("threads", f"left {len(w.threads)} things unopened or unresolved",
                [("reward.completion", -1, 0.4), ("exploration", -1, 0.2)], "weak")
        elif not w.threads and w.threads_resolved:
            add("threads", "left nothing unresolved behind them", [("reward.completion", 1, 0.4)], "weak")
        w.flags["_night_closed"] = True
        s.snapshots.append({"turn": s.turn, "scene": "night", "dims": self.model.snapshot()})
        s.observations = self.model.to_list()
        s.save()
