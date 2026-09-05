#!/usr/bin/env python3
"""Frozen Git views plus an explicitly sourced live ledger; no Git/game writes."""
from __future__ import annotations
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "design/astra"
CATEGORIES = {"CANONICAL_ALREADY_IN_MAIN", "ACCEPTED_CANDIDATE", "TECHNICALLY_PROVEN_BUT_HUMAN_PENDING",
              "FAILED_GATE", "SUPERSEDED", "EVIDENCE_ONLY", "QUARANTINED_DIRTY", "DUPLICATE", "UNKNOWN_REQUIRES_REVIEW"}


def read(path):
    return json.loads((OUT / path).read_text(encoding="utf-8-sig"))


def write(name, content):
    (OUT / name).write_text(content, encoding="utf-8", newline="\n")


def dump(name, content):
    write(name, json.dumps(content, indent=2, sort_keys=True, ensure_ascii=False) + "\n")


def esc(value):
    return str(value).replace("|", "\\|").replace("\n", " ")


def evidence_path(name):
    """Live inputs must name an existing artifact inside the packet."""
    if not isinstance(name, str) or not name or "\\" in name:
        raise ValueError("Live evidence path must be a packet-relative POSIX path")
    relative = Path(name)
    if relative.is_absolute() or ":" in name or ".." in relative.parts:
        raise ValueError(f"Unsafe live evidence path: {name}")
    resolved = (OUT / relative).resolve()
    if not resolved.is_relative_to(OUT.resolve()):
        raise ValueError(f"Live evidence escapes packet: {name}")
    return resolved


def live_completeness(base):
    """Authenticate explicit audit inputs without scanning moving Git state.

    A nonzero audit is valid evidence and is retained as such. A fresh static
    inventory never becomes a fresh runtime or human acceptance claim.
    """
    state = read("LIVE_STATE.json")
    if state.get("schema_version") != 1 or state.get("frozen_sanitation_base") != base:
        raise ValueError("LIVE_STATE schema/base does not match frozen sanitation")
    head = state.get("ledger_evidence_head", "")
    if not isinstance(head, str) or not re.fullmatch(r"[0-9a-f]{40}", head):
        raise ValueError("LIVE_STATE requires an exact ledger evidence head")
    binding = state["completeness_source"]
    source_path = evidence_path(binding["path"])
    receipt_path = evidence_path(binding["receipt_path"])
    source_bytes, receipt_bytes = source_path.read_bytes(), receipt_path.read_bytes()
    source_sha = hashlib.sha256(source_bytes).hexdigest()
    receipt_sha = hashlib.sha256(receipt_bytes).hexdigest()
    if source_sha != binding.get("sha256") or receipt_sha != binding.get("receipt_sha256"):
        raise ValueError("Live completeness source/receipt hash mismatch")
    receipt = json.loads(receipt_bytes.decode("utf-8-sig"))
    if receipt.get("repository_head") != head or binding.get("repository_head") != head:
        raise ValueError("Stale live completeness receipt: evidence heads disagree")
    if binding.get("audit_id") != "orison_v2_completeness":
        raise ValueError("Live source must be the completeness audit")
    runs = [r for r in receipt["runs"] if r.get("id") == binding["audit_id"]]
    selftests = [r for r in receipt["runs"] if r.get("id") == binding["audit_id"] + "_selftest"]
    if len(runs) != 1 or len(selftests) != 1:
        raise ValueError("Live receipt needs one completeness run and one fixture run")
    run, selftest = runs[0], selftests[0]
    if (receipt_path.parent / run["stdout"]).resolve() != source_path or run.get("stdout_sha256") != source_sha:
        raise ValueError("Live source does not match receipt output identity")
    if type(run.get("exit_code")) is not int or type(selftest.get("exit_code")) is not int:
        raise ValueError("Live receipt must retain actual integer exits")
    source = json.loads(source_bytes.decode("utf-8-sig"))
    requirements = source.get("requirements")
    if not isinstance(requirements, list) or not requirements:
        raise ValueError("Live completeness has no requirements")
    ids = [r["id"] for r in requirements]
    if len(ids) != len(set(ids)) or source.get("summary", {}).get("requirements") != len(ids):
        raise ValueError("Live completeness requirement identities/count do not close")
    provenance = {
        "kind": "STATIC_AUDIT", "path": binding["path"], "sha256": source_sha,
        "receipt_path": binding["receipt_path"], "receipt_sha256": receipt_sha,
        "repository_head": head, "audit_id": binding["audit_id"],
        "exit_code": run["exit_code"], "selftest_exit_code": selftest["exit_code"],
        "runtime_proof_created": False, "human_acceptance_created": False,
    }
    return state, source, provenance


