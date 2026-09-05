"""Reservation admission; terminal regression delegates to the unchanged39 oracle."""
from pathlib import Path
from collections import Counter
import copy
import json
import math
import re
import terminal_assess

HERE = Path(__file__).resolve().parent
PLAN = json.loads((HERE.parent / "preparation.json").read_text(encoding="utf-8"))
TERMINAL = HERE.parent.with_name("v2_terminal_access_arrival_02")
# Exact copied assessor bytes; only its plan location is overridden explicitly.
terminal_assess.PLAN = json.loads((TERMINAL / "preparation.json").read_text(encoding="utf-8"))
KNOWN = json.loads((HERE / "known_diagnostics.json").read_text(encoding="utf-8"))


def comparison_identity(raw):
    """Independent one-to-one anonymous leaf mapping; raw payload is untouched."""
    if not isinstance(raw,dict) or any(not isinstance(path,str) or not isinstance(row,dict) for path,row in raw.items()):
        raise ValueError("malformed node identity rows")
    nonleaves = {"/".join(path.split("/")[:index]) for path in raw for index in range(1,len(path.split("/")))}
    mapping, aliases, occupied = {}, {}, set()
    for path,row in raw.items():
        parent, separator, leaf = path.rpartition("/")
        canonical = path
        if re.fullmatch(r"@CollisionShape3D@[0-9]+",leaf):
            if row.get("class") != "CollisionShape3D" or path in nonleaves or (parent or ".") not in raw:
                raise ValueError("anonymous identity is not an exact leaf CollisionShape3D under a recorded parent")
            canonical = parent + separator + "@CollisionShape3D"
            aliases[path] = canonical
        if canonical in occupied: raise ValueError("ambiguous anonymous siblings or canonical alias collision")
        occupied.add(canonical); mapping[path] = canonical
    normalized, rewrites = {}, 0
    for path,row in raw.items():
        copied = copy.deepcopy(row)
        if "collision_descendants" in copied:
            refs = copied["collision_descendants"]
            if not isinstance(refs,list) or any(not isinstance(ref,str) or ref not in mapping for ref in refs):
                raise ValueError("unresolved collision descendant reference")
            canonical = [mapping[ref] for ref in refs]
            if len(set(canonical)) != len(canonical): raise ValueError("duplicate collision identity reference")
            rewrites += sum(left != right for left,right in zip(refs,canonical))
            copied["collision_descendants"] = canonical
        normalized[mapping[path]] = copied
    return normalized,{"valid":True,"aliases":aliases,"reference_rewrites":rewrites,"raw_count":len(raw)}


def geometry(rows):
    result = copy.deepcopy(rows)
    for row in result.values():
        row.pop("visible", None); row.pop("visible_in_tree", None)
    return result


def visible_count(rows, paths):
    count = 0
    for path in paths:
        row = rows[path]
        if row["visible"] is True and row["visible_in_tree"] is True: count += 1
        elif row["visible"] is not False or row["visible_in_tree"] is not False: raise ValueError("partial/inherited display state")
    return count


def validate_witness(witness, flags):
    if witness.get("complete") is not True: raise ValueError("incomplete witness")
    targets = PLAN["target_paths"]
    env, lift = PLAN["envelope_paths"], PLAN["landing_paths"]
    if witness["target_paths"] != targets or witness["envelope_paths"] != env or witness["landing_paths"] != lift: raise ValueError("authored target identity list changed")
    review, hidden, production = witness["review"], witness["hidden"], witness["production_targets"]
    if len(review) != len(hidden) or len(review) <= 78 or set(production) != set(targets): raise ValueError("full generated population or target census incomplete")
    for rows in (review,hidden,production):
        for path in targets:
            row = rows[path]
            required = {"class","script","metadata","transform","global_transform","global_position_values","visible","visible_in_tree","layers","local_aabb","world_aabb","world_aabb_values","mesh_class","box_size","surface_count","materials","collision_descendants"}
            if not isinstance(row,dict) or not required.issubset(row): raise ValueError("target geometry payload incomplete")
            if row["class"] != "MeshInstance3D" or row["mesh_class"] != "BoxMesh" or row["surface_count"] != 1 or row["collision_descendants"] != []: raise ValueError("target shape/collision contract changed")
            if any(not isinstance(row[key],str) or not re.fullmatch(r"(?:[0-9a-f]{2})+",row[key]) for key in ("transform","global_transform","local_aabb","world_aabb","box_size")): raise ValueError("invalid exact target geometry encoding")
            if not isinstance(row["world_aabb_values"],list) or len(row["world_aabb_values"]) != 2: raise ValueError("unreadable world bounds")
            for vec in [row["global_position_values"],*row["world_aabb_values"]]:
                if not isinstance(vec,list) or len(vec)!=3 or any(type(v) not in (int,float) or not math.isfinite(v) for v in vec): raise ValueError("nonfinite geometry values")
            if not isinstance(row["materials"],list) or len(row["materials"]) != 1: raise ValueError("target material missing")
    normalized_review, review_identity = comparison_identity(review)
    normalized_hidden, hidden_identity = comparison_identity(hidden)
    if witness.get("comparison_identity") != {"review":review_identity,"hidden":hidden_identity}: raise ValueError("comparison identity evidence differs from independently proven map")
    if geometry(normalized_review) != geometry(normalized_hidden): raise ValueError("generated geometry or semantic record changed")
    if geometry(production) != geometry({path:review[path] for path in targets}): raise ValueError("production target geometry changed")
    other = lambda rows:{path:[row.get("visible"),row.get("visible_in_tree")] for path,row in rows.items() if path not in targets and "visible" in row}
    if other(normalized_review) != other(normalized_hidden): raise ValueError("non-target display changed")
    collisions = lambda rows:{path:row for path,row in rows.items() if "collision_layer" in row or "shape_class" in row}
    if not collisions(normalized_review) or collisions(normalized_review) != collisions(normalized_hidden): raise ValueError("collision owner records absent or changed")
    for key in ("review","hidden","production","shell","acoustic"):
        if witness["retirement"][key] is not True: raise ValueError("actual retirement/restoration missing")
    expected = {
        "dedicated review displays all seventy envelopes": visible_count(review,env)==70,
        "dedicated review displays all eight landing clearances": visible_count(review,lift)==8,
        "hidden blockout suppresses all seventy envelopes": visible_count(hidden,env)==0,
        "hidden blockout suppresses all eight landing clearances": visible_count(hidden,lift)==0,
        "production selects reservation suppression before construction": witness["production_flag"] is False,
        "production suppresses all seventy envelopes": visible_count(production,env)==0,
        "production suppresses all eight landing clearances": visible_count(production,lift)==0,
    }
    if type(witness["production_flag"]) is not bool or any(flags.get(label) is not value for label,value in expected.items()): raise ValueError("display payload contradicts actual checks")


