"""Independent immutable-artifact and direction timing comparison; no engine."""
from pathlib import Path
from collections import defaultdict
import hashlib
import json
import math
import statistics

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
RUNS = ROOT / "design/astra/evidence/vulkan_composed/runs"
NAMES = ["material_floor_admission_v1_full_01", "material_one_census_v1_full_01"]
OWNER = "game/scripts/reality/apartment_encroachment.gd"
OWNER_HASHES = ["2a440504ab80404f4d9f4ab16138df7db9255801ca879ff91aabafe3c7f4d0ca",
    "1a1b067ff5b95c03fea739747c97deaaf9621e03a635b318b3379cef07bd3776"]


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1048576), b""): h.update(chunk)
    return h.hexdigest()


def canonical_hash(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def stats(values):
    ordered = sorted(values)
    return {"n": len(values), "min_ms": min(values), "median_ms": statistics.median(values),
        "mean_ms": statistics.mean(values), "p95_nearest_rank_ms": ordered[math.ceil(len(values) * .95) - 1],
        "max_ms": max(values), "samples_ms": values}


def read_run(name, expected_owner):
    base = RUNS / name
    result = json.loads((base / "result.json").read_text())
    probe = json.loads((base / "frames/probe.json").read_text())
    entries = result["artifacts"]
    assert len(entries) == 62
    checked = {}
    for relative, expected in entries.items():
        path = (base / relative).resolve()
        assert path.is_relative_to(base.resolve()) and path.is_file(), relative
        actual = sha(path)
        assert actual == expected, relative
        checked[relative] = actual
    # Verify every retained source copy against its independently recorded map.
    source_copies = 0
    for label in ("before", "after"):
        assert sha(base / (label + ".diff")) == result[label]["diff_sha256"]
        assert result[label]["files"][OWNER] == expected_owner
        for relative, fingerprint in entries.items():
            prefix = label + "_sources/"
            if relative.startswith(prefix):
                assert result[label]["files"][relative[len(prefix):]] == fingerprint
                source_copies += 1
    for wrapper_path, fingerprint in result["wrapper_inputs"].items():
        assert entries[Path(wrapper_path).name + ".source"] == fingerprint
    assert result["before"] == result["after"]
    assert result["engines_before"] == result["engines_after"] and len(result["engines_before"]) == 2
    assert result["actual_engine_exit"] == result["gate"]["diagnostic_gate_exit"] == 0
    assert result["source_unchanged"] and probe["functional_failures"] == 0
    assert len(probe["checks"]) == 314 and all(x["passed"] for x in probe["checks"])
    additive = ROOT / "design/astra/evidence/composed_material_ownership" / (name + "_additive_v2.json")
    classified = json.loads(additive.read_text())
    assert classified["source_result_sha256"] == sha(base / "result.json")
    assert classified["diagnostic_gate_exit"] == classified["material_gate"]["material_gate_exit"] == 0
    return result, probe, {"result_sha256": sha(base / "result.json"), "probe_sha256": entries["frames/probe.json"],
        "verified_artifacts": checked, "verified_artifact_count": len(checked), "verified_source_copies": source_copies,
        "additive_result_sha256": sha(additive), "source_file_count": len(result["before"]["files"]),
        "engine_and_gate_exit": 0, "checks": 314, "capture_count": len(probe["captures"])}


def direction_rows(probe):
    rows = []
    previous = None
    for index, row in enumerate(probe["transitions"]):
        direction = str(previous) + " -> " + row["station"]
        if not row["warmup"]:
            phase = "six_cycle_loop"
            if row["cycle"] == 7:
                phase = "post_loop_capture_return"
            elif row["cycle"] == 6:
                phase = "post_control_retirement_return"
                # The exact fixture explicitly calls _apply_visibility(STATIONS[2].zone)
                # after the mirror/blocker/private-world controls, outside the array.
                direction = "orison -> passage"
            # The contiguous six-cycle loop is the matched measurement set.
            # Later captured returns follow ownership/subview controls.
            rows.append({"index": index, "cycle": row["cycle"], "direction": direction,
                "phase": phase,
                "apply_ms": row["apply_usec"] / 1000, "repeated_scan_ms": row["repeated_scan_usec"] / 1000,
                "frame_count": len(row["frames"]), "frames": row["frames"]})
        previous = row["station"]
    return rows


def material_summary(row):
    cases = {}
    for case, data in row["cases"].items():
        cases[case] = {"unit": data["unit"], "finishes": len(data["finishes"]), "props": len(data["props"]),
            "rows": {kind: [{k:v for k,v in x.items() if k != "material_id"} for x in data[kind]] for kind in ("finishes", "props")}}
    refresh = row.get("refresh", {})
    counts = {k:v for k,v in refresh.items() if type(v) is int or type(v) is bool}
    registry = {floor: {k:v for k,v in data.items() if k not in ("material_ids", "installed_ids")}
        for floor, data in row["registries"].items()}
    restored = None
    if row["refresh_exercised"]:
        restored = (refresh["registry_lifecycle_before"] == refresh["registry_lifecycle_after"]
            and refresh["before_forced"] == refresh["after_forced"]
            and refresh["before_intensities"] == refresh["after_intensities"]
            and refresh["before_state"] == refresh["after_state"]
            and refresh["before_beachheads"] == refresh["during_beachheads"] == refresh["after_beachheads"])
        assert restored and refresh["passed"] and refresh["facts_unchanged"] and refresh["same_frame_restored"]
        assert all(x["evaluated"] and x["passed"] for key in ("case_comparisons", "case_lifecycle_comparisons", "registry_lifecycle_comparisons") for x in refresh[key])
    assert not row["issues"] and row["outside_measured_intervals"]
    return {"stage": row["stage"], "private_geometry": row["private_geometry"], "actor_geometry": row["actor_geometry"],
        "case_counts": {k:{f:v for f,v in x.items() if f != "rows"} for k,x in cases.items()},
        "case_rows_without_instance_ids_sha256": canonical_hash({k:x["rows"] for k,x in cases.items()}),
        "cache_count": len(row["cache_consumers"]), "cache_keys_sha256": canonical_hash(sorted(x["key"] for x in row["cache_consumers"])),
        "cache_live_budget_checks": all(x["live"] and x["budget_matches"] for x in row["cache_consumers"]),
        "excluded_contaminated": sum(x["contaminated"] for x in row["excluded_draws"]), "registries": registry,
        "refresh_exercised": row["refresh_exercised"], "refresh_counts_and_flags": counts,
        "independent_before_after_restoration_equal": restored, "surface_governor": row["surface_governor"]}


def main():
    loaded = [read_run(n, h) for n,h in zip(NAMES, OWNER_HASHES)]
    a,b = [x[0] for x in loaded]; pa,pb = [x[1] for x in loaded]
    maps = [x["before"]["files"] for x in (a,b)]
    changed = {p: [maps[0].get(p),maps[1].get(p)] for p in sorted(set(maps[0])|set(maps[1])) if maps[0].get(p) != maps[1].get(p)}
    assert changed == {OWNER: OWNER_HASHES}
    assert a["wrapper_inputs"] == b["wrapper_inputs"] and a["engines_before"] == b["engines_before"]
    assert a["before"]["head"] == b["before"]["head"] and a["hardware_context"] == b["hardware_context"]
    commands = [(RUNS/n/"command.ps1").read_text().replace(n,"MATCHED_RUN") for n in NAMES]
    assert commands[0] == commands[1]
    samples = [direction_rows(p) for p in (pa,pb)]
    assert [[(r["cycle"],r["direction"],r["phase"]) for r in x] for x in samples][0] == [[(r["cycle"],r["direction"],r["phase"]) for r in x] for x in samples][1]
    directions = []
    for phase,direction in dict.fromkeys((r["phase"],r["direction"]) for r in samples[0]):
        pair = [stats([r["apply_ms"] for r in rows if r["phase"] == phase and r["direction"] == direction]) for rows in samples]
        directions.append({"phase": phase, "direction": direction, "baseline": pair[0], "optimized": pair[1],
            "median_change_percent": 100*(pair[1]["median_ms"] / pair[0]["median_ms"]-1),
            "mean_change_percent": 100*(pair[1]["mean_ms"] / pair[0]["mean_ms"]-1)})
    population_rows = []
    assert len(pa["populations"]) == len(pb["populations"])
    for index,(x,y) in enumerate(zip(pa["populations"],pb["populations"])):
        if "population" in x:
            population_rows.append({"index": index, "cycle": x["cycle"], "station": x["station"],
                "baseline": x["population"], "optimized": y["population"], "equal": x["population"] == y["population"]})
    material = [[material_summary(x) for x in p["material_observations"]] for p in (pa,pb)]
    frame_governors = [dict.fromkeys(json.dumps(f["surface_governor"],sort_keys=True) for r in rows for f in r["frames"]) for rows in samples]
    summary = {"schema": "astra.independent.one-census.matched-review.v1", "status": "SOURCE_BOUND_MATCHED_PAIR_REVIEW_COMPLETE",
        "runs": {n:x[2] for n,x in zip(NAMES,loaded)},
        "source_changes_only": changed, "engine_identity_equal": a["engines_before"], "wrapper_identity_equal": a["wrapper_inputs"],
        "normalized_command_equal": True, "hardware_context": a["hardware_context"], "head": a["before"]["head"],
        "source_map_scope": "All 4,045 captured game/tools paths, excluding Git-ignored cache/profile. All retained artifacts/copies verified against recorded hashes; historical uncopied source bytes are represented by captured hash maps.",
        "capture_review": "18 hashes per run verified; human/visual review belongs to root and is not claimed here.",
        "timing_definition": "apply_usec brackets synchronous production visibility call only, before four sampled rendered frames and separate16 repeated no-op scans. Five warmups excluded. Main36 transitions separated from the post-loop Harukiya capture return and post-control retirement Passage return. Exact fixture explicitly resets visibility to Orison before the latter; direction is not inferred merely from the preceding receipt row. First harukiya->street has n1, later orison->street n5.",
        "directional_apply_timing": directions, "nonwarmup_raw_samples": samples,
        "population_rows": population_rows, "population_equal_rows": sum(x["equal"] for x in population_rows),
        "population_compared_rows": len(population_rows),
        "initial_readiness_population": [p["populations"][0] for p in (pa,pb)],
        "harukiya_census_exact_equal": pa["populations"][1] == pb["populations"][1],
        "recorded_material_environment_equal": pa["material_observations"][0]["refresh"]["precondition"]["environment"] == pb["material_observations"][0]["refresh"]["precondition"]["environment"],
        "frame_governor_distinct_states": [[json.loads(v) for v in x] for x in frame_governors],
        "material_observations": dict(zip(("baseline","optimized"),material)),
        "material_stage_comparison": [{"stage": x["stage"], "same_case_rows_without_runtime_ids": x["case_rows_without_instance_ids_sha256"] == y["case_rows_without_instance_ids_sha256"],
            "same_cache_keys": x["cache_keys_sha256"] == y["cache_keys_sha256"], "same_registry_counts": x["registries"] == y["registries"],
            "same_governor": x["surface_governor"] == y["surface_governor"], "same_refresh_counts_and_flags": x["refresh_counts_and_flags"] == y["refresh_counts_and_flags"]}
            for x,y in zip(*material)],
        "material_retirement": [p["material_retirement"] for p in (pa,pb)],
        "scope_limits": ["One ordered full V1 run per source; no repeated randomized or order-balanced trial, confidence interval, V2 or release FPS claim.",
            "Live actor/arcade/governor activity remains enabled; scene population and timing are sampled, not a deterministic lockstep simulation.",
            "Recorded instance IDs are process-local. Material comparisons use paths/counts/contract predicates; no arbitrary texture-pixel or cross-process resource identity claim.",
            "Wrapper source and explicit command/env policy are identical apart from required output/profile paths; complete inherited host environment and OS/GPU background load are not snapshotted.",
            "Measured apply call includes downstream material/callback/index work. The source-only delta supports this matched sweep comparison, not universal attribution of all frame/wall-clock differences."]}
    out = ROOT / "design/astra/reviews/one_census_matched_execution_review.json"
    assert not out.exists(), "preserve prior review"
    out.write_text(json.dumps(summary,indent=2)+"\n")
    print(json.dumps({"review": str(out), "sha256": sha(out), "changed": changed,
        "timings": [{k:v for k,v in row.items() if k not in ("baseline","optimized")} | {"n":row["baseline"]["n"],"baseline_median_ms":row["baseline"]["median_ms"],"optimized_median_ms":row["optimized"]["median_ms"]} for row in directions],
        "population_equal": [summary["population_equal_rows"],summary["population_compared_rows"]],
        "material_stages": summary["material_stage_comparison"],"governors":summary["frame_governor_distinct_states"]},indent=2))


if __name__ == "__main__":
    main()
