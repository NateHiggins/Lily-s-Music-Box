"""Runtime projections retain source evidence and refuse unsupported semantics."""
import copy
import json
import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import build_historical_radio_notice as notice
import build_v2_street_section as street


class RuntimeSourceProjectionTests(unittest.TestCase):
    def test_street_projection_preserves_only_the_consumed_frame(self):
        source = json.loads(street.REPORT.read_text(encoding="utf-8"))
        original = copy.deepcopy(source)
        projected = street.runtime_frame(source)
        self.assertEqual(set(projected), {"schema", "frame", "source_threshold_z", "arcade_building_line_z"})
        for key in ("source_threshold_z", "arcade_building_line_z"):
            self.assertEqual(projected[key], source[key])
        self.assertEqual(source, original)
        self.assertEqual(street.RUNTIME_FRAME.read_bytes(), (json.dumps(projected, indent=2)+"\n").encode("utf-8"))

    def test_street_projection_rejects_foreign_origin_and_invalid_coordinates(self):
        source = json.loads(street.REPORT.read_text(encoding="utf-8"))
        for field, value in [("schema", "unknown"), ("source_threshold_marker", "another_door"),
                             ("source_threshold_z", True), ("arcade_building_line_z", float("nan"))]:
            with self.subTest(field=field, value=value):
                bad = copy.deepcopy(source)
                bad[field] = value
                with self.assertRaises(ValueError):
                    street.runtime_frame(bad)

    def test_notice_projection_retains_display_facts_without_research_metadata(self):
        source = json.loads(notice.SOURCE.read_text(encoding="utf-8"))
        original = copy.deepcopy(source)
        projected = notice.runtime_notice(source)
        self.assertEqual(set(projected), {"schema_version", "id", "notice_heading", "notice_date_line",
                                         "effective", "assignments", "shared_after"})
        self.assertEqual(set(projected["assignments"][0]), {"station", "before_kc", "after_kc"})
        self.assertEqual(set(projected["shared_after"]), {"stations", "kc"})
        self.assertNotIn("time_standard", projected["effective"])
        self.assertEqual(source, original)
        self.assertEqual(notice.OUTPUT.read_bytes(), notice.encoded_notice(source))
        for old, new in zip(source["assignments"], projected["assignments"]):
            self.assertEqual(new, {key: old[key] for key in ("station", "before_kc", "after_kc")})

    def test_notice_projection_refuses_changed_medium_time_or_citation_claim(self):
        source = json.loads(notice.SOURCE.read_text(encoding="utf-8"))
        variants = []
        for key, value in [("schema_version", True), ("medium", "live_broadcast")]:
            bad = copy.deepcopy(source)
            bad[key] = value
            variants.append(bad)
        for key, value in [("time_standard", "UTC"), ("minute_of_day", 1440)]:
            bad = copy.deepcopy(source)
            bad["effective"][key] = value
            variants.append(bad)
        bad = copy.deepcopy(source)
        bad["shared_after"]["program_hours"] = "all day"
        variants.append(bad)
        bad = copy.deepcopy(source)
        bad["assignments"][0]["before_sources"] = ["not_in_bibliography"]
        variants.append(bad)
        for bad in variants:
            with self.assertRaises(ValueError):
                notice.runtime_notice(bad)


if __name__ == "__main__":
    unittest.main(verbosity=2)
