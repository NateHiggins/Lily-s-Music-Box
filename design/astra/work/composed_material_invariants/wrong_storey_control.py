"""Source-bound foreign-owner corruption; not the healed missing-seed omission."""
from pathlib import Path
import difflib
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
OWNER = Path("game/scripts/reality/apartment_encroachment.gd")
BASE = HERE / "controls/build_marker_omission/originals" / OWNER
BASE_SHA = "7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def corrupt_build_storey(raw):
    assert sha(raw) == BASE_SHA, "requires exact reviewed ownership source"
    start = raw.index(b"func build(layout: Dictionary, floor_nodes: Dictionary, witnesses: Node = null) -> int:")
    match = re.search(rb"(?m)^func ", raw[start + 1:])
    assert match is not None
    end = start + 1 + match.start()
    method = raw[start:end]
    before = b'\t\t\t\tmaterial.set_meta("living_storey", floor_id)\n'
    after = b'\t\t\t\tmaterial.set_meta("living_storey", "F00")\n'
    assert method.count(before) == 1 and after not in raw
    return raw[:start] + method.replace(before, after, 1) + raw[end:]


def is_exact_corruption(original, observed):
    try:
        return corrupt_build_storey(original) == observed
    except (AssertionError, ValueError):
        return False


def main():
    original = BASE.read_bytes()
    changed = corrupt_build_storey(original)
    folder = HERE / "controls/build_wrong_storey"
    for label, raw in (("originals", original), ("proposed", changed)):
        path = folder / label / OWNER
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            assert path.read_bytes() == raw, "do not overwrite an earlier control revision"
        else:
            path.write_bytes(raw)
    patch = "".join(difflib.unified_diff(original.decode().splitlines(True), changed.decode().splitlines(True),
                                       fromfile="a/" + OWNER.as_posix(), tofile="b/" + OWNER.as_posix()))
    (folder / "corruption.patch").write_bytes(patch.encode())
    receipt = {"status": "PREPARED_ONLY; initial actual-build green and row review required before execution",
               "original_sha256": sha(original), "corruption_sha256": sha(changed),
               "transform": 'Only build() finish seed: living_storey=floor_id becomes explicit fixture sentinel "F00"',
               "preserved": "Later missing-marker seed, foreign-owner copying, registry rebuild, all callbacks, renderer and private-world guards",
               "expected_scope": "Foreign-storey corruption of actual built finish rows; stale installed identity and missed immediate finish updates; registry still correct",
               "not_proven": "The original absent-seed omission is repaired by the later binder and is not an expected red",
               "structural_check": is_exact_corruption(original, changed)}
    (folder / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
