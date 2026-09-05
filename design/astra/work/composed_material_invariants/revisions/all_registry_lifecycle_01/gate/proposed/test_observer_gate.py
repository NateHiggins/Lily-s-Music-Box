from pathlib import Path
import copy
import importlib.util
import unittest
from observer_gate import CONTRACT, validate_v2_refresh
from material_gate import classify_materials

PACKAGE = Path(__file__).resolve().parents[4]
spec = importlib.util.spec_from_file_location("old_material_fixture", PACKAGE / "gate_revisions/signed_ids_01/proposed/test_material_gate.py")
old_fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(old_fixture)

FLOOR = {"cal_memory_radio": "F05", "juno_feedback_tetris": "F02", "mae_contradictory_antiques": "F06",
         "mina_caption_crisis": "F02", "omar_unrepairable": "F03", "peter_form_corridor": "F04"}


def fixture():
    probe = old_fixture.fixture()
    for observation in probe["material_observations"]:
        floor_ids = {floor: [] for floor in FLOOR.values()}
        for case, data in observation["cases"].items():
            for kind in ("finishes", "props"):
                for row in data[kind]:
                    row["material_id"] -= 9223370061119417423
                    if kind == "finishes": row["slot"] = 0
                    floor_ids[FLOOR[case]].append(row["material_id"])
        # Include real-contract non-case lifecycle targets to catch incomplete restoration.
        for i, floor in enumerate(sorted(floor_ids)): floor_ids[floor].append(-100 - i)
        observation["registries"] = {floor: {"slots": len(ids), "unique": len(ids), "invalid": 0,
                                            "material_ids": sorted(ids), "installed_ids": sorted(ids)} for floor, ids in floor_ids.items()}
        if not observation["refresh_exercised"]: continue
        refresh = observation["refresh"]
        comparisons, case_lifecycle = [], []
        for case, data in observation["cases"].items():
            for plural, kind in (("finishes", "finish"), ("props", "prop")):
                for row in data[plural]:
                    expected = 0.1 if kind == "finish" else [0.0, 0.035, 0.025, 0.0]
                    comparison = {"case_id": case, "kind": kind, "path": row["path"], "material_id": row["material_id"],
                                  "evaluated": True, "passed": True, "identity_matches": True, "state_matches": True,
                                  "actual_state": expected, "expected_state": expected}
                    if kind == "finish": comparison["slot"] = row["slot"]
                    comparisons.append(comparison)
                    case_lifecycle.append({"material_id": row["material_id"], "floor": FLOOR[case], "evaluated": True,
                                           "passed": True, "actual": 1.0, "expected": 1.0})
        snapshots, registry_comparisons = {}, []
        for floor, ids in floor_ids.items():
            for mid in ids:
                snapshots[str(mid)] = {"material_id": mid, "write_floors": [floor], "value": 0.0}
                registry_comparisons.append({"material_id": mid, "write_floors": [floor], "evaluated": True,
                                             "passed": True, "actual": 1.0, "expected": 1.0})
        refresh.update(comparison_contract=CONTRACT, case_comparisons=comparisons, case_rows_planned=12, case_rows_evaluated=12,
                       case_comparisons_evaluated=24, case_materials_touched=12, case_lifecycle_comparisons=case_lifecycle,
                       case_lifecycle_materials_evaluated=12, registry_live_slots=17, registry_unique_materials=17,
                       registry_types_valid=True, registry_lifecycle_comparisons=registry_comparisons,
                       registry_lifecycle_materials_evaluated=17, registry_lifecycle_before=copy.deepcopy(snapshots),
                       registry_lifecycle_after=copy.deepcopy(snapshots), registry_lifecycle_restored=True,
                       registry_restore_failures=[], lifecycle_restore_union_size=17)
    return probe


