"""Small synthetic admission controls; no Godot launch."""
import copy
import json
import unittest
from unittest.mock import patch
import assess


def fixture(phase="01_candidate"):
    spec=next(x for x in assess.PLAN["sequence"] if x["run_name"]==phase)
    failed=spec["predicted_failure_labels_not_runtime_results"]
    rows=[{"label":label,"passed":label not in failed} for label in assess.PLAN["full_unique_ordered_labels"]]
    node={"class":"MeshInstance3D","script":"","metadata":{"purpose":"authored"},"transform":"00000000","global_transform":"00000000","global_position_values":[0,0,0],"visible":True,"visible_in_tree":True,"layers":1,"local_aabb":"00000000","world_aabb":"00000000","world_aabb_values":[[0,0,0],[1,1,1]],"mesh_class":"BoxMesh","box_size":"00000000","surface_count":1,"materials":[{"class":"StandardMaterial3D","albedo":"Color(1,1,1,1)","roughness":0.9,"transparency":0}],"collision_descendants":[]}
    review={path:copy.deepcopy(node) for path in assess.PLAN["target_paths"]}
    review["."]={"class":"Node3D","visible":True,"visible_in_tree":True}
    review["Wall/Collision"]={"class":"StaticBody3D","collision_layer":1,"collision_mask":1,"transform":"Transform3D(identity)","visible":True,"visible_in_tree":True}
    hidden=copy.deepcopy(review)
    for path in assess.PLAN["target_paths"]:hidden[path].update(visible=False,visible_in_tree=False)
    production={path:copy.deepcopy(review[path] if failed else hidden[path]) for path in assess.PLAN["target_paths"]}
    witness={"complete":True,"review":review,"hidden":hidden,"production_targets":production,"production_flag":bool(failed),"target_paths":assess.PLAN["target_paths"].copy(),"envelope_paths":assess.PLAN["envelope_paths"].copy(),"landing_paths":assess.PLAN["landing_paths"].copy(),"retirement":dict.fromkeys(["review","hidden","production","shell","acoustic"],True)}
    probe={"schema":"astra.v2-reservation-display.probe.v1","root":"v2","renderer":"forward_plus","pid":123,"checks":rows,"failures":len(failed),"witnesses":witness}
    return probe,transcript(probe),spec["expected_native_exit"]


def transcript(probe):
    return "Godot Engine v4.7.1.stable.official.a13da4feb\nVulkan 1.3 Forward+\n"+"\n".join(f'[V2 RESERVATION] {"PASS" if row["passed"] else "FAIL"} {row["label"]}' for row in probe["checks"])+f'\n[V2 RESERVATION] checks=28 failures={probe["failures"]}\n'


def evaluate(probe,log,native,phase="01_candidate",**changes):
    args=dict(probe=probe,stdout=log,stderr="",wrapper="",native=native,source_ok=True,pid_ok=True,engine_ok=True,phase=phase);args.update(changes)
    return assess.assess(**args)


class ReservationControls(unittest.TestCase):
    def test_candidate_omission_and_restore(self):
        for phase in ("01_candidate","02_production_flag_omission","03_restored_candidate"):
            p,log,native=fixture(phase);result=evaluate(p,log,native,phase)
            self.assertEqual(result["control_contract_exit"],0,result)
            self.assertEqual(result["diagnostic_gate_exit"],native)

    def test_visible_production_cannot_be_admitted_as_green(self):
        p,log,code=fixture()
        for row in p["witnesses"]["production_targets"].values():row.update(visible=True,visible_in_tree=True)
        self.assertIn("reservation_geometry_display_witness_invalid",evaluate(p,log,code)["reasons"])

    def test_deleted_target_wrong_bounds_and_collision_descendant_reject(self):
        for kind in ("delete","bounds","collision","identity"):
            p,log,code=fixture();path=assess.PLAN["target_paths"][0]
            if kind=="delete":p["witnesses"]["production_targets"].pop(path)
            elif kind=="bounds":p["witnesses"]["hidden"][path]["world_aabb"]="changed actual bounds"
            elif kind=="collision":p["witnesses"]["production_targets"][path]["collision_descendants"]=[path+"/Collision"]
            else:p["witnesses"]["target_paths"][0]="invented"
            with self.subTest(kind=kind):self.assertEqual(evaluate(p,log,code)["control_contract_exit"],1)

    def test_non_target_display_and_collision_mask_change_reject(self):
        for field,value in [("visible",False),("collision_mask",0)]:
            p,log,code=fixture();p["witnesses"]["hidden"]["Wall/Collision"][field]=value
            with self.subTest(field=field):self.assertEqual(evaluate(p,log,code)["control_contract_exit"],1)

    def test_missing_witness_and_retirement_reject(self):
        for kind in ("missing","incomplete","retirement"):
            p,log,code=fixture()
            if kind=="missing":p.pop("witnesses")
            elif kind=="incomplete":p["witnesses"]["complete"]=False
            else:p["witnesses"]["retirement"]["production"]=False
            with self.subTest(kind=kind):self.assertEqual(evaluate(p,log,code)["control_contract_exit"],1)

    def test_partial_rows_or_footer_reject(self):
        p,log,code=fixture()
        self.assertEqual(evaluate(p,log.replace("checks=28 failures=0",""),code)["control_contract_exit"],1)
        p["checks"].pop();self.assertEqual(evaluate(p,log,code)["control_contract_exit"],1)

    def test_unknown_errors_retention_source_pid_engine_and_timeout_reject(self):
        p,log,code=fixture()
        for extra in [dict(stderr="ERROR: unknown"),dict(stderr="ObjectDB instances leaked at exit"),dict(source_ok=False),dict(pid_ok=False),dict(engine_ok=False),dict(native=124)]:
            args=dict(probe=p,log=log,native=code);args.update(extra)
            with self.subTest(extra=extra):self.assertEqual(evaluate(**args)["control_contract_exit"],1)

    def test_terminal_phase_uses_unchanged_39_contract(self):
        marker={"exact_terminal_assessor":True}
        with patch.object(assess.terminal_assess,"assess",return_value=marker) as reused:
            result=assess.assess({},"stdout","stderr","wrapper",0,True,True,True,"04_terminal_regression")
            self.assertIs(result,marker)
            self.assertEqual(reused.call_args.args[-1],"02_candidate")
            self.assertEqual(len(assess.terminal_assess.PLAN["full_unique_ordered_labels"]),39)


if __name__=="__main__":unittest.main()
