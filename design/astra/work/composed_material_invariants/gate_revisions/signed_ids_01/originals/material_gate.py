"""Additive gate; the existing Vulkan diagnostic contract is never weakened."""
import math
CASES = {"mina_caption_crisis", "peter_form_corridor", "juno_feedback_tetris",
         "mae_contradictory_antiques", "cal_memory_radio", "omar_unrepairable"}
STAGES = ["before_measured"] + [f"cycle_{i}" for i in range(6)] + ["before_retirement"]
FLOORS = {"F02", "F03", "F04", "F05", "F06"}


def safe_refresh_contract(refresh):
    precondition = refresh.get("precondition", {})
    values = precondition.get("effective_intensities", {})
    probes = precondition.get("probe_intensities", [])
    threshold = precondition.get("threshold")
    def low(value):
        return type(value) in (float, int) and math.isfinite(value) and 0 <= value < 0.3
    if precondition.get("passed") is not True or precondition.get("issues") != [] or threshold != 0.3 \
            or set(values) != CASES or not all(low(value) for value in values.values()) \
            or len(probes) != 6 or not all(low(value) for value in probes):
        return False
    environment = precondition.get("environment", {})
    if set(environment) != {"ENCROACH", "ENCROACH_FORCE"} or any(not isinstance(v, str) for v in environment.values()):
        return False
    before = refresh.get("before_beachheads", {})
    if not CASES.issubset(before) or before != refresh.get("during_beachheads") or before != refresh.get("after_beachheads"):
        return False
    for entry in before.values():
        if entry.get("present") is False:
            continue
        if entry.get("present") is not True or entry.get("live") is not True or entry.get("original_count") != 0 \
                or not isinstance(entry.get("node_id"), int) or not isinstance(entry.get("draws"), dict):
            return False
        for draw in entry["draws"].values():
            if not all(isinstance(draw.get(key), int) for key in ("draw_id", "mesh_id", "override_id")) \
                    or not isinstance(draw.get("active_material_ids"), list):
                return False
    return refresh.get("mutated") is True and refresh.get("force_restored") is True \
        and refresh.get("intensities_restored") is True and isinstance(refresh.get("before_forced"), dict) \
        and refresh["before_forced"] == refresh.get("after_forced") \
        and refresh.get("before_intensities") == values and refresh.get("after_intensities") == values


def classify_materials(probe, expected_owner_sha256):
    reasons = []
    if probe.get("material_contract") != "actual_build_ownership_v1":
        reasons.append("missing actual-build material contract")
    observations = probe.get("material_observations", [])
    retirement = probe.get("material_retirement", {})
    if probe.get("root") == "v2":
        if observations or retirement.get("applicable") is not False:
            reasons.append("V2 material applicability misrepresented")
        return {"material_gate_exit": int(bool(reasons)), "reasons": reasons, "applicable": False}
    if probe.get("root") != "v1":
        reasons.append("undeclared actual root")
    if [row.get("stage") for row in observations] != STAGES:
        reasons.append("material observation sequence missing, duplicated or reordered")
    for row in observations:
        stage = row.get("stage")
        if row.get("owner_source_sha256") != expected_owner_sha256:
            reasons.append(f"{stage}: owner source does not match bound candidate")
        if row.get("outside_measured_intervals") is not True or row.get("issues") != []:
            reasons.append(f"{stage}: material issues or timing scope failure")
        governor = row.get("surface_governor", {})
        if governor.get("props_tier_on") is not True or governor.get("queued_material_changes") != 0:
            reasons.append(f"{stage}: incomplete active prop-tier precondition")
        cases = row.get("cases", {})
        if set(cases) != CASES:
            reasons.append(f"{stage}: six actual build cases incomplete")
        current_ids = set()
        for case, data in cases.items():
            finishes, props = data.get("finishes", []), data.get("props", [])
            if not finishes or not props:
                reasons.append(f"{stage}/{case}: nonempty actual finish and prop populations required")
            for item in finishes + props:
                current_ids.add(item.get("material_id"))
                if not item.get("path") or not isinstance(item.get("material_id"), int) or item["material_id"] <= 0:
                    reasons.append(f"{stage}/{case}: missing real draw/material identity")
                if item.get("live") is not True or item.get("marker_ok") is not True:
                    reasons.append(f"{stage}/{case}: stale installed material or missing owner marker")
            if any(item.get("guard_ok") is not True for item in finishes):
                reasons.append(f"{stage}/{case}: actual build guard failure")
            if any(item.get("source_linked") is not True for item in props):
                reasons.append(f"{stage}/{case}: actual prop source link failure")
        registries = row.get("registries", {})
        if set(registries) != FLOORS:
            reasons.append(f"{stage}: actual floor registries incomplete")
        for floor, data in registries.items():
            ids, installed = data.get("material_ids", []), data.get("installed_ids", [])
            if not ids or len(ids) != len(set(ids)) or ids != installed or data.get("invalid") != 0 \
                    or data.get("slots") != len(ids) or data.get("unique") != len(ids):
                reasons.append(f"{stage}/{floor}: registry differs from unique active installed resources")
        excluded = row.get("excluded_draws", [])
        private = sum(item.get("boundary") == "private" for item in excluded)
        actors = sum(item.get("boundary") == "actor" for item in excluded)
        if private <= 0 or actors <= 0 or private != row.get("private_geometry") or actors != row.get("actor_geometry") \
                or any(item.get("contaminated") is not False for item in excluded):
            reasons.append(f"{stage}: missing or contaminated actual private/actor population")
        caches = row.get("cache_consumers", [])
        if not caches or any(item.get("live") is not True or item.get("budget_matches") is not True for item in caches):
            reasons.append(f"{stage}: active SurfacePass cache consumer/governor proof incomplete")
        should_refresh = stage in {"before_measured", "before_retirement"}
        if row.get("refresh_exercised") is not should_refresh:
            reasons.append(f"{stage}: wrong explicit refresh scope")
        if should_refresh:
            refresh = row.get("refresh", {})
            if not safe_refresh_contract(refresh):
                reasons.append(f"{stage}: unsafe, unrecorded or changed beachhead/force threshold boundary")
            if refresh.get("passed") is not True or refresh.get("facts_unchanged") is not True \
                    or refresh.get("same_frame_restored") is not True or not refresh.get("before_state") \
                    or refresh.get("before_state") != refresh.get("after_state") \
                    or refresh.get("tested_current_materials") != len(current_ids):
                reasons.append(f"{stage}: actual state/lifecycle/identity restoration incomplete")
    if retirement.get("applicable") is not True or retirement.get("released") is not True \
            or retirement.get("owned_case_materials_observed", 0) <= 0 or retirement.get("retained_material_ids") != []:
        reasons.append("actual unique case material retirement incomplete")
    return {"material_gate_exit": int(bool(reasons)), "reasons": reasons, "applicable": True,
            "scope": "real-build/installed-material observations outside measured intervals; existing native/capture gate remains required"}
