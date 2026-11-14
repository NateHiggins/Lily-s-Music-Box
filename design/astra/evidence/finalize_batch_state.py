"""Bind this batch's ledger to retained evidence; never rescan frozen Git truth."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]
PACKET = ROOT / "design/astra"
def read(name):
    return json.loads((PACKET / name).read_text())
def write(name, data):
    (PACKET / name).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
def sha(name):
    return hashlib.sha256((PACKET / name).read_bytes()).hexdigest()

head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
receipt_path = "evidence/final_repair_audits/receipt.json"
source_path = "evidence/final_repair_audits/orison_v2_completeness.stdout.txt"
assert read(receipt_path)["repository_head"] == head
state = read("LIVE_STATE.json")
state["ledger_evidence_head"] = head
state["completeness_source"].update(path=source_path, sha256=sha(source_path),
    receipt_path=receipt_path, receipt_sha256=sha(receipt_path), repository_head=head)
state["latest_accepted_landing"]["runtime_revalidation"] = "SCOPED_TESTS_PASS_AFTER_REPAIRS; no new human acceptance"
state["latest_repair_commit"] = head
write("LIVE_STATE.json", state)

rows = read("reviews/production_obligations.json")
by_id = {r["id"]: r for r in rows}
r = by_id["ASTRA-INTEGRATE-M11B"]
r.update(current_state="Accepted boundary integrated; M11B75/M11A40, repaired M08F29 and actual fresh-profile matrix24 pass within their scoped contracts.",
    composed_runtime_proof="evidence/m11b_runtime/receipt.json; evidence/audio_repair_runtime/final_review.json; evidence/audio_ownership/receipt.json. These prove scoped runtime behavior, not exterior selector integration or whole-world visual acceptance.",
    next_decisive_action="Reconstruct the quarantined F01 proposal from traceable dependencies in a clean implementation; preserve accepted review scope and v1 default.")
r["automated_proof"].update(runtime_revalidation="SCOPED_PASS_WITH_REPAIRS", latest_static_receipt=receipt_path)
r["open_defects"] = ["Standalone exterior remains outside the production selector", "No full-world or new human visual acceptance", "Five existing v1 cam_noel_witches placement warnings remain"]

r = by_id["ASTRA-BASE-M08F-FRESH-PROFILE"]
r.update(status="RUNTIME_PROVEN", current_state="M08F, M11A and genuine two-root harnesses now create checked save parents; each passed in independently fresh profiles after preserved failures.",
    next_decisive_action="Maintain independent-profile runs; address production save/title recovery separately under ASTRA-SAVE.")
r["automated_proof"]["matrix_receipt"] = "evidence/audio_repair_runtime/matrix_directory_green/verbose_launch/receipt.json"
r["open_defects"] = ["This repairs harness setup; it does not implement atomic production saves or safe title-screen continuation"]

r = by_id["ASTRA-BASE-M08F-RETENTION"]
r.update(status="RUNTIME_PROVEN", authoritative_owner="NightRegisterProp / AudioPolicy source-owned slots",
    experiential_outcome="Retired register sounds release their streams and decoders without silencing another live source",
    current_state="NightRegister paper cue identified and repaired; pending playback and off-tree callbacks covered; final M08F29, owner20, NightRegister148 and matrix24 have no audio retention diagnostics.",
    production_consumer="NightRegisterProp in composed roots and AudioPolicy.release_source",
    automated_proof={"receipt":"evidence/audio_ownership/receipt.json", "receipt_sha256":sha("evidence/audio_ownership/receipt.json"), "same_fixture_controls":"missing owner1 / missing pending-slot release1 / complete0", "late_callback":"red19/20 exit1 / green20/20 exit0"},
    composed_runtime_proof="Final M08F verbose exit0 and genuine fresh-profile matrix24 exit0; independent source-ownership controls retain live-neighbor playback. No sound is skipped or globally muted.",
    next_decisive_action="Perform composed listening and continue broader ownership/performance coverage without generalizing this bounded repair.")
r["open_defects"] = ["No new listening acceptance or whole-game lifetime certification", "Other historical audio paths require their own ownership evidence"]
r["provenance"]["repair_commit"] = "ac40f163fc0be18bfd8cb5bb2ede2a6c4f5f3f54"

r = by_id["ASTRA-M08F-EVIDENCE-INTEGRITY"]
r.update(status="INTEGRATED", current_state="Capture is explicitly inspection-only; 105 selftests and 23 CLI controls reject unsupported/stale runtime receipts; seven prior runtime claims are demoted.",
    automated_proof={"receipt":"evidence/capture_contract_source_binding/validation.json", "receipt_sha256":sha("evidence/capture_contract_source_binding/validation.json"), "windowed_receipt":"evidence/capture_contract_runtime/receipt.json"},
    composed_runtime_proof="Twelve windowed composition images captured after correcting a typed-path parse error. They prove inspection capture only; loader/RGB8 diagnostics and visual debt are retained.",
    next_decisive_action="Generate actual executed runtime-contract receipts for the seven open requirements, with source digests and measured ownership; improve failed inspection framing.")
r["open_defects"] = ["Seven runtime claims still need admissible execution receipts", "Five inspection frames need replacement framing; none is FINAL", "Windowed loader and RGB8 diagnostics remain"]
r["provenance"]["repair_commit"] = "fc359a687e069d0b2e2baa70d71c352da26fd87e"

r = by_id["ASTRA-ART"]
r["current_state"] = "Current twelve-frame production composition inspection: FINAL0, REFINE5, SALVAGEABLE2, REPLACE5; dark blockout and apparatus readability remain substantial debt."
if "reviews/m08f_composition_visual_review.md" not in r["provenance"]["sources"]:
    r["provenance"]["sources"].append("reviews/m08f_composition_visual_review.md")
r = by_id["ASTRA-AUDIO"]
r["automated_proof"] = "evidence/audio_red_green.json: 25 audit red/green pairs; evidence/audio_ownership/receipt.json: bounded NightRegister lifetime repair. Neither proves listening or complete acoustic coverage."
r = by_id["ASTRA-INPUT"]
r["automated_proof"] = "evidence/prompt_repair/receipt.json: three semantic prompt repairs, 28 selftests, baseline unchanged. Actual independent input routes remain unproven."
write("reviews/production_obligations.json", rows)
