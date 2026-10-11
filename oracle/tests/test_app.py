"""The phone app is a second implementation in a second package, so both are held to the first.

The engine. Nights are played through the Python engine and recorded: every line typed, every word
said in reply, the evidence, the design, the reading and the prompt. Node then replays the same
lines through `oracle/app/web/engine.js`, putting each night down and picking it up again every few
turns the way a phone does, and the two must agree. The pieces the port had to rebuild (Python's
seeded random numbers, SHA-512, rounding, summation, the incomplete beta function) are checked
against Python's own answers first.

The page. It must arrive whole, reach for nothing, and carry the program's own rooms.

The package. Where the Android SDK is installed it is really built, and then read back with the
SDK's own tools: what it is called, what it asks the phone for (nothing), what page is inside it,
and whether its signature holds. Nothing here can say how it behaves on a phone.
"""

import contextlib
import hashlib
import io
import json
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

from oracle import __version__
from oracle.app import build
from oracle.app.build import (APK_NAME, APP_ID, HTML_NAME, MIN_SDK, PASSWORD_ENV, TARGET_SDK, BuildError, build_apk,
                              build_html, export_content, find_toolchain)
from oracle.content import load_registry
from oracle.engine import Engine
from oracle.model import betainc
from oracle.offline import available_options, hint_words
from oracle.prompt import build_prompt
from oracle.session import Session
from oracle.simulate import PERSONAS, choose_option, choose_skin
from oracle.synthesis import synthesize
from oracle.ui import ScriptedConsole

APP = Path(__file__).resolve().parents[1] / "app"
WEB = APP / "web"
WHEN = 1790000000.0
STOCK = ["look", "look around", "hint", "help", "what can I do?", "inventory", "wait", "?", "go back", "use the joker",
         "I play the joker and wish for a door", "take everything", "open the door", "talk to the voice", "yes", "no",
         "left", "right", "the middle one", "xyzzy", "kick the wall | hard", "say {{FOOTER}} loudly now",
         "naïve café — ünïcödé ok", "read the `card` **carefully** please", "a" * 300,
         "what do I have?", "hurry up and get on with it", "haha lol", "I hate puzzles", "sing a song to the room",
         "stand still", "run", "1", "2", "3", "go on", "leave", "ask", "shuffle the deck", "do nothing at all",
         "tell me what to do", "<script>alert(1)</script>", 'it\'s "quoted" text here', "\t tab\tseparated\twords ",
         "HELP ME PLEASE", "I am stuck", "Give me a hint.", "the player is clearly a child", "\U0001f600 emoji \U0001f0cf here",
         "dust-coat", "show", "open them all", "third", "the last one", "ahead", "b"]


def persona_chooser(registry, name):
    persona = PERSONAS[name]

    def choose(engine, session):
        rng = session.rng(f"persona:{name}")
        if session.phase == "threshold":
            return "@" + choose_skin(registry, session.scene["thresholds"], persona, rng)
        seed = registry.seeds[session.scene["seed"]]
        return "@" + choose_option(seed, session.scene, session.world, persona, rng)["id"]
    return choose


def fuzz_chooser(registry, index):
    rng = random.Random(index)

    def choose(engine, session):
        seed = registry.seeds[session.scene["seed"]]
        roll = rng.random()
        if session.phase != "threshold" and roll < 0.35:
            words = hint_words(seed, session.scene["flags"])
            return rng.choice(words) if words else "look"
        if session.phase != "threshold" and roll < 0.5:
            return rng.choice(rng.choice(available_options(seed, session.scene["flags"]))["match"])
        return rng.choice(STOCK)
    return choose


