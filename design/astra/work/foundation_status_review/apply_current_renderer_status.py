"""Record reviewed renderer evidence without promoting acceptance tiers."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / "design/astra"
path = BASE / "reviews/production_obligations.json"
rows = json.loads(path.read_text(encoding="utf-8"))
row = next(r for r in rows if r["id"] == "ASTRA-PERF")
row["current_state"] = (
    "Full V1 foundation candidate passes 305/305, native/gate 0. A matched helper omission "
    "completes 296/296 with native exit 0 but diagnostic gate 1; exact restoration completes "
    "296/296 with gate 0. Street/Passage still stalls about 610 ms, and material registration "
    "arrays grow on repeated sweeps. Viewport omission and applicable V2 proof remain open.")
row["automated_proof"] = (
    "Full V1 candidate 305/305; scoped root-retirement omission/restoration both 296/296. "
    "Omission emits 1,174 stale-set errors and 2,316 shadow-count underflows at the declared "
    "native sites; restored source emits neither and both retire without retention diagnostics. "
    "Independent sequence recognizes only the declared expected red and stays diagnostic exit 1. "
    "Native-call count on unchanged masks and general live-state growth remain unproved.")
row["next_decisive_action"] = (
    "Attribute the transition stall by measured phase and prove duplicate material registration; "
    "repair the shared owner without suppressing late consumers or governor behavior. Finish "
    "viewport omission/restoration and applicable V2 proof, then obtain uninstrumented composed "
    "costs. Preserve Harukiya's unchanged historical gate.")
row["performance"]["measured_result"] = (
    "Full V1 candidate Street-to-Passage median 622.336 ms and reverse 615.593 ms (six each). "
    "Matched root-retirement omission/restoration Street-to-Passage 755.713/617.063 ms; reverse "
    "617.259/610.729 ms. Native logging confounds omission deltas. These synchronous transition "
    "measurements establish a current stall, not isolated helper overhead or shipping p95.")
row["open_defects"] = [
    "Street/Passage transitions still stall roughly 610 ms; phase attribution and final uninstrumented correction are pending",
    "Encroachment material arrays grow on repeated sweeps; source shows duplicate registration, unique-resource census pending",
    "Current source is uncommitted; independent viewport omission and applicable V2 composition are pending",
    "No-op native-call count remains explicitly unproved",
    "Harukiya >250 remains red despite 247/247 measured indexing and 36 source-eligible groups; historical 264 discrepancy unresolved",
    "Full-game steady frame pacing and target-machine performance remain unproved",
    "Inherited loader diagnostics, RGB8 conversions and found-art placement warnings remain; no human visual/listening acceptance",
]
for source in [
    "evidence/vulkan_composed/pair_bookkeeping_sequences/foundations_pair_01/receipt.json",
    "reviews/vulkan_composed_foundations_candidate_review.md",
    "work/visibility_transition_profile/README.md",
]:
    if source not in row["provenance"]["sources"]:
        row["provenance"]["sources"].append(source)
path.write_text(json.dumps(rows, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

addition = """

- V1-PAIR-CONTROL-CURRENT: the matched `foundations_pair_01` omission completes 296 checks and actual root retirement with native exit 0, but diagnostic exit 1: 1,174 stale-set errors and 2,316 underflows at the declared engine sites. Exact-restored candidate completes the same 296 checks with native/gate 0 and no pairing or retention diagnostics. The aggregate recognizes the scoped negative control and remains diagnostic red; the separate private-world helper case is explicitly excluded from this scope.
- TRANSITION-STALL-CURRENT: Street/Passage still takes roughly 610 ms synchronously with or without the workaround. Native error logging prevents interpreting the control delta as isolated helper overhead. Phase instrumentation is prepared; no shipping optimization or frame-budget acceptance has been claimed.
- MATERIAL-REGISTRATION-GROWTH: preserved candidate stdout reports F02 material slots growing 78 → 568 → 686 → … → 2,456 and F04 83 → 413 → 539 → … → 2,433. Source inspection finds `_bind_storey` appends after `_bind_living` already deduplicates/registers. This is an unresolved repeated-sweep defect; exact unique-material census and correction remain pending. Zero teardown retention diagnostics do not prove zero live-state growth.
- ROOT-ARCADE-VIEW: root independently viewed the exact `actual_arcade_before_passage.png` and `actual_arcade_after_passage.png` captures from `candidate_v1_foundations_01`. The same Operations room, crates, clipboard and text remain rendered; the Insert Coin text changes brightness between animation frames. This verifies visible content continuity only, not final art, physical usability or human acceptance.
"""
p = BASE / "PLAYTEST_FINDINGS.md"
text = p.read_text(encoding="utf-8")
assert "V1-PAIR-CONTROL-CURRENT" not in text
p.write_text(text + addition, encoding="utf-8")
p = BASE / "DECISION_LOG.md"
with p.open("a", encoding="utf-8") as stream:
    stream.write("\n- ASTRA-D027: retain the successfully completed matched renderer negative as diagnostic red, with exact restoration and declared native source sites. The roughly 610 ms transition stall and repeated material-registration growth are separate open defects; functional and teardown success cannot close them. Measure phase cost before changing the shared material owner, preserve late consumers, and rerun without instrumentation before any performance claim.\n")
p = BASE / "RISK_REGISTER.md"
with p.open("a", encoding="utf-8") as stream:
    stream.write("\nCurrent measured additions: Street/Passage transitions stall roughly 610 ms; ApartmentEncroachment's material arrays grow on repeated sweeps. Both are release-critical. The completed renderer omission/restoration isolates native bookkeeping but does not establish acceptable transition cost or zero live-state growth.\n")
