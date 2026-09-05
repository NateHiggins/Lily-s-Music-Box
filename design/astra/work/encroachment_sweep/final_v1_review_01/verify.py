"""Final uninstrumented V1 evidence verification; no engine or live mutation."""
from pathlib import Path
from collections import Counter, defaultdict
import hashlib
import importlib.util
from importlib.machinery import SourceFileLoader
import json
import math
import statistics
import struct

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / "game/project.godot").is_file())
RUNS = ROOT / "design/astra/evidence/vulkan_composed/runs"
FINAL = RUNS / "candidate_v1_material_final_01"
REFERENCE = RUNS / "viewport_guard_final_01_restored"
EXPECTED = {
    "game/scripts/reality/apartment_encroachment.gd": "1a1b067ff5b95c03fea739747c97deaaf9621e03a635b318b3379cef07bd3776",
    "game/scripts/building/building_root.gd": "cde44cd16b9ebdfedde0bcda34b404c2a675adffe106ba4ac0d576d26e8e1fd4",
    "game/tests/vulkan_composed_root_test.gd": "5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3",
    "game/tests/VulkanComposedRootTest.tscn": "b95080899e02aa01d87b9a688ffee970f5d3e5ef14399d87cde6d91d40cc2663",
}


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1048576), b""): h.update(chunk)
    return h.hexdigest()