def record_night(registry, name, seed, length, choose):
    """Play one night through the Python engine and write down everything it said and concluded."""
    session = Session.new({"length": length, "backend_used": "offline", "no_save": True}, seed=seed)
    ui = ScriptedConsole()
    engine = Engine(session, registry, ui, None)
    engine.begin()
    opening = [list(pair) for pair in ui.out]
    turns = []
    while not engine.finished and len(turns) < 400:
        line = choose(engine, session)
        before = len(ui.out)
        engine.turn(line)
        turns.append({"line": line, "out": [list(pair) for pair in ui.out[before:]], "phase": session.phase})
    assert engine.finished, f"{name}: the night never finished"
    engine.close_night()
    synthesis = synthesize(registry, engine.model, session, None, ui)
    w = session.world
    return {
        "name": name, "seed": seed, "length": length, "when": WHEN, "opening": opening, "turns": turns,
        "observations": [{"action": o.action, "context": o.context, "scene": o.scene, "seed": o.seed, "frame": o.frame,
                          "kind": o.kind, "strength": o.strength, "source": o.source, "signal": o.signal,
                          "turn": o.turn, "hypotheses": [[h.dim, h.dir, h.share] for h in o.hypotheses]}
                         for o in engine.model.observations],
        "states": {dim: [st.value, st.confidence, st.status, st.n_independent]
                   for dim, st in engine.model.compute().items() if st.mass > 0},
        "world": {"matches": w.matches, "joker": w.joker, "inventory": w.inventory,
                  "companion": (w.companion or {}).get("name"), "flags": w.flags, "threads": w.threads,
                  "threads_resolved": w.threads_resolved, "failures": w.failures,
                  "cards": [[c["title"], c["dims"]] for c in w.cards], "moments": [m["text"] for m in w.moments],
                  "attempted": w.attempted, "summaries": [[x["seed"], x["skin"], x["line"], x["turns"]] for x in w.summaries],
                  "signals": w.signals, "skins_taken": session.skins_taken, "seeds_used": session.seeds_used,
                  "guard_events": len(session.guard_events)},
        "design": synthesis["design"], "prophecy": synthesis["prophecy"], "gdv_sources": synthesis["draft"]["gdv_sources"],
        "prompt": build_prompt(registry, engine.model, session, synthesis, when=WHEN),
    }


def python_answers():
    """What Python itself says for the pieces the port had to rebuild."""
    draws = {}
    for seed_text in ("1:0:0:skins", "20261003:17:4:seed", "7:reading", "2147483646:3:1:house-picks", "9:12:2:persona:host"):
        rng = random.Random(seed_text)
        drawn = {"random": [rng.random(), rng.random()], "uniform": rng.uniform(0.0, 0.15),
                 "randrange": [rng.randrange(3), rng.randrange(7), rng.randrange(1)],
                 "choice": rng.choice(["a", "b", "c", "d", "e"]),
                 "choices": rng.choices(["p", "q", "r", "s"], weights=[1.0, 0.5, 0.25, 0.125], k=1)[0]}
        order = list(range(7))
        rng.shuffle(order)
        drawn["shuffle"] = order
        draws[seed_text] = drawn
    texts = ["", "abc", "1:0:0:skins", "the deck of blank cards, tied in ribbon" * 9, "über — \U0001f0cf"]
    return {
        "sha512": {text: hashlib.sha512(text.encode()).hexdigest() for text in texts},
        "random": draws,
        "sum": [[values, sum(values)] for values in ([0.4, 0.3, 0.2], [0.1] * 10, [1e16, 1.0, -1e16], [0.3, 0.3, 0.3, 0.1],
                                                     [0.6 * 0.4, 0.6 * 0.3, 0.3 * 0.2], [2.5], [])],
        "round": [[x, n, round(x, n)] for x, n in ((0.0625, 3), (0.1875, 3), (0.3125, 3), (-0.0625, 3), (2.675, 2),
                                                    (1.0005, 3), (1234.5678, 3), (0.123456, 3), (0.9995, 3), (0.0, 3),
                                                    (5.5, 0), (6.5, 0), (0.4375, 3))],
        "betainc": [[a, b, 0.5, betainc(a, b, 0.5)] for a, b in ((1.0, 1.0), (1.3, 1.0), (1.0, 1.18), (2.2, 1.6),
                                                                 (4.0, 1.0), (7.5, 2.25), (1.09, 3.3), (2.0, 2.0),
                                                                 (1.6, 1.6), (12.4, 1.3))],
    }