def render():
    snap = read("evidence/repository_snapshot.json")
    rules = read("reviews/adoption_rulings.json")
    patches = read("evidence/patch_equivalence.json")
    duplicates = {line.split()[1] for result in patches for line in result["stdout"].splitlines() if line.startswith("- ")}
    base = snap["base_commit"]
    # Validate live inputs before touching even the unchanged frozen views.
    live, source, audit_proof = live_completeness(base)
    rows = []
    for commit in snap["commits_outside_base"]:
        sha = commit["commit"]
        override = rules.get(sha, {})
        category = "DUPLICATE" if sha in duplicates else "UNKNOWN_REQUIRES_REVIEW"
        reason = "git cherry marks the patch equivalent to canonical ancestry." if sha in duplicates else "No traceable adoption ruling reconstructed; retain without merging."
        paths = commit["changed_paths"]
        if paths and all(p.startswith(("design/", "art/renders/")) for p in paths) and sha not in duplicates:
            category, reason = "EVIDENCE_ONLY", "Changed paths contain documentation/capture only; no runtime implementation is adopted."
        category = override.get("classification", category)
        if category not in CATEGORIES:
            raise ValueError(f"Unknown category {category}: {sha}")
        overlapping = sorted({ref for other in snap["commits_outside_base"] if other["commit"] != sha and set(paths) & set(other["changed_paths"]) for ref in other["containing_refs"]} - set(commit["containing_refs"]))
        rows.append({**commit, "classification": category, "reason": override.get("reason", reason),
                     "reachable_from_canonical_base": False,
                     "dependencies": override.get("dependencies", commit["parents"]),
                     "overlapping_branches": overlapping,
                     "acceptance_receipt": override.get("acceptance_receipt", None),
                     "production_consumer": override.get("production_consumer", "UNVERIFIED; changed-path presence is not consumer proof."),
                     "evidence_scope": override.get("evidence_scope", "UNREVIEWED"),
                     "test_status_after_rebasing": "NOT_RUN; not adopted at sanitation snapshot.",
                     "visual_performance_debt": override.get("debt", ["Production composition, visual quality and performance not established by this record."]),
                     "review_source": override.get("review_source", "evidence/patch_equivalence.json" if sha in duplicates else "evidence/repository_snapshot.json")})
    refs = []
    for ref in snap["refs"]:
        if ref.get("not_a_commit"):
            refs.append({**ref, "classification": "UNKNOWN_REQUIRES_REVIEW"})
        else:
            refs.append({**ref, "classification": "CANONICAL_ALREADY_IN_MAIN" if ref["tip_reachable_from_base"] else "SEE_COMMIT_ROWS",
                         "canonical_ancestry_series": "All commits in this ref intersecting base ancestry are CANONICAL_ALREADY_IN_MAIN; outside-base commits enumerated individually."})
    dirty = [{"worktree": w["worktree"], "head": w.get("HEAD"), "classification": "QUARANTINED_DIRTY",
              "tracked_changes": w["tracked_changes"], "untracked_files": w["untracked_files"],
              "inventory": "evidence/repository_snapshot.json#worktrees", "adopted": False}
             for w in snap["worktrees"] if w.get("dirty") and str(w["worktree"]).replace("/", "\\") != snap["canonical_worktree"]]
    matrix = {"schema_version": 1, "canonical_base": base, "scope": "Frozen ASTRA-SANITIZE-0; subsequent landings belong in INTEGRATION_REGISTER.md.",
              "allowed_categories": sorted(CATEGORIES), "refs": refs, "commits": rows, "dirty_worktree_overlays": dirty,
              "counts_by_classification": dict(sorted(Counter(r["classification"] for r in rows).items()))}
    dump("BRANCH_ADOPTION_MATRIX.json", matrix)
    lines = ["# Branch adoption matrix", "", f"Frozen canonical base: `{base}`. No merge is implied by an accepted candidate.", "",
             "Every non-main line is represented in the JSON ref inventory. Common ancestry is classified as CANONICAL_ALREADY_IN_MAIN; every distinct outside-base commit has a row below. Dirty bytes are a separate quarantined overlay, even when their HEAD is accepted or already canonical.", "",
             "| Commit | Classification | Subject | Decision/evidence |", "| --- | --- | --- | --- |"]
    for r in sorted(rows, key=lambda r: (r["date"], r["commit"])):
        lines.append(f"| `{r['commit']}` | {r['classification']} | {esc(r['subject'])} | {esc(r['reason'])} See `{r['review_source']}`. |")
    lines += ["", "Exact paths, dependencies, overlap, receipts, consumer, composition scope, rebase status, and debt are in the JSON for each row. No absent field is treated as a pass.", "", "## Dirty overlays", ""]
    lines.extend(f"- `{r['worktree']}` at `{r['head']}`: {r['tracked_changes']} tracked status entries, {r['untracked_files']} untracked files; QUARANTINED_DIRTY." for r in dirty)
    write("BRANCH_ADOPTION_MATRIX.md", "\n".join(lines) + "\n")
    truth = ["# Repository truth — ASTRA-SANITIZE-0", "", f"Verified fetched `origin/main`: `{base}`. Both `git -c gc.auto=0 fetch --all --tags` invocations succeeded; the separately observed fetch exit is 0. No prune was requested.", "",
             f"New worktree: `{snap['canonical_worktree']}`. New branch: `{snap['canonical_branch']}`. Created from the exact base above; `git status --porcelain=v1` was empty immediately after checkout. Census includes new untracked sanitation tooling created after that empty check.", "",
             "This packet is a frozen observation, not a live certification of moving checkouts. Commands used `git --no-optional-locks` for the census. No shared checkout was cleaned, reset, staged, or reused; no stash, branch, evidence directory, or worktree was deleted. Generated import state in the new worktree is recorded separately from this pre-import census.", "",
             "Remote endpoints:", ""] + [f"- `{r}`" for r in snap["remote_urls"]]
    truth += ["", f"Inventory: {len(snap['refs'])} refs (local, remote-tracking, and tags), {len(snap['worktrees'])} worktrees, {len(snap['stash'])} stashes, {len(rows)} distinct commits outside the base.", "",
              "## Refs and ancestry", "", "Behind/ahead are relative to the verified base, never to the stale local main. Reachable means the ref tip is in base ancestry. Each full commit series is in the JSON.", "",
              "| Ref | Exact tip | Last commit date | Behind / ahead | Merge bases | Reachable |", "| --- | --- | --- | --- | --- | --- |"]
    for r in refs:
        truth.append(f"| `{r['ref']}` | `{r['hash']}` | {r['last_commit_date']} | {r.get('behind_base','?')} / {r.get('ahead_of_base','?')} | {', '.join(r.get('merge_bases',[]))} | {r.get('tip_reachable_from_base','unverified')} |")
    truth += ["", "## Worktrees", "", "Counts are porcelain status entries; metadata-only import entries can appear without a substantive normalized Git diff. See the M11 review for the byte comparison.", "",
              "| Worktree | HEAD / branch | State | Tracked / untracked |", "| --- | --- | --- | --- |"]
    for w in snap["worktrees"]:
        truth.append(f"| `{w['worktree']}` | `{w.get('HEAD','?')}` / `{w.get('branch','DETACHED')}` | {'DIRTY' if w.get('dirty') else 'CLEAN'} | {w.get('tracked_changes',0)} / {w.get('untracked_files',0)} |")
    truth += ["", "## Stashes", ""]
    truth.extend(f"- `{s['name']}` `{s['hash']}` ({s['date']}): {s['subject']}. Exact paths in frozen JSON; preserved." for s in snap["stash"])
    truth += ["", "## Evidence and bounds", "", "- `evidence/repository_snapshot.json`: full paths and status for every worktree, diff digests, M11C2 changed/untracked file SHA-256, refs and commit dependencies.",
              "- `evidence/patch_equivalence.json`: `git cherry -v` outputs against the verified base, preserving exact exits. A patch duplicate is not a new feature.",
              "- `reviews/m11_review.md` and `reviews/dream_review.md`: receipt scope, current consumers, dependencies, failed gates and protected-file concerns.",
              "- `evidence/base_audits/receipt.json`: actual exits and logs. Completeness/data/prompt failures remain open.",
              "- `OWNER_MANDATE.md`: exact current instruction text; outranks older date/quest/release assumptions.",
              "", "Fresh import/boot success, beauty, player comprehension, and complete release scope are not proven by Git. See RELEASE_EVIDENCE_MATRIX.md and PLAYTEST_FINDINGS.md."]
    write("REPOSITORY_TRUTH.md", "\n".join(truth) + "\n")
    master = []
    for r in source["requirements"]:
        status = r["status"] if r["status"] in {"ABSENT", "PROGRAMMED", "RUNTIME_PROVEN", "HUMAN_ACCEPTED"} else "PROGRAMMED"
        scopes = r["blocking_scopes"]
        row = {"id": "V2." + r["id"], "subsystem": r["dimension"],
               "experiential_outcome": r["notes"] or r["id"], "current_state": r["status"],
               "desired_final_state": "Perceptible authored V2 obligation in composed world, with full scoped release proof.",
               "authoritative_owner": "V2 architectural program / semantic source owners; per-owner validation remains required.",
               "production_consumer": "OrisonV2RuntimeRoot via BuildingRootSelector explicit v2; record-specific composition is only as proven by the source evidence.",
               "dependencies": r["blocked_by"],
               "severity": "BLOCKER" if any(s in scopes for s in ["FIRST_SLICE_TECHNICAL", "GOLDEN_SHIFT_V2"]) else "RELEASE_CRITICAL",
               "scope": "early complete path" if "GOLDEN_SHIFT_V2" in scopes or "FIRST_SLICE_TECHNICAL" in scopes else "full world",
               "provenance": {"base_commit": base, "evidence_commit": live["ledger_evidence_head"],
                              "source": audit_proof["path"], "source_sha256": audit_proof["sha256"],
                              "receipt": audit_proof["receipt_path"], "receipt_sha256": audit_proof["receipt_sha256"],
                              "requirement": r["id"], "claims": r["provenance"]},
               "implementation_strategy": "Owner-first source to semantic owner to named anchor to derived transform; complete structural dependencies before room art.",
               "automated_proof": {**audit_proof, "new_run": "STATIC_AUDIT_ONLY"},
               "composed_runtime_proof": {"new_run": "NOT_RUN", "source_status": r["status"],
                                         "source_provenance": r["provenance"],
                                         "inheritance_note": "The current static audit reports inherited claims; it did not execute these runtime/human proofs."},
               "human_proof_required": "Real-eye-height route/function comprehension, production lighting and motion; final acceptance remains required.",
               "performance": {"budget": "Provisional p95 frame <16.6ms, main <=8ms, physics <=2ms, GPU <14ms; production boot <18s.", "measured_result": None, "scope": "Must name complete content scope; no first-slice extrapolation."},
               "persistence_reconstruction": "Stable semantic identities; save/destroy/reconstruct without authority duplication or lost facts.",
               "status": status, "source_evidence_tier": r["status"],
               "open_defects": list(r["blocking_scopes"]) + (["v1 fallback retained"] if r["temporary_v1_fallback"] else []),
               "next_decisive_action": "Resolve dependencies and perform record-specific production proof; do not promote from this generated row."}
        master.append(row)
    for row in read("reviews/production_obligations.json"):
        master.append(row)
    master.sort(key=lambda r: r["id"])
    ledger = {"schema_version": 2, "base_commit": base,
              "ledger_evidence_head": live["ledger_evidence_head"], "completeness_source": audit_proof,
              "evidence_policy": "Frozen Git decisions remain at sanitation base. The live ledger reads only LIVE_STATE's hash-bound current audit. V2 audit runtime/human tiers are inherited source claims; authored outcome rows cite their own current runtime receipts. No completion percentage.",
              "counts_by_severity": dict(sorted(Counter(r["severity"] for r in master).items())),
              "counts_by_scope": dict(sorted(Counter(r["scope"] for r in master).items())),
              "counts_by_evidence_tier": dict(sorted(Counter(r["status"] for r in master).items())), "rows": master}
    dump("MASTER_COMPLETION_LEDGER.json", ledger)
    lines = ["# Master completion ledger", "", ledger["evidence_policy"], "",
             f"Current static evidence head: `{live['ledger_evidence_head']}`. Source: `{audit_proof['path']}` (SHA-256 `{audit_proof['sha256']}`). Audit exit {audit_proof['exit_code']}; fixture exit {audit_proof['selftest_exit_code']}. These exits do not constitute new composed-runtime or human proof.",
             "", "Counts are obligations, not completion percentages.", ""]
    for key in ["counts_by_severity", "counts_by_scope", "counts_by_evidence_tier"]:
        lines.append(f"- {key}: " + "; ".join(f"{k}={v}" for k,v in ledger[key].items()))
    lines += ["", "The JSON carries owners, consumers, provenance, implementation strategy, proof, performance, persistence and defects for every row. V2 source statuses are retained separately: spatial proof does not silently become composed runtime proof.", "", "| Stable ID | Outcome / current state | Severity / scope | Evidence tier | Next decisive action |", "| --- | --- | --- | --- | --- |"]
    lines.extend(f"| `{r['id']}` | {esc(r['experiential_outcome'])} / {esc(r['current_state'])} | {r['severity']} / {r['scope']} | {r['status']} | {esc(r['next_decisive_action'])} |" for r in master)
    write("MASTER_COMPLETION_LEDGER.md", "\n".join(lines) + "\n")
    print(f"Rendered {len(rows)} commit decisions, {len(refs)} refs, {len(master)} completion obligations.")


if __name__ == "__main__":
    render()
