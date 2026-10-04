import argparse
import contextlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

from oracle import clipboard, guard
from oracle.bundle import BundleError, build_bundle
from oracle.cli import finish, hand_over, help_text, main, run_night
from oracle.content import load_registry
from oracle.devview import render, write_devview
from oracle.engine import Engine
from oracle.model import PlayerModel
from oracle.offline import available_options
from oracle.prompt import (CHECKER, MANUAL_NAME, PROMPT_FILE, PromptError, build_prompt, find_manual,
                           prepare_project, save_prompt, word_count)
from oracle.session import Session, forget, list_sessions, prompts_dir
from oracle.simulate import PERSONAS, run_persona
from oracle.synthesis import build_draft
from oracle.ui import ScriptedConsole

PACKAGE = Path(__file__).resolve().parents[1]
HEADINGS = ("# Build me a game: ", "## 1. Before anything else", "## 2. What this message is", "## 3. The game",
            "### What it stands on (FROM PLAY)", "### Also seen, more faintly (FAINT)", "### Game Design Vector",
            "### Laws (FROM PLAY)", "### Echoes of the night (FROM PLAY)", "### Not known",
            "## 4. Acceptance: the reading", "## 5. Scope (mine to change)", "## 6. My standing grant",
            "## 7. What I expect back")


def table(text: str, heading: str) -> list[list[str]]:
    """The rows of the first table after a heading, without its header and rule."""
    rows = []
    for line in text.split(heading, 1)[1].splitlines()[1:]:
        if line.startswith("|"):
            rows.append([cell.strip() for cell in line.strip().strip("|").split("|")])
        elif rows:
            break
    return rows[2:]


def part(text: str, heading: str) -> str:
    """One section of the prompt: from its heading to the next heading of any level."""
    body = text.split(heading, 1)[1]
    return re.split(r"\n#{2,3} ", body, maxsplit=1)[0]


def fake_manual(folder: Path, reference: bool = True) -> Path:
    """A stand-in manual: a core, its reference folder, the checker, and one thing that is neither."""
    folder.mkdir(parents=True, exist_ok=True)
    (folder / MANUAL_NAME).write_text("# manual core\n", encoding="utf-8")
    if reference:
        (folder / "manual").mkdir(exist_ok=True)
        (folder / "manual" / "REF_PROCESS.md").write_text("## section 5.8\n", encoding="utf-8")
        (folder / "manual" / CHECKER).write_text("print(1)\n", encoding="utf-8")
        (folder / "manual" / "scratch.txt").write_text("not part of the manual\n", encoding="utf-8")
    return folder / MANUAL_NAME


def night_to_the_reading(registry, seed=6, first_lines=(), config=None):
    """A whole night played from the page, stopped just before the reading."""
    session = Session.new(dict({"length": "short", "backend_used": "offline"}, **(config or {})), seed=seed)
    ui = ScriptedConsole()
    engine = Engine(session, registry, ui, None)
    engine.begin()
    for line in first_lines:
        engine.turn(line)
    while not engine.finished:
        if session.phase == "threshold":
            engine.turn("the first one")
        else:
            seed_data = registry.seeds[session.scene["seed"]]
            closing = [o for o in available_options(seed_data, session.scene["flags"]) if o["resolves"]]
            engine.turn("@" + closing[0]["id"])
    return engine, session


class PromptTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.r = load_registry()
        cls.night = run_persona(cls.r, "cartographer", seed=3, save=True)
        cls.design = cls.night["synthesis"]["design"]
        cls.text = build_prompt(cls.r, cls.night["model"], cls.night["session"], cls.night["synthesis"], when=0)

    def test_it_is_one_complete_message(self):
        position = -1
        for heading in HEADINGS:
            found = self.text.find(heading)
            self.assertGreater(found, position, heading)        # every part, in order
            position = found
        self.assertNotIn("{{", self.text)
        self.assertTrue(self.text.startswith(f"# Build me a game: {self.design['working_title']}\n"))
        self.assertIn(f"> Build me **{self.design['working_title']}**: {self.design['pitch']}", self.text)
        self.assertTrue(self.text.endswith("\n"))
        self.assertFalse(self.text.endswith("\n\n"))

    def test_it_tells_the_builder_how_to_use_the_manual(self):
        for needle in ("AI_GAME_DEVELOPMENT_MANUAL.md", "Read it in full", "`manual/`", "chapter A4",
                       "section 5.8 in `manual/REF_PROCESS.md`", "stop and ask me for it", "SHA-256",
                       "chapter A2", "requirement row", "day-zero report", "KEPT", "DEFAULT APPLIED", "PROPOSED"):
            self.assertIn(needle, self.text)

    def test_its_own_words_are_plain_and_name_nothing_of_the_program_s(self):
        # Nothing the program itself wrote needs more than ASCII (the player's words are another matter).
        self.assertTrue(self.text.isascii())
        self.assertNotIn("\r", self.text)
        self.assertNotIn("\t", self.text)
        # Nothing but the manual has to travel with it: it names no file of this program's.
        for stranger in ("oracle_packet", "design_profile", "BUILDER_PROMPT", "python -m oracle", ".blank-deck",
                         "oracle_events", "BUILD_RESULT", self.night["session"].id):
            self.assertNotIn(stranger, self.text)

    def test_every_fact_is_said_once(self):
        signals = self.design["design_signals"]
        for entry in signals["dominant"] + signals["secondary"]:
            self.assertEqual(self.text.count(entry["design_consequence"]), 1, entry["signal"])
        self.assertEqual(self.text.count(signals["productive_contradiction"]["resolution"]), 2)   # pitch, and X
        for law in self.design["negative_constraints"]:
            self.assertEqual(self.text.count(law), 1, law)
        for callback in self.design["personal_callbacks"]:
            self.assertEqual(self.text.count(callback["becomes"]), 1)
        self.assertEqual(self.text.count(self.design["unrequested_feature"]["feature"]), 1)

    def test_the_vector_is_whole_and_says_what_was_decided(self):
        rows = table(self.text, "### Game Design Vector")
        fields = self.r.implications["gdv_fields"]
        self.assertEqual([row[0] for row in rows], [f["label"] for f in fields])
        for field, (label, value, basis) in zip(fields, rows):
            self.assertEqual(value, " ".join(self.design["game_design_vector"][field["id"]].replace("|", "/").split()))
            if value == field["default"] or value.lower().startswith("unknown"):
                # Open to the builder, unless the scope already holds it: then it is the owner's.
                self.assertEqual(basis, "SCOPE" if field.get("scope") else "DEFAULT", label)
            else:
                # Decided by one of the five signals or by the ways taken, or offered on weaker evidence.
                self.assertRegex(basis, r"^(FROM PLAY \((S[1-5]|the ways taken between rooms)\)|FAINT)$", label)
        bases = [row[2] for row in rows]
        self.assertIn("DEFAULT", bases)
        self.assertEqual(sorted(f["id"] for f in fields if f.get("scope")),
                         ["camera_perspective", "session_length", "social_structure"])
        self.assertTrue(any(re.fullmatch(r"FROM PLAY \(S[1-5]\)", basis) for basis in bases))

    def test_every_vision_is_an_acceptance_row(self):
        rows = table(self.text, "## 4. Acceptance: the reading")
        visions = self.night["synthesis"]["prophecy"]["visions"]
        self.assertEqual([row[0] for row in rows], [v["card"] for v in visions])
        self.assertIn(f"told these {len(visions)} things", self.text)
        for vision, (card, told, through) in zip(visions, rows):
            self.assertEqual(told, vision["text"])
            # Each promise points at the one place its design consequence is stated...
            self.assertRegex(through, r"^(S[1-5]|X|E[1-9]|L\d+|nothing was seen here.*)$", card)
            if re.fullmatch(r"(S[1-5]|X|E[1-9]|L\d+)", through):
                # ...and it is the right place: the paragraph with that label says what fulfils it.
                paragraph = re.split(rf"\*\*{through}\b", self.text, maxsplit=1)[1].split("\n\n", 1)[0]
                if through.startswith(("E", "L")):
                    paragraph = paragraph.split("\n", 1)[0]
                self.assertIn(vision["fulfils"].rstrip("."), paragraph, card)

    def test_the_grant_has_the_manual_s_shape_and_lifts_nothing(self):
        grant = part(self.text, "## 6. My standing grant")
        for field in ("**Kind:** leave to proceed, and a taste licence.", "**Covers:** reversible work inside this folder",
                      "**Lifts from the reserved list:** nothing.", "**Stays reserved to me:**", "**Lapses:**",
                      "It does not turn your judgement into my acceptance."):
            self.assertIn(field, grant)
        # It claims the manual's whole reserved list, and adds to it; it does not offer a shorter one as the same.
        for reserved in ("everything the manual's chapter A2 reserves", "each outward act it names", "a push",
                         "a backup off this machine", "the scope in section 5", "player data",
                         "safety, which is never taste", "every download and install",
                         "anything outside this folder that you did not create yourself",
                         "the engine's own data and an engine-lane lock are yours to write"):
            self.assertIn(reserved, grant)
        self.assertIn("File it as grant 1, dated the day you receive this.", grant)
        self.assertIn("State it back to me in your day-zero report.", grant)

    def test_the_scope_is_the_owner_s_and_three_lines_are_not_open(self):
        scope = part(self.text, "## 5. Scope (mine to change)")
        held, fixed = scope.split("Three lines are not yours to open:")
        self.assertIn("I have not examined these lines", held)
        self.assertEqual(held.count("\n- "), len(self.r.implications["scope"]["constraints"]))
        self.assertEqual([line[2:] for line in fixed.strip().splitlines()], self.r.implications["scope"]["fixed"])
        for line in ("The game itself never reaches out", "Original everything", "Photosensitive-safe"):
            self.assertIn(line, fixed)
        # A DEFAULT may be changed by the builder for a stated reason. Scope may not, so it is not called one.
        self.assertNotIn("Scope (DEFAULT)", self.text)
        self.assertIn("10 to 30 minutes", held)

    def test_weaker_evidence_is_offered_and_never_required(self):
        faint = part(self.text, "### Also seen, more faintly (FAINT)")
        self.assertIn("Drop it where it does not fit.", faint)
        self.assertNotIn("must", faint.split("\n\n", 1)[0])
        self.assertIn("**FAINT**: the night gave weaker evidence for it. It is offered, not decided (PROPOSED)", self.text)
        order = "the laws; the visions in section 4; the dominant signals and X; the secondary signals; the echoes; the faint lines"
        self.assertIn(order, self.text)
        self.assertIn("do not rebuild the adventure", self.text)
        self.assertNotIn("beat table", self.text)

    def test_the_owner_sees_the_proposed_game_before_the_apparatus(self):
        # The prompt gives signals and no mechanic, so the builder's invention must reach the owner first.
        self.assertIn("This message gives no mechanic.", self.text)
        self.assertIn("treat it as PROPOSED until I have played it", self.text)
        back = part(self.text, "## 7. What I expect back")
        first = back.split("\n2. ")[0]
        self.assertIn("At once, before the records and the instruments", first)
        self.assertIn("marked PROPOSED", first)
        self.assertIn("Then carry on without waiting for my answer.", first)
        self.assertIn("A vision I do not tick stays open", back)

    def test_proving_a_vision_is_not_accepting_it(self):
        reading = part(self.text, "## 4. Acceptance: the reading")
        self.assertIn("the visions of the reading", reading)
        self.assertIn("requirement row in the plan, with the check that proves it", reading)
        self.assertIn("Proven is not accepted: only my answer after playing accepts a vision.", reading)
        self.assertNotIn("closes", reading + part(self.text, "## 7. What I expect back"))

    def test_what_is_not_known_is_all_listed_and_named(self):
        unknown = [line[2:] for line in part(self.text, "### Not known").splitlines() if line.startswith("- ")]
        states = self.night["model"].compute()
        axes = [st for st in states.values() if self.r.dims[st.id].family == "axis"]
        not_seen = [st for st in axes if st.status == "unknown"]
        pairs = [line for line in unknown if re.fullmatch(r"[a-z ]+: .+ or .+", line)]
        self.assertEqual(len(pairs), len(not_seen))             # every one of them, not the first seven
        self.assertIn(f"{len(axes) - len(not_seen)} of {len(axes)} core dimensions observed", self.text)
        for st in not_seen:
            self.assertIn(f"{st.id.replace('_', ' ')}: {self.r.dims[st.id].neg} or {self.r.dims[st.id].pos}", unknown)

    def test_evidence_is_told_about_the_player_not_to_the_builder(self):
        for name in PERSONAS:
            run = run_persona(self.r, name, seed=2)
            text = build_prompt(self.r, run["model"], run["session"], run["synthesis"], when=0)
            for line in text.splitlines():
                if line.startswith("- Seen when they: "):
                    self.assertNotRegex(line, r"\b(you|your|yours|yourself)\b", line)
                    self.assertNotIn("chose to", line)          # every authored act has its own words
                    for act in line[len("- Seen when they: "):].rstrip(".").split("; "):
                        self.assertRegex(act, r"^[a-z]", act)   # a phrase that follows "they", not a sentence

    def test_one_event_is_one_echo(self):
        # The tinkerer shuffles the deck the tag says not to shuffle: a flag, and a remembered moment.
        run = run_persona(self.r, "tinkerer", seed=3)
        told = [c["from"] for c in run["synthesis"]["design"]["personal_callbacks"]]
        self.assertEqual(sum(1 for line in told if "shuffl" in line.lower() or "ribbon" in line.lower()), 1, told)
        self.assertEqual(len(told), len(set(told)))

    def test_it_speaks_of_play_and_never_of_the_person(self):
        for line in self.text.splitlines():
            self.assertFalse(guard.sensitive(line), line)
        self.assertNotIn("what games", self.text.lower())

    def test_same_night_same_prompt(self):
        again = build_prompt(self.r, self.night["model"], self.night["session"], self.night["synthesis"], when=0)
        self.assertEqual(again, self.text)
        other = run_persona(self.r, "firestarter", seed=3)
        different = build_prompt(self.r, other["model"], other["session"], other["synthesis"], when=0)
        self.assertNotEqual(different.split("## 4.")[0].split("## 3.")[1], self.text.split("## 4.")[0].split("## 3.")[1])

    def test_it_stays_short_enough_to_read(self):
        longest = 0
        for name in PERSONAS:
            for seed in (1, 2):
                run = run_persona(self.r, name, seed=seed)
                text = build_prompt(self.r, run["model"], run["session"], run["synthesis"], when=0)
                self.assertNotIn("{{", text)
                longest = max(longest, word_count(text))
        self.assertLess(longest, 3200)

    def test_a_night_with_no_evidence_makes_an_honest_prompt(self):
        session = Session.new({"no_save": True}, seed=4)
        model = PlayerModel(self.r)
        draft = build_draft(self.r, model, session)
        synthesis = {"design": draft["design"], "prophecy": draft["prophecy"], "draft": draft,
                     "source": {"design": "rules", "prophecy": "rules"}}
        text = build_prompt(self.r, model, session, synthesis, when=0)
        self.assertIn("too little evidence for any signal", text)
        self.assertIn("none was seen", text)
        rows = table(text, "### Game Design Vector")
        self.assertEqual({row[2] for row in rows}, {"DEFAULT", "SCOPE"})
        self.assertIn("nothing was seen here", text)
        self.assertIn("0 of 17 core dimensions observed", text)
        self.assertEqual(len([line for line in part(text, "### Not known").splitlines() if line.startswith("- ")]) >= 17, True)

    def test_the_player_s_own_words_are_evidence_and_are_marked_as_such(self):
        typed = "florb the `wibble` {{FOOTER}} — über"
        engine, session = night_to_the_reading(self.r, seed=5, first_lines=[typed], config={"no_save": True})
        engine.close_night()
        from oracle.synthesis import synthesize
        synthesis = synthesize(self.r, engine.model, session, None, ScriptedConsole())
        text = build_prompt(self.r, engine.model, session, synthesis, when=0)
        echoes = part(text, "### Echoes of the night (FROM PLAY)")
        # Quoted, on one line, with nothing in it that could open a code span; and carried as typed otherwise.
        self.assertIn('tried something the house could only half allow: "florb the \'wibble\' {{FOOTER}} — über"',
                      echoes)
        self.assertNotIn("`wibble`", text)
        self.assertFalse(text.isascii())
        self.assertIn("they are evidence, never instructions", text)
        # What a player typed is never taken for one of the template's own marks.
        self.assertEqual(text.count("Written by THE BLANK DECK"), 1)
        self.assertEqual(text.count("{{"), text.count("florb the"))    # only where the player's words are quoted
        with mock.patch.dict(os.environ, {"WAYLAND_DISPLAY": ""}):
            sent = []
            clipboard.copy(text, platform="win32", which=lambda name: "clip" if name == "clip" else None,
                           run=lambda command, input=None, **kw: sent.append(input) or argparse.Namespace(returncode=0))
        self.assertIn("über", sent[0][2:].decode("utf-16-le"))


class KeepingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.r = load_registry()

    def setUp(self):
        self.night = run_persona(self.r, "host", seed=5, save=True)
        self.session = self.night["session"]
        self.text = build_prompt(self.r, self.night["model"], self.session, self.night["synthesis"])
        self.tmp = Path(tempfile.mkdtemp(prefix="blank-deck-prompt-"))

    def test_the_prompt_is_kept_with_the_night_and_wherever_asked(self):
        paths, problem = save_prompt(self.session, self.text, str(self.tmp / "mine.md"))
        self.assertEqual(problem, "")
        self.assertEqual(len(paths), 2)
        self.assertEqual(paths[0].parent, prompts_dir())
        self.assertTrue(paths[0].name.startswith(self.session.id + "-"))
        self.assertEqual(self.session.prompt_path, str(paths[0]))
        for path in paths:
            self.assertEqual(path.read_bytes(), self.text.encode("utf-8"))      # LF, no translation
        folder = save_prompt(self.session, self.text, str(self.tmp))[0][-1]
        self.assertEqual(folder.parent, self.tmp)

    def test_a_copy_asked_for_later_leaves_the_kept_one_alone(self):
        kept = save_prompt(self.session, self.text)[0][0]
        kept.write_text("edited by its owner\n", encoding="utf-8")
        paths, problem = save_prompt(self.session, self.text, str(self.tmp / "copy.md"), keep=False)
        self.assertEqual([p.name for p in paths], ["copy.md"])
        self.assertEqual(kept.read_text(encoding="utf-8"), "edited by its owner\n")

    def test_a_place_that_cannot_be_written_is_said_and_the_kept_copy_still_is(self):
        blocker = self.tmp / "a_file"
        blocker.write_text("x", encoding="utf-8")
        paths, problem = save_prompt(self.session, self.text, str(blocker / "under" / "p.md"))
        self.assertEqual(len(paths), 1)                         # the night's own copy was written
        self.assertEqual(paths[0].parent, prompts_dir())
        self.assertIn("could not write the prompt to", problem)

    def test_a_night_that_keeps_nothing_writes_only_where_it_is_told(self):
        self.session.config["no_save"] = True
        before = set(prompts_dir().glob("*")) if prompts_dir().is_dir() else set()
        self.assertEqual(save_prompt(self.session, self.text), ([], ""))
        paths, problem = save_prompt(self.session, self.text, str(self.tmp / "only.md"))
        self.assertEqual([p.name for p in paths], ["only.md"])
        self.assertEqual(set(prompts_dir().glob("*")) if prompts_dir().is_dir() else set(), before)

    def test_forgetting_a_night_forgets_its_prompt_and_only_its_own(self):
        self.session.save()
        kept = save_prompt(self.session, self.text)[0][0]
        other = run_persona(self.r, "tinkerer", seed=6, save=True)
        other["session"].save()
        other_kept = save_prompt(other["session"], self.text)[0][0]
        # Part of an id is not an id: it must match nothing, however many nights begin that way.
        for partial in (self.session.id[:4], self.session.id[:9], self.session.id[:-1], "*", ""):
            self.assertEqual(forget(partial) if partial else [], [])
        self.assertTrue(kept.is_file() and other_kept.is_file())
        removed = forget(self.session.id)
        self.assertIn(str(kept), removed)
        self.assertFalse(kept.exists())
        self.assertTrue(other_kept.is_file())

    def test_a_folder_is_made_ready_for_a_builder(self):
        manual = find_manual(str(fake_manual(self.tmp / "source")))
        made = prepare_project(str(self.tmp / "game"), self.text, manual)
        game = self.tmp / "game"
        self.assertEqual((game / PROMPT_FILE).read_bytes(), self.text.encode("utf-8"))
        self.assertEqual((game / MANUAL_NAME).read_text(encoding="utf-8"), "# manual core\n")
        # The reference documents and the manual's own checker travel with the core; nothing else does.
        self.assertEqual(sorted(p.name for p in (game / "manual").iterdir()), ["REF_PROCESS.md", CHECKER])
        self.assertEqual((made["files"], made["reference"]), (4, 1))
        prepare_project(str(game), self.text, manual)               # the same files again: nothing to refuse

    def test_nothing_already_in_the_folder_is_ever_replaced(self):
        game = self.tmp / "taken"
        game.mkdir()
        (game / PROMPT_FILE).write_text("someone else's prompt\n", encoding="utf-8")
        with self.assertRaises(PromptError):
            prepare_project(str(game), self.text, None)
        self.assertEqual((game / PROMPT_FILE).read_text(encoding="utf-8"), "someone else's prompt\n")
        # A clash anywhere refuses the whole thing: no prompt is written beside somebody's other manual.
        manual = find_manual(str(fake_manual(self.tmp / "source")))
        other = self.tmp / "other_manual"
        (other / "manual").mkdir(parents=True)
        (other / "manual" / "REF_PROCESS.md").write_text("their own notes\n", encoding="utf-8")
        with self.assertRaises(PromptError) as caught:
            prepare_project(str(other), self.text, manual)
        self.assertIn("manual/REF_PROCESS.md", str(caught.exception))
        self.assertFalse((other / PROMPT_FILE).exists())
        self.assertFalse((other / MANUAL_NAME).exists())
        self.assertEqual((other / "manual" / "REF_PROCESS.md").read_text(encoding="utf-8"), "their own notes\n")

    def test_the_manual_is_found_where_it_is_named(self):
        core = fake_manual(self.tmp / "m")
        self.assertEqual(find_manual(str(core)).where, str(core))
        self.assertEqual(find_manual(str(core.parent)).where, str(core))        # the folder will do
        self.assertIsNone(find_manual(str(self.tmp / "nowhere.md")))
        prompt_only = prepare_project(str(self.tmp / "bare"), self.text, None)
        self.assertIsNone(prompt_only["manual"])
        self.assertEqual([p.name for p in (self.tmp / "bare").iterdir()], [PROMPT_FILE])

    def test_a_core_without_its_reference_folder_is_said_to_be_alone(self):
        from oracle.cli import _prepare
        core = fake_manual(self.tmp / "core_only", reference=False)
        said = []
        self.assertTrue(_prepare(said.append, str(self.tmp / "half"), self.text, str(core)))
        told = "\n".join(said)
        self.assertIn("NOT there", told)
        self.assertNotIn("and manual/: the manual, copied", told)
        self.assertFalse((self.tmp / "half" / "manual").exists())


