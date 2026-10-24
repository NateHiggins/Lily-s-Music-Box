"""INERT provenance checks and raw packet manifest; no qualification claims."""
import gzip
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def main():
    board = load(ROOT/"gates_after/board.json")
    assert not board["comparison"]["regressions"]
    checks = load(ROOT/"source_checks.json")["checks"]
    for check in checks:
        raw = gzip.decompress((ROOT/check["archive"]).read_bytes())
        assert hashlib.sha256(raw).hexdigest()==check["sha256"]
        assert hashlib.sha256(raw.replace(b"\r\n",b"\n")).hexdigest()==check["lf_sha256"]
    protected = load(ROOT/"protected.json")
    for row in protected["files"]:
        path = REPO/row["path"]
        raw = path.read_bytes()
        if path.suffix!=".bin":raw=raw.replace(b"\r\n",b"\n")
        assert hashlib.sha256(raw).hexdigest()==row["sha256"],row["path"]
    rows = []
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or path.name=="artifact_manifest.json" or "__pycache__" in path.parts:
            continue
        raw = path.read_bytes()
        rows.append({"path":path.relative_to(ROOT).as_posix(),"bytes":len(raw),
                     "sha256":hashlib.sha256(raw).hexdigest()})
    data = {"evidence_class":"INERT",
            "scope":"Actual played streaming baseline, halo removal, original fixture failures, diagnostics and sources. No runtime_contract or human acceptance. Manifest excludes itself/Python caches.","files":rows}
    (ROOT/"artifact_manifest.json").write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
    print("Raw source matches",len(checks),"protected",len(protected["files"]),"files",len(rows))


if __name__=="__main__":main()