def value_sha(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def load_gate(path):
    assert sha(path) == "2197f6ad6b9a13cf83c1d99313808b20b3a8be1472997d7e53d6ef61e035d264"
    loader = SourceFileLoader("retained_final_v1_gate", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def main():
    final = json.loads((FINAL / "result.json").read_text())
    reference = json.loads((REFERENCE / "result.json").read_text())
    probe = json.loads((FINAL / "frames/probe.json").read_text())
    reference_probe = json.loads((REFERENCE / "frames/probe.json").read_text())
    artifacts = final["artifacts"]
    assert len(artifacts) == 62
    for name, fingerprint in artifacts.items():
        path = (FINAL / name).resolve()
        assert path.is_relative_to(FINAL.resolve()) and path.is_file() and sha(path) == fingerprint, name
    copies = {}
    for phase in ("before", "after"):
        assert sha(FINAL / (phase + ".diff")) == final[phase]["diff_sha256"]
        for path, fingerprint in EXPECTED.items(): assert final[phase]["files"][path] == fingerprint
        for name, fingerprint in artifacts.items():
            prefix = phase + "_sources/"
            if name.startswith(prefix):
                assert final[phase]["files"][name[len(prefix):]] == fingerprint
                copies[name] = fingerprint
    assert len(copies) == 32 and final["before"] == final["after"] and final["source_unchanged"]
    assert final["engines_before"] == final["engines_after"] == reference["engines_before"] == reference["engines_after"]
    assert len(final["engines_before"]) == 2
    assert final["wrapper_inputs"] == reference["wrapper_inputs"]
    for path, fingerprint in final["wrapper_inputs"].items(): assert artifacts[Path(path).name + ".source"] == fingerprint
    assert sha(REFERENCE / "frames/probe.json") == reference["artifacts"]["frames/probe.json"]
    assert sha(REFERENCE / "before_sources/game/tests/vulkan_composed_root_test.gd") == EXPECTED["game/tests/vulkan_composed_root_test.gd"]
    labels = [x["label"] for x in probe["checks"]]
    assert len(labels) == 305 and labels == [x["label"] for x in reference_probe["checks"]]
    assert all(x["passed"] for x in probe["checks"]) and probe["functional_failures"] == 0
    assert "material_contract" not in probe and "material_observations" not in probe
    assert all(any(x["label"] == label and x["passed"] for x in probe["checks"])
        for label in ("actual shell retired", "actual selected world retired"))
    stdout = (FINAL / "stdout.log").read_text(encoding="utf-8-sig", errors="replace")
    stderr = (FINAL / "stdout.log.stderr").read_text(encoding="utf-8-sig", errors="replace")
    gate = load_gate(FINAL / "gate.py.source")
    replay = gate.classify(final["actual_engine_exit"], stdout, stderr, probe,
        final["before"]["files"] == final["after"]["files"], True)
    assert replay == final["gate"] and replay["diagnostic_gate_exit"] == final["actual_engine_exit"] == 0
    assert not replay["retention"] and not replay["non_inherited_error_headers"]
    assert replay["unpair_errors"] == replay["soft_shadow_underflows"] == 0

    images = []
    assert len(probe["captures"]) == 18
    assert [x["name"] for x in probe["captures"]] == [x["name"] for x in reference_probe["captures"]]
    for capture in probe["captures"]:
        path = Path(capture["file"]).resolve()
        assert path.is_relative_to((FINAL / "frames").resolve()) and capture["written"]
        relative = path.relative_to(FINAL).as_posix()
        assert relative in artifacts
        with path.open("rb") as stream: header = stream.read(24)
        assert header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR"
        dimensions = list(struct.unpack(">II", header[16:24]))
        assert dimensions == capture["size"]
        images.append({"name": capture["name"], "file": relative, "dimensions": dimensions,
            "sha256": artifacts[relative], "visual_review": "root-owned; not performed by this verifier"})

    rows = []; previous = None
    assert len(probe["transitions"]) == 43
    for index, transition in enumerate(probe["transitions"]):
        assert len(transition["frames"]) == 4 and transition["repeated_scan_count"] == 16
        phase = "warmup" if transition["warmup"] else "six_cycle_loop"
        direction = str(previous) + " -> " + transition["station"]
        if transition["cycle"] == 7: phase = "post_loop_capture_return"
        elif transition["cycle"] == 6:
            phase = "post_control_retirement_return"
            direction = "orison -> passage"  # Explicit production visibility reset in exact fixture.
        rows.append({"index": index, "cycle": transition["cycle"], "phase": phase, "direction": direction,
            "apply_ms": transition["apply_usec"] / 1000,
            "separate_16_scan_ms": transition["repeated_scan_usec"] / 1000, "frames": transition["frames"]})
        previous = transition["station"]
    counts = dict(Counter(x["phase"] for x in rows))
    assert counts == {"warmup": 5, "six_cycle_loop": 36, "post_loop_capture_return": 1, "post_control_retirement_return": 1}
    directions = []
    for phase,direction in dict.fromkeys((x["phase"],x["direction"]) for x in rows if x["phase"] != "warmup"):
        values = [x["apply_ms"] for x in rows if (x["phase"],x["direction"]) == (phase,direction)]
        ordered = sorted(values)
        directions.append({"phase": phase,"direction":direction,"n":len(values),"samples_ms":values,
            "median_ms":statistics.median(values),"mean_ms":statistics.mean(values),"min_ms":min(values),
            "max_ms":max(values),"p95_nearest_rank_ms":ordered[math.ceil(.95*len(values))-1]})
    before, prior = final["before"]["files"], reference["before"]["files"]
    changes = {p:[prior.get(p),before.get(p)] for p in sorted(set(before)|set(prior)) if before.get(p)!=prior.get(p)}
    expected_changes = {"game/scripts/reality/apartment_encroachment.gd"} | {"game/tests/fixtures/encroachment_sweep/"+name+".gd" for name in ("baseline","candidate","drop_late","priority")}
    assert set(changes) == expected_changes
    budget_counts = Counter(f["surface_governor"]["budget"] for row in rows if row["phase"] == "six_cycle_loop" for f in row["frames"])
    record = {"schema":"astra.final-v1-independent-review.v1","status":"FINAL_BASE_V1_CONTRACT_VERIFIED",
        "run":str(FINAL.relative_to(ROOT)),"source_result_sha256":sha(FINAL/"result.json"),
        "reference":str(REFERENCE.relative_to(ROOT)),"reference_result_sha256":sha(REFERENCE/"result.json"),
        "all_62_verified_artifacts":artifacts,"all_32_verified_source_copies":copies,
        "exact_runtime_owners":EXPECTED,"source_inventory_count":len(before),"source_unchanged":True,
        "source_map_change_since_reference":changes,"engines_equal_and_stable":final["engines_before"],
        "wrappers_equal":final["wrapper_inputs"],"ordered_305_labels":labels,"ordered_labels_sha256":value_sha(labels),
        "ordered_reference_labels_equal":True,"actual_engine_exit":final["actual_engine_exit"],
        "gate_replay_exactly_equals_recorded":True,"raw_diagnostic_classification":replay,
        "captures":images,"transition_phase_counts":counts,"directional_apply_timings":directions,
        "raw_transition_samples":rows,"main_loop_governor_budget_frame_counts":dict(budget_counts),
        "actual_root_retirement":{"shell":True,"selected_world":True,"native_retention_diagnostics":[]},
        "owned_controls":probe["owned_controls"],"subviews":probe["subviews"],
        "all_arcade_observation_issues": [x for x in probe["arcade_observations"] if x.get("issues")],
        "scope_limits":["Base fixture has no material probe. This run proves neither all-registry lifecycle restoration nor per-material WeakRef retirement; those belong to separate d67 receipts.",
            "Controlled actual-root teleport/render/ownership/retirement smoke, not player traversal, human visual acceptance or release performance.",
            "Apply timings bracket synchronous visibility call, not whole frame time; sampled governor remains adaptive. Single-source single-run timings, no speedup comparison or confidence interval.",
            "Five warmups and two one-off capture/retirement returns remain separate from the36 main transitions. Native no-op call count is not proven.",
            "The reference differs at owner plus four inactive source fixtures; exact ordered labels establish contract continuity, not an isolated timing comparison."]}
    out = ROOT/"design/astra/reviews/final_v1_material_execution_review.json"
    assert not out.exists()
    out.write_text(json.dumps(record,indent=2)+"\n")
    print(json.dumps({"status":record["status"],"json_sha256":sha(out),"source_result_sha256":record["source_result_sha256"],
        "gate":replay,"timings":[{k:v for k,v in x.items() if k!='samples_ms'} for x in directions],
        "governor":dict(budget_counts),"artifacts":len(artifacts),"source_copies":len(copies)},indent=2))


if __name__ == "__main__":
    main()
