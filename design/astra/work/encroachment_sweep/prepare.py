"""Prepare one transient mesh census on top of the reviewed ownership repair.

Writes only this work package. No live edit, Godot or source adoption.
"""
from pathlib import Path
import argparse
import difflib
import hashlib
import json
import re

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]
REL = "game/scripts/reality/apartment_encroachment.gd"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("ownership_candidate", type=Path)
    parser.add_argument("--revision")
    args = parser.parse_args()
    output = BASE
    if args.revision:
        assert re.fullmatch(r"[A-Za-z0-9_-]+", args.revision)
        output = BASE / "revisions" / args.revision
        output.mkdir(parents=True, exist_ok=False)
    source = args.ownership_candidate.resolve()
    assert source.is_relative_to(ROOT / "design/astra/work"), "reviewed outside-game input required"
    raw = source.read_bytes()
    before = raw.decode("utf-8").replace("\r\n", "\n")
    assert "func _living_candidate(mi: MeshInstance3D, scope: Node) -> bool:" in before
    start = before.index("func reach_props(root: Node) -> int:\n")
    end = before.index("\n\nfunc _apply_prop_states", start)
    method = (BASE / "reach_props.gdfragment").read_text(encoding="utf-8")
    after = before[:start] + method.rstrip() + before[end:]
    records = {}
    for label, data in [("originals", raw), ("proposed", after.encode("utf-8"))]:
        target = output / label / REL
        target.parent.mkdir(parents=True, exist_ok=True)
        assert not target.exists(), "preserve prior preparation; use a reviewed revision"
        target.write_bytes(data)
        records[label] = hashlib.sha256(data).hexdigest()
    patch = "".join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
        fromfile="a/" + REL, tofile="b/" + REL))
    (output / "encroachment_sweep.patch").write_text(patch, encoding="utf-8", newline="\n")
    (output / "reach_props.gdfragment").write_text(method, encoding="utf-8", newline="\n")
    (output / "preparation.json").write_text(json.dumps({
        "status": "PREPARED_NOT_INSTALLED_UNRUN", "source": str(source),
        "file": REL, "sha256": records,
        "scope": "One transient eligible mesh census; existing ownership guard, case precedence, state push, callbacks and final storey refresh retained. No persistent cache or callback suppression."
    }, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
