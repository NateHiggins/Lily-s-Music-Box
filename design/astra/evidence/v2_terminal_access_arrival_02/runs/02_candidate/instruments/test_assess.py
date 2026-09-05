"""Small synthetic controls for receipt admission; these never run Godot."""
import copy
import math
import unittest
import assess


def fixture(phase="02_candidate"):
    spec = next(row for row in assess.PLAN["sequence"] if row["run_name"] == phase)
    failures = spec["predicted_failure_labels_not_runtime_results"]
    rows = [{"label": label, "passed": label not in failures} for label in assess.PLAN["full_unique_ordered_labels"]]
    face = "actual scope front faces the operator" not in failures
    desk = "V2 owns exactly one actual DeskZone" not in failures
    ray = {"from": [-9.9, 11.01, 1.25], "to": [-7.8, 11.01, 1.25], "actor_position": [-9.9, 9.6, 1.25], "camera_position": [-9.9, 11.01, 1.25], "physics_processing": False, "hit_from_inside": False, "collider": "actual/desk" if desk else "", "target_is_desk": desk, "hit_position": [0.5, 1, 0] if desk else []}
    diag = {"complete": True, "scope_front": [-1, 0, 0] if face else [0, 0, 1], "operator_direction": [-0.85, 0, 0], "front_dot": 1.0 if face else 0.0,
        "terminal_position": [0, 0, 0], "terminal_basis": [], "semantic_position": [0, 0, 0], "semantic_basis": [], "scope_position": [-8.9, 11.01, 1.25], "scope_basis": [],
        "desk_count": int(desk), "call_count": 1, "desk_size": [0.8, 1.6, 0.8] if desk else [], "first_ray": ray, "second_ray": copy.deepcopy(ray),
        "world_events": [], "case_open_delay_factor": 0.05, "first_interact_action_dispatched": True, "seated_E_action_dispatched": desk, "reentry_action_dispatched": desk, "escape_key_dispatched": desk, "scope": "SYNTHETIC ASSESSOR CONTROL ONLY",
        "operator_position": [-9.9,9.6,1.25], "arrival": {
            "before_position": [0,0,-14.25], "position": [-3.6,0.1,24.72], "camera_position": [-3.6,1.51,24.72],
            "velocity": [0,0,0], "yaw": math.atan2(-3.6,14.9), "camera_local_rotation": [0,0,0],
            "phase_before": "complete", "phase_after": "complete", "waited_process_frames": 1, "stable_process_frames": 2,
            "observed": True, "settled": True, "director_owns_world": True, "intro_complete": True,
            "noclip": False, "call_locked": False, "collision_layer": 1, "collision_mask": 1}}
    probe = {"schema": "astra.v2-terminal-access.probe.v2", "root": "v2", "renderer": "forward_plus", "pid": 123, "checks": rows, "failures": len(failures), "diagnostics": diag}
    return probe, transcript(probe), spec["expected_native_exit"]


def transcript(probe):
    return "Godot Engine v4.7.1.stable.official.a13da4feb\nVulkan 1.3 Forward+\n" + "\n".join(f'[V2 TERMINAL ACCESS] {"PASS" if row["passed"] else "FAIL"} {row["label"]}' for row in probe["checks"]) + f'\n[V2 TERMINAL ACCESS] checks=39 failures={probe["failures"]}\n'


def evaluate(probe, stdout, native, phase="02_candidate", **overrides):
    args = {"probe": probe, "stdout": stdout, "stderr": "", "wrapper": "", "native": native, "source_ok": True, "pid_ok": True, "engine_ok": True, "phase": phase}
    args.update(overrides)
    return assess.assess(**args)


