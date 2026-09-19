#!/usr/bin/env python3
"""Validate frozen Astra evidence and prove packet defects fail independently.

No Git, Godot, production writes, or live repository census is used. Renderer
and input preparation run only in disposable copies of the frozen packet.

    python tools/tests/test_astra_packet.py --evidence design/astra/evidence/packet_live_validation.json
    python tools/tests/test_astra_packet.py --check-packet design/astra
"""
from __future__ import annotations

import argparse
from collections import Counter
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
PACKET = ROOT / "design/astra"
CATEGORIES = {
    "CANONICAL_ALREADY_IN_MAIN", "ACCEPTED_CANDIDATE",
    "TECHNICALLY_PROVEN_BUT_HUMAN_PENDING", "FAILED_GATE", "SUPERSEDED",
    "EVIDENCE_ONLY", "QUARANTINED_DIRTY", "DUPLICATE", "UNKNOWN_REQUIRES_REVIEW",
}
STATUSES = {"ABSENT", "QUARANTINED", "PROGRAMMED", "INTEGRATED",
            "RUNTIME_PROVEN", "HUMAN_ACCEPTED", "RELEASE_PROVEN"}
SEVERITIES = {"BLOCKER", "RELEASE_CRITICAL", "MAJOR", "POLISH", "OPTIONAL"}
SCOPES = {"early complete path", "full campaign", "full world", "release",
          "post-launch"}