def assess(probe, stdout, stderr, wrapper, native, source_ok, pid_ok, engine_ok, phase):
    spec = next(row for row in PLAN["sequence"] if row["run_name"] == phase)
    if spec["kind"] == "terminal":
        return terminal_assess.assess(probe,stdout,stderr,wrapper,native,source_ok,pid_ok,engine_ok,"02_candidate")
    reasons=[]
    if not source_ok: reasons.append("source_binding_failed")
    if not pid_ok: reasons.append("actual_engine_pid_ancestry_missing")
    if not engine_ok: reasons.append("installed_engine_binding_failed")
    if native not in (0,1): reasons.append("runner_refusal_timeout_or_unexpected_exit")
    if "Godot Engine v4.7.1.stable.official.a13da4feb" not in stdout or "Vulkan " not in stdout or "Forward+" not in stdout: reasons.append("actual_windowed_engine_identity_missing")
    debt,unknown,retention=[],[],[]
    allowed_errors={tuple(row) for row in KNOWN["errors"]}; allowed_warnings={tuple(row) for row in KNOWN["warnings"]}
    lines=(stdout+"\n"+stderr+"\n"+wrapper).splitlines()
    for i,line in enumerate(lines):
        if any(x in line for x in ("ObjectDB instances leaked","resources still in use at exit","Unreferenced static string")):retention.append(line)
        if not line.startswith(("ERROR:","SCRIPT ERROR:","WARNING:")):continue
        pair=(line,lines[i+1].strip() if i+1<len(lines) else "")
        if pair in (allowed_warnings if line.startswith("WARNING:") else allowed_errors):debt.append(pair)
        else:unknown.append(pair)
    if unknown:reasons.append("unknown_native_diagnostic")
    if retention:reasons.append("retention_diagnostic")
    if not isinstance(probe,dict):reasons.append("missing_or_unreadable_probe");probe={}
    rows=probe.get("checks",[])
    if not isinstance(rows,list) or any(not isinstance(row,dict) for row in rows):reasons.append("malformed_check_rows");rows=[]
    labels=[row.get("label") for row in rows]
    if labels!=PLAN["full_unique_ordered_labels"] or len(rows)!=28 or len(set(labels))!=28:reasons.append("exact_unique_28_label_contract_failed")
    if any(type(row.get("passed")) is not bool for row in rows):reasons.append("non_boolean_check")
    failed=[row.get("label") for row in rows if row.get("passed") is not True]
    if probe.get("schema")!="astra.v2-reservation-display.probe.v1" or probe.get("root")!="v2" or probe.get("renderer")!="forward_plus" or type(probe.get("pid")) is not int or probe.get("pid",0)<=0:reasons.append("probe_identity_invalid")
    if type(probe.get("failures")) is not int or probe.get("failures")!=len(failed):reasons.append("failure_count_inconsistent")
    raw=re.findall(r"^\[V2 RESERVATION\] (PASS|FAIL) (.+)$",stdout,re.M)
    if raw!=[("PASS" if row.get("passed") is True else "FAIL",row.get("label")) for row in rows]:reasons.append("raw_check_rows_do_not_match_probe")
    if re.findall(r"^\[V2 RESERVATION\] checks=(\d+) failures=(\d+)$",stdout,re.M)!=[("28",str(len(failed)))]:reasons.append("completion_footer_missing_or_inconsistent")
    if len(rows)<3 or any(row.get("passed") is not True for row in rows[-3:]):reasons.append("actual_retirement_or_acoustic_restore_failed")
    try:validate_witness(probe.get("witnesses",{}),{row["label"]:row["passed"] for row in rows})
    except (KeyError,ValueError,TypeError,AttributeError):reasons.append("reservation_geometry_display_witness_invalid")
    if failed!=spec["predicted_failure_labels_not_runtime_results"]:reasons.append("failure_set_differs_from_exact_planned_variant")
    if native!=spec["expected_native_exit"]:reasons.append("native_exit_differs_from_planned_variant")
    red=bool(reasons or native or failed)
    return {"diagnostic_gate_exit":int(red),"control_contract_exit":int(bool(reasons)),"ordinary_product_status":"FAILED" if red else "PASSED_IN_FOCUSED_SCOPE","reasons":reasons,"failed_labels":failed,"passed":len(rows)-len(failed),"total":len(rows),"known_diagnostic_debt":[{"header":p[0],"detail":p[1],"count":n} for p,n in Counter(debt).items()],"unknown_diagnostics":unknown,"retention":retention,"negative_control_scope_only":bool(failed and not reasons)}
