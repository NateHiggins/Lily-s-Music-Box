"""Exact real-build marker omission; no live mutation or engine entry point."""
from pathlib import Path
import difflib
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OWNER = Path("game/scripts/reality/apartment_encroachment.gd")
BASE = ROOT / "design/astra/work/encroachment_sweep/revisions/ownership_7c54c_01/originals" / OWNER
BASE_SHA = "7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def omit_build_marker(raw):
    assert sha(raw) == BASE_SHA, "requires exact reviewed 7c54c ownership source"
    start = raw.index(b"func build(layout: Dictionary, floor_nodes: Dictionary, witnesses: Node = null) -> int:")
    match = re.search(rb"(?m)^func ", raw[start + 1:])
    assert match is not None
    end = start + 1 + match.start()
    method = raw[start:end]
    line = b'\t\t\t\tmaterial.set_meta("living_storey", floor_id)\n'
    assert method.count(line) == 1
    return raw[:start] + method.replace(line, b"", 1) + raw[end:]


def is_exact_omission(original, observed):
    try:
        return observed == omit_build_marker(original)
    except (AssertionError, ValueError):
        return False


def main():
    raw = BASE.read_bytes()
    changed = omit_build_marker(raw)
    directory = HERE / "controls/build_marker_omission"
    original = directory / "originals" / OWNER
    proposed = directory / "proposed" / OWNER
    original.parent.mkdir(parents=True, exist_ok=True)
    proposed.parent.mkdir(parents=True, exist_ok=True)
    if original.exists(): assert original.read_bytes() == raw
    else: original.write_bytes(raw)
    proposed.write_bytes(changed)
    patch = "".join(difflib.unified_diff(raw.decode().splitlines(True), changed.decode().splitlines(True),
        fromfile="a/" + OWNER.as_posix(), tofile="b/" + OWNER.as_posix()))
    (directory / "omission.patch").write_bytes(patch.encode())
    receipt = {"status": "PREPARED_UNRUN_NO_LIVE_INSTALL", "owner": OWNER.as_posix(),
        "baseline_sha256": sha(raw), "omission_sha256": sha(changed),
        "only_change": "Remove the single living_storey metadata seed from real build() finish construction",
        "structural_check": is_exact_omission(raw, changed),
        "preserved": ["ownership ancestry guard", "in-place unique registry rebuild", "case prop marker",
                      "nullable living_source guard", "all runtime state callbacks", "renderer helper and viewport boundary"],
        "planned_expected_red": "Actual build publishes finish rows whose original resources lose installed identity/marker after storey refresh; all six cases observed; only named material assertion failures with complete unchanged native/capture/retirement proof.",
        "control_limit": "Runtime red and exact restored green are required; this source preparation is not observed failure evidence."}
    (directory / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
