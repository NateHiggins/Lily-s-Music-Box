#!/usr/bin/env python3
"""Audit an Orison authored-dialogue tree without pretending to grade prose.

Structural contradictions fail. Stylistic observations are evidence for a
human mouth pass and never change the exit code. This distinction is deliberate:
the owner voice guide is a critical practice, not a bag of banned words.
"""

from __future__ import annotations

import argparse
import collections
import json
import re
import sys
from pathlib import Path
from typing import Any


WORD = re.compile(r"[A-Za-z0-9]+(?:['’][A-Za-z]+)?")
SENTENCE = re.compile(r"[^.!?…]+[.!?…]*")
CORRECTION = re.compile(r"\b(?:is|are|was|were|that's|that is)\s+not\b", re.I)
MEASURE = re.compile(
    r"\b(?:\d+(?:\.\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|"
    r"eleven|twelve|twenty|thirty|forty|fifty|hundred|thousand)\b", re.I
)
INSTITUTION = re.compile(
    r"\b(?:record|caption|file|log|annotation|verdict|certified|caller|"
    r"technician|instruction|draft|testimony|report)\b", re.I
)
BODY_CARRIER = re.compile(
    r"\b(?:hand|hands|jaw|ear|ears|mouth|voice|breath|skin|wrist|finger|"
    r"fingers|face|eye|eyes)\b", re.I
)
PHYSICAL_CARRIER = re.compile(
    r"\b(?:room|door|wall|pipe|radiator|valve|lamp|light|wire|tape|paper|"
    r"card|kettle|machine|receiver|dial|glass)\b", re.I
)
GENERIC_TRAILER = re.compile(
    r"\b(?:not just|more than just|isn't just|everything changes|"
    r"nothing is what it seems|dark secret|comes alive)\b", re.I
)


def words(text: str) -> list[str]:
    return [item.lower().replace("’", "'") for item in WORD.findall(text)]