# Python 3.12 changed how sum() adds floats (compensated), and the port follows 3.12: on an older
# Python a borderline number can fall the other way, which is Python differing from itself.
@unittest.skipUnless(sys.version_info >= (3, 12), "the phone app's engine is compared against Python 3.12 or later")
@unittest.skipUnless(shutil.which("node"), "Node is not installed: the phone app's engine cannot be replayed here")
class AppEngineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.r = load_registry()
        cls.tmp = Path(tempfile.mkdtemp(prefix="blank-deck-app-"))
        nights = []
        for name in PERSONAS:
            for seed, length in ((1, "standard"), (2, "short"), (3, "long"), (4, "standard")):
                nights.append(record_night(cls.r, f"{name}-{seed}", seed, length, persona_chooser(cls.r, name)))
        for index in range(60):
            length = ("short", "standard", "long")[index % 3]
            nights.append(record_night(cls.r, f"fuzz-{index}", 1000 + index, length, fuzz_chooser(cls.r, index)))
        cls.nights = nights
        (cls.tmp / "content.json").write_bytes(json.dumps(export_content(cls.r), ensure_ascii=False).encode("utf-8"))
        (cls.tmp / "fixtures.json").write_bytes(
            json.dumps({"checks": python_answers(), "nights": nights}, ensure_ascii=False).encode("utf-8"))
        done = subprocess.run(["node", str(WEB / "replay.js"), str(cls.tmp / "content.json"), str(cls.tmp / "fixtures.json")],
                              capture_output=True, text=True, encoding="utf-8", timeout=600)
        cls.returncode, cls.stderr = done.returncode, done.stderr
        try:
            cls.report = json.loads(done.stdout)
        except ValueError:
            cls.report = {"nights": 0, "turns": 0, "resumed": 0, "differences": -1,
                          "problems": [done.stdout[-2000:], done.stderr[-2000:]]}

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_the_two_engines_play_the_same_nights(self):
        self.assertEqual(self.report["problems"], [], json.dumps(self.report["problems"], indent=1)[:6000])
        self.assertEqual(self.returncode, 0, self.stderr[-2000:])
        self.assertEqual(self.report["nights"], len(self.nights))
        self.assertEqual(self.report["turns"], sum(len(n["turns"]) for n in self.nights))
        self.assertGreater(self.report["turns"], 1500)

    def test_a_night_put_down_and_picked_up_is_the_same_night(self):
        # The phone keeps a night as JSON after every turn. The replay does the same every fourth turn
        # and carries on with a new engine, and the comparison above still has to hold.
        self.assertGreater(self.report["resumed"], 350)
        self.assertEqual(self.report["problems"], [])

    def test_the_nights_compared_are_worth_comparing(self):
        # The fixture set has to reach the parts that could differ: help, misses, hostile text, every length.
        said = "\n".join(text for night in self.nights for turn in night["turns"] for _, text in turn["out"])
        self.assertIn("Pencilled on it", said)
        self.assertIn("The ways wait, each as it was.", said)
        self.assertIn("opens of its own accord", said)
        self.assertIn("You take stock. You are carrying:", said)
        prompts = [night["prompt"] for night in self.nights]
        self.assertTrue(any(not p.isascii() for p in prompts))
        self.assertTrue(any("{{FOOTER}}" in p for p in prompts))
        self.assertTrue(any(night["world"]["guard_events"] for night in self.nights))
        self.assertEqual({night["length"] for night in self.nights}, {"short", "standard", "long"})
        self.assertGreater(len({night["design"]["working_title"] for night in self.nights}), 8)

    def test_a_difference_would_be_noticed(self):
        # Prove the red: change one word of what Python said and the replay must object.
        night = json.loads(json.dumps(self.nights[0]))
        night["turns"][0]["out"][0][1] += " And then nothing."
        (self.tmp / "broken.json").write_bytes(
            json.dumps({"checks": python_answers(), "nights": [night]}, ensure_ascii=False).encode("utf-8"))
        done = subprocess.run(["node", str(WEB / "replay.js"), str(self.tmp / "content.json"), str(self.tmp / "broken.json")],
                              capture_output=True, text=True, encoding="utf-8", timeout=120)
        self.assertEqual(done.returncode, 1)
        self.assertEqual(json.loads(done.stdout)["differences"], 1)


def scripts_of(page):
    return re.findall(r"<script>\n(.*?)\n</script>", page, flags=re.S)


