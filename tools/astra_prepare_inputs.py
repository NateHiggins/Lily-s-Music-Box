#!/usr/bin/env python3
"""Assemble reviewed decisions and explicit owner-mandated outcome obligations."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
P = ROOT / "design/astra"
R = P / "reviews"
BASE = "c2dc01771bc25b07f5dcf7a6040102345b8c57d5"


def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")


def main():
    rulings = {}
    for name in ["m11_review", "dream_review"]:
        d = json.loads((R / (name + ".json")).read_text(encoding="utf-8-sig"))
        for c in d["commits"]:
            if c["classification"] == "CANONICAL_ALREADY_IN_MAIN":
                continue
            rulings[c["commit"]] = {
                "classification": c["classification"], "reason": c.get("reason", c.get("rationale")),
                "acceptance_receipt": c.get("human_acceptance", c.get("acceptance_evidence")),
                "production_consumer": c.get("current_consumer", c.get("production_consumer")),
                "evidence_scope": c.get("evidence_scope", c.get("composition_scope")),
                "dependencies": c.get("dependencies", c.get("parents", [])),
                "debt": c.get("visual_performance_debt", []), "review_source": "reviews/" + name + ".json"}
    write(R / "adoption_rulings.json", rulings)
    # The live ledger input becomes authored data after its first creation.
    # Rebuilding Git decision views must never reset subsequent production work.
    existing_obligations = R / "production_obligations.json"
    if existing_obligations.exists():
        rows = json.loads(existing_obligations.read_text(encoding="utf-8"))
        if not isinstance(rows, list) or not rows:
            raise ValueError("Live production obligations must be a nonempty list.")
        print(f"Prepared {len(rulings)} rulings; preserved {len(rows)} live outcome obligations.")
        return
    # These are explicit production outcomes from the owner mandate. They are
    # not claims that the named owners/consumers are already finished.
    items = [
        ("SANITIZE-0", "repository", "Trust one canonical line and preserve recoverable work", "Packet assembled; validation pending", "BLOCKER", "release", "PROGRAMMED", "Git / scoped receipts", "Canonical branch", "Validate deterministic packet with red fixtures; commit named paths."),
        ("INTEGRATE-M11B", "world substrate", "Keep accepted exterior/opening work on one verified development line", "12 dependency commits outside main", "BLOCKER", "early complete path", "QUARANTINED", "Bodega source / OrisonV2Blockout", "Standalone OrisonV2ExteriorCell / F02-F04 reviews", "Integrate only through a9e455b after sanitation and replay required tests."),
        ("F01-CUT", "world substrate", "Traverse streamed F01 without lost fixture identity", "C1 rehearsal; C2 dirty consumer", "BLOCKER", "early complete path", "QUARANTINED", "Owner registry / geometry provider", "BuildingRoot monolith", "Close clean lineage and reversible provider parity, full routes/save and two-cycle teardown."),
        ("CLOCK", "simulation time", "Start at local time of day on an independent campaign date", "CampaignClock imports host date", "RELEASE_CRITICAL", "early complete path", "INTEGRATED", "CampaignClock", "ScheduleDirector / ResidentRoutines / celestial time", "Prove host-date independence and correct elapsed-clock consumers with deterministic reload."),
        ("SAVE", "persistence", "Resume every dramatic boundary without loss or duplication", "Version4 direct write lacks atomic readback", "BLOCKER", "release", "INTEGRATED", "RealityState", "CampaignShell / fact consumers", "Red corruption/interruption paths; validated atomic write/readback/schema migration."),
        ("OPENSHIFT", "causal world", "Work, ignore, abandon and meddle create continuing actor behavior", "Corrected owners in main; default v1 presence assumes home", "RELEASE_CRITICAL", "early complete path", "INTEGRATED", "OpenShiftSituation / NpcObservationLedger", "Both roots / WorkOrders", "Bind real presence; play four dispositions through reconstruction."),
        ("AGENT-MINA", "embodied cast", "Mina hears hammer, seeks player, interrupts and resumes with memory", "Shared bounded perception/planner/executor incomplete", "RELEASE_CRITICAL", "early complete path", "PROGRAMMED", "NpcObservationLedger / ResidentRoutines / ResidentNav", "AnimatedResident / NPCPlaceholder", "Build shared perception and action execution; observe a complete day in life."),
        ("AGENT-AMBIENT", "embodied cast", "A resident without a case lives an ordinary persistent day", "Profiles/routes lack complete day-in-life proof", "RELEASE_CRITICAL", "full world", "PROGRAMMED", "Shared agent stack", "ResidentRoutines / AnimatedResident", "Prove second character from data with venue, social encounter, props, disturbance and reload."),
        ("MINA", "campaign", "Optional Mina shift reaches dream, wake and continuing residue", "Strongest authored case; composed release quality pending", "BLOCKER", "early complete path", "PROGRAMMED", "RealityCaseManager / WorkOrders / DreamDirector", "Mina situation / CampaignShell", "Play both starts, tactile repair, procurement, earned conversation, dream, wake and four dispositions."),
        ("CASE-DATA", "narrative authority", "Ambient neighbors do not acquire counterfeit canonical cases", "18 case-like records, only Mina enabled", "RELEASE_CRITICAL", "full campaign", "PROGRAMMED", "Bible / case authority", "reality_cases.json / RealityCaseManager", "Classify six canonical cases, ambient incidents, sanctioned expansion and retired prototypes."),
        ("DREAM-LAMP", "supernatural ecology", "Actual lamp exposure reveals intact anatomy in a furnished Orison room", "Isolated acceptance; absent critter binding; failed C1 gates", "RELEASE_CRITICAL", "full campaign", "QUARANTINED", "DreamExposureField / ecology / lamp state", "ApartmentEncroachment / cellular materials", "Close source dependencies; prove lamp-write/material-read, save ownership and perception."),
        ("ECOLOGY", "supernatural ecology", "A colony explores information-rich props and retreats leaving cleanable stain", "Lifecycle parts exist; bounded sensing/decisions incomplete", "RELEASE_CRITICAL", "full world", "PROGRAMMED", "Ecology sensory/state owners", "LivingField / fauna presenters", "Prove stimulus-response decisions and physical retreat/stain before scaling organisms."),
        ("ART", "environment art", "Every playable view reads as one occupied 1928 building", "Prototype art; full eye-height verdict census absent", "RELEASE_CRITICAL", "full world", "PROGRAMMED", "V2 authored geometry/material sources", "Playable V2 cells under actual light", "Audit FINAL/SALVAGEABLE/REFINE/REPLACE/MISSING; finish substrate then hero views."),
        ("INTERACTION", "interaction", "Tools answer contact, resistance, sound and interruption on both inputs", "85 implementors;2 forbidden prompts;185 legacy carriers", "RELEASE_CRITICAL", "early complete path", "INTEGRATED", "PlayerController / prop authorities", "clock_prop / physical affordances", "Remove live carrier violations with red proof; shared player/NPC stance/contact semantics."),
        ("AUDIO", "audio", "Players and residents locate meaningful sources through shared acoustic truth", "Static gate green; cue coverage is narrower than all sound", "RELEASE_CRITICAL", "full world", "PROGRAMMED", "AcousticGraphData / AudioPolicy", "Emitters / hearing / captions", "Prove audit can fail; derive V2 graph; headphones and speakers listening tests."),
        ("DATA", "authored data", "Authored fields drive perceptible behavior or honest deferred status", "1304 findings including build-time false positives", "MAJOR", "full world", "PROGRAMMED", "Domain data owners", "Build generators / runtime readers", "Classify real consumers; never blanket-baseline or delete authored data."),
        ("PERF", "performance", "The complete game holds frame pacing through seamless boundaries", "Partial-root historical timings incomparable", "BLOCKER", "release", "PROGRAMMED", "Residency / domain simulation budgets", "Composed CPU/GPU/physics/audio/agents", "Profile content-equivalent roots and two cycles; full target-machine p95 and leak proof."),
        ("INPUT", "input/accessibility", "Controller and keyboard/mouse independently finish waking and dream routes", "Human controller-only route pending", "RELEASE_CRITICAL", "release", "PROGRAMMED", "PlayerController / focus/cancel owners", "Panels / menus / dream controls", "Human route with keyboard/mouse physically unavailable; remap/focus/cancel validation."),
        ("ACCESS", "input/accessibility", "Motion, flash, sound and text accommodations match their labels", "Coverage and public labels unverified", "RELEASE_CRITICAL", "release", "PROGRAMMED", "Settings / captions / camera", "Weather/dream effects and UI", "Validate every public claim; lived-experience review for narcolepsy remains a release gate."),
        ("NETWORK", "privacy/offline", "Weather and optional generation fall back into a complete local experience", "Full network failure/consent paths unproven", "RELEASE_CRITICAL", "release", "PROGRAMMED", "LiveWeatherService / dialogue broker", "Authored Queens weather / local dialogue", "Test opt-in, timeout, malformed output, disconnect and reload without progression dependency."),
        ("EXPORT", "release", "Clean install boots, saves, recovers and exits without project errors", "Base import exit0 has Unicode diagnostics", "BLOCKER", "release", "PROGRAMMED", "Desktop export / save / license owners", "Packaged title and campaign", "Attribute errors, package/install/crash/corruption/rollback, then two representative machines."),
        ("CUTOVER", "release", "V2 becomes production through an accepted reversible selector change", "DEFAULT_ID=v1; whole-building blockers open", "BLOCKER", "release", "ABSENT", "BuildingRootSelector / owner", "Title / CampaignShell", "Clean full cutover matrix, then present exact one-line flip for separate authorization."),
        ("REVIEW", "release", "Fresh players inhabit, infer, choose and recover without developer knowledge", "Reviewer and ethical/accessibility playthrough pending", "BLOCKER", "release", "ABSENT", "Owner / fresh players / reviewers", "Complete installed game", "Prepare concrete composed candidate for perceptual, ethical and release review."),
        ("V1-RETIRE", "retirement", "Retire v1 after accepted V2 and proven rollback window", "v1 is required reference/current default", "BLOCKER", "release", "ABSENT", "Owner retirement ruling", "Selector / packaged resources", "Keep v1 until explicit retirement authorization and completed rollback window.")]
    for name, predecessor in [("Peter", "Mina"), ("Juno", "Peter"), ("Cal", "Juno"), ("Omar", "Cal"), ("Mae", "Omar")]:
        items.append((name.upper(), "campaign", f"{name} has a distinct complete situation and dream", "Canonical authored case; release proof pending", "RELEASE_CRITICAL", "full campaign", "PROGRAMMED", "RealityCaseManager / shared agent stack", name + " situation / CampaignShell", f"Complete after {predecessor}; prove reuse, open-shift dispositions, sequence breaking and residue."))
    rows = []
    for short, sub, outcome, current, severity, scope, status, owner, consumer, action in items:
        id = "ASTRA-" + short
        rows.append({"id": id, "subsystem": sub, "experiential_outcome": outcome, "current_state": current,
                     "desired_final_state": "RELEASE_PROVEN for this outcome and all applicable definition-of-done dimensions.",
                     "authoritative_owner": owner, "production_consumer": consumer,
                     "dependencies": [] if short == "SANITIZE-0" else ["ASTRA-SANITIZE-0"],
                     "severity": severity, "scope": scope,
                     "provenance": {"base_commit": BASE, "branch": "codex/astra-canonical-20260904", "sources": ["OWNER_MANDATE.md", "AUTHORITY_HIERARCHY.md", "DEBT_DEDUPLICATION.md"]},
                     "implementation_strategy": action, "automated_proof": "See exact base_audits exits; new outcome proof pending.",
                     "composed_runtime_proof": "No new proof grants release status. See scoped source review and current runtime receipts.",
                     "human_proof_required": "Composed perceptual review; ethics/accessibility when applicable. No automatic acceptance.",
                     "performance": {"budget": "Provisional p95 total<16.6ms,main<=8ms,physics<=2ms,GPU<14ms;boot<18s;zero second-cycle growth.", "measured_result": None},
                     "persistence_reconstruction": "Facts and semantic IDs survive save/destroy/reconstruct, interruption and tier transitions.",
                     "status": status, "open_defects": [current], "next_decisive_action": action})
    write(R / "production_obligations.json", rows)
    print(f"Prepared {len(rulings)} reviewed rulings and {len(rows)} explicit production outcomes.")


if __name__ == "__main__":
    main()
