import copy
import unittest
from material_gate import classify_materials, CASES, STAGES, FLOORS


def fixture():
    observations = []
    for stage in STAGES:
        cases = {}
        for i, case in enumerate(sorted(CASES)):
            cases[case] = {"finishes": [{"path": case + "/Finish", "material_id": i + 1, "live": True, "marker_ok": True, "guard_ok": True}],
                           "props": [{"path": case + "/Prop", "material_id": i + 7, "live": True, "marker_ok": True, "source_linked": True}]}
        row = {"stage": stage, "owner_source_sha256": "expected", "outside_measured_intervals": True, "issues": [],
               "surface_governor": {"props_tier_on": True, "queued_material_changes": 0}, "cases": cases,
               "registries": {floor: {"slots": 1, "unique": 1, "invalid": 0, "material_ids": [1], "installed_ids": [1]} for floor in FLOORS},
               "private_geometry": 1, "actor_geometry": 1,
               "excluded_draws": [{"boundary": "private", "contaminated": False}, {"boundary": "actor", "contaminated": False}],
               "cache_consumers": [{"live": True, "budget_matches": True}],
               "refresh_exercised": stage in {"before_measured", "before_retirement"}}
        if row["refresh_exercised"]:
            beachheads = {case: {"present": False} for case in CASES}
            beachheads["mina_caption_crisis"] = {"present": True, "live": True, "original_count": 0,
                                                  "node_id": 100, "draws": {"body": {"draw_id": 101, "mesh_id": 102,
                                                                                     "override_id": 103, "active_material_ids": [103]}}}
            row["refresh"] = {"passed": True, "facts_unchanged": True, "same_frame_restored": True,
                              "before_state": {"draw": 1}, "after_state": {"draw": 1}, "tested_current_materials": 12,
                              "mutated": True, "force_restored": True, "intensities_restored": True,
                              "precondition": {"passed": True, "issues": [], "threshold": 0.3,
                                               "effective_intensities": {case: 0.0 for case in CASES},
                                               "probe_intensities": [0.10, 0.12, 0.14, 0.16, 0.18, 0.20],
                                               "environment": {"ENCROACH": "", "ENCROACH_FORCE": ""}},
                              "before_forced": {}, "after_forced": {},
                              "before_intensities": {case: 0.0 for case in CASES}, "after_intensities": {case: 0.0 for case in CASES},
                              "before_beachheads": copy.deepcopy(beachheads), "during_beachheads": copy.deepcopy(beachheads),
                              "after_beachheads": copy.deepcopy(beachheads)}
        observations.append(row)
    return {"root": "v1", "material_contract": "actual_build_ownership_v1", "material_observations": observations,
            "material_retirement": {"applicable": True, "released": True, "owned_case_materials_observed": 12, "retained_material_ids": []}}


class MaterialGateControls(unittest.TestCase):
    def test_synthetic_complete_contract(self):
        self.assertEqual(classify_materials(fixture(), "expected")["material_gate_exit"], 0)

    def test_missing_stage_case_or_population(self):
        for operation in ("stage", "case", "props", "registry"):
            probe = fixture()
            row = probe["material_observations"][0]
            if operation == "stage": probe["material_observations"].pop()
            elif operation == "case": row["cases"].pop(next(iter(CASES)))
            elif operation == "props": row["cases"][next(iter(CASES))]["props"].clear()
            else: row["registries"].pop("F02")
            self.assertEqual(classify_materials(probe, "expected")["material_gate_exit"], 1)

    def test_stale_finish_or_prop(self):
        for kind in ("finishes", "props"):
            probe = fixture()
            probe["material_observations"][0]["cases"][next(iter(CASES))][kind][0]["live"] = False
            self.assertEqual(classify_materials(probe, "expected")["material_gate_exit"], 1)

    def test_duplicate_or_detached_registry(self):
        for key, value in (("slots", 2), ("installed_ids", [2]), ("invalid", 1)):
            probe = fixture()
            probe["material_observations"][0]["registries"]["F02"][key] = value
            self.assertEqual(classify_materials(probe, "expected")["material_gate_exit"], 1)

    def test_private_cache_and_governor_rejections(self):
        for operation in ("private", "cache", "queue", "budget"):
            probe = fixture()
            row = probe["material_observations"][0]
            if operation == "private": row["excluded_draws"][0]["contaminated"] = True
            elif operation == "cache": row["cache_consumers"][0]["live"] = False
            elif operation == "budget": row["cache_consumers"][0]["budget_matches"] = False
            else: row["surface_governor"]["queued_material_changes"] = 1
            self.assertEqual(classify_materials(probe, "expected")["material_gate_exit"], 1)

    def test_unrestored_state_or_retained_material(self):
        for operation in ("state", "count", "retirement"):
            probe = fixture()
            if operation == "state": probe["material_observations"][0]["refresh"]["after_state"] = {"draw": 2}
            elif operation == "count": probe["material_observations"][0]["refresh"]["tested_current_materials"] = 11
            else: probe["material_retirement"]["retained_material_ids"] = [1]
            self.assertEqual(classify_materials(probe, "expected")["material_gate_exit"], 1)

    def test_source_drift_and_wrong_timing_scope(self):
        probe = fixture()
        self.assertEqual(classify_materials(probe, "changed")["material_gate_exit"], 1)
        probe["material_observations"][0]["outside_measured_intervals"] = False
        self.assertEqual(classify_materials(probe, "expected")["material_gate_exit"], 1)

    def test_v2_absence_has_no_material_claim(self):
        probe = {"root": "v2", "material_contract": "actual_build_ownership_v1", "material_observations": [],
                 "material_retirement": {"applicable": False}}
        result = classify_materials(probe, "unused")
        self.assertEqual(result["material_gate_exit"], 0)
        self.assertFalse(result["applicable"])

    def test_reject_unsafe_initial_or_forced_threshold_side(self):
        for kind, value in (("initial", 0.3), ("initial", float("nan")), ("initial", 0.8), ("probe", 0.315), ("probe", 0.3)):
            probe = fixture()
            pre = probe["material_observations"][0]["refresh"]["precondition"]
            if kind == "initial": pre["effective_intensities"]["mina_caption_crisis"] = value
            else: pre["probe_intensities"][-1] = value
            self.assertEqual(classify_materials(probe, "expected")["material_gate_exit"], 1)

    def test_reject_active_replaced_or_missing_beachhead_evidence(self):
        for operation in ("active", "during", "after", "missing", "forced", "intensity", "refused"):
            probe = fixture()
            refresh = probe["material_observations"][0]["refresh"]
            if operation == "active": refresh["before_beachheads"]["mina_caption_crisis"]["original_count"] = 1
            elif operation in {"during", "after"}: refresh[operation + "_beachheads"]["mina_caption_crisis"]["draws"]["body"]["override_id"] = 104
            elif operation == "missing": refresh.pop("before_beachheads")
            elif operation == "forced": refresh["after_forced"]["mina_caption_crisis"] = 0.1
            elif operation == "intensity": refresh["after_intensities"]["mina_caption_crisis"] = 0.1
            else: refresh["mutated"] = False
            self.assertEqual(classify_materials(probe, "expected")["material_gate_exit"], 1)


if __name__ == "__main__":
    unittest.main()
