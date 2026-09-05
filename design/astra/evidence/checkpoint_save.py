"""Select the committed save/title audit without changing earlier receipts."""
from pathlib import Path
import hashlib
import json
import subprocess

BASE = Path(__file__).resolve().parents[1]
ROOT = BASE.parents[1]
HEAD = "9548301873807117a870aeb6e517173e81a4713f"


def read(name):
    return json.loads((BASE / name).read_text(encoding="utf-8"))


def write(name, value):
    (BASE / name).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8", newline="\n")


def digest(name):
    return hashlib.sha256((BASE / name).read_bytes()).hexdigest()


assert subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == HEAD
receipt_path = "evidence/save_commit_audits/receipt.json"
receipt = read(receipt_path)
assert receipt["repository_head"] == HEAD
run = next(r for r in receipt["runs"] if r["id"] == "orison_v2_completeness")
assert run["exit_code"] == 2
assert all(r["exit_code"] == 0 for r in receipt["runs"] if r["id"].endswith("_selftest"))
live = read("LIVE_STATE.json")
live["completeness_source"] = {
    "audit_id": run["id"], "path": "evidence/save_commit_audits/" + run["stdout"],
    "receipt_path": receipt_path, "receipt_sha256": digest(receipt_path),
    "repository_head": HEAD, "sha256": run["stdout_sha256"],
}
live["ledger_evidence_head"] = HEAD
live["latest_repair_commit"] = HEAD
live["latest_save_title_commit"] = HEAD
write("LIVE_STATE.json", live)

rows = read("reviews/production_obligations.json")
by_id = {row["id"]: row for row in rows}
clock = by_id["ASTRA-CLOCK"]
clock["composed_runtime_proof"] = (
    "Final title_save_recovery/runtime/matrix_calendar_final:30/30 exit0,92.851s; "
    "all four root directions preserve the exact epoch/start/elapsed clock and destination civil date. "
    "Actual Continue enters CampaignShell with a real player and matching clock/facts in both roots (5 checks each). "
    "Headless reconstruction/launch evidence, not walked input or full-game performance."
)
clock["next_decisive_action"] = (
    "Replace remaining host Unix world timestamps with explicit campaign provenance; retain legacy ambiguity. "
    "Then prove resident perception and schedule delivery in the composed world."
)
clock["open_defects"] = [x for x in clock["open_defects"]
                         if x != "Exact calendar across every composed reconstruction boundary pending"]
clock["open_defects"].append("Complete dramatic-boundary, human schedule and physical perception coverage remains open")
clock["provenance"]["reconstruction_commit"] = HEAD
clock["provenance"]["sources"] = list(dict.fromkeys(clock["provenance"]["sources"] + [
    "evidence/title_save_recovery/runtime/matrix_calendar_final/receipt.json",
    "evidence/title_save_recovery/runtime/actual_continue_v1_final/receipt.json",
    "evidence/title_save_recovery/runtime/actual_continue_v2_final/receipt.json",
]))