MASTER_FIELDS = {
    "id", "subsystem", "experiential_outcome", "current_state",
    "desired_final_state", "authoritative_owner", "production_consumer",
    "dependencies", "severity", "scope", "provenance",
    "implementation_strategy", "automated_proof", "composed_runtime_proof",
    "human_proof_required", "performance", "persistence_reconstruction",
    "status", "open_defects", "next_decisive_action",
}
REQUIRED_FILES = (
    "REPOSITORY_TRUTH.md", "BRANCH_ADOPTION_MATRIX.json",
    "BRANCH_ADOPTION_MATRIX.md", "AUTHORITY_HIERARCHY.md",
    "DEBT_DEDUPLICATION.md", "INTEGRATION_SEQUENCE.md",
    "MASTER_COMPLETION_LEDGER.json", "MASTER_COMPLETION_LEDGER.md",
    "INTEGRATION_REGISTER.md", "DECISION_LOG.md", "RISK_REGISTER.md",
    "PLAYTEST_FINDINGS.md", "RELEASE_EVIDENCE_MATRIX.md", "OWNER_MANDATE.md",
    "LIVE_STATE.json",
)
JSON_FILES = {
    "snapshot": "evidence/repository_snapshot.json",
    "patches": "evidence/patch_equivalence.json",
    "m11_review": "reviews/m11_review.json",
    "dream_review": "reviews/dream_review.json",
    "rulings": "reviews/adoption_rulings.json",
    "obligations": "reviews/production_obligations.json",
    "baseline_completeness": "evidence/base_audits/orison_v2_completeness.stdout.txt",
    "baseline_audit_receipt": "evidence/base_audits/receipt.json",
    "live_state": "LIVE_STATE.json",
    "matrix": "BRANCH_ADOPTION_MATRIX.json",
    "ledger": "MASTER_COMPLETION_LEDGER.json",
}
GENERATED = (
    "BRANCH_ADOPTION_MATRIX.json", "BRANCH_ADOPTION_MATRIX.md",
    "REPOSITORY_TRUTH.md", "MASTER_COMPLETION_LEDGER.json",
    "MASTER_COMPLETION_LEDGER.md",
)
OBSERVATIONS: list[dict] = []
DETERMINISM: dict = {}
CLI_PROOF: dict = {}
LIVE_REJECTIONS: list[dict] = []


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_packet(path: Path) -> dict:
    data = {key: json.loads((path / name).read_text(encoding="utf-8-sig"))
            for key, name in JSON_FILES.items()}
    data["sequence"] = (path / "INTEGRATION_SEQUENCE.md").read_text(encoding="utf-8")
    data["required_file_presence"] = {
        name: (path / name).is_file() and (path / name).stat().st_size > 0
        for name in REQUIRED_FILES
    }
    data["baseline_source_sha256"] = digest((path / JSON_FILES["baseline_completeness"]).read_bytes())
    data["baseline_receipt_sha256"] = digest((path / JSON_FILES["baseline_audit_receipt"]).read_bytes())
    data["live_load_error"] = None
    data["completeness"] = {"requirements": []}
    data["live_receipt"] = {}
    try:
        binding = data["live_state"]["completeness_source"]
        for name in (binding["path"], binding["receipt_path"]):
            relative = Path(name)
            if (relative.is_absolute() or ":" in name or "\\" in name
                    or ".." in relative.parts
                    or not (path / relative).resolve().is_relative_to(path.resolve())):
                raise ValueError("Live source must be inside the packet")
        source_bytes = (path / binding["path"]).read_bytes()
        receipt_bytes = (path / binding["receipt_path"]).read_bytes()
        data["completeness"] = json.loads(source_bytes.decode("utf-8-sig"))
        data["live_receipt"] = json.loads(receipt_bytes.decode("utf-8-sig"))
        data["live_source_sha256"] = digest(source_bytes)
        data["live_receipt_sha256"] = digest(receipt_bytes)
        data["loaded_source_path"] = binding["path"]
        data["loaded_receipt_path"] = binding["receipt_path"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        data["live_load_error"] = type(error).__name__
    return data


def packet_input_files(path: Path) -> tuple[str, ...]:
    live = json.loads((path / "LIVE_STATE.json").read_text(encoding="utf-8"))
    binding = live["completeness_source"]
    return tuple(sorted(set((*REQUIRED_FILES, *JSON_FILES.values(),
                             binding["path"], binding["receipt_path"]))))


def review_rulings(data: dict) -> dict:
    """Authoritative review fields, independently of generated ruling files."""
    result = {}
    for name in ("m11_review", "dream_review"):
        for row in data[name]["commits"]:
            if row["classification"] == "CANONICAL_ALREADY_IN_MAIN":
                continue
            result[row["commit"]] = {
                "classification": row["classification"],
                "acceptance_receipt": row.get("human_acceptance", row.get("acceptance_evidence")),
                "production_consumer": row.get("current_consumer", row.get("production_consumer")),
                "evidence_scope": row.get("evidence_scope", row.get("composition_scope")),
                "dependencies": row.get("dependencies", row.get("parents", [])),
                "review_source": "reviews/" + name + ".json",
            }
    return result


def validate(data: dict) -> list[str]:
    """Return actionable contract failures without consulting moving Git refs."""
    errors = []

    def require(ok, code, detail):
        if not ok:
            errors.append(f"{code}: {detail}")

    def indexed(rows, key, label):
        ids = [row.get(key) for row in rows]
        require(len(set(ids)) == len(ids), "DUPLICATE_ID", label)
        return {row[key]: row for row in rows if key in row}

    for name, exists in data["required_file_presence"].items():
        require(exists, "MISSING_DELIVERABLE", name)
    snap, matrix, ledger = data["snapshot"], data["matrix"], data["ledger"]
    base = snap["base_commit"]
    require(matrix.get("canonical_base") == base and ledger.get("base_commit") == base,
            "BASE_MISMATCH", "matrix and ledger must use the frozen base")
    live = data["live_state"]
    binding = live.get("completeness_source", {})
    receipt = data["live_receipt"]
    head = live.get("ledger_evidence_head")
    require(not data["live_load_error"], "LIVE_LOAD", "missing/invalid live source")
    require(live.get("schema_version") == 1 and live.get("frozen_sanitation_base") == base,
            "LIVE_BASE", "live state must retain frozen sanitation identity")
    require(isinstance(head, str) and re.fullmatch(r"[0-9a-f]{40}", head) is not None,
            "LIVE_HEAD", "exact evidence head required")
    require(binding.get("path") == data.get("loaded_source_path")
            and binding.get("receipt_path") == data.get("loaded_receipt_path"),
            "LIVE_PATH", "explicit binding must select the loaded artifacts")
    require(binding.get("sha256") == data.get("live_source_sha256")
            and binding.get("receipt_sha256") == data.get("live_receipt_sha256"),
            "LIVE_HASH", "raw source/receipt identity must match binding")
    require(binding.get("repository_head") == head and receipt.get("repository_head") == head,
            "LIVE_STALE_HEAD", "receipt/binding/evidence heads must agree")
    require(binding.get("audit_id") == "orison_v2_completeness", "LIVE_AUDIT_ID", "wrong audit")
    runs = [r for r in receipt.get("runs", []) if r.get("id") == "orison_v2_completeness"]
    selftests = [r for r in receipt.get("runs", []) if r.get("id") == "orison_v2_completeness_selftest"]
    require(len(runs) == 1 and len(selftests) == 1, "LIVE_RUN_COVERAGE", "exact audit/fixture pair required")
    proof = None
    if len(runs) == 1 and len(selftests) == 1:
        run, selftest = runs[0], selftests[0]
        expected_output = (Path(binding.get("receipt_path", "")).parent / run.get("stdout", "")).as_posix()
        require(expected_output == binding.get("path")
                and run.get("stdout_sha256") == data.get("live_source_sha256"),
                "LIVE_RECEIPT_OUTPUT", "receipt must name/hash selected output")
        require(type(run.get("exit_code")) is int and type(selftest.get("exit_code")) is int,
                "LIVE_EXITS", "actual integer exits required")
        proof = {"kind": "STATIC_AUDIT", "path": binding.get("path"),
                 "sha256": data.get("live_source_sha256"), "receipt_path": binding.get("receipt_path"),
                 "receipt_sha256": data.get("live_receipt_sha256"), "repository_head": head,
                 "audit_id": "orison_v2_completeness", "exit_code": run.get("exit_code"),
                 "selftest_exit_code": selftest.get("exit_code"),
                 "runtime_proof_created": False, "human_acceptance_created": False}
        require(ledger.get("completeness_source") == proof, "LIVE_LEDGER_SOURCE", "ledger source stale or promoted")
    live_ids = [r["id"] for r in data["completeness"]["requirements"]]
    require(bool(live_ids) and len(live_ids) == len(set(live_ids))
            and data["completeness"].get("summary", {}).get("requirements") == len(live_ids),
            "LIVE_REQUIREMENTS", "source count/identities must close")
    require(ledger.get("ledger_evidence_head") == head, "LIVE_LEDGER_HEAD", "ledger must use explicit live head")
    source = indexed(snap["commits_outside_base"], "commit", "snapshot commits")
    commits = indexed(matrix["commits"], "commit", "matrix commits")
    require(set(source) == set(commits), "COMMIT_COVERAGE",
            "matrix must represent every outside-base commit exactly once")
    frozen_refs = indexed(snap["refs"], "ref", "snapshot refs")
    refs = indexed(matrix["refs"], "ref", "matrix refs")
    require(set(frozen_refs) == set(refs), "REF_COVERAGE", "all frozen refs required")
    outside_union = {sha for ref in snap["refs"]
                     for sha in ref.get("commits_outside_base", [])}
    require(outside_union == set(source), "CENSUS_UNION",
            "ref histories must close the outside-base census")
    expected_rulings = review_rulings(data)
    require(set(data["rulings"]) == set(expected_rulings), "RULING_COVERAGE",
            "prepared rulings must contain exactly the independent reviewed commits")
    duplicates = set()
    for result in data["patches"]:
        require(result.get("exit_code") == 0, "PATCH_PROOF_FAILED", result.get("ref"))
        for line in result.get("stdout", "").splitlines():
            if line.startswith("- "):
                duplicates.add(line.split()[1])

    for sha, row in commits.items():
        frozen = source.get(sha)
        if frozen is None:
            continue
        for key in ("changed_paths", "parents", "containing_refs", "date", "subject"):
            require(row.get(key) == frozen.get(key), "FROZEN_METADATA", f"{sha} {key}")
        require(row.get("reachable_from_canonical_base") is False,
                "FALSE_REACHABILITY", sha)
        category = row.get("classification")
        require(category in CATEGORIES, "INVALID_CLASSIFICATION", sha)
        require(category != "CANONICAL_ALREADY_IN_MAIN", "OUTSIDE_AS_CANONICAL", sha)
        expected = expected_rulings.get(sha)
        if expected is not None:
            for key, value in expected.items():
                require(row.get(key) == value, "REVIEW_MAPPING", f"{sha} {key}")
                require(data["rulings"].get(sha, {}).get(key) == value,
                        "PREPARE_MAPPING", f"{sha} {key}")
        else:
            permitted = {"UNKNOWN_REQUIRES_REVIEW"}
            if sha in duplicates:
                permitted = {"DUPLICATE"}
            elif frozen["changed_paths"] and all(
                p.startswith(("design/", "art/renders/")) for p in frozen["changed_paths"]
            ):
                permitted.add("EVIDENCE_ONLY")
            require(category in permitted, "UNREVIEWED_PROMOTION", sha)
        if category == "ACCEPTED_CANDIDATE":
            receipt = row.get("acceptance_receipt")
            # These are nonvisual guard/UID-only dependencies. A generic prose
            # reason or fabricated receipt cannot waive acceptance on art/code.
            paths = row["changed_paths"]
            nonvisual = bool(paths) and all(
                p.startswith(("tools/", "design/")) or p.endswith(".uid")
                for p in paths
            )
            traceable = isinstance(receipt, (dict, list)) and bool(receipt)
            require(nonvisual or traceable, "ACCEPTANCE_REQUIRED", sha)
            require(bool(expected), "ACCEPTANCE_REVIEW_REQUIRED", sha)
            require(bool(row.get("production_consumer")) and bool(row.get("evidence_scope")),
                    "ACCEPTANCE_SCOPE_REQUIRED", sha)
            for entry in receipt if isinstance(receipt, list) else ([receipt] if traceable else []):
                require(isinstance(entry, dict) and bool(entry.get("path"))
                        and bool(entry.get("receipt_commit", entry.get("commit")))
                        and bool(entry.get("receipt_git_blob", entry.get("blob_sha"))),
                        "RECEIPT_IDENTITY", sha)

    for name, row in refs.items():
        frozen = frozen_refs.get(name)
        if frozen is None:
            continue
        for key, value in frozen.items():
            require(row.get(key) == value, "REF_FROZEN_METADATA", f"{name} {key}")
        if frozen.get("not_a_commit"):
            continue
        history = frozen["commits_outside_base"]
        require(len(history) == frozen["ahead_of_base"], "REF_AHEAD_COUNT", name)
        require(frozen["tip_reachable_from_base"] == (not history),
                "REF_REACHABILITY", name)
        expected_category = ("CANONICAL_ALREADY_IN_MAIN" if not history
                             else "SEE_COMMIT_ROWS")
        require(row.get("classification") == expected_category, "REF_CLASSIFICATION", name)
        for sha in history:
            require(name in source.get(sha, {}).get("containing_refs", []),
                    "REF_CONTAINMENT", f"{name} {sha}")

    def norm(path):
        return str(path).replace("/", "\\").lower()

    dirty = {norm(row["worktree"]): row for row in snap["worktrees"]
             if row.get("dirty") and norm(row["worktree"]) != norm(snap["canonical_worktree"])}
    overlays = {norm(row["worktree"]): row for row in matrix["dirty_worktree_overlays"]}
    require(set(overlays) == set(dirty), "DIRTY_COVERAGE", "preserve all dirty overlays")
    for key, row in overlays.items():
        require(row.get("classification") == "QUARANTINED_DIRTY" and row.get("adopted") is False,
                "DIRTY_ADOPTION", key)
    require(matrix.get("counts_by_classification") == dict(Counter(
        row["classification"] for row in matrix["commits"])),
        "MATRIX_COUNTS", "classification totals")

    master = indexed(ledger["rows"], "id", "master rows")
    source_requirements = {"V2." + row["id"]: row
                           for row in data["completeness"]["requirements"]}
    obligations = indexed(data["obligations"], "id", "production obligations")
    require(set(master) == set(source_requirements) | set(obligations), "MASTER_COVERAGE",
            "all authored and source obligations must remain represented")
    for row_id, row in master.items():
        missing = MASTER_FIELDS - set(row)
        require(not missing, "MASTER_FIELDS", f"{row_id}: {sorted(missing)}")
        require(row.get("status") in STATUSES, "MASTER_STATUS", row_id)
        require(row.get("severity") in SEVERITIES, "MASTER_SEVERITY", row_id)
        require(row.get("scope") in SCOPES, "MASTER_SCOPE", row_id)
        require(isinstance(row.get("dependencies"), list), "MASTER_DEPENDENCIES", row_id)
        require(isinstance(row.get("open_defects"), list), "MASTER_DEFECTS", row_id)
        perf = row.get("performance", {})
        require(isinstance(perf, dict) and "budget" in perf and "measured_result" in perf,
                "MASTER_PERFORMANCE", row_id)
        require(isinstance(row.get("provenance"), dict)
                and row["provenance"].get("base_commit") == base,
                "MASTER_PROVENANCE", row_id)
        if row_id in source_requirements:
            source_row = source_requirements[row_id]
            state = source_row["status"]
            expected_status = state if state in {
                "ABSENT", "PROGRAMMED", "RUNTIME_PROVEN", "HUMAN_ACCEPTED"
            } else "PROGRAMMED"
            require(row.get("current_state") == state and row.get("source_evidence_tier") == state
                    and row.get("status") == expected_status,
                    "MASTER_TIER_PROMOTION", row_id)
            provenance = row.get("provenance", {})
            require(provenance.get("evidence_commit") == head
                    and provenance.get("source") == binding.get("path")
                    and provenance.get("source_sha256") == data.get("live_source_sha256")
                    and provenance.get("receipt") == binding.get("receipt_path")
                    and provenance.get("receipt_sha256") == data.get("live_receipt_sha256")
                    and provenance.get("claims") == source_row["provenance"],
                    "LIVE_ROW_PROVENANCE", row_id)
            require(row.get("automated_proof") == {**(proof or {}), "new_run": "STATIC_AUDIT_ONLY"},
                    "LIVE_STATIC_PROOF", row_id)
            runtime = row.get("composed_runtime_proof", {})
            require(isinstance(runtime, dict) and runtime.get("new_run") == "NOT_RUN"
                    and runtime.get("source_status") == state
                    and runtime.get("source_provenance") == source_row["provenance"],
                    "LIVE_RUNTIME_PROMOTION", row_id)
        elif row_id in obligations:
            require(row == obligations[row_id], "MASTER_OBLIGATION_MAPPING", row_id)
    for count_key, row_key in (("counts_by_severity", "severity"),
                               ("counts_by_scope", "scope"),
                               ("counts_by_evidence_tier", "status")):
        expected = dict(Counter(row.get(row_key) for row in ledger["rows"]))
        require(ledger.get(count_key) == expected, "MASTER_COUNTS", count_key)

    section_match = re.search(
        r"(?ms)^## Authorized accepted dependency landing\s*\n(.*?)(?=^## |\Z)",
        data["sequence"],
    )
    require(section_match is not None, "SEQUENCE_SECTION", "approved sequence missing")
    if section_match:
        section = section_match.group(1)
        sequence = re.findall(r"(?m)^\|\s*(\d+)\s*\|\s*`([0-9a-f]{40})`\s*\|", section)
        require(bool(sequence), "SEQUENCE_EMPTY", "approved sequence has no exact hashes")
        require([int(n) for n, _ in sequence] == list(range(1, len(sequence) + 1)),
                "SEQUENCE_ORDER", "contiguous dependency order required")
        sha_list = [sha for _, sha in sequence]
        require(len(set(sha_list)) == len(sha_list), "SEQUENCE_DUPLICATE", "duplicate adoption")
        require(set(re.findall(r"`([0-9a-f]{40})`", section)) <= set(sha_list),
                "SEQUENCE_UNLISTED_HASH", "narrative merge target must be enumerated")
        c2 = {row["commit"] for row in data["m11_review"]["commits"]
              if row.get("group") == "M11C2"}
        prior = {base}
        for _, sha in sequence:
            row = commits.get(sha, {})
            require(sha in commits, "SEQUENCE_UNKNOWN", sha)
            require(row.get("classification") in {"ACCEPTED_CANDIDATE", "EVIDENCE_ONLY"},
                    "SEQUENCE_UNSAFE_CLASS", sha)
            require(sha not in c2, "SEQUENCE_C2", sha)
            require(set(row.get("parents", [])) <= prior, "SEQUENCE_DEPENDENCY", sha)
            prior.add(sha)
    return sorted(set(errors))


def load_tool(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class AstraPacketTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.frozen = load_packet(PACKET)

    def test_frozen_packet_covers_census_and_preserves_review_scope(self):
        self.assertEqual(validate(self.frozen), [])

    def assert_mutation_fails(self, name, mutate, code):
        changed = copy.deepcopy(self.frozen)
        mutate(changed)
        errors = validate(changed)
        self.assertTrue(any(error.startswith(code + ":") for error in errors), errors)
        self.assertEqual(validate(self.frozen), [])
        OBSERVATIONS.append({"fixture_id": name, "expected_failure": code,
                             "red_exit_code": 1 if errors else 0,
                             "red_diagnostics": errors, "restored_exit_code": 0})

    def test_classification_changes_cannot_override_independent_review(self):
        self.assert_mutation_fails(
            "failed_gate_promoted", lambda d: next(
                row for row in d["matrix"]["commits"] if row["classification"] == "FAILED_GATE"
            ).update(classification="ACCEPTED_CANDIDATE"), "REVIEW_MAPPING",
        )
        self.assert_mutation_fails(
            "prepared_ruling_promoted", lambda d: next(
                row for row in d["rulings"].values() if row["classification"] == "FAILED_GATE"
            ).update(classification="ACCEPTED_CANDIDATE"), "PREPARE_MAPPING",
        )

    def test_deleted_rows_false_reachability_and_changed_paths_fail(self):
        cases = (
            ("deleted_commit", lambda d: d["matrix"]["commits"].pop(), "COMMIT_COVERAGE"),
            ("deleted_ref", lambda d: d["matrix"]["refs"].pop(), "REF_COVERAGE"),
            ("false_reachable", lambda d: d["matrix"]["commits"][0].update(
                reachable_from_canonical_base=True), "FALSE_REACHABILITY"),
            ("omitted_changed_path", lambda d: d["matrix"]["commits"][0]["changed_paths"].pop(),
             "FROZEN_METADATA"),
            ("dirty_bytes_adopted", lambda d: d["matrix"]["dirty_worktree_overlays"][0].update(
                adopted=True), "DIRTY_ADOPTION"),
        )
        for name, mutation, code in cases:
            with self.subTest(name=name):
                self.assert_mutation_fails(name, mutation, code)

    def test_visual_candidate_without_receipt_fails(self):
        self.assert_mutation_fails(
            "missing_visual_acceptance", lambda d: next(
                row for row in d["matrix"]["commits"]
                if row["classification"] == "ACCEPTED_CANDIDATE" and row["acceptance_receipt"]
                and any(p.endswith(".gd") for p in row["changed_paths"])
            ).update(acceptance_receipt=None), "ACCEPTANCE_REQUIRED",
        )

    def test_master_omissions_invalid_values_and_tier_promotion_fail(self):
        cases = (
            ("deleted_master_row", lambda d: d["ledger"]["rows"].pop(), "MASTER_COVERAGE"),
            ("missing_persistence", lambda d: d["ledger"]["rows"][0].pop(
                "persistence_reconstruction"), "MASTER_FIELDS"),
            ("missing_performance_measurement", lambda d: d["ledger"]["rows"][0]["performance"].pop(
                "measured_result"), "MASTER_PERFORMANCE"),
            ("invented_done_status", lambda d: d["ledger"]["rows"][0].update(status="DONE"),
             "MASTER_STATUS"),
            ("invalid_severity", lambda d: d["ledger"]["rows"][0].update(severity="MINOR"),
             "MASTER_SEVERITY"),
            ("invalid_scope", lambda d: d["ledger"]["rows"][0].update(scope="everything"),
             "MASTER_SCOPE"),
            ("spatial_to_release_promotion", lambda d: next(
                row for row in d["ledger"]["rows"] if row.get("source_evidence_tier") == "SPATIALLY_PROVEN"
            ).update(status="RELEASE_PROVEN"), "MASTER_TIER_PROMOTION"),
        )
        for name, mutation, code in cases:
            with self.subTest(name=name):
                self.assert_mutation_fails(name, mutation, code)

    def test_failed_and_c2_commits_cannot_enter_approved_sequence(self):
        def append_sha(data, sha):
            data["sequence"] = data["sequence"].replace(
                "\n## Deferred lines", f"\n| 13 | `{sha}` | injected adoption |\n\n## Deferred lines"
            )

        failed = next(row["commit"] for row in self.frozen["matrix"]["commits"]
                      if row["classification"] == "FAILED_GATE")
        c2 = next(row["commit"] for row in self.frozen["m11_review"]["commits"]
                  if row.get("group") == "M11C2" and row["classification"] == "EVIDENCE_ONLY")
        self.assert_mutation_fails("failed_commit_in_sequence", lambda d: append_sha(d, failed),
                                   "SEQUENCE_UNSAFE_CLASS")
        self.assert_mutation_fails("c2_evidence_in_sequence", lambda d: append_sha(d, c2),
                                   "SEQUENCE_C2")

    def test_live_source_identity_and_inherited_proof_cannot_be_laundered(self):
        def stale_source(data):
            binding = data["live_state"]["completeness_source"]
            binding.update(path=JSON_FILES["baseline_completeness"],
                           receipt_path=JSON_FILES["baseline_audit_receipt"],
                           sha256=data["baseline_source_sha256"],
                           receipt_sha256=data["baseline_receipt_sha256"],
                           repository_head=data["snapshot"]["base_commit"])
            data.update(completeness=data["baseline_completeness"],
                        live_receipt=data["baseline_audit_receipt"],
                        live_source_sha256=data["baseline_source_sha256"],
                        live_receipt_sha256=data["baseline_receipt_sha256"],
                        loaded_source_path=binding["path"], loaded_receipt_path=binding["receipt_path"])

        self.assert_mutation_fails("live_source_hash_mismatch", lambda d:
            d["live_state"]["completeness_source"].update(sha256="0" * 64), "LIVE_HASH")
        self.assert_mutation_fails("stale_valid_baseline_source", stale_source, "LIVE_STALE_HEAD")
        self.assert_mutation_fails("static_audit_claimed_as_runtime", lambda d: next(
            row for row in d["ledger"]["rows"] if row["id"].startswith("V2.")
        )["composed_runtime_proof"].update(new_run="PASS"), "LIVE_RUNTIME_PROMOTION")

    def test_renderer_rejects_invalid_live_input_before_writing_frozen_views(self):
        renderer = load_tool("astra_render_packet")
        with tempfile.TemporaryDirectory(prefix="astra-live-source-fixture-") as tmp:
            packet = Path(tmp)
            for relative in packet_input_files(PACKET):
                target = packet / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((PACKET / relative).read_bytes())
            original = self.frozen["live_state"]
            before = {name: digest((packet / name).read_bytes()) for name in GENERATED}

            def stale(state):
                state["completeness_source"].update(
                    path=JSON_FILES["baseline_completeness"],
                    receipt_path=JSON_FILES["baseline_audit_receipt"],
                    sha256=self.frozen["baseline_source_sha256"],
                    receipt_sha256=self.frozen["baseline_receipt_sha256"],
                    repository_head=self.frozen["snapshot"]["base_commit"],
                )

            cases = (
                ("missing_live_file", lambda s: s["completeness_source"].update(path="evidence/missing.json")),
                ("live_path_escape", lambda s: s["completeness_source"].update(path="../outside.json")),
                ("live_hash_mismatch", lambda s: s["completeness_source"].update(sha256="0" * 64)),
                ("stale_baseline_receipt", stale),
            )
            for name, change in cases:
                with self.subTest(name=name):
                    state = copy.deepcopy(original)
                    change(state)
                    (packet / "LIVE_STATE.json").write_text(json.dumps(state), encoding="utf-8")
                    with mock.patch.multiple(renderer, OUT=packet), self.assertRaises((ValueError, OSError)):
                        renderer.render()
                    self.assertEqual(before, {n: digest((packet / n).read_bytes()) for n in GENERATED})
                    LIVE_REJECTIONS.append({"fixture_id": name, "renderer_rejected": True,
                                            "all_existing_generated_views_unchanged": True})

    def test_prepare_and_renderer_are_deterministic_on_frozen_fixture(self):
        prepare = load_tool("astra_prepare_inputs")
        renderer = load_tool("astra_render_packet")
        with tempfile.TemporaryDirectory(prefix="astra-packet-fixture-") as tmp:
            root = Path(tmp)
            packet = root / "design/astra"
            for relative in packet_input_files(PACKET):
                source = PACKET / relative
                target = packet / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.read_bytes())
            immutable_names = [JSON_FILES[key] for key in (
                "snapshot", "patches", "m11_review", "dream_review", "baseline_completeness", "live_state")]
            immutable_names.extend([self.frozen["live_state"]["completeness_source"]["path"],
                                    self.frozen["live_state"]["completeness_source"]["receipt_path"]])
            immutable_before = {name: digest((packet / name).read_bytes()) for name in immutable_names}
            generated_inputs = ("reviews/adoption_rulings.json", "reviews/production_obligations.json")

            def generate():
                with mock.patch.multiple(prepare, ROOT=root, P=packet, R=packet / "reviews"), \
                     mock.patch.multiple(renderer, ROOT=root, OUT=packet), \
                     mock.patch("subprocess.run", side_effect=AssertionError("No live process allowed")), \
                     mock.patch("subprocess.check_output", side_effect=AssertionError("No live census allowed")), \
                     contextlib.redirect_stdout(io.StringIO()):
                    prepare.main()
                    renderer.render()
                return {name: digest((packet / name).read_bytes())
                        for name in (*GENERATED, *generated_inputs)}

            first = generate()
            self.assertEqual(validate(load_packet(packet)), [])
            second = generate()
            self.assertEqual(first, second)
            immutable_after = {name: digest((packet / name).read_bytes()) for name in immutable_names}
            self.assertEqual(immutable_before, immutable_after)
            for name in (*GENERATED, *generated_inputs):
                self.assertEqual((packet / name).read_bytes(), (PACKET / name).read_bytes(),
                                 f"Checked-in/generated packet is stale: {name}")
            # Once bootstrapped, live outcomes may progress and acquire new
            # obligations. Rebuilding Git views must retain those authored bytes.
            obligations_path = packet / "reviews/production_obligations.json"
            authored = json.loads(obligations_path.read_text(encoding="utf-8"))
            authored[0]["current_state"] = "Synthetic fixture has progressed"
            authored[0]["status"] = "INTEGRATED"
            new_row = copy.deepcopy(authored[0])
            new_row.update(id="ASTRA-FIXTURE-NEW-DEFECT", status="ABSENT",
                           current_state="Synthetic newly discovered defect")
            authored.append(new_row)
            authored_bytes = (json.dumps(authored, indent=2, sort_keys=True) + "\n").encode("utf-8")
            obligations_path.write_bytes(authored_bytes)
            generate()
            self.assertEqual(obligations_path.read_bytes(), authored_bytes)
            evolved = load_packet(packet)
            self.assertEqual(validate(evolved), [])
            evolved_rows = {row["id"]: row for row in evolved["ledger"]["rows"]}
            self.assertEqual(evolved_rows[new_row["id"]], new_row)
            self.assertEqual(evolved_rows[authored[0]["id"]], authored[0])
            DETERMINISM.update({"same_bytes_twice": True, "matches_current_packet": True,
                                "frozen_sources_unchanged": True, "generated_sha256": first,
                                "authored_progress_retained": True,
                                "additional_live_obligation_retained": True})

    def test_cli_returns_one_for_deleted_commit_and_zero_after_restoration(self):
        with tempfile.TemporaryDirectory(prefix="astra-packet-cli-") as tmp:
            packet = Path(tmp)
            for relative in packet_input_files(PACKET):
                target = packet / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((PACKET / relative).read_bytes())
            matrix_path = packet / JSON_FILES["matrix"]
            original = matrix_path.read_bytes()
            changed = json.loads(original)
            deleted_commit = changed["commits"].pop()["commit"]
            matrix_path.write_text(json.dumps(changed), encoding="utf-8")

            def run_cli():
                result = subprocess.run(
                    [sys.executable, str(Path(__file__).resolve()), "--check-packet", str(packet)],
                    capture_output=True, text=True, encoding="utf-8", check=False, timeout=20,
                )
                self.assertEqual(result.stderr, "")
                return {"exit_code": result.returncode, "report": json.loads(result.stdout),
                        "stderr": result.stderr}

            red = run_cli()
            self.assertEqual(red["exit_code"], 1)
            self.assertFalse(red["report"]["valid"])
            self.assertTrue(any(e.startswith("COMMIT_COVERAGE:") for e in red["report"]["errors"]))
            matrix_path.write_bytes(original)
            green = run_cli()
            self.assertEqual(green["exit_code"], 0)
            self.assertEqual(green["report"], {"valid": True, "errors": []})
            CLI_PROOF.update({"command": ["python", "tools/tests/test_astra_packet.py",
                                           "--check-packet", "<temporary_frozen_packet>"],
                              "deleted_commit": deleted_commit, "red": red, "restored": green})


def main() -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--check-packet", type=Path)
    args, unittest_args = parser.parse_known_args()
    if args.evidence is not None and args.evidence.name == "packet_validation.json" and args.evidence.exists():
        raise SystemExit("Preserve the original sanitation proof; select a new live validation receipt path.")
    if args.check_packet is not None:
        errors = validate(load_packet(args.check_packet))
        print(json.dumps({"valid": not errors, "errors": errors}, indent=2))
        return 1 if errors else 0
    OBSERVATIONS.clear()
    DETERMINISM.clear()
    CLI_PROOF.clear()
    LIVE_REJECTIONS.clear()
    program = unittest.main(argv=[sys.argv[0], *unittest_args], exit=False)
    passed = program.result.wasSuccessful()
    if args.evidence is not None:
        data = load_packet(PACKET)
        source_paths = {"tools/tests/test_astra_packet.py": Path(__file__),
                        **{"tools/" + name + ".py": ROOT / "tools" / (name + ".py")
                           for name in ("astra_prepare_inputs", "astra_render_packet", "astra_repository_snapshot")},
                        **{"design/astra/" + name: PACKET / name for name in JSON_FILES.values()},
                        **{"design/astra/" + name: PACKET / name for name in (
                            data["live_state"]["completeness_source"]["path"],
                            data["live_state"]["completeness_source"]["receipt_path"])}}
        receipt = {
            "schema_version": 1,
            "scope": "Frozen sanitation packet structural/evidence validation; no live Git or runtime claims",
            "base_commit": data["snapshot"]["base_commit"],
            "ledger_evidence_head": data["live_state"]["ledger_evidence_head"],
            "source_sha256": {name: digest(path.read_bytes()) for name, path in sorted(source_paths.items())},
            "tests_run": program.result.testsRun,
            "tests_successful": passed,
            "frozen_packet_errors": validate(data),
            "counts": {"commits": len(data["matrix"]["commits"]),
                       "refs": len(data["matrix"]["refs"]),
                       "master_rows": len(data["ledger"]["rows"])},
            "deterministic_replay": DETERMINISM,
            "actual_cli_red_green": CLI_PROOF,
            "live_renderer_red_fixtures": sorted(LIVE_REJECTIONS, key=lambda r: r["fixture_id"]),
            "red_fixture_results": sorted(OBSERVATIONS, key=lambda row: row["fixture_id"]),
            "red_fixture_exit_semantics": "1 when validate() reports errors, otherwise 0; same validator as --check-packet",
            "limitations": [
                "Frozen Git metadata is checked for internal closure and exact preservation, not rescanned.",
                "Scoped receipts are traced to independent review mapping; this is not fresh human acceptance.",
                "No generated row establishes geometry, audibility, player comprehension, or release quality.",
            ],
        }
        args.evidence.parent.mkdir(parents=True, exist_ok=True)
        args.evidence.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
