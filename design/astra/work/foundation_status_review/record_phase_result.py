"""Publish measured phase/identity findings without changing evidence tiers."""
from pathlib import Path
import json

BASE = Path(__file__).resolve().parents[2]
path = BASE / "reviews/production_obligations.json"
rows = json.loads(path.read_text(encoding="utf-8"))
row = next(r for r in rows if r["id"] == "ASTRA-PERF")
row["current_state"] = (
    "Full V1 foundation candidate passes 305/305; the matched helper omission reproduces native "
    "pairing errors and exact restoration clears them. A separately instrumented 296-check run "
    "attributes about 523 ms of the 619 ms Street/Passage transition to encroachment rebinding. "
    "Repeated sweeps add duplicate material references with unchanged exact unique-ID sets. "
    "Shared-owner repair, viewport omission and applicable V2 proof remain open.")
row["open_defects"][0] = (
    "Street/Passage still stalls roughly 610 ms; a phase probe attributes about 523 ms to "
    "encroachment callbacks. Internal attribution and final uninstrumented correction are pending")
row["open_defects"][1] = (
    "Encroachment material lists add duplicate references: F02-F06 exact unique-ID sets remain "
    "fixed across 43 observations while slot counts grow. Registry and material identity repair pending")
row["performance"]["measured_result"] += (
    " Diagnostic phase probe: Street-to-Passage 618.869 ms total, encroachment callback 523.691 ms, "
    "surface plus callbacks 549.169 ms, late index 22.967 ms, Street index 29.589 ms. The callback "
    "timing includes nested work; it does not isolate duplicate-registration cost. Per-mask "
    "instrumentation adds overhead and supplies no shipping helper-overhead claim.")
for source in [
    "evidence/vulkan_composed/renderer_foundations_checkpoint.json",
    "evidence/vulkan_composed/visibility_phase_census_summary.json",
    "evidence/vulkan_composed/visibility_phase_census_material_identity.json",
    "reviews/visibility_transition_profile_review.md",
]:
    if source not in row["provenance"]["sources"]:
        row["provenance"]["sources"].append(source)
path.write_text(json.dumps(rows, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
p = BASE / "PLAYTEST_FINDINGS.md"
text = p.read_text(encoding="utf-8")
assert "ENCROACHMENT-PHASE-PROVEN" not in text
p.write_text(text + "\n- ENCROACHMENT-PHASE-PROVEN: the separate diagnostic candidate completes 296 checks, native/gate 0, clean retirement and exact two-file restoration. Its Street-to-Passage median is 618.869 ms, including 523.691 ms in the encroachment callback. The exact unique material-ID sets on F02-F06 stay fixed through all 43 census observations while duplicate slots accumulate (invalid slots remain zero). This proves duplicate registration and the broad expensive phase, not that deduplication alone removes the pause. See the source-bound phase and identity reviews.\n", encoding="utf-8")