class AdmissionControls(unittest.TestCase):
    def test_all_six_named_variants_keep_strict_negative_red(self):
        for spec in assess.PLAN["sequence"]:
            with self.subTest(phase=spec["run_name"]):
                q, log, code = fixture(spec["run_name"])
                verdict = evaluate(q, log, code, spec["run_name"])
                self.assertEqual(verdict["control_contract_exit"], 0, verdict)
                self.assertEqual(verdict["diagnostic_gate_exit"], int(bool(code)))

    def test_missing_receipt(self):
        _, log, code = fixture()
        self.assertEqual(evaluate(None, log, code)["control_contract_exit"], 1)

    def test_source_pid_and_engine_binding_refuse(self):
        q, log, code = fixture()
        for key in ["source_ok", "pid_ok", "engine_ok"]:
            with self.subTest(key=key): self.assertEqual(evaluate(q, log, code, **{key: False})["control_contract_exit"], 1)

    def test_duplicate_omitted_and_malformed_rows(self):
        for variant in ["duplicate", "omitted", "malformed"]:
            q, log, code = fixture()
            if variant == "duplicate": q["checks"][1] = q["checks"][0].copy()
            elif variant == "omitted": q["checks"].pop()
            else: q["checks"][3] = None
            with self.subTest(variant=variant): self.assertEqual(evaluate(q, log, code)["control_contract_exit"], 1)

    def test_retirement_failure_cannot_be_absorbed_as_a_control(self):
        q, _, code = fixture("03_orientation_omission")
        q["checks"][-3]["passed"] = False; q["failures"] += 1
        self.assertEqual(evaluate(q, transcript(q), code, "03_orientation_omission")["control_contract_exit"], 1)

    def test_expected_red_does_not_accept_a_different_failed_claim(self):
        q, _, code = fixture("03_orientation_omission")
        next(row for row in q["checks"] if row["label"] == "actual scope front faces the operator")["passed"] = True; next(row for row in q["checks"] if row["label"] == "actual V2 startup succeeds")["passed"] = False
        self.assertEqual(evaluate(q, transcript(q), code, "03_orientation_omission")["control_contract_exit"], 1)

    def test_unknown_error_warning_and_retention_reject(self):
        q, log, code = fixture()
        for detail in ["ERROR: unrelated", "SCRIPT ERROR: Parse Error", "WARNING: unrelated", "ObjectDB instances leaked at exit", "ERROR: geom->softshadow_count==0 - BUG!"]:
            with self.subTest(detail=detail): self.assertEqual(evaluate(q, log, code, stderr=detail)["control_contract_exit"], 1)

    def test_exact_known_warning_pair_is_retained_but_changed_detail_rejects(self):
        q, log, code = fixture()
        pair = assess.KNOWN["warnings"][0]
        good = evaluate(q, log, code, stderr="\n".join(pair))
        self.assertEqual(good["control_contract_exit"], 0)
        self.assertEqual(good["known_diagnostic_debt"][0]["count"], 1)
        self.assertEqual(evaluate(q, log, code, stderr=pair[0]+"\nUnrelated warning")["control_contract_exit"], 1)

    def test_refusals_and_timeout_are_not_expected_functional_red(self):
        q, log, _ = fixture("01_original")
        for code in [73, 78, 124]:
            with self.subTest(code=code): self.assertEqual(evaluate(q, log, code, "01_original")["control_contract_exit"], 1)

    def test_incomplete_payload_and_false_front_claim_reject(self):
        for variant in ["absent", "incomplete", "false_front", "nan"]:
            q, log, code = fixture()
            if variant == "absent": q["diagnostics"].pop("scope_basis")
            elif variant == "incomplete": q["diagnostics"]["complete"] = False
            elif variant == "false_front": q["diagnostics"]["front_dot"] = 0.0
            else: q["diagnostics"]["front_dot"] = float("nan")
            with self.subTest(variant=variant): self.assertEqual(evaluate(q, log, code)["control_contract_exit"], 1)

    def test_raw_rows_and_footer_are_required(self):
        q, log, code = fixture()
        for changed in [log.replace("checks=39 failures=0", "checks=35 failures=0"), log.replace("PASS actual scope front", "FAIL actual scope front")]:
            self.assertEqual(evaluate(q, changed, code)["control_contract_exit"], 1)

    def test_each_ray_at_old_curb_rejects_even_with_true_claims(self):
        for key in ("first_ray", "second_ray"):
            q, log, code = fixture()
            q["diagnostics"][key]["from"] = [-3.6,1.51,24.72]
            with self.subTest(ray=key):
                verdict = evaluate(q, log, code)
                self.assertIn("arrival_or_authored_operator_ray_origin_invalid", verdict["reasons"])
                self.assertEqual(verdict["control_contract_exit"], 1)

    def test_camera_and_actor_origin_are_independently_bound(self):
        for ray in ("first_ray", "second_ray"):
            for field in ("camera_position", "actor_position"):
                q, log, code = fixture()
                q["diagnostics"][ray][field] = [0,0,0]
                with self.subTest(ray=ray,field=field):
                    self.assertEqual(evaluate(q, log, code)["control_contract_exit"], 1)

    def test_nonfinite_wrong_range_wrong_aim_or_missing_pose_reject(self):
        for key,value in [("from", [float("nan"),11.01,1.25]), ("to", [-6.8,11.01,1.25]), ("to", [-9.9,13.11,1.25]), ("physics_processing", True), ("actor_position", None)]:
            q, log, code = fixture()
            q["diagnostics"]["second_ray"][key] = value
            with self.subTest(key=key,value=value):
                self.assertEqual(evaluate(q, log, code)["control_contract_exit"], 1)

    def test_arrival_must_be_observed_and_settled_without_ritual_mutation(self):
        for field,value in [("before_position",[-3.6,0.1,24.72]), ("position",[0,0,0]), ("observed",False), ("settled",False), ("waited_process_frames",0), ("stable_process_frames",0), ("director_owns_world",False), ("phase_after","arrived"), ("yaw",0), ("noclip",True)]:
            q, log, code = fixture()
            q["diagnostics"]["arrival"][field] = value
            with self.subTest(field=field):
                self.assertEqual(evaluate(q, log, code)["control_contract_exit"], 1)

    def test_missing_arrival_payload_and_false_stance_labels_reject(self):
        for variant in ("arrival", "first ray starts from the authored operator and eye", "second ray starts from the authored operator and eye"):
            q, log, code = fixture()
            if variant == "arrival": q["diagnostics"].pop("arrival")
            else: next(row for row in q["checks"] if row["label"] == variant)["passed"] = False
            with self.subTest(variant=variant):
                self.assertEqual(evaluate(q, log, code)["control_contract_exit"], 1)


if __name__ == "__main__": unittest.main()