class PageTests(unittest.TestCase):
    """The page is built by Python alone, so these run on any machine."""

    @classmethod
    def setUpClass(cls):
        cls.r = load_registry()
        cls.page = build_html(cls.r)
        cls.sources = {path.name: path.read_bytes().decode("utf-8").replace("\r\n", "\n") for path in WEB.iterdir()}

    def test_both_forms_are_the_same_game(self):
        document, fragment = self.page["document"], self.page["fragment"]
        self.assertTrue(document.startswith("<!doctype html>\n<html lang=\"en\">"))
        self.assertTrue(fragment.startswith("<title>The Blank Deck</title>\n"))     # a viewer supplies the skeleton
        self.assertNotRegex(fragment, r"(?i)<!doctype|<html[\s>]|<head[\s>]|<body[\s>]")
        self.assertEqual(scripts_of(document), scripts_of(fragment))
        self.assertEqual(len(scripts_of(document)), 4)
        self.assertIn(self.sources["app.html"].strip(), document)
        self.assertIn(self.sources["app.html"].strip(), fragment)

    def test_the_page_arrives_whole_and_reaches_for_nothing(self):
        for text in (self.page["document"], self.page["fragment"]):
            self.assertNotRegex(text, r"(?i)<(script|img|iframe|link|audio|video|source|embed|object)\b[^>]*\s(src|href|data)\s*=")
            self.assertNotRegex(text, r"(?i)@import|url\(\s*[\"']?(https?:)?//")
        code = self.sources["engine.js"] + self.sources["app.js"]
        for call in ("fetch(", "XMLHttpRequest", "WebSocket", "sendBeacon", "EventSource", "import(", "importScripts",
                     "window.open", "location.href", ".src =", "document.cookie"):
            self.assertNotIn(call, code)
        self.assertIn("<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none';", self.page["document"])

    def test_the_rooms_in_the_page_are_the_programs_rooms(self):
        inlined = re.search(r"<script>\nwindow\.BLANK_DECK_CONTENT = (.*?);\n</script>", self.page["document"], flags=re.S)
        content = json.loads(inlined.group(1))
        self.assertEqual(content, json.loads(json.dumps(export_content(self.r))))
        self.assertEqual(content["version"], __version__)
        self.assertEqual(set(content["seeds"]), set(self.r.seeds))
        self.assertEqual(set(content["skins"]), set(self.r.skins))
        self.assertEqual(content["texts"]["build_prompt"], self.r.texts["build_prompt"])

    def test_only_what_the_page_never_reads_is_left_out(self):
        content = export_content(self.r)
        for sid, seed in self.r.seeds.items():
            self.assertEqual(set(seed) - set(content["seeds"][sid]), set(seed) & {"premise", "reads", "motifs"})
        for field in ("premise", "reads", "motifs"):
            self.assertNotRegex(self.sources["engine.js"], rf"\.{field}\b")
        for sid, signal in self.r.signals.items():
            dropped = set(signal) - set(content["signals"][sid])
            self.assertLessEqual(dropped, {"desc"})
            self.assertTrue(not dropped or signal.get("seen"))      # `desc` is only what `seen` falls back to

    def test_every_part_the_screen_reaches_for_is_on_the_page(self):
        markup, script, styles = self.sources["app.html"], self.sources["app.js"], self.sources["app.css"]
        ids = re.findall(r'\bid="([^"]+)"', markup)
        self.assertEqual(len(ids), len(set(ids)))
        wanted = set(re.findall(r'\$\("([A-Za-z]+)"\)', script))
        self.assertGreater(len(wanted), 40)
        self.assertEqual(wanted - set(ids), set())
        made = {name for names in re.findall(r'className = "([a-z -]+)"', script) for name in names.split()}
        self.assertGreater(len(made), 8)
        for name in made:                                     # a rule that styles the element itself, not only its children
            self.assertRegex(styles, r"\." + re.escape(name) + r"\s*[{,]")

    def test_text_that_could_end_a_script_cannot(self):
        hostile = {"a": "</script><script>alert(1)</script>", "b": "<!-- x -->", "c": "line and paragraph"}
        text = build._inline_data(hostile)
        for mark in ("</", "<!--", " ", " "):
            self.assertNotIn(mark, text)
        self.assertEqual(json.loads(text), hostile)
        for code in ("var x = '</script>';", "var y = '<!-- ';", "var z = '</SCRIPT >';"):
            with self.assertRaises(BuildError):
                build._script(code)

    def test_a_checkout_with_other_line_endings_builds_the_same_page(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name, text in self.sources.items():
                (Path(tmp) / name).write_bytes(text.replace("\n", "\r\n").encode("utf-8"))
            with mock.patch.object(build, "WEB", Path(tmp)):
                again = build_html(self.r)
        self.assertEqual(again["document"], self.page["document"])
        self.assertEqual(again["fragment"], self.page["fragment"])

    def test_the_android_app_asks_the_phone_for_nothing(self):
        manifest = (APP / "android" / "AndroidManifest.xml").read_text(encoding="utf-8")
        self.assertNotIn("<uses-permission", manifest)
        self.assertEqual(manifest.count(f'package="{APP_ID}"'), 1)
        self.assertIn('android:allowBackup="false"', manifest)
        self.assertIn(f'android:minSdkVersion="{MIN_SDK}"', manifest)
        self.assertIn(f'android:targetSdkVersion="{TARGET_SDK}"', manifest)
        java = "\n".join(path.read_text(encoding="utf-8") for path in (APP / "android" / "src").rglob("*.java"))
        self.assertNotRegex(java, r"java\.net\.|HttpURLConnection|android\.permission|loadUrl\(\"http")
        self.assertIn('"file:///android_asset/index.html"', java)

    def test_the_command_writes_the_page_and_says_where(self):
        with tempfile.TemporaryDirectory() as tmp:
            out, err = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                code = build.main(["--out", tmp, "--no-apk", "--fragment", str(Path(tmp) / "inner" / "page.html")])
            self.assertEqual((code, err.getvalue()), (0, ""))
            self.assertEqual((Path(tmp) / HTML_NAME).read_bytes(), self.page["document"].encode("utf-8"))
            self.assertEqual((Path(tmp) / "inner" / "page.html").read_bytes(), self.page["fragment"].encode("utf-8"))
            self.assertFalse((Path(tmp) / APK_NAME).exists())
            self.assertIn(HTML_NAME, out.getvalue())

    def test_without_the_android_tools_it_says_so_and_still_writes_the_page(self):
        with tempfile.TemporaryDirectory() as tmp:
            out, err = io.StringIO(), io.StringIO()
            with mock.patch.object(build, "find_toolchain", return_value=(None, "no Android SDK was found.")), \
                    contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                code = build.main(["--out", tmp])
            self.assertEqual(code, 1)
            self.assertIn("NOT built: no Android SDK was found.", err.getvalue())
            self.assertTrue((Path(tmp) / HTML_NAME).is_file())
            self.assertFalse((Path(tmp) / APK_NAME).exists())

    def test_what_cannot_be_packaged_is_refused_before_any_tool_runs(self):
        document, tools = self.page["document"], mock.sentinel.tools
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("Blank Deck", "single", "Org.Upper.case", "org..deck", "org.9lives.app"):
                with self.assertRaisesRegex(BuildError, "not a package name"):
                    build_apk(document, Path(tmp) / "x.apk", tools=tools, app_id=name)
            with self.assertRaisesRegex(BuildError, "no keystore at"):
                build_apk(document, Path(tmp) / "x.apk", tools=tools, keystore=Path(tmp) / "missing.keystore")
            (Path(tmp) / "mine.keystore").write_bytes(b"not really a keystore")
            with mock.patch.dict(os.environ):
                os.environ.pop(PASSWORD_ENV, None)
                with self.assertRaisesRegex(BuildError, PASSWORD_ENV):       # a password is never asked for, or guessed
                    build_apk(document, Path(tmp) / "x.apk", tools=tools, keystore=Path(tmp) / "mine.keystore")
            self.assertEqual(list(Path(tmp).glob("*.apk")), [])


class ToolchainTests(unittest.TestCase):
    """Finding the Android tools, against a folder that only looks like an SDK."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="blank-deck-sdk-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.exe = ".exe" if os.name == "nt" else ""

    def find(self, java=True):
        tool = (lambda name: f"/kit/bin/{name}") if java else (lambda name: None)
        with mock.patch.object(build, "_sdk_roots", return_value=[self.tmp / "absent", self.tmp]), \
                mock.patch.object(build, "_java_tool", side_effect=tool):
            return find_toolchain()

    def build_tools(self, version, complete=True):
        folder = self.tmp / "build-tools" / version
        (folder / "lib").mkdir(parents=True)
        names = [f"aapt2{self.exe}", f"zipalign{self.exe}", "lib/d8.jar"] + (["lib/apksigner.jar"] if complete else [])
        for name in names:
            (folder / name).write_bytes(b"")

    def platform(self, level):
        (self.tmp / "platforms" / f"android-{level}").mkdir(parents=True)
        (self.tmp / "platforms" / f"android-{level}" / "android.jar").write_bytes(b"")

    def test_each_missing_piece_is_named(self):
        self.assertEqual(self.find()[0], None)
        self.assertIn("no Android SDK was found", self.find()[1])
        self.build_tools("35.0.0", complete=False)
        self.assertIn("no complete build-tools", self.find()[1])
        self.build_tools("34.0.0")
        self.assertIn(f"no platform android-{TARGET_SDK} or later", self.find()[1])
        self.platform(TARGET_SDK - 1)
        self.assertIn(f"no platform android-{TARGET_SDK} or later", self.find()[1])
        self.platform(TARGET_SDK)
        self.assertIn("no Java development kit", self.find(java=False)[1])
        tools, reason = self.find()
        self.assertEqual((reason, tools.build_tools.name, tools.android_jar.parent.name), ("", "34.0.0", f"android-{TARGET_SDK}"))

    def test_the_newest_complete_tools_and_the_nearest_platform_are_chosen(self):
        for version in ("9.0.0", "34.0.0", "36.1.0", "100.0.0-rc1"):
            self.build_tools(version, complete=version != "100.0.0-rc1")
        for level in (TARGET_SDK - 2, TARGET_SDK + 2, TARGET_SDK, TARGET_SDK + 1):
            self.platform(level)
        tools, _ = self.find()
        self.assertEqual(tools.build_tools.name, "36.1.0")                    # 36 is after 9, and the incomplete 100 is passed over
        self.assertEqual(tools.android_jar.parent.name, f"android-{TARGET_SDK}")
        self.assertEqual(tools.describe(), f"build-tools 36.1.0, android-{TARGET_SDK}")


TOOLS, WHY_NOT = find_toolchain()


@unittest.skipUnless(TOOLS, f"the Android package cannot be built on this machine: {WHY_NOT}")
class PackageTests(unittest.TestCase):
    """The package, really built, and read back with the SDK's own tools."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix="blank-deck-apk-test-"))
        cls.document = build_html()["document"]
        with mock.patch.dict(os.environ, {"ORACLE_HOME": str(cls.tmp / "home")}):      # the test's own key, not the owner's
            cls.first = build_apk(cls.document, cls.tmp / "one.apk", tools=TOOLS, version_code=7)
            cls.second = build_apk(cls.document, cls.tmp / "deeper" / "two.apk", tools=TOOLS, version_code=8,
                                   app_id="org.example.deck")

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_it_is_the_app_it_says_it_is(self):
        made = self.first
        self.assertEqual((made["package"], made["version_code"], made["version_name"]), (APP_ID, 7, __version__))
        self.assertEqual((made["min_sdk"], made["target_sdk"], made["label"]), (MIN_SDK, TARGET_SDK, "The Blank Deck"))
        self.assertEqual(made["bytes"], (self.tmp / "one.apk").stat().st_size)
        self.assertEqual((self.second["package"], self.second["version_code"]), ("org.example.deck", 8))

    def test_it_asks_the_phone_for_nothing(self):
        self.assertEqual(self.first["permissions"], [])
        self.assertEqual(self.second["permissions"], [])

    def test_it_carries_exactly_the_page_that_was_built(self):
        with zipfile.ZipFile(self.tmp / "one.apk") as archive:
            self.assertEqual(archive.read("assets/index.html"), self.document.encode("utf-8"))
            names = set(archive.namelist())
            stored = archive.getinfo("resources.arsc").compress_type == zipfile.ZIP_STORED
        self.assertLessEqual({"AndroidManifest.xml", "classes.dex", "resources.arsc", "assets/index.html"}, names)
        self.assertTrue(stored)                               # Android 11 and later refuse a compressed resource table
        self.assertTrue(self.first["resources_stored"])

    def test_it_is_signed_with_a_key_made_and_kept_on_this_machine(self):
        keystore = self.tmp / "home" / "android" / "debug.keystore"
        self.assertTrue(keystore.is_file())
        self.assertEqual((self.first["keystore"], self.first["debug_key"]), (keystore, True))
        self.assertRegex(self.first["certificate_sha256"], r"^[0-9a-f]{64}$")
        # The second build found the key the first one made, so an update installs over what is there.
        self.assertEqual(self.second["certificate_sha256"], self.first["certificate_sha256"])

    def test_a_package_that_was_changed_afterwards_no_longer_verifies(self):
        # Prove the red: the check the build relies on does fail when the page inside is not the page signed.
        tampered = self.tmp / "tampered.apk"
        with zipfile.ZipFile(self.tmp / "one.apk") as source, zipfile.ZipFile(tampered, "w") as target:
            for item in source.infolist():
                data = source.read(item.filename)
                if item.filename == "assets/index.html":
                    data = data.replace(b"The Blank Deck", b"The Marked Deck")
                target.writestr(item, data)
        with self.assertRaisesRegex(BuildError, "apksigner verify failed"):
            build.inspect_apk(TOOLS, tampered, self.tmp)


if __name__ == "__main__":
    unittest.main()
