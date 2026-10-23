"""Independent strict-decoder cases; writes a separate extended packet."""
import base64
import json
import random
from pathlib import Path


def valid(raw):
    try:
        raw.decode("utf-8", "strict")
        return True
    except UnicodeDecodeError:
        return False


def generate():
    bits = bytearray(8192)
    for code in range(65536):
        if valid(code.to_bytes(2, "big")):
            bits[code >> 3] |= 1 << (code & 7)
    rng = random.Random(20261023)
    cases = [bytes([n]) for n in range(256)]
    cases += [rng.randbytes(rng.randrange(65)) for _ in range(6000)]
    for cp in [0, 127, 128, 2047, 2048, 55295, 57344, 65535, 65536, 1114111]:
        raw = chr(cp).encode()
        cases += [raw, b"a" + raw + b"z", b"\0" + raw, raw + b"\0", b"\0\xff"]
    for text in ["c080", "eda080", "f0808080", "f4908080", "f5808080", "e08080",
                 "e09fbf", "edb080", "f08fbfbf", "f48fbfbf", "e282", "f09f92", "e24180"]:
        raw = bytes.fromhex(text)
        cases += [raw, b"a" * 1024 + raw, b"\0" + raw, b"\0a" + raw]
    for _ in range(1000):
        cp = rng.randrange(0x110000)
        if 0xd800 <= cp <= 0xdfff:
            cp = 0x20ac
        raw = chr(cp).encode()
        cases += [b"a" + raw + b"z", raw[:-1], b"a" + raw + b"\xff", raw[:1] + b"\0" + raw[1:]]
    for lead, tail in [(0xe0, b"\x80"), (0xed, b"\xbf"), (0xf0, b"\x80\x80"), (0xf4, b"\xbf\xbf")]:
        for second in range(256):
            raw = bytes([lead, second]) + tail
            cases += [raw, b"ascii" + raw + b"\0"]
    for count in [63, 64, 65, 128]:
        raw = ("é a" * count).encode()
        cases += [raw, raw + b"\xff", raw + b"\0\xff", b"\xff" + raw]
    return {"evidence_class": "INERT", "oracle": "Python strict UTF-8; exhaustive two-byte inputs, seeded random, boundaries, valid Unicode, NUL and run-limit controls.",
            "two_byte_valid_bits": base64.b64encode(bits).decode(),
            "cases": [{"hex": raw.hex(), "valid": valid(raw)} for raw in cases]}


if __name__ == "__main__":
    target = Path(__file__).resolve().parent / "utf8_extended"
    target.mkdir(exist_ok=True)
    (target / "oracle.json").write_text(json.dumps(generate(), indent=2) + "\n", encoding="utf-8")