save = by_id["ASTRA-SAVE"]
save.update({
    "current_state": "Checked temp/backup/journal recovery, byte readback and UTF-8/envelope validation integrated. Ordinary title Continue preserves the saved campaign; explicit New archives prior bytes and launches only after verified persistence.",
    "production_consumer": "RealityState/RealitySaveStorage, production title and GameBoot, CampaignShell and reconstructed fact consumers.",
    "automated_proof": "Final storage195/195, compatibility14/14 and calendar52/52 exit0 clean. Original protection, malformed-entry, UTF-8, omitted-readback and future-fallback controls fail meaningfully; exact restores pass. Title123/123, existing title/audio and composed17/29 regressions pass.",
    "composed_runtime_proof": "Actual Continue enters CampaignShell with a real player and preserved saved facts/calendar under V1 and V2 (5/5 each). Four-direction exact calendar matrix30/30. Four interruption/recovery cases span ten real processes; killed writer exit81 is deliberate, new readers exit0. Ten final title states captured and reviewed; no human input/listening acceptance.",
    "implementation_strategy": "Retain one save owner and fixed sibling paths; complete domain validation and native durable replacement, then the full dramatic-boundary/packaging/human matrix.",
    "next_decisive_action": "Validate remaining domain scalar/ID/deeper payloads through their existing owners and prove the complete dramatic-boundary route; establish native replacement and two-machine packaging before release.",
    "open_defects": [
        "No native atomic replacement or checked OS power-loss durability; verified backup/journal supplies bounded crash recovery",
        "Single-process ownership only; no cross-process file lock",
        "Absent/version-0 documents retain default-based migration policy",
        "Domain scalar ranges, IDs, vocabulary, chronology and deeper nested payloads are not comprehensively checked before adoption",
        "Complete eleven-boundary and sequence-breaking reconstruction route remains unproven",
        "Human pointer/controller, listening, comprehension and two-machine install/recovery gates remain open",
    ],
    "status": "INTEGRATED",
})
save["performance"]["measured_result"] = (
    "Title handler process17.337s; actual V1/V2 Continue processes23.799s/3.369s with different content scopes; "
    "four-direction matrix92.851s; legacy composed saves1.699s/2.640s. These include fixture setup/teardown and are not boot or frame p95 measurements."
)
save["provenance"]["repair_commit"] = HEAD
save["provenance"]["sources"] = list(dict.fromkeys(save["provenance"]["sources"] + [
    "reviews/save_recovery_implementation_review.md",
    "reviews/title_save_recovery_visual_review.md",
    "evidence/save_recovery/complete_recovery_green/receipt.json",
    "evidence/save_recovery/process_restart_03/receipt.json",
    "evidence/title_save_recovery/runtime/handlers_final/receipt.json",
    "evidence/title_save_recovery/runtime/matrix_calendar_final/receipt.json",
    "evidence/title_save_recovery/runtime/title_capture_final/receipt.json",
]))
write("reviews/production_obligations.json", rows)

protected = []
for row in read("evidence/final_batch.json")["protected_paths"]:
    path = row["path"]
    blob = subprocess.check_output(["git", "rev-parse", HEAD + ":" + path], cwd=ROOT, text=True).strip()
    working = subprocess.check_output(["git", "hash-object", "--path=" + path, path],
                                      cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    assert blob == working == row["current_blob"], path
    protected.append({"path": path, "blob": blob})
proofs = [
    "evidence/save_recovery/complete_recovery_green/receipt.json",
    "evidence/save_recovery/process_restart_03/receipt.json",
    "evidence/title_save_recovery/runtime/handlers_final/receipt.json",
    "evidence/title_save_recovery/runtime/matrix_calendar_final/receipt.json",
    "evidence/title_save_recovery/runtime/title_capture_final/receipt.json",
    "evidence/title_save_recovery/runtime/existing_save_matrix_final/receipt.json",
    "evidence/title_save_recovery/runtime/m08f_reconstruction_final/receipt.json",
]
write("evidence/save_checkpoint.json", {
    "production_commit": HEAD, "branch": "codex/astra-canonical-20260904",
    "canonical_worktree": str(ROOT), "opening_date": "1928-11-10",
    "verified_remote_main": "c2dc01771bc25b07f5dcf7a6040102345b8c57d5",
    "remote_check": "git ls-remote origin refs/heads/main returned that exact hash with exit0 during this checkpoint",
    "production_selector": "v1", "protected_paths": protected,
    "evidence_receipts_sha256": {p: digest(p) for p in proofs},
    "audit_receipt": receipt_path, "audit_receipt_sha256": digest(receipt_path),
    "audit_exits": {r["id"]: r["exit_code"] for r in receipt["runs"]},
    "full_game_complete": False, "human_acceptance_granted": False,
    "push_release_or_cutover_performed": False,
    "next_production_milestone": "Validate the proven isolated layer-unpair workaround in actual V1 transitions, ownership and retirement, with measured cost; it remains unintegrated.",
})
print("Save/title checkpoint bound; 17 protected paths unchanged; all release limits remain explicit.")