class ClipboardTests(unittest.TestCase):
    def run_with(self, platform, tools, returncode=0, fail=()):
        calls = []

        def which(name):
            return f"/bin/{name}" if name in tools else None

        def run(command, input=None, **kw):
            calls.append((command, input))
            if Path(command[0]).name in fail:
                raise OSError("cannot start")
            return argparse.Namespace(returncode=returncode)

        with mock.patch.dict(os.environ, {"WAYLAND_DISPLAY": ""}):
            result = clipboard.copy("one\ntwo — three\n", platform=platform, which=which, run=run)
        return result, calls

    def test_windows_gets_unicode_and_its_own_line_endings(self):
        (done, how), calls = self.run_with("win32", {"clip"})
        self.assertEqual((done, how), (True, "clip"))
        data = calls[0][1]
        self.assertTrue(data.startswith(b"\xff\xfe"))               # the mark that makes clip read Unicode
        self.assertEqual(data[2:].decode("utf-16-le"), "one\r\ntwo — three\r\n")

    def test_other_systems_get_utf8(self):
        (done, how), calls = self.run_with("darwin", {"pbcopy"})
        self.assertEqual((done, how), (True, "pbcopy"))
        self.assertEqual(calls[0][1], "one\ntwo — three\n".encode("utf-8"))
        (done, how), calls = self.run_with("linux", {"xclip", "xsel"})
        self.assertEqual(how, "xclip")
        self.assertEqual(calls[0][0][1:], ["-selection", "clipboard"])

    def test_no_tool_is_said_plainly(self):
        (done, how), calls = self.run_with("linux", set())
        self.assertFalse(done)
        self.assertIn("no clipboard tool", how)
        self.assertEqual(calls, [])
        self.assertIsNone(clipboard.available("linux", lambda name: None))

    def test_a_tool_that_cannot_start_is_passed_over_for_the_next(self):
        (done, how), calls = self.run_with("linux", {"xclip", "xsel"}, fail=("xclip",))
        self.assertEqual((done, how), (True, "xsel"))
        self.assertEqual([Path(c[0][0]).name for c in calls], ["xclip", "xsel"])

    def test_when_nothing_works_every_failure_is_reported(self):
        (done, how), calls = self.run_with("win32", {"clip"}, returncode=1)
        self.assertFalse(done)
        self.assertEqual(how, "clip: exit 1")
        (done, how), calls = self.run_with("linux", {"xclip", "xsel"}, fail=("xclip", "xsel"))
        self.assertFalse(done)
        self.assertIn("xclip: cannot start", how)
        self.assertIn("xsel: cannot start", how)


class HandOverTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.r = load_registry()

    def args(self, **kw):
        base = dict(out=None, copy=None, project=None, manual=None)
        base.update(kw)
        return argparse.Namespace(**base)

    def test_the_night_ends_in_the_reading_and_then_the_prompt(self):
        engine, session = night_to_the_reading(self.r)
        ui = ScriptedConsole()
        self.assertEqual(finish(engine, self.r, ui, self.args()), 0)
        kinds = [kind for kind, _ in ui.out]
        banner = kinds.index("banner")
        self.assertEqual(ui.out[banner][1], "I HAVE SEEN WHAT YOU WILL PLAY.")
        self.assertEqual(kinds[banner + 1:banner + 7], ["narrate", "proprietor", "note", "rule", "raw", "rule"])
        self.assertEqual(ui.out[banner + 1][1], self.r.reading["last_card"])
        self.assertEqual(ui.out[banner + 2][1], self.r.reading["handoff_line"])
        self.assertIn("Out of the fiction now", ui.out[banner + 3][1])
        raw = ui.out[banner + 5][1]
        self.assertTrue(raw.startswith("# Build me a game: "))
        self.assertEqual(session.phase, "done")
        self.assertEqual(session.prompt, raw)                       # what was shown is what was kept
        self.assertEqual(Path(session.prompt_path).read_bytes(), raw.encode("utf-8"))
        after = "\n".join(text for kind, text in ui.out[banner + 7:] if kind == "plain")
        self.assertIn(f"Saved: {session.prompt_path}", after)
        self.assertIn("To have the game built:", after)
        self.assertIn("prompt --project <folder>", after)
        self.assertIn(f"forget {session.id}", after)
        # Nobody is at the keyboard, so nobody is asked, and the clipboard is left alone.
        self.assertNotIn("confirm", kinds)
        self.assertNotIn("clipboard", after)

    def test_the_clipboard_is_only_touched_with_a_yes(self):
        engine, session = night_to_the_reading(self.r, seed=7)
        engine.close_night()
        with mock.patch("oracle.cli.clipboard.available", return_value="clip"), \
                mock.patch("oracle.cli.clipboard.copy", return_value=(True, "clip")) as copy:
            ui = ScriptedConsole(confirms=[False])
            ui.interactive = True
            hand_over(ui, session, "the prompt\n", self.args())
            self.assertEqual(copy.call_count, 0)                    # asked, and the answer was no
            self.assertIn("confirm", [kind for kind, _ in ui.out])

            ui = ScriptedConsole(confirms=[True])
            ui.interactive = True
            hand_over(ui, session, "the prompt\n", self.args())
            copy.assert_called_once_with("the prompt\n")
            self.assertIn("On the clipboard: the prompt, 2 words.", ui.text(("plain",)))

            ui = ScriptedConsole()
            ui.interactive = True
            hand_over(ui, session, "the prompt\n", self.args(copy=False))      # --no-copy: not even asked
            self.assertNotIn("confirm", [kind for kind, _ in ui.out])
            self.assertEqual(copy.call_count, 1)

            ui = ScriptedConsole()
            hand_over(ui, session, "the prompt\n", self.args(copy=True))       # --copy: no question needed
            self.assertEqual(copy.call_count, 2)

    def test_a_copy_that_fails_is_said_and_the_prompt_is_still_there(self):
        engine, session = night_to_the_reading(self.r, seed=8)
        engine.close_night()
        with mock.patch("oracle.cli.clipboard.copy", return_value=(False, "clip: exit 1")):
            ui = ScriptedConsole()
            hand_over(ui, session, "the prompt\n", self.args(copy=True))
        text = ui.text(("plain",))
        self.assertIn("Not copied to the clipboard: clip: exit 1.", text)
        self.assertIn("Saved: ", text)
        self.assertIn(("raw", "the prompt\n"), ui.out)

    def test_a_file_that_cannot_be_written_does_not_hide_the_one_that_was(self):
        engine, session = night_to_the_reading(self.r, seed=10)
        engine.close_night()
        tmp = Path(tempfile.mkdtemp(prefix="blank-deck-handover-"))
        (tmp / "a_file").write_text("x", encoding="utf-8")
        ui = ScriptedConsole()
        hand_over(ui, session, "the prompt\n", self.args(out=str(tmp / "a_file" / "p.md")))
        text = ui.text(("plain",))
        self.assertIn(f"Saved: {session.prompt_path}", text)
        self.assertIn("Not saved: could not write the prompt to", text)

    def test_a_project_folder_can_be_made_on_the_way_out(self):
        engine, session = night_to_the_reading(self.r, seed=9)
        engine.close_night()
        tmp = Path(tempfile.mkdtemp(prefix="blank-deck-handover-"))
        core = fake_manual(tmp / "source")
        ui = ScriptedConsole()
        hand_over(ui, session, "the prompt\n", self.args(project=str(tmp / "game"), manual=str(core)))
        self.assertEqual((tmp / "game" / PROMPT_FILE).read_text(encoding="utf-8"), "the prompt\n")
        self.assertTrue((tmp / "game" / MANUAL_NAME).is_file())
        text = ui.text(("plain",))
        self.assertIn("A folder is ready for the builder", text)
        self.assertNotIn("To have the game built:", text)

    def test_a_night_that_keeps_nothing_is_told_only_what_is_true(self):
        engine, session = night_to_the_reading(self.r, seed=11, config={"no_save": True})
        ui = ScriptedConsole()
        finish(engine, self.r, ui, self.args())
        after = ui.text(("plain", "note"))
        self.assertIn("This night keeps nothing, so the program cannot show the prompt again. Copy it from the screen now.",
                      after)
        self.assertIn("To have the game built:", after)
        # Nothing was kept, so none of the commands that read a kept night are offered: they would
        # hand over some other night's prompt.
        for false_promise in ("prompt --copy", "prompt --project", "dev --open", "forget", "resume", "Saved:"):
            self.assertNotIn(false_promise, after)
        self.assertNotIn("resume", help_text(kept=False))
        self.assertIn("leaving ends it", help_text(kept=False))
        self.assertIn("resume", help_text(kept=True))

    def test_leaving_a_night_that_keeps_nothing_does_not_promise_a_return(self):
        session = Session.new({"length": "short", "no_save": True}, seed=12)
        ui = ScriptedConsole(inputs=["quit"])
        engine = Engine(session, self.r, ui, None)
        engine.begin()
        self.assertEqual(run_night(engine, ui), "quit")
        said = ui.text(("note",))
        self.assertIn("This night was not being kept. It ends here.", said)
        self.assertNotIn("resume", said)
        kept = Session.new({"length": "short"}, seed=12)
        ui = ScriptedConsole(inputs=["quit"])
        engine = Engine(kept, self.r, ui, None)
        engine.begin()
        run_night(engine, ui)
        self.assertIn(f"resume {kept.id}", ui.text(("note",)))


class DeveloperViewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.r = load_registry()
        cls.night = run_persona(cls.r, "cartographer", seed=3, save=True)
        cls.session = cls.night["session"]
        cls.session.prompt = build_prompt(cls.r, cls.night["model"], cls.session, cls.night["synthesis"])

    def test_developer_view_shows_what_the_house_knew(self):
        html = render(self.r, self.session)
        for needle in ("The player model", "How the profile moved", "What the house dealt, and why",
                       "Every observation", "From profile to design", "Game Design Vector", "The reading",
                       "Exact prompt handed over", "Build me a game:", "Transcript", "We do not know"):
            self.assertIn(needle, html)
        self.assertIn(self.session.id, html)
        self.assertNotIn("<script", html)
        path = write_devview(self.r, self.session, str(Path(tempfile.mkdtemp(prefix="blank-deck-dev-")) / "dev.html"))
        self.assertGreater(path.stat().st_size, 20000)

    def test_developer_view_escapes_what_the_player_typed(self):
        session = Session.from_dict(self.session.to_dict())
        session.transcript.append({"turn": 99, "role": "player", "text": "<script>alert(1)</script>", "scene": ""})
        html = render(self.r, session)
        self.assertNotIn("<script>alert(1)</script>", html)
        self.assertIn("&lt;script&gt;alert(1)&lt;/script&gt;", html)

    def test_an_unfinished_night_has_no_prompt_to_show(self):
        session = Session.new({"no_save": True}, seed=2)
        self.assertIn("no prompt has been written", render(self.r, session))


