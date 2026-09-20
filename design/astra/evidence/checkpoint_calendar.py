"""Bind the selected immutable calendar audit and scoped runtime receipts."""
from pathlib import Path
import hashlib
import json

BASE = Path(__file__).resolve().parents[1]


def read(name):
    return json.loads((BASE / name).read_text(encoding="utf-8"))


def write(name, value):
    (BASE / name).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8", newline="\n")


receipt_path = "evidence/calendar_commit_audits/receipt.json"
receipt = read(receipt_path)
head = "dd434b15ba6b13cb3951e6ef7e867f9054da2cff"
assert receipt["repository_head"] == head
selected = next(r for r in receipt["runs"] if r["id"] == "orison_v2_completeness")
assert selected["exit_code"] == 2
live = read("LIVE_STATE.json")
live["completeness_source"] = {
    "audit_id": selected["id"],
    "path": "evidence/calendar_commit_audits/" + selected["stdout"],
    "receipt_path": receipt_path,
    "receipt_sha256": hashlib.sha256((BASE / receipt_path).read_bytes()).hexdigest(),
    "repository_head": head,
    "sha256": selected["stdout_sha256"],
}
live["ledger_evidence_head"] = head
live["latest_repair_commit"] = head
live["latest_calendar_commit"] = head
write("LIVE_STATE.json", live)

rows = read("reviews/production_obligations.json")
by_id = {row["id"]: row for row in rows}
clock = by_id["ASTRA-CLOCK"]
clock.update({
    "current_state": "Authored Saturday November 10, 1928; one local hour/minute sample, persisted Gregorian simulation clock, both root providers and visible civil-time readers integrated.",
    "production_consumer": "CampaignTime, both building roots, ScheduleDirector, DayNightDirector, clock props, PhoneOS, songbook, Open Shift durations and observations.",
    "automated_proof": "Calendar 52/52 exit0 (0.881s), protected-bind old source 51/52 exit1, midnight omission 49/50 exit1. World-time focused27/27; original duration and sight-presence controls fail. Raw exact-source receipts retained.",
    "composed_runtime_proof": "V1/V2 reconstruction26/26, all four directions exit0 (92.763s); initial provider coherence and sole advance owner. Exact epoch preservation at each direction remains a pending30-check patch. Actual V1 notice captures show campaign-time copy through the player interaction ray, not walked input.",
    "next_decisive_action": "Finish protected save recovery and ordinary Continue; prove exact calendar through all root directions; replace remaining host Unix world timestamps with explicit campaign provenance.",
    "open_defects": [
        "WorkOrders, inventory, incident and NightRegister timestamp fields still use host Unix time",
        "Fixed EST only; authored daylight-offset transitions absent",
        "Legacy ambiguous duration facts require authored recoverability; an old porter intent may hold indefinitely",
        "Absent-resident sight is gated; audible-event observation still ignores presence",
        "Exact calendar across every composed reconstruction boundary pending",
        "No human schedule/calendar perceptual acceptance or complete game performance proof"
    ],
    "status": "INTEGRATED",
})
clock["provenance"]["repair_commit"] = head
clock["provenance"]["sources"] = list(dict.fromkeys(clock["provenance"]["sources"] + [
    "reviews/campaign_calendar_integration.md", "reviews/world_time_coherence.md",
    "evidence/historical_radio_notice/protected_bind_green/run_receipt.json",
    "evidence/world_time_coherence/receipt.json",
]))
clock["performance"]["measured_result"] = "Focused process0.881s; composed matrix92.763s. These are fixture durations, not p95 frame/boot measurements."

history = by_id["ASTRA-HISTORICAL-TIMELINE"]
history.update({
    "current_state": "Owner-selected November 10, 1928; sourced November11 03:00EST frequency reallocation has a physical V1 lobby hand-copy and campaign-time inspection text.",
    "production_consumer": "V1 LobbyBulletinBoard named wireless-notice control and service-wire inspection copy via actual PlayerController interaction ray.",
    "implementation_strategy": "Extend sourced historical records through real physical delivery and perception owners; preserve explicit instants and distinguish station frequencies from programme schedules.",
    "automated_proof": "Notice17/17 exit0, including invalid time and neighbor audio ownership; exact owner-teardown omission16/17 exit1. See immutable notice aggregate and final source bindings.",
    "composed_runtime_proof": "Three final actual V1 lobby images reviewed; physical paper and both service-wire phases readable after copy repair. Camera teleported, Dummy audio. Not walked-input, listening, resident learning, V2 or human acceptance.",
    "next_decisive_action": "Provide the notice in the authored V2 world and prove one resident learns a sourced event through actual embodied reading or audible radio perception.",
    "open_defects": [
        "V2 physical notice consumer absent",
        "Resident observation/learning delivery absent",
        "Authentic radio programming and audible broadcast delivery absent",
        "Human historical and perceptual acceptance pending",
        "V1 Forward+ capture has unresolved shadow-count/light-unpair teardown BUG diagnostics"
    ],
    "status": "INTEGRATED",
})
history["provenance"].update({
    "authority": "Latest explicit owner reply: nov 10 is perfect. The date is selected, superseding the earlier proposal.",
    "repair_commit": head,
    "research_sha256": hashlib.sha256((BASE / "reviews/campaign_date_research.md").read_bytes()).hexdigest(),
})
history["provenance"]["sources"] = list(dict.fromkeys(history["provenance"]["sources"] + [
    "reviews/historical_notice_review.md", "reviews/campaign_calendar_integration.md",
    "evidence/historical_radio_notice/runtime_visual_validation.json",
    "evidence/historical_radio_notice/canonical_runtime_bindings.json",
]))
write("reviews/production_obligations.json", rows)
print("Bound calendar commit and scoped outcomes; release and human gates remain open.")