def load_tree(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read dialogue JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError("dialogue root must be an object")
    return value


def targets(node: dict[str, Any]) -> list[tuple[str, str]]:
    found: list[tuple[str, str]] = []
    silence = node.get("silence_goto")
    if isinstance(silence, str) and silence:
        found.append(("silence_goto", silence))
    for index, choice in enumerate(node.get("choices", [])):
        if isinstance(choice, dict) and isinstance(choice.get("goto"), str):
            found.append((f"choices[{index}].goto", choice["goto"]))
    return found


def reachable(starts: list[str], nodes: dict[str, Any]) -> set[str]:
    seen: set[str] = set()
    pending = list(starts)
    while pending:
        node_id = pending.pop()
        if node_id in seen or node_id not in nodes:
            continue
        seen.add(node_id)
        node = nodes[node_id]
        if isinstance(node, dict):
            pending.extend(target for _, target in targets(node))
    return seen


def ngrams(lines: dict[str, str], size: int = 4) -> list[tuple[str, list[str]]]:
    owners: dict[str, set[str]] = collections.defaultdict(set)
    for node_id, line in lines.items():
        tokens = words(line)
        for index in range(len(tokens) - size + 1):
            owners[" ".join(tokens[index : index + size])].add(node_id)
    repeated = [(phrase, sorted(ids)) for phrase, ids in owners.items()
                if len(ids) >= 3]
    return sorted(repeated, key=lambda item: (-len(item[1]), item[0]))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dialogue", type=Path)
    parser.add_argument("--voice-dir", type=Path)
    parser.add_argument("--strict-takes", action="store_true",
                        help="fail when a node and its expected voice take differ")
    args = parser.parse_args()

    try:
        tree = load_tree(args.dialogue)
    except ValueError as exc:
        print(f"FAIL: {exc}")
        return 2

    failures: list[str] = []
    notices: list[str] = []
    nodes = tree.get("nodes", {})
    entries = tree.get("entries", {})
    meta = tree.get("meta", {})
    if not isinstance(nodes, dict) or not nodes:
        failures.append("nodes must be a non-empty object")
        nodes = {}
    if not isinstance(entries, dict) or not entries:
        failures.append("entries must be a non-empty object")
        entries = {}

    for entry, node_id in entries.items():
        if node_id not in nodes:
            failures.append(f"entry {entry!r} points to missing node {node_id!r}")

    lines: dict[str, str] = {}
    labels: list[tuple[str, str]] = []
    silence_nodes: list[str] = []
    for node_id, raw_node in nodes.items():
        if not isinstance(raw_node, dict):
            failures.append(f"node {node_id!r} is not an object")
            continue
        line = raw_node.get("line")
        if not isinstance(line, str) or not line.strip():
            failures.append(f"node {node_id!r} has no spoken line")
        else:
            lines[node_id] = line.strip()
        choices = raw_node.get("choices", [])
        if not isinstance(choices, list):
            failures.append(f"node {node_id!r} choices is not an array")
            choices = []
        for index, choice in enumerate(choices):
            if not isinstance(choice, dict):
                failures.append(f"node {node_id!r} choice {index} is not an object")
                continue
            label = choice.get("label")
            if not isinstance(label, str) or not label.strip():
                failures.append(f"node {node_id!r} choice {index} has no label")
            else:
                labels.append((node_id, label.strip()))
        for field, target in targets(raw_node):
            if target not in nodes:
                failures.append(
                    f"node {node_id!r} {field} points to missing node {target!r}"
                )
        if isinstance(raw_node.get("silence_goto"), str):
            silence_nodes.append(node_id)

    reached = reachable([str(value) for value in entries.values()], nodes)
    for node_id in sorted(set(nodes) - reached):
        failures.append(f"node {node_id!r} is unreachable from every entry")

    voice_summary = "not checked"
    if args.voice_dir:
        prefix = str(meta.get("voice_prefix", ""))
        voice_status = str(meta.get("voice_status", "unspecified"))
        expected = {f"{prefix}{node_id}.ogg" for node_id in nodes}
        actual = {path.name for path in args.voice_dir.glob(f"{prefix}*.ogg")}
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        voice_summary = (f"{len(actual)} takes / {len(expected)} reserved; "
                         f"status={voice_status}")
        if missing:
            message = f"missing takes: {', '.join(missing)}"
            if args.strict_takes:
                failures.append(message)
            elif voice_status not in {"unvoiced_pending_casting", "text_only"}:
                notices.append(message)
        if extra:
            message = f"orphan takes: {', '.join(extra)}"
            (failures if args.strict_takes else notices).append(message)

    spoken_words = sum(len(words(line)) for line in lines.values())
    choice_words = sum(len(words(label)) for _, label in labels)
    sentences = [sentence.strip() for line in lines.values()
                 for sentence in SENTENCE.findall(line) if sentence.strip()]
    corpus = list(lines.values())

    moves = {
        "correction": sum(bool(CORRECTION.search(line)) for line in corpus),
        "measured detail": sum(bool(MEASURE.search(line)) for line in corpus),
        "institutional carrier": sum(bool(INSTITUTION.search(line)) for line in corpus),
        "body carrier": sum(bool(BODY_CARRIER.search(line)) for line in corpus),
        "physical carrier": sum(bool(PHYSICAL_CARRIER.search(line)) for line in corpus),
    }
    generic = [(node_id, line) for node_id, line in lines.items()
               if GENERIC_TRAILER.search(line)]
    if generic:
        notices.append("generic trailer-language candidates: " + ", ".join(
            node_id for node_id, _ in generic))

    repeated = ngrams(lines)
    if repeated:
        notices.append("four-word phrases used by 3+ nodes: " + "; ".join(
            f"{phrase!r} ({len(ids)})" for phrase, ids in repeated[:8]))

    print("AUTHORED VOICE AUDIT")
    print(f"source: {args.dialogue}")
    print(f"nodes: {len(nodes)} ({len(reached)} reachable)")
    print(f"entries: {len(entries)}")
    print(f"spoken words: {spoken_words}; choice words: {choice_words}")
    average = (sum(len(words(sentence)) for sentence in sentences) / len(sentences)
               if sentences else 0.0)
    print(f"sentences: {len(sentences)}; mean sentence words: {average:.1f}")
    print(f"authored silence: {len(silence_nodes)}/{len(nodes)} nodes")
    print(f"voice: {voice_summary}")
    print("voice-guide observations (non-scoring):")
    for name, count in moves.items():
        print(f"  {name}: {count}/{len(lines)} lines")
    for notice in notices:
        print(f"NOTICE: {notice}")
    for failure in failures:
        print(f"FAIL: {failure}")
    if failures:
        print(f"RESULT: FAIL ({len(failures)} structural contradictions)")
        return 1
    print("RESULT: PASS (structure only; human mouth pass still required)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