class CommandLineTests(unittest.TestCase):
    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        # Nobody is at the keyboard: a command that would ask must say so and stop, not wait.
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err), mock.patch("sys.stdin", io.StringIO("")):
            code = main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def finished_night(self, persona, seed):
        registry = load_registry()
        night = run_persona(registry, persona, seed=seed, save=True)
        session = night["session"]
        session.prompt = build_prompt(registry, night["model"], session, night["synthesis"])
        save_prompt(session, session.prompt)
        session.save()
        return night, session

    def test_doctor(self):
        code, out, _ = self.run_cli("doctor")
        self.assertEqual(code, 0)
        self.assertIn("Content: valid.", out)
        self.assertIn("Narrator: the authored rooms, which need nothing.", out)
        self.assertIn("Clipboard:", out)

    def test_a_model_is_never_called_unless_asked_for(self):
        from oracle.cli import build_parser, choose_narrator
        args = build_parser().parse_args(["play"])
        self.assertEqual(args.narrator, "offline")
        with mock.patch("oracle.cli.AutoBackend") as auto, mock.patch("oracle.cli.make_backend") as make:
            ui = ScriptedConsole()
            self.assertIsNone(choose_narrator(args, ui))
            self.assertEqual((auto.call_count, make.call_count), (0, 0))
            self.assertEqual(ui.out, [])                             # and nothing needs saying about it
        self.assertEqual(build_parser().parse_args(["play", "--backend", "codex"]).narrator, "codex")

    def test_simulate_one_persona(self):
        target = tempfile.mkdtemp(prefix="blank-deck-sim-")
        code, out, _ = self.run_cli("simulate", "--persona", "speedrunner", "--length", "short", "--out", target)
        self.assertEqual(code, 0)
        self.assertIn("== speedrunner", out)
        self.assertIn("dominant:", out)
        folder = Path(target) / "speedrunner"
        self.assertTrue((folder / "prompt.md").read_text(encoding="utf-8").startswith("# Build me a game: "))
        self.assertNotIn(b"\r\n", (folder / "prompt.md").read_bytes())
        self.assertEqual(json.loads((folder / "profile.json").read_text(encoding="utf-8"))["version"],
                         "blank-deck.profile.v1")
        self.assertTrue((folder / "devview.html").is_file())

    def test_list_and_forget(self):
        night, session = self.finished_night("tinkerer", 8)
        self.assertIn(session.id, [s["id"] for s in list_sessions()])
        code, out, _ = self.run_cli("list")
        self.assertIn(session.id, out)
        self.assertIn(night["synthesis"]["design"]["working_title"], out)
        code, out, _ = self.run_cli("forget", session.id)          # nobody to confirm: nothing is erased
        self.assertEqual(code, 1)
        self.assertIn(session.id, [s["id"] for s in list_sessions()])
        code, out, _ = self.run_cli("forget", session.id[:8], "--yes")     # part of an id erases nothing
        self.assertIn("There was nothing to erase.", out)
        self.assertTrue(Path(session.prompt_path).is_file())
        code, out, _ = self.run_cli("forget", session.id, "--yes")
        self.assertEqual(code, 0)
        self.assertNotIn(session.id, [s["id"] for s in list_sessions()])
        self.assertFalse(Path(session.prompt_path).exists())
        self.assertEqual(forget(session.id), [])

    def test_prompt_profile_and_dev_from_a_saved_night(self):
        night, session = self.finished_night("host", 9)
        target = Path(tempfile.mkdtemp(prefix="blank-deck-cli-"))

        code, out, err = self.run_cli("prompt", session.id)
        self.assertEqual((code, out), (0, session.prompt))          # the prompt and nothing else
        code, out, err = self.run_cli("prompt", session.id, "--out", str(target / "p.md"))
        self.assertEqual(code, 0)
        self.assertEqual((target / "p.md").read_bytes(), session.prompt.encode("utf-8"))
        core = fake_manual(target / "source")
        code, out, err = self.run_cli("prompt", session.id, "--project", str(target / "game"), "--manual", str(core))
        self.assertEqual(code, 0)
        self.assertEqual((target / "game" / PROMPT_FILE).read_bytes(), session.prompt.encode("utf-8"))
        self.assertTrue((target / "game" / "manual" / "REF_PROCESS.md").is_file())
        with mock.patch("oracle.cli.clipboard.copy", return_value=(True, "clip")) as copy:
            code, out, err = self.run_cli("prompt", session.id, "--copy")
        copy.assert_called_once_with(session.prompt)
        self.assertIn("On the clipboard", out)

        code, out, err = self.run_cli("profile", session.id)
        self.assertEqual(json.loads(out)["working_title"], night["synthesis"]["design"]["working_title"])
        code, out, err = self.run_cli("dev", session.id, "--out", str(target / "dev.html"))
        self.assertEqual(code, 0)
        self.assertTrue((target / "dev.html").is_file())

    def test_asking_for_an_old_prompt_changes_nothing_about_that_night(self):
        older_night, older = self.finished_night("speedrunner", 21)
        newer_night, newer = self.finished_night("cartographer", 22)
        self.assertNotEqual(older.prompt, newer.prompt)
        kept = Path(older.prompt_path)
        kept.write_text("edited by its owner\n", encoding="utf-8")
        order = [s["id"] for s in list_sessions()]
        target = Path(tempfile.mkdtemp(prefix="blank-deck-old-"))
        code, out, err = self.run_cli("prompt", older.id, "--out", str(target / "old.md"))
        self.assertEqual(code, 0)
        self.assertEqual((target / "old.md").read_bytes(), older.prompt.encode("utf-8"))
        self.assertEqual(kept.read_text(encoding="utf-8"), "edited by its owner\n")     # not rewritten
        self.assertEqual([s["id"] for s in list_sessions()], order)                     # and not made the latest
        code, out, err = self.run_cli("prompt")
        self.assertEqual(out, newer.prompt)

    def test_a_night_from_before_the_prompt_existed_still_gives_one(self):
        registry = load_registry()
        night = run_persona(registry, "tinkerer", seed=4, save=True)
        night["session"].save()                                     # a finished night with no prompt kept
        code, out, err = self.run_cli("prompt", night["session"].id)
        self.assertEqual(code, 0)
        self.assertTrue(out.startswith("# Build me a game: "))

    def test_an_unfinished_night_has_no_prompt(self):
        session = Session.new({"length": "short"}, seed=12)
        session.save()
        code, out, err = self.run_cli("prompt", session.id)
        self.assertEqual(code, 1)
        self.assertIn("No finished night", err)

    def test_a_place_that_cannot_be_written_ends_in_one_line_not_a_traceback(self):
        night, session = self.finished_night("host", 23)
        tmp = Path(tempfile.mkdtemp(prefix="blank-deck-unwritable-"))
        (tmp / "a_file").write_text("x", encoding="utf-8")
        under = str(tmp / "a_file" / "below" / "out")
        for argv in (("bundle", "--out", under + ".pyz", "--no-manual"), ("dev", session.id, "--out", under + ".html"),
                     ("profile", session.id, "--out", under + ".json"),
                     ("simulate", "--persona", "host", "--length", "short", "--out", under)):
            code, out, err = self.run_cli(*argv)
            self.assertEqual(code, 1, argv)
            self.assertEqual(len(err.strip().splitlines()), 1, err)
            self.assertNotIn("Traceback", err)
        code, out, err = self.run_cli("prompt", session.id, "--out", under + ".md")
        self.assertEqual(code, 1)
        self.assertIn("Not saved: could not write the prompt to", out)


