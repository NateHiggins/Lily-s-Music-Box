"""Canonical audit-compatible hashes from preserved manifests, without rerunning or rewriting proof."""
import hashlib
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent
bindings = []
for path in sorted(BASE.glob("*/run_receipt.json")):
    receipt = json.loads(path.read_text())
    values = {}
    for label in ["source_before", "source_after"]:
        rows = json.loads((path.parent / (label + ".runtime_inputs.json")).read_text())
        manifest = sorted([row["path"], row["sha256"]] for row in rows)
        encoded = json.dumps(manifest, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
        values[label] = hashlib.sha256(encoded).hexdigest()
    bindings.append({"receipt": path.relative_to(BASE).as_posix(),
                     "receipt_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                     "historical_fixture_digest": receipt["source_before"]["runtime_inputs_sha256"],
                     "canonical_runtime_inputs_sha256": values,
                     "canonical_source_unchanged": values["source_before"] == values["source_after"]})
result = {
    "schema": "astra.historical_notice_canonical_source_binding.v1",
    "reason": "Original custom run receipts used sorted path-NUL-sha-newline framing. These audit-compatible hashes use the same preserved file manifests with the canonical audit JSON encoding. The historical receipts are unchanged.",
    "canonical_encoding": "UTF-8 compact JSON of sorted [relative_posix_path, raw_file_sha256] pairs; no newline; same as tools/audit_orison_v2_completeness.py runtime_inputs_sha256",
    "scope": "Source fingerprint supplement only; composition captures are not admissible structured runtime-contract receipts.",
    "bindings": bindings,
}
target = BASE / "canonical_runtime_bindings.json"
assert not target.exists()
target.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps([row for row in bindings if row["receipt"].startswith("capture_03/")], indent=2))
