#!/usr/bin/env python3
"""Exercise the audio audit's real CLI on isolated red/green repositories.

    python tools/tests/test_audio_emitters.py
    python tools/tests/test_audio_emitters.py --evidence path/to/receipt.json

Fixtures never modify the production catalogue, scripts, or audit thresholds.
The optional receipt omits temporary paths and timing so it is reproducible.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


AUDITOR = Path(__file__).resolve().parents[1] / "audit_audio_emitters.py"
VALID_CUE = {
    "stream_key": "fixture_latch",
    "purpose": "interaction",
    "bus": "Interaction",
    "priority": 55,
    "volume_db": -18.0,
    "unit_size": 1.0,
    "max_distance": 6.0,
    "cooldown": 0.05,
    "max_instances": 3,
    "caption": "latch seats",
    "graph_transmitted": False,
}
VALID_SCRIPT = (
    'func play_fixture():\n'
    '\tvar player := AudioStreamPlayer3D.new()\n'
    '\tplayer.bus = "Interaction"\n'
    '\taudio.present_3d(&"interaction.fixture", position)\n'
)
FAILURE_COUNTS = (
    "unclassified_direct_players",
    "unknown_literal_semantic_cues",
    "invalid_catalog_cues",
    "legacy_helper_budget_excess",
)
OBSERVATIONS: list[dict] = []


def catalogue(cue: dict | None = None) -> dict:
    return {"schema_version": 1, "cues": {
        "interaction.fixture": copy.deepcopy(VALID_CUE if cue is None else cue),
    }}


def serialized(value: dict) -> str:
    return json.dumps(value, indent=2, sort_keys=True) + "\n"


class AudioEmitterCliTests(unittest.TestCase):
    def run_cli(self, script: str, catalog: dict) -> dict:
        """Run the actual CLI, retaining report and real process status."""
        with tempfile.TemporaryDirectory(prefix="audio-audit-fixture-") as tmp:
            root = Path(tmp)
            scripts = root / "game" / "scripts"
            data = root / "game" / "data"
            scripts.mkdir(parents=True)
            data.mkdir(parents=True)
            (scripts / "fixture.gd").write_text(script, encoding="utf-8")
            (data / "audio_cues.json").write_text(
                serialized(catalog), encoding="utf-8"
            )
            output = root / "audit.json"
            completed = subprocess.run(
                [sys.executable, str(AUDITOR), "--repo", str(root),
                 "--format", "json", "--output", str(output), "--check"],
                capture_output=True, text=True, encoding="utf-8", timeout=20,
                check=False,
            )
            self.assertTrue(output.is_file(), completed.stderr)
            self.assertEqual(completed.stderr, "")
            return {
                "exit_code": completed.returncode,
                "stdout": completed.stdout.replace("\r\n", "\n"),
                "stderr": completed.stderr,
                "report": json.loads(output.read_text(encoding="utf-8")),
                "inputs": {
                    "game/scripts/fixture.gd": script,
                    "game/data/audio_cues.json": catalog,
                },
            }

    def assert_red_green(
        self, fixture_id: str, red_script: str, red_catalog: dict,
        expected_failure: str, green_script: str = VALID_SCRIPT,
        green_catalog: dict | None = None,
    ) -> tuple[dict, dict]:
        red = self.run_cli(red_script, red_catalog)
        self.assertEqual(red["exit_code"], 1, red["stdout"])
        self.assertTrue(red["stdout"].startswith("AUDIO EMITTER AUDIT: FAIL"))
        self.assertGreater(red["report"]["summary"][expected_failure], 0)
        for key in FAILURE_COUNTS:
            if key != expected_failure:
                self.assertEqual(red["report"]["summary"][key], 0, key)

        green = self.run_cli(
            green_script, catalogue() if green_catalog is None else green_catalog
        )
        self.assertEqual(green["exit_code"], 0, green["stdout"])
        self.assertTrue(green["stdout"].startswith("AUDIO EMITTER AUDIT: PASS"))
        for key in FAILURE_COUNTS:
            self.assertEqual(green["report"]["summary"][key], 0, key)
        OBSERVATIONS.append({
            "fixture_id": fixture_id,
            "expected_failure_category": expected_failure,
            "red": red,
            "corrected": green,
        })
        return red["report"], green["report"]

    def test_unclassified_bus_cannot_borrow_another_players_assignment(self):
        for player_type in ("AudioStreamPlayer", "AudioStreamPlayer2D",
                            "AudioStreamPlayer3D"):
            with self.subTest(player_type=player_type):
                red_script = (
                    'func play_fixture():\n'
                    f'\tvar player := {player_type}.new()\n'
                    '\tother_player.bus = "Interaction"\n'
                    '\taudio.present_3d("interaction.fixture", position)\n'
                )
                corrected = red_script.replace("other_player.bus", "player.bus")
                red, green = self.assert_red_green(
                    f"unclassified_bus_{player_type}", red_script, catalogue(),
                    "unclassified_direct_players", corrected,
                )
                self.assertEqual(red["unclassified_direct_sites"], [{
                    "path": "game/scripts/fixture.gd", "line": 2,
                    "variable": "player",
                }])
                self.assertEqual(green["summary"]["direct_player_constructions"], 1)

    def test_bus_assignment_in_a_later_function_does_not_classify_player(self):
        script = (
            'func first():\n'
            '\tvar player := AudioStreamPlayer3D.new()\n'
            '\tadd_child(player)\n'
            '\n'
            'func second():\n'
            '\tplayer.bus = "Interaction"\n'
        )
        self.assert_red_green(
            "unclassified_bus_wrong_function", script, catalogue(),
            "unclassified_direct_players",
            script.replace('\tadd_child(player)',
                           '\tplayer.bus = "Interaction"\n\tadd_child(player)'),
        )

    def test_unknown_semantic_cue_requires_catalogue_membership(self):
        for method in ("present_3d", "observe_existing_3d"):
            for prefix in ("", "&"):
                with self.subTest(method=method, prefix=prefix):
                    red_script = (
                        'func play_fixture():\n'
                        f'\taudio.{method}({prefix}"interaction.missing", position)\n'
                    )
                    corrected = red_script.replace(
                        "interaction.missing", "interaction.fixture"
                    )
                    red, green = self.assert_red_green(
                        f"unknown_cue_{method}_{'string_name' if prefix else 'string'}",
                        red_script, catalogue(), "unknown_literal_semantic_cues",
                        corrected,
                    )
                    self.assertEqual(red["unknown_literal_semantic_cues"],
                                     ["interaction.missing"])
                    self.assertEqual(green["summary"]["literal_semantic_requests"], 1)

    def test_catalogue_semantic_values_and_ranges_fail_with_diagnostics(self):
        cases = (
            ("purpose_bus_mismatch", {"bus": "Weather"}, "cannot route"),
            ("unknown_purpose", {"purpose": "unruled"}, "cannot route"),
            ("empty_stream", {"stream_key": "  "}, "must be non-empty"),
            ("empty_caption", {"caption": "\t"}, "must be non-empty"),
            ("priority_low", {"priority": -1}, "priority is outside"),
            ("priority_high", {"priority": 101}, "priority is outside"),
            ("zero_unit_size", {"unit_size": 0}, "distance profile"),
            ("negative_max_distance", {"max_distance": -1}, "distance profile"),
            ("negative_cooldown", {"cooldown": -0.1}, "cooldown or concurrency"),
            ("zero_concurrency", {"max_instances": 0}, "cooldown or concurrency"),
            ("excess_concurrency", {"max_instances": 17}, "cooldown or concurrency"),
        )
        for label, changes, diagnostic in cases:
            with self.subTest(label=label):
                bad_cue = dict(VALID_CUE, **changes)
                red, _ = self.assert_red_green(
                    f"catalogue_{label}", VALID_SCRIPT, catalogue(bad_cue),
                    "invalid_catalog_cues",
                )
                self.assertEqual(len(red["catalog_failures"]), 1)
                self.assertIn(diagnostic, red["catalog_failures"][0])

    def test_missing_caption_fails_instead_of_making_silent_catalogue_green(self):
        bad_cue = dict(VALID_CUE)
        del bad_cue["caption"]
        red, _ = self.assert_red_green(
            "catalogue_missing_caption", VALID_SCRIPT, catalogue(bad_cue),
            "invalid_catalog_cues",
        )
        self.assertEqual(red["catalog_failures"],
                         ["interaction.fixture: missing caption"])

    def test_helper_ceiling_allows_boundary_but_rejects_one_more_use(self):
        # These are the published non-regression ceilings, not values read back
        # from the implementation: widening a budget must require review here.
        for key, ceiling in (("tick", 25), ("knock", 14), ("hum_loop", 9),
                             ("pop", 7), ("creak", 5)):
            with self.subTest(key=key):
                call = f'\tAudioUtils.make_emitter("{key}")\n'
                red_script = 'func play_fixture():\n' + call * (ceiling + 1)
                corrected = 'func play_fixture():\n' + call * ceiling
                red, green = self.assert_red_green(
                    f"helper_budget_{key}", red_script, catalogue(),
                    "legacy_helper_budget_excess", corrected,
                )
                self.assertEqual(red["legacy_helper_budget_excess"], {
                    key: {"actual": ceiling + 1, "budget": ceiling},
                })
                self.assertEqual(green["summary"]["make_emitter_calls"], ceiling)


def main() -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--evidence", type=Path)
    args, unittest_args = parser.parse_known_args()
    OBSERVATIONS.clear()
    program = unittest.main(argv=[sys.argv[0], *unittest_args], exit=False)
    passed = program.result.wasSuccessful()
    if args.evidence is not None:
        receipt = {
            "schema_version": 1,
            "scope": "Synthetic static audio audit CLI red/green proof only",
            "source_sha256": {
                "tools/audit_audio_emitters.py": hashlib.sha256(
                    AUDITOR.read_bytes()).hexdigest(),
                "tools/tests/test_audio_emitters.py": hashlib.sha256(
                    Path(__file__).read_bytes()).hexdigest(),
            },
            "command": ["python", "tools/tests/test_audio_emitters.py"],
            "fixture_cli": [
                "python", "tools/audit_audio_emitters.py", "--repo", "<fixture>",
                "--format", "json", "--output", "<fixture>/audit.json", "--check",
            ],
            "tests_run": program.result.testsRun,
            "tests_successful": passed,
            "red_green_pairs": sorted(OBSERVATIONS,
                                      key=lambda row: row["fixture_id"]),
            "limitations": [
                "Static source fixture checks do not establish runtime audibility, "
                "masking, source quality, routing correctness, or player comprehension.",
                "This packet exercises declared semantic constraints with parseable "
                "catalogue values; it does not certify arbitrary JSON/type validation.",
            ],
        }
        args.evidence.parent.mkdir(parents=True, exist_ok=True)
        args.evidence.write_text(serialized(receipt), encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
