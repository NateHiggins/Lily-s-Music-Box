"""Export recording sheets, make Omni voice requests, and align recorded WAVs."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
PROFILES = ROOT / "game/data/voice/voice_profiles.json"
TOKEN = re.compile(r"[a-z0-9]+(?:_[a-z0-9]+)*")
SHAPES = frozenset("ABCDEFGHX")


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key {key!r}")
        result[key] = value
    return result


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=unique_object)


def fingerprint(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def line_id(tree: str, node: str) -> str:
    if not isinstance(tree, str) or not isinstance(node, str) \
            or not TOKEN.fullmatch(tree) or not TOKEN.fullmatch(node):
        raise ValueError(f"Unsafe tree or node ID {tree!r}, {node!r}")
    return f"{tree}__{node}"


def load_profiles(path: Path) -> dict:
    doc = read_json(path)
    if doc.get("schema_version") != 1 or not isinstance(doc.get("profiles"), list):
        raise ValueError("Unsupported voice profile registry")
    entries = doc["profiles"]
    if not all(isinstance(profile, dict) and isinstance(profile.get("id"), str) for profile in entries):
        raise ValueError("Voice profile entries require an ID")
    doc["profiles"] = {profile["id"]: profile for profile in entries}
    if len(doc["profiles"]) != len(entries):
        raise ValueError("Duplicate voice profile ID")
    for key, profile in doc["profiles"].items():
        if not TOKEN.fullmatch(key):
            raise ValueError(f"Unsafe voice profile ID {key!r}")
        for field in ("display_name", "voice_description", "delivery_direction"):
            if not isinstance(profile.get(field), str) or not profile[field].strip():
                raise ValueError(f"Voice profile {key} lacks {field}")
        if profile.get("delivery") not in {"spoken", "written", "silent"}:
            raise ValueError(f"Invalid delivery for {key}")
        if type(profile.get("seed")) is not int or not 0 <= profile["seed"] < 2**31:
            raise ValueError(f"Invalid generation seed for {key}")
        for variant in profile.get("variants", []):
            if variant not in doc["profiles"] or variant == key:
                raise ValueError(f"Unknown voice variant {variant!r} for {key}")
    return doc


def recording_lines(dialogue_dir: Path, registry: dict) -> list[dict]:
    rows = []
    speakers = {profile["display_name"].casefold(): key
                for key, profile in registry["profiles"].items()}
    paths = sorted(dialogue_dir.glob("*.json"))
    if not paths:
        raise ValueError(f"No dialogue JSON in {dialogue_dir}")
    for path in paths:
        doc = read_json(path)
        profile_id = "companion" if path.stem == "prologue" else path.stem
        if profile_id not in registry["profiles"]:
            raise ValueError(f"No voice profile for dialogue tree {path.stem}")
        profile = registry["profiles"][profile_id]
        meta = doc.get("meta", {})
        if isinstance(doc.get("nodes"), dict):
            nodes = sorted(doc["nodes"].items())
        else:
            key = "messages" if "messages" in doc else "lines"
            if not isinstance(doc.get(key), list):
                raise ValueError(f"Unsupported dialogue shape in {path}")
            nodes = [(node["id"], node) for node in doc[key]]
        for node_id, node in nodes:
            identity = line_id(path.stem, node_id)
            if not isinstance(node, dict):
                raise ValueError(f"Invalid dialogue node {identity}")
            node_profile_id = profile_id
            node_profile = profile
            text = node.get("line", node.get("text"))
            if not isinstance(text, str) or not text.strip():
                raise ValueError(f"Empty or non-text line {identity}")
            speaker = node.get("speaker", meta.get("speaker_default", profile["display_name"]))
            if not isinstance(speaker, str) or not speaker.strip():
                raise ValueError(f"Empty speaker for {identity}")
            if "speaker" in node:
                node_profile_id = speakers.get(speaker.casefold())
                if node_profile_id is None:
                    raise ValueError(f"No voice profile for speaker {speaker!r} in {identity}")
                node_profile = registry["profiles"][node_profile_id]
            delivery = node_profile["delivery"]
            if node.get("spoken") is False:
                delivery = "written"
            if node.get("delivery") in {"written", "silent"}:
                delivery = node["delivery"]
            rows.append({
                "line_id": identity, "tree": path.stem, "node_id": node_id,
                "speaker": speaker, "profile_id": node_profile_id, "delivery": delivery,
                "text": text, "text_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
                "wav_filename": identity + ".wav" if delivery == "spoken" else "",
                "cues_filename": identity + ".cues.json" if delivery == "spoken" else "",
                "voice_description": node_profile["voice_description"],
                "delivery_direction": node_profile["delivery_direction"],
            })
    rows.sort(key=lambda row: row["line_id"])
    if len({row["line_id"] for row in rows}) != len(rows):
        raise ValueError("Duplicate line identity in dialogue")
    return rows


def voice_request(registry: dict, profile_id: str, text: str,
                  reference_root: Path | None = None, performance_note: str = "") -> dict:
    profile = registry["profiles"][profile_id]
    if profile["delivery"] != "spoken":
        raise ValueError(f"{profile_id} is {profile['delivery']}; no spoken voice request")
    if profile.get("variants"):
        raise ValueError(f"Choose a distinct speaker profile from {profile['variants']}")
    if not text.strip():
        raise ValueError("A voice request needs authored text")
    args = {"text": text, "seed": profile["seed"]}
    reference = profile.get("reference")
    if reference:
        if reference_root is None:
            raise ValueError(f"{profile_id} has a selected voice; supply --reference-root")
        name = reference["file"]
        if Path(name).name != name or not name.endswith(".wav"):
            raise ValueError("Unsafe voice reference filename")
        path = reference_root / name
        if fingerprint(path) != reference["sha256"]:
            raise ValueError(f"Voice reference changed for {profile_id}")
        args.update(like=str(path.resolve()), ref_text=reference["text"])
    else:
        if profile.get("requires_reference"):
            raise ValueError(f"{profile_id} needs a supplied voice reference before generation")
        args["voice"] = " ".join((
            profile["voice_description"], profile.get("accent_direction", ""),
            profile["delivery_direction"], performance_note, registry["recording_direction"]))
    return {"kind": "voice", "args": args}


def validate_cues(doc: dict) -> None:
    if not isinstance(doc, dict) or not isinstance(doc.get("mouthCues"), list):
        raise ValueError("Rhubarb output has no mouthCues array")
    if not isinstance(doc.get("metadata"), dict):
        raise ValueError("Rhubarb output has no metadata record")
    duration = doc["metadata"].get("duration")
    if type(duration) not in (float, int) or not math.isfinite(duration) or duration < 0:
        raise ValueError("Rhubarb output has an invalid duration")
    end = 0.0
    for cue in doc["mouthCues"]:
        if not isinstance(cue, dict):
            raise ValueError("Rhubarb cue is not a record")
        start, stop = cue.get("start"), cue.get("end")
        if any(type(t) not in (float, int) or not math.isfinite(t) for t in (start, stop)):
            raise ValueError("Rhubarb cue has an invalid timestamp")
        if start < end - 0.000001 or stop <= start or stop > duration + 0.011:
            raise ValueError("Rhubarb cues overlap or exceed the audio duration")
        if cue.get("value") not in SHAPES:
            raise ValueError("Rhubarb cue has an unknown mouth shape")
        end = stop
    if duration > 0 and not doc["mouthCues"]:
        raise ValueError("Nonempty audio has no mouth cues")


def align_wavs(wav_dir: Path, output_dir: Path, rows: list[dict],
               rhubarb: str, timeout: float = 300, evidence_dir: Path | None = None) -> list[Path]:
    sources = sorted(path for path in wav_dir.iterdir()
                     if path.is_file() and path.suffix.lower() == ".wav")
    if not sources:
        raise ValueError(f"No WAV recordings in {wav_dir}")
    catalog = {row["line_id"]: row for row in rows}
    for source in sources:
        if source.stem not in catalog or catalog[source.stem]["delivery"] != "spoken":
            raise ValueError(f"Unknown or unspoken recording ID {source.stem}")
    output_dir.mkdir(parents=True, exist_ok=True)
    outputs = []
    for source in sources:
        row = catalog[source.stem]
        before = fingerprint(source)
        with tempfile.TemporaryDirectory(prefix=".rhubarb-", dir=output_dir) as temporary:
            staging = Path(temporary)
            hint = staging / "dialogue.txt"
            hint.write_text(row["text"], encoding="utf-8")
            pending = staging / "cues.json"
            command = [rhubarb, "-f", "json", "--extendedShapes", "GHX", "-d", str(hint),
                       "-o", str(pending), str(source.resolve())]
            evidence = evidence_dir / source.stem if evidence_dir is not None else None
            if evidence is not None and evidence.exists():
                raise ValueError(f"Refusing to overwrite alignment evidence: {evidence}")
            try:
                result = subprocess.run(command, capture_output=True, text=True,
                    encoding="utf-8", errors="replace", timeout=timeout)
            except Exception as error:
                if evidence is not None:
                    shutil.copytree(staging, evidence)
                    (evidence / "failure.txt").write_text(repr(error), encoding="utf-8")
                    (evidence / "command.json").write_text(json.dumps(command), encoding="utf-8")
                raise
            if evidence is not None:
                shutil.copytree(staging, evidence)
                (evidence / "command.json").write_text(json.dumps(command), encoding="utf-8")
                (evidence / "result.json").write_text(json.dumps({"exit_code": result.returncode,
                    "stdout": result.stdout, "stderr": result.stderr}), encoding="utf-8")
            if result.returncode:
                raise ValueError(f"Rhubarb failed for {source.name}: {result.stderr[-2000:]}")
            doc = read_json(pending)
            validate_cues(doc)
            if fingerprint(source) != before:
                raise ValueError(f"Recording changed during alignment: {source}")
            # Keep Rhubarb's schema and timings while making the source filename portable.
            doc["metadata"]["soundFile"] = source.name
            pending.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            target = output_dir / (source.stem + ".cues.json")
            os.replace(pending, target)
            outputs.append(target)
    return outputs


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profiles", type=Path, default=PROFILES)
    parser.add_argument("--dialogue-dir", type=Path, default=ROOT / "game/data/dialogue")
    commands = parser.add_subparsers(dest="command", required=True)
    sheet = commands.add_parser("sheet", help="Export a CSV with spoken and written lines")
    sheet.add_argument("--out", type=Path, required=True)
    request = commands.add_parser("request", help="Print an Omni Studio voice request")
    selection = request.add_mutually_exclusive_group(required=True)
    selection.add_argument("--line-id")
    selection.add_argument("--profile-id")
    words = request.add_mutually_exclusive_group()
    words.add_argument("--text", help="Authored words when selecting a profile directly")
    words.add_argument("--audition", action="store_true", help="Use this profile's proposed casting line")
    request.add_argument("--reference-root", type=Path)
    cues = commands.add_parser("cues", help="Run Rhubarb over named WAV recordings")
    cues.add_argument("--wavs", type=Path, required=True)
    cues.add_argument("--out-dir", type=Path, default=ROOT / "game/data/voice")
    cues.add_argument("--rhubarb", default=os.environ.get("RHUBARB_EXE") or shutil.which("rhubarb"))
    cues.add_argument("--timeout", type=float, default=300)
    args = parser.parse_args()
    try:
        registry = load_profiles(args.profiles)
        if args.command == "request" and args.profile_id:
            text = registry["profiles"][args.profile_id].get("audition_text", "") if args.audition else args.text
            if text is None:
                parser.error("--profile-id requires --text or --audition")
            intent = registry["profiles"][args.profile_id].get("audition_intent", "") if args.audition else ""
            print(json.dumps(voice_request(registry, args.profile_id, text, args.reference_root, intent), indent=2))
            return
        rows = recording_lines(args.dialogue_dir, registry)
        if args.command == "sheet":
            args.out.parent.mkdir(parents=True, exist_ok=True)
            with args.out.open("w", encoding="utf-8-sig", newline="") as stream:
                writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
                writer.writeheader()
                writer.writerows(rows)
            print(f"Wrote {len(rows)} lines to {args.out}")
        elif args.command == "request":
            if args.text is not None or args.audition:
                parser.error("--line-id uses the exact authored dialogue text")
            row = next((row for row in rows if row["line_id"] == args.line_id), None)
            if row is None or row["delivery"] != "spoken":
                parser.error("Select an existing spoken line ID")
            print(json.dumps(voice_request(registry, row["profile_id"], row["text"], args.reference_root), indent=2))
        else:
            if not args.rhubarb or not math.isfinite(args.timeout) or args.timeout <= 0:
                parser.error("Provide --rhubarb and a positive finite --timeout")
            for path in align_wavs(args.wavs, args.out_dir, rows, args.rhubarb, args.timeout):
                print(path)
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        parser.exit(1, f"Voice intake failed: {error}\n")


if __name__ == "__main__":
    main()