class StandaloneTests(unittest.TestCase):
    """The program as one file, and as a folder copied somewhere else. Each is run as a real
    process from a directory that holds nothing of the source."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix="blank-deck-standalone-"))
        cls.manual = find_manual(str(fake_manual(cls.tmp / "source")))
        cls.info = build_bundle(str(cls.tmp / "deck.pyz"), manual=cls.manual)
        cls.elsewhere = cls.tmp / "elsewhere"
        cls.elsewhere.mkdir()
        cls.env = dict(os.environ, ORACLE_HOME=str(cls.tmp / "home"), PYTHONIOENCODING="utf-8", NO_COLOR="1")
        cls.env.pop("PYTHONPATH", None)

    def run_python(self, *argv, stdin="", cwd=None):
        return subprocess.run([sys.executable, *argv], input=stdin, cwd=cwd or self.elsewhere, env=self.env,
                              capture_output=True, text=True, encoding="utf-8", timeout=120)

    def run_file(self, *argv, stdin=""):
        return self.run_python(str(self.info["path"]), *argv, stdin=stdin)

    def test_the_single_file_holds_the_program_and_not_its_tests(self):
        with zipfile.ZipFile(self.info["path"]) as archive:
            names = set(archive.namelist())
        for needed in ("__main__.py", "oracle/cli.py", "oracle/prompt.py", "oracle/content/seeds_core.json",
                       "oracle/content/build_prompt.md", f"oracle/manual_kit/{MANUAL_NAME}",
                       "oracle/manual_kit/manual/REF_PROCESS.md", f"oracle/manual_kit/manual/{CHECKER}"):
            self.assertIn(needed, names)
        self.assertFalse([n for n in names if "/tests/" in n or "__pycache__" in n or n.endswith("scratch.txt")])
        self.assertFalse([n for n in names if n.startswith("oracle/app/")])       # the phone build stays behind
        self.assertEqual(self.info["bytes"], self.info["path"].stat().st_size)
        self.assertEqual(self.info["reference"], 1)

    def test_it_runs_from_anywhere(self):
        done = self.run_file("doctor")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn("Content: valid.", done.stdout)
        self.assertRegex(done.stdout, r"Run as: python\S* \S*deck\.pyz")
        self.assertIn("This copy: one file", done.stdout)
        self.assertIn("the copy carried inside this program", done.stdout)

    def test_a_whole_night_can_be_played_from_it(self):
        # A player who only ever types "wait" is carried through every room by the house.
        done = self.run_file("--length", "short", "--seed", "5", "--fast", "--plain", "--no-copy",
                             "--project", str(self.tmp / "game"), stdin="wait\n" * 90)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn("I HAVE SEEN WHAT YOU WILL PLAY.", done.stdout)
        self.assertIn("the prompt begins below this line", done.stdout)
        self.assertRegex(done.stdout, r"deck\.pyz prompt --copy")
        prompt = (self.tmp / "game" / PROMPT_FILE).read_text(encoding="utf-8")
        self.assertIn(prompt, done.stdout.replace("\r\n", "\n"))     # the screen shows exactly what was written
        self.assertEqual((self.tmp / "game" / MANUAL_NAME).read_text(encoding="utf-8"), "# manual core\n")
        self.assertTrue((self.tmp / "game" / "manual" / CHECKER).is_file())
        again = self.run_file("prompt")
        self.assertEqual(again.stdout.replace("\r\n", "\n"), prompt)

    def test_a_copied_folder_runs_without_being_installed(self):
        copied = self.tmp / "carried somewhere" / "oracle"
        shutil.copytree(PACKAGE, copied, ignore=shutil.ignore_patterns("tests", "__pycache__"))
        done = self.run_python(str(copied), "doctor")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn("Content: valid.", done.stdout)
        self.assertIn("This copy: a folder of source files.", done.stdout)
        self.assertIn(f'"{copied}"', done.stdout)                  # told to type what was typed, quoted for its space
        inside = self.run_python(".", "doctor", cwd=copied)         # and from inside the folder
        self.assertEqual(inside.returncode, 0, inside.stderr)
        self.assertRegex(inside.stdout, r"Run as: python\S* \.")

    def test_a_single_file_can_only_copy_itself(self):
        done = self.run_file("bundle", "--out", str(self.tmp / "copy.pyz"))
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual((self.tmp / "copy.pyz").read_bytes(), self.info["path"].read_bytes())

    def test_a_file_that_cannot_be_written_is_refused_by_name(self):
        (self.tmp / "a_file").write_text("x", encoding="utf-8")
        with self.assertRaises(BundleError):
            build_bundle(str(self.tmp / "a_file" / "under" / "deck.pyz"), with_manual=False)

    def test_nothing_in_it_needs_a_python_newer_than_it_says(self):
        # Path.write_text grew its newline argument in Python 3.10. The README promises 3.9.
        for source in sorted(PACKAGE.glob("*.py")):
            text = source.read_text(encoding="utf-8")
            self.assertNotRegex(text, r"write_text\([^)\n]*newline=", source.name)
            self.assertNotRegex(text, r"(?m)^\s*match .+:\s*$", source.name)
            self.assertIn("from __future__ import annotations", text) if "->" in text else None


if __name__ == "__main__":
    unittest.main()
