import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

from oracle.builder import EventReader, offer_play, run_build
from oracle.cli import main
from oracle.content import load_registry
from oracle.devview import render, write_devview
from oracle.packet import MANUAL_NAME, write_packet
from oracle.session import Session, forget, list_sessions
from oracle.simulate import run_persona
from oracle.ui import ScriptedConsole

FAKE_BUILDER = r'''
import json, pathlib, sys, time
root = pathlib.Path.cwd()
prompt = sys.stdin.read()
assert "Build this game" in prompt
profile = json.loads((root / "oracle_packet" / "design_profile.json").read_text(encoding="utf-8"))
card = profile["prophecy"]["visions"][0]["card"]

def emit(**event):
    with open(root / "oracle_events.jsonl", "a", encoding="utf-8") as fh:
        fh.write(json.dumps(event) + "\n")

emit(event="packet_read")
emit(event="project_created", proof="project.godot")        # claimed before it exists
time.sleep(0.6)                                             # long enough for the oracle to look
(root / "COVENANT.md").write_text("covenant", encoding="utf-8")
emit(event="covenant_written", proof="COVENANT.md")
(root / "project.godot").write_text("; engine project", encoding="utf-8")
emit(event="project_created", proof="project.godot")
emit(event="project_created", proof="project.godot")        # said twice
emit(event="fixed", detail="nothing had failed")
emit(event="tests_passing")                                 # no proof named
emit(event="test_failed", detail="smoke test: missing node")
emit(event="fixed", detail="node added")
emit(event="vision_fulfilled", card="A Card Nobody Dealt")
emit(event="vision_fulfilled", card=card)
emit(event="world_domination")
emit(event="first_run", proof="../outside.log")             # proof outside the project
emit(event="done")                                          # before the result exists
time.sleep(0.6)
(root / "BUILD_RESULT.json").write_text(json.dumps({
    "status": "ok", "title": "Fake", "play_command": [sys.executable, "-c", "print(1)"],
    "summary": "A fake.", "visions": [], "defaults_applied": [], "known_gaps": []}), encoding="utf-8")
emit(event="done")
print("builder finished")
'''


class PacketTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.r = load_registry()
        cls.night = run_persona(cls.r, "cartographer", seed=3, save=True)
        cls.tmp = Path(tempfile.mkdtemp(prefix="blank-deck-packet-"))
        cls.packet = write_packet(cls.r, cls.night["model"], cls.night["session"], cls.night["synthesis"],
                                  out_dir=str(cls.tmp))
        cls.night["session"].save()

    def test_packet_has_every_file(self):
        names = {p.name for p in self.packet.iterdir()}
        self.assertTrue({"GAME_DESCRIPTION.md", "design_profile.json", "prophecy.md", "BUILDER_PROMPT.md",
                         "transcript.md"} <= names)
        self.assertEqual(self.night["session"].packet_dir, str(self.packet))

    def test_game_description_is_a_complete_brief(self):
        text = (self.packet / "GAME_DESCRIPTION.md").read_text(encoding="utf-8")
        design = self.night["synthesis"]["design"]
        self.assertIn(f"# {design['working_title']}", text)
        self.assertIn("Evidence class: **INERT**", "\n".join(text.splitlines()[:30]))
        for heading in ("## The prompt", "## What the design stands on", "## Design implications",
                        "## Game Design Vector", "## Negative constraints", "## Personal callbacks",
                        "## The feature nobody asked for", "## What is not known", "## The prophecy",
                        "## Scope constraints", "## How to build from this"):
            self.assertIn(heading, text)
        rows = [line for line in text.splitlines() if line.startswith("| ") and "---" not in line]
        self.assertGreaterEqual(len(rows), len(self.r.gdv_field_ids()) + len(self.night["synthesis"]["prophecy"]["visions"]))
        for vision in self.night["synthesis"]["prophecy"]["visions"]:
            self.assertIn(vision["card"], text)
        self.assertNotIn("{{", text)

    def test_builder_prompt_is_ready_to_paste(self):
        text = (self.packet / "BUILDER_PROMPT.md").read_text(encoding="utf-8")
        self.assertNotIn("{{", text)
        self.assertIn(self.night["synthesis"]["design"]["working_title"], text)
        self.assertIn("oracle_events.jsonl", text)
        self.assertIn("BUILD_RESULT.json", text)
        self.assertIn("Godot", text)

    def test_profile_json_round_trips(self):
        profile = json.loads((self.packet / "design_profile.json").read_text(encoding="utf-8"))
        self.assertEqual(profile["version"], "blank-deck.profile.v1")
        self.assertEqual(profile["working_title"], self.night["synthesis"]["design"]["working_title"])

    def test_manual_is_copied_when_one_is_given(self):
        manual = self.tmp / "manual.md"
        manual.write_text("# manual\n", encoding="utf-8")
        reference = self.tmp / "manual"
        reference.mkdir()
        (reference / "REF_PROCESS.md").write_text("## section 5.8\n", encoding="utf-8")
        (reference / "check_manual.py").write_text("print(1)\n", encoding="utf-8")
        out = self.tmp / "with_manual"
        packet = write_packet(self.r, self.night["model"], self.night["session"], self.night["synthesis"],
                              out_dir=str(out), manual=str(manual))
        self.assertTrue((packet / MANUAL_NAME).is_file())
        # The reference files travel with the core; only documents are copied.
        self.assertEqual(sorted(p.name for p in (packet / "manual").iterdir()), ["REF_PROCESS.md"])
        prompt = (packet / "BUILDER_PROMPT.md").read_text(encoding="utf-8")
        self.assertIn("section 5.8", prompt)
        self.assertIn("Read it in full", prompt)
        self.night["session"].packet_dir = str(self.packet)

    def test_developer_view_shows_what_the_house_knew(self):
        session = self.night["session"]
        html = render(self.r, session)
        for needle in ("The player model", "How the profile moved", "What the house dealt, and why",
                       "Every observation", "From profile to design", "Game Design Vector", "The reading",
                       "Exact prompt for the builder", "Transcript", "We do not know"):
            self.assertIn(needle, html)
        self.assertIn(session.id, html)
        self.assertNotIn("<script", html)
        path = write_devview(self.r, session, str(self.tmp / "dev.html"))
        self.assertGreater(path.stat().st_size, 20000)

    def test_developer_view_escapes_what_the_player_typed(self):
        session = Session.from_dict(self.night["session"].to_dict())
        session.transcript.append({"turn": 99, "role": "player", "text": "<script>alert(1)</script>", "scene": ""})
        html = render(self.r, session)
        self.assertNotIn("<script>alert(1)</script>", html)
        self.assertIn("&lt;script&gt;alert(1)&lt;/script&gt;", html)


class BuilderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.r = load_registry()

    def setUp(self):
        self.night = run_persona(self.r, "host", seed=5, save=True)
        self.session = self.night["session"]
        self.tmp = Path(tempfile.mkdtemp(prefix="blank-deck-build-"))
        write_packet(self.r, self.night["model"], self.session, self.night["synthesis"], out_dir=str(self.tmp / "p"))
        self.script = self.tmp / "fake_builder.py"
        self.script.write_text(FAKE_BUILDER, encoding="utf-8")

    def build(self, script=None, **kw):
        ui = ScriptedConsole()
        command = f'"{sys.executable}" "{script or self.script}"'
        record = run_build(self.session, ui, preset="command", command=command,
                           project_dir=str(self.tmp / "game"), poll_seconds=0.05, **kw)
        return record, ui

    def test_only_real_events_are_shown_and_in_order(self):
        record, ui = self.build()
        shown = [text for kind, text in ui.out if kind == "banner"]
        card = self.night["synthesis"]["prophecy"]["visions"][0]["card"].upper()
        self.assertEqual(shown, [
            "OTHER HANDS HAVE TAKEN UP THE CARDS.",
            "ITS LAWS ARE BEING WRITTEN.",
            "A WORLD IS FORMING.",
            "THE WORLD HAS DIED.",
            "THE WORLD IS BEING BORN AGAIN.",
            f"A CARD HAS COME TRUE: {card}.",
            "IT IS FINISHED.",
        ])
        self.assertEqual(record["status"], "ok")
        self.assertEqual(record["returncode"], 0)
        why = [w["why"] for w in record["events_withheld"]]
        self.assertEqual(why, ["proof file missing", "already shown", "nothing had failed", "proof file missing",
                               "not a card that was dealt, or already shown", "unrecognised event",
                               "proof file missing", "BUILD_RESULT.json not written"])
        self.assertIn("builder finished", Path(record["log"]).read_text(encoding="utf-8"))
        self.assertTrue((self.tmp / "game" / "oracle_packet" / "GAME_DESCRIPTION.md").is_file())
        self.assertEqual(self.session.build["status"], "ok")
        self.assertIn("Build this game", record["prompt"])

    def test_a_builder_that_writes_no_result_is_reported_as_failed(self):
        quiet = self.tmp / "quiet.py"
        quiet.write_text("import sys\nsys.stdin.read()\nprint('gave up')\n", encoding="utf-8")
        record, ui = self.build(script=quiet)
        self.assertEqual(record["status"], "failed")
        self.assertEqual([t for k, t in ui.out if k == "banner"], [])

    def test_a_builder_that_never_stops_is_stopped(self):
        slow = self.tmp / "slow.py"
        slow.write_text("import sys, time\nsys.stdin.read()\ntime.sleep(60)\n", encoding="utf-8")
        record, ui = self.build(script=slow, timeout_minutes=0.01)
        self.assertEqual(record["status"], "timeout")
        self.assertTrue(record["timed_out"])

    def test_half_written_event_lines_wait_for_their_newline(self):
        project = self.tmp / "partial"
        project.mkdir()
        reader = EventReader(project, [])
        (project / "oracle_events.jsonl").write_text('{"event": "packet_read"}\n{"event": "core_verb_', encoding="utf-8")
        self.assertEqual(reader.poll(), ["OTHER HANDS HAVE TAKEN UP THE CARDS."])
        self.assertEqual(reader.poll(), [])
        with open(project / "oracle_events.jsonl", "a", encoding="utf-8") as fh:
            fh.write('playable"}\n')
        self.assertEqual(reader.poll(), ["THE CREATURES HAVE LEARNED HOW TO MOVE."])

    def test_the_game_is_never_launched_without_a_yes(self):
        record, _ = self.build()
        ui = ScriptedConsole()                      # its confirm() always answers no
        self.assertFalse(offer_play(record, ui))
        self.assertTrue(any("The builder says the game starts with" in t for k, t in ui.out if k == "note"))


class CommandLineTests(unittest.TestCase):
    def run_cli(self, *argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = main(list(argv))
        return code, out.getvalue()

    def test_doctor(self):
        code, out = self.run_cli("doctor")
        self.assertEqual(code, 0)
        self.assertIn("Content: valid.", out)
        self.assertIn("offline", out)

    def test_simulate_one_persona(self):
        code, out = self.run_cli("simulate", "--persona", "speedrunner", "--length", "short")
        self.assertEqual(code, 0)
        self.assertIn("== speedrunner", out)
        self.assertIn("dominant:", out)

    def test_list_and_forget(self):
        night = run_persona(load_registry(), "tinkerer", seed=8, save=True)
        session = night["session"]
        session.save()
        self.assertIn(session.id, [s["id"] for s in list_sessions()])
        code, out = self.run_cli("list")
        self.assertIn(session.id, out)
        code, out = self.run_cli("forget", session.id)          # not a terminal: must be confirmed
        self.assertEqual(code, 1)
        self.assertIn(session.id, [s["id"] for s in list_sessions()])
        code, out = self.run_cli("forget", session.id, "--yes")
        self.assertEqual(code, 0)
        self.assertNotIn(session.id, [s["id"] for s in list_sessions()])
        self.assertEqual(forget(session.id), [])

    def test_packet_and_dev_from_a_saved_night(self):
        night = run_persona(load_registry(), "host", seed=9, save=True)
        night["session"].save()
        target = tempfile.mkdtemp(prefix="blank-deck-cli-")
        code, out = self.run_cli("packet", night["session"].id, "--out", target)
        self.assertEqual(code, 0)
        self.assertTrue((Path(target) / "oracle_packet" / "GAME_DESCRIPTION.md").is_file())
        code, out = self.run_cli("dev", night["session"].id, "--out", os.path.join(target, "dev.html"))
        self.assertEqual(code, 0)
        self.assertTrue((Path(target) / "dev.html").is_file())


if __name__ == "__main__":
    unittest.main()
