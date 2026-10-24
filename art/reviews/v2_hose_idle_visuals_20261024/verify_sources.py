"""INERT raw source/controlled archive checks, not runtime qualification."""
import gzip
import hashlib
import json
from pathlib import Path

PACKET = Path(__file__).resolve().parent
REPO = PACKET.parents[2]
known = {}
for path in PACKET.rglob("*.gz"):
    data = gzip.decompress(path.read_bytes())
    known.setdefault(hashlib.sha256(data).hexdigest(), []).append(path.relative_to(REPO).as_posix())
rows = []
for path in sorted(PACKET.glob("*.log.receipt.json")):
    receipt = json.loads(path.read_text())
    source = receipt.get("source", {})
    wanted = source.get("test_sha256")
    matches = list(known.get(wanted, []))
    live = REPO / source["test_path"]
    if live.exists() and hashlib.sha256(live.read_bytes()).hexdigest() == wanted:
        matches.append(source["test_path"])
    rows.append(dict(receipt=path.relative_to(REPO).as_posix(), test_path=source["test_path"],
                     test_sha256=wanted, source_matches=bool(matches), matching_sources=matches,
                     completed=receipt["execution"]["completed"],
                     exit_code=receipt["execution"]["exit_code"],
                     timed_out=receipt["execution"]["timed_out"]))
result = dict(evidence_class="INERT", scope="Top-level raw source matching only; no reconstruction of every dirty-world input or runtime_contract status.", checks=rows)
(PACKET / "source_checks.json").write_text(json.dumps(result, indent=2) + "\n")
assert rows and all(row["source_matches"] for row in rows)
for row in json.loads((PACKET / "source_final/sources.json").read_text())["sources"]:
    data = gzip.decompress((REPO / row["archive"]).read_bytes())
    assert hashlib.sha256(data).hexdigest() == row["sha256"]
    assert hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest() == row["lf_sha256"]
    assert hashlib.sha256((REPO / row["path"]).read_bytes().replace(b"\r\n", b"\n")).hexdigest() == row["lf_sha256"]
protected = json.loads((PACKET / "protected.json").read_text())["files"]
for row in protected:
    data = (REPO / row["path"]).read_bytes()
    if row["hash_mode"] == "LF-normalized": data = data.replace(b"\r\n", b"\n")
    assert hashlib.sha256(data).hexdigest() == row["sha256"] and row["unchanged_from_previous"]
print(f"{len(rows)} executed sources match; final archives/current LF sources match; {len(protected)} protected paths unchanged")