class ObserverGateControls(unittest.TestCase):
    def assert_rejected(self, mutate):
        probe = fixture()
        mutate(probe["material_observations"][0]["refresh"])
        self.assertEqual(classify_materials(probe, "expected")["material_gate_exit"], 1)

    def test_complete_signed_id_payload_including_noncase_registry_targets(self):
        self.assertEqual(classify_materials(fixture(), "expected")["material_gate_exit"], 0)

    def test_missing_contract_or_arrays_rejected(self):
        for key in ("comparison_contract", "case_comparisons", "case_lifecycle_comparisons", "registry_lifecycle_comparisons",
                    "registry_lifecycle_before", "registry_lifecycle_after"):
            with self.subTest(key=key): self.assert_rejected(lambda r: r.pop(key))

    def test_plausible_truncation_does_not_reduce_expected_case_population(self):
        def mutate(r):
            r["case_comparisons"].pop()
            r["case_rows_planned"] = r["case_rows_evaluated"] = 11
            r["case_comparisons_evaluated"] = 22
        self.assert_rejected(mutate)

    def test_unexecuted_or_failed_row_cannot_hide_under_passed_aggregate(self):
        for key in ("evaluated", "passed", "identity_matches", "state_matches"):
            with self.subTest(key=key): self.assert_rejected(lambda r: r["case_comparisons"][0].__setitem__(key, False))

    def test_actual_state_mismatch_or_wrong_census_path_rejected(self):
        self.assert_rejected(lambda r: r["case_comparisons"][0].__setitem__("actual_state", 0.8))
        self.assert_rejected(lambda r: r["case_comparisons"][0].__setitem__("path", "missing/other"))

    def test_touched_and_evaluated_count_mismatches_rejected(self):
        for key in ("case_rows_planned", "case_rows_evaluated", "case_comparisons_evaluated", "case_materials_touched",
                    "case_lifecycle_materials_evaluated", "registry_live_slots", "registry_unique_materials",
                    "registry_lifecycle_materials_evaluated", "lifecycle_restore_union_size"):
            with self.subTest(key=key): self.assert_rejected(lambda r: r.__setitem__(key, r[key] - 1))

    def test_duplicate_or_unexecuted_lifecycle_comparison_rejected(self):
        for key in ("case_lifecycle_comparisons", "registry_lifecycle_comparisons"):
            self.assert_rejected(lambda r: r[key].__setitem__(0, copy.deepcopy(r[key][1])))
            self.assert_rejected(lambda r: r[key][0].__setitem__("evaluated", False))

    def test_noncase_restoration_failure_cannot_hide_behind_case_snapshots(self):
        self.assert_rejected(lambda r: r["registry_lifecycle_after"]["-100"].__setitem__("value", 42.0))

    def test_missing_noncase_target_rejected_even_with_plausible_reduced_counts(self):
        def mutate(r):
            for key in ("registry_lifecycle_before", "registry_lifecycle_after"): r[key].pop("-100")
            r["registry_lifecycle_comparisons"] = [x for x in r["registry_lifecycle_comparisons"] if x["material_id"] != -100]
            r["registry_unique_materials"] = r["registry_lifecycle_materials_evaluated"] = 16
            r["lifecycle_restore_union_size"] = 16
        self.assert_rejected(mutate)

    def test_missing_value_or_wrong_floor_membership_rejected(self):
        def missing_value(r):
            for key in ("registry_lifecycle_before", "registry_lifecycle_after"): r[key]["-100"].pop("value")
        self.assert_rejected(missing_value)
        self.assert_rejected(lambda r: r["registry_lifecycle_comparisons"][0].__setitem__("write_floors", ["F00"]))

    def test_bool_zero_or_out_of_range_comparison_ids_rejected(self):
        for value in (True, False, 0, -(1 << 63) - 1, 1 << 63):
            self.assert_rejected(lambda r: r["case_comparisons"][0].__setitem__("material_id", value))

    def test_missing_evaluation_reasons_are_separate(self):
        observation = fixture()["material_observations"][0]
        refresh = observation["refresh"]
        refresh["case_comparisons"] = []
        refresh["case_lifecycle_comparisons"] = []
        refresh["registry_lifecycle_comparisons"] = []
        reasons = validate_v2_refresh(refresh, observation["cases"], observation["registries"])
        self.assertEqual(len(reasons), 3)
        self.assertIn("independent case comparison", reasons[0])
        self.assertIn("case lifecycle comparison", reasons[1])
        self.assertIn("registry lifecycle", reasons[2])


if __name__ == "__main__":
    unittest.main()
