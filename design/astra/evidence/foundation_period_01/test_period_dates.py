#!/usr/bin/env python3
"""Synthetic period/calendar controls; never modify production sources."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import audit_period_dates as audit

CALENDAR = {"schema_version": 1, "year": 1928, "month": 11, "day": 10,
            "timezone": "America/New_York", "utc_offset_minutes": -300}
CLOCK = "game/scripts/game/campaign_clock.gd"
AUTHORED = ('func calendar_year() -> int:\n'
            '\tvar authored := {"year": 1928}\n'
            '\treturn authored.year\n'
            'func _sample_local_minute_of_day() -> int:\n'
            '\tvar local := Time.get_time_dict_from_system()\n'
            '\treturn local.hour * 60 + local.minute\n')
HOST = ('func _initialize_epoch_from_host() -> void:\n'
        '\tvar host := Time.get_date_dict_from_system()\n'
        '\tvar copied := host.year\n'
        '\t_state.epoch_year = copied\n'
        '\tRealityState.commit()\n')


def write_json(root, path, value):
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(value), encoding="utf-8")


def make_repo(root):
    write_json(root, "game/data/campaign_calendar.json", CALENDAR)
    write_json(root, "game/data/prop_service_wire.json", {"period_cutoff": "1928-12-31"})
    provenance = {
        "field_semantics": {audit.FIXTURE_FIELD: {
            "classification": "generated_flavor", "authored": False,
            "generator": "tools/author_light_provenance.py",
            "canonical_authority": None, "player_surface": "debug_overlay_only",
            "temporal_status": "UNRULED"}},
        "fixture_count": 1,
        "fixtures": {"fixture": {"provenance": "installed 1928"}}}
    for prefix in ("art", "game"):
        write_json(root, prefix + "/data/light_provenance.json", provenance)
    write_json(root, "game/data/library.json", {"books": [{"id": "book", "year": 1927}]})
    for path in audit.EXPECTED_CONSUMERS:
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text('func year_of(record):\n\treturn record.year\n', encoding="utf-8")
    (root / CLOCK).write_text(AUTHORED, encoding="utf-8")
    (root / "game/scripts/phoneos").mkdir(parents=True, exist_ok=True)
    (root / "game/scripts/phoneos/phone_os.gd").write_text(
        'func display_date():\n\tvar clock := CampaignClock.new()\n'
        '\treturn clock.datetime_string()\n', encoding="utf-8")


class PeriodDateTests(unittest.TestCase):
    def test_accepted_calendar_and_each_field_drift(self):
        self.assertEqual(audit.campaign_calendar_failures(CALENDAR), [])
        for field, wrong in {"schema_version": True, "year": 2026, "month": 9,
                             "day": 5, "timezone": "host", "utc_offset_minutes": 0}.items():
            with self.subTest(field=field):
                self.assertTrue(audit.campaign_calendar_failures(dict(CALENDAR, **{field: wrong})))

    def test_authored_year_remains_a_classified_consumer(self):
        with tempfile.TemporaryDirectory(prefix="period_dates_") as tmp:
            root = Path(tmp)
            make_repo(root)
            failures, notes = audit.audit(root)
            self.assertEqual(failures, [])
            self.assertTrue(any("authored_campaign_calendar" in note for note in notes))

    def test_phone_host_date_is_rejected_even_with_fictional_year_prefix(self):
        with tempfile.TemporaryDirectory(prefix="period_dates_") as tmp:
            root = Path(tmp)
            make_repo(root)
            path = root / "game/scripts/phoneos/phone_os.gd"
            path.write_text(path.read_text() +
                            '\nfunc old_date():\n\treturn "1928" + Time.get_datetime_string_from_system().substr(4)\n',
                            encoding="utf-8")
            failures, _ = audit.audit(root)
            self.assertTrue(any("PhoneOS date must" in item for item in failures))

    def test_cli_host_calendar_red_then_authored_green(self):
        with tempfile.TemporaryDirectory(prefix="period_dates_") as tmp:
            root = Path(tmp)
            make_repo(root)
            path = root / CLOCK
            command = [sys.executable, str(TOOLS / "audit_period_dates.py"), str(root)]
            path.write_text(HOST, encoding="utf-8")
            red = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(red.returncode, 1, red.stdout + red.stderr)
            self.assertIn("host calendar/time is not authorized", red.stdout)
            path.write_text(AUTHORED, encoding="utf-8")
            green = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(green.returncode, 0, green.stdout + green.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
