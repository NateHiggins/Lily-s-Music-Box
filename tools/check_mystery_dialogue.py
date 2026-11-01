#!/usr/bin/env python3
"""Hold the first-draft mystery dialogue (game/data/mystery) to its own rules.

    python tools/check_mystery_dialogue.py [--render design/mystery_dialogue/READ_ALOUD.md]

Every line is still a draft for the owner's playtest. Failures are structural or rule breaks a machine can
see; whether a line is funny, or right for Adela, stays with people. Each tree
also passes tools/audit_authored_voice.py, which owns the shared tree contract.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
DRAFTS = ROOT / "game/data/mystery"
LIVE_COMPANION = ROOT / "game/data/dialogue/companion.json"
YEAR = ("1928-11-10", "1929-11-09")
DEATH = "1929-07-19"
# The owner signed off the bank's other review lines on 2026-10-30. This one is a
# pitch note and the bank bars it from implementation.
BANK_EXCLUDED = {"JF027"}
# Adela is a woman riding a body the residents take for the night man. They may
# use that job title; nothing else may call the player a man.
MISADDRESS = re.compile(r"\b(sir|mister|young man|my boy|maintenance man)\b", re.I)
# No word here reached anyone in 1929. The owner's lore pass, 2026-10-31.
MODERN_TERMS = re.compile(r"\b(transgender|cisgender|pansexual|transfemme|lgbt\w*|non-binary)\b", re.I)
GAME_TEXT = ("dialogue", "mystery", "opinions", "newspapers")
RESIDENT_FORBIDDEN = re.compile(r"\b(the tenant|signal pro|instrument)\b", re.I)
PRE_DEATH = re.compile(r"\b(late miss|was killed|her death|funeral|the body|she fell|she died)\b", re.I)
# The conclusive chain of section 4.5 and the one telling.
SOLVE = ("m_white_kid", "m_glove_scrap", "m_button_book", "m_route_book", "m_letter_compared", "m_told_nadia")
TREE_CHOICE_KEYS = {"label", "goto", "requires", "evidence", "infer", "trust", "flag"}
TREE_NODE_KEYS = {"line", "choices", "silence_goto", "silence_trust", "flag", "flags", "bank", "speaker"}


def bank_family(bank: str) -> str:
    return bank.split("-")[0]


def targets(node: dict) -> list[str]:
    out = [c["goto"] for c in node.get("choices", []) if "goto" in c]
    if "silence_goto" in node:
        out.append(node["silence_goto"])
    return out


def check_tree(name: str, tree: dict, granted: set[str], required: dict, seen_banks: dict) -> list[str]:
    errors: list[str] = []
    nodes, threads = tree.get("nodes", {}), tree.get("threads", [])
    if not tree.get("meta", {}).get("notes"):
        errors.append(f"{name}: meta.notes is empty")
    reached: set[str] = set()
    ids = set()
    roots: dict[str, str] = {}
    for thread in threads:
        tid = thread["id"]
        if tid in ids:
            errors.append(f"{name}: thread {tid} repeats")
        ids.add(tid)
        if thread["root"] in roots:
            errors.append(f"{name}: {tid} shares root {thread['root']} with {roots[thread['root']]}")
        roots[thread["root"]] = tid
        if not (YEAR[0] <= thread["from"] <= thread["until"] <= YEAR[1]):
            errors.append(f"{name}: {tid} dates fall outside the year or run backwards")
        for flag in thread.get("requires", []) + thread.get("requires_any", []):
            required.setdefault(flag, []).append(f"{name}:{tid}")
        if "requires_any" in thread and len(thread["requires_any"]) < 2:
            errors.append(f"{name}: {tid} requires_any names fewer than two flags")
        stack, walk = [thread["root"]], set()
        while stack:
            node_id = stack.pop()
            if node_id in walk:
                continue
            if node_id not in nodes:
                errors.append(f"{name}: {tid} reaches missing node {node_id}")
                continue
            walk.add(node_id)
            stack.extend(targets(nodes[node_id]))
        reached |= walk
        # A thread wholly before the death may not speak from after it.
        if thread["until"] <= DEATH:
            for node_id in walk & set(nodes):
                match = PRE_DEATH.search(nodes[node_id].get("line", ""))
                if match:
                    errors.append(f"{name}: {tid}/{node_id} speaks from after her death: {match.group(0)!r}")
    for node_id in set(nodes) - reached:
        errors.append(f"{name}: node {node_id} is unreachable")
    for node_id, node in nodes.items():
        unknown = set(node) - TREE_NODE_KEYS
        if unknown:
            errors.append(f"{name}: node {node_id} has unknown fields {sorted(unknown)}")
        line = node.get("line", "")
        if not line:
            errors.append(f"{name}: node {node_id} has no line")
        if node.get("choices") and "silence_goto" not in node:
            errors.append(f"{name}: node {node_id} has choices but no authored silence")
        if MISADDRESS.search(line):
            errors.append(f"{name}: node {node_id} misaddresses the player")
        if RESIDENT_FORBIDDEN.search(line):
            errors.append(f"{name}: node {node_id} names what no resident can know")
        for flag in filter(None, [node.get("flag")]):
            granted.add(flag)
        for flag in node.get("flags", []):
            granted.add(flag)
        if "bank" in node:
            if bank_family(node["bank"]) in BANK_EXCLUDED:
                errors.append(f"{name}: node {node_id} uses excluded bank line {node['bank']}")
            if node["bank"] in seen_banks:
                errors.append(f"{name}: bank line {node['bank']} already used in {seen_banks[node['bank']]}")
            seen_banks[node["bank"]] = f"{name}:{node_id}"
        for choice in node.get("choices", []):
            if set(choice) - TREE_CHOICE_KEYS:
                errors.append(f"{name}: node {node_id} has an unknown choice field")
            if MISADDRESS.search(choice.get("label", "")):
                errors.append(f"{name}: node {node_id} choice misaddresses the player")
            for flag in choice.get("requires", []):
                required.setdefault(flag, []).append(f"{name}:{node_id}")
    return errors


def check_companion(doc: dict, granted: set[str], required: dict, seen_banks: dict) -> list[str]:
    errors: list[str] = []
    live = {line["id"] for line in json.loads(LIVE_COMPANION.read_text(encoding="utf8"))["lines"]}
    ids: set[str] = set()
    for line in doc["lines"]:
        lid = line["id"]
        if lid in live or lid in ids:
            errors.append(f"companion: line id {lid} collides")
        ids.add(lid)
        if not lid.startswith("m_"):
            errors.append(f"companion: line id {lid} has no m_ prefix")
        if line["surface"] == "typed" and not line.get("phrases"):
            errors.append(f"companion: typed line {lid} has no phrases")
        if line["surface"] == "witnessed" and not line.get("witness"):
            errors.append(f"companion: witnessed line {lid} names no witness")
        if MISADDRESS.search(line["text"]):
            errors.append(f"companion: {lid} misaddresses the player")
        if re.search(r"\b(signal pro|the tenant)\b", line["text"], re.I):
            errors.append(f"companion: {lid} knows what it serves")
        for flag in line.get("requires", []):
            required.setdefault(flag, []).append(f"companion:{lid}")
        if "bank" in line:
            if bank_family(line["bank"]) in BANK_EXCLUDED:
                errors.append(f"companion: {lid} uses excluded bank line {line['bank']}")
            if line["bank"] in seen_banks:
                errors.append(f"companion: bank line {line['bank']} already used in {seen_banks[line['bank']]}")
            seen_banks[line["bank"]] = f"companion:{lid}"
    for branch in doc["branches"]:
        for lid in branch["sequence"]:
            if lid not in ids:
                errors.append(f"companion: branch {branch['id']} names missing line {lid}")
    # The ending prints one reply and nothing comes after it.
    if doc["lines"][-1]["id"] != "m_end_keep":
        errors.append("companion: m_end_keep must close the file")
    # A line that grants a flag is the joke ladder's only gate.
    granted |= ids
    return errors


def thread_open(thread: dict, held: set[str]) -> bool:
    any_of = thread.get("requires_any", [])
    return set(thread.get("requires", [])) <= held and (not any_of or bool(set(any_of) & held))


def unlocks(trees: dict[str, dict], carriers: set[str], companion_lines: set[str]) -> set[str]:
    """Every flag a player can come to hold, ignoring dates: visits are free, so
    only a cycle of requirements can make evidence unreachable."""
    held = set(carriers) | companion_lines
    changed = True
    while changed:
        changed = False
        for tree in trees.values():
            for thread in tree["threads"]:
                if not thread_open(thread, held):
                    continue
                stack, walk = [thread["root"]], set()
                while stack:
                    node_id = stack.pop()
                    if node_id in walk:
                        continue
                    walk.add(node_id)
                    node = tree["nodes"][node_id]
                    for flag in [node.get("flag"), *node.get("flags", [])]:
                        if flag and flag not in held:
                            held.add(flag)
                            changed = True
                    stack += [c["goto"] for c in node.get("choices", []) if set(c.get("requires", [])) <= held]
                    if "silence_goto" in node:
                        stack.append(node["silence_goto"])
    return held


def render(trees: dict[str, dict]) -> str:
    out = ["Evidence class: **INERT**", "", "# Mystery dialogue, for reading aloud", "",
           "Generated by `tools/check_mystery_dialogue.py --render`. Edit the JSON beside it.",
           "Every line is PROPOSED. HOLD waits on Mina's canon.", ""]
    for name, tree in sorted(trees.items()):
        speaker = tree["meta"]["speaker_default"]
        out += [f"## {speaker}", "", tree["meta"]["notes"], ""]
        for thread in tree["threads"]:
            tags = [f"{thread['from']} to {thread['until']}"]
            if thread.get("hours"):
                tags.append("-".join(thread["hours"]))
            if thread.get("requires"):
                tags.append("needs " + ", ".join(f"**{f}**" for f in thread["requires"]))
            if thread.get("requires_any"):
                tags.append("needs any of " + ", ".join(f"**{f}**" for f in thread["requires_any"]))
            if thread.get("hold"):
                tags.append("HOLD")
            out += [f"### \"{thread['topic']}\"", "", " · ".join(tags), ""]
            stack, seen = [thread["root"]], []
            while stack:
                node_id = stack.pop(0)
                if node_id in seen:
                    continue
                seen.append(node_id)
                node = tree["nodes"][node_id]
                out.append(f"- **{node.get('speaker', speaker)}** ({node_id}): {node['line']}")
                for choice in node.get("choices", []):
                    gate = " [needs " + ", ".join(choice["requires"]) + "]" if choice.get("requires") else ""
                    out.append(f"  - > {choice['label']}{gate} → {choice['goto']}")
                    stack.append(choice["goto"])
                if "silence_goto" in node:
                    out.append(f"  - (silence) → {node['silence_goto']}")
                    stack.append(node["silence_goto"])
            out.append("")
    return "\n".join(out) + "\n"


def check_modern_terms(data: pathlib.Path) -> list[str]:
    errors: list[str] = []
    for part in GAME_TEXT:
        for path in sorted((data / part).glob("*.json")):
            match = MODERN_TERMS.search(path.read_text(encoding="utf8"))
            if match:
                errors.append(f"{part}/{path.name}: {match.group(0)!r} is not a word of the period")
    return errors


def run(folder: pathlib.Path = DRAFTS) -> tuple[list[str], dict]:
    trees: dict[str, dict] = {}
    for path in sorted(folder.glob("*.json")):
        if path.stem not in {"carriers", "companion_mystery", "object_copy"}:
            trees[path.stem] = json.loads(path.read_text(encoding="utf8"))
    errors: list[str] = []
    granted: set[str] = set()
    required: dict = {}
    banks: dict = {}
    for name, tree in trees.items():
        errors += check_tree(name, tree, granted, required, banks)
    errors += check_companion(json.loads((folder / "companion_mystery.json").read_text(encoding="utf8")),
                              granted, required, banks)
    for item in json.loads((folder / "object_copy.json").read_text(encoding="utf8"))["copy"]:
        if not item.get("surface"):
            errors.append(f"object copy {item['id']} names no surface")
        if item["bank"] in banks:
            errors.append(f"bank line {item['bank']} already used in {banks[item['bank']]}")
        banks[item["bank"]] = f"object_copy:{item['id']}"
    carriers = set(json.loads((folder / "carriers.json").read_text(encoding="utf8"))["carriers"])
    for flag, users in sorted(required.items()):
        if flag not in granted and flag not in carriers:
            errors.append(f"flag {flag} is required by {users[0]} and nothing grants it")
    for flag in sorted(carriers - set(required)):
        errors.append(f"carrier {flag} is required by nothing")
    companion_lines = {line["id"] for line in json.loads(
        (folder / "companion_mystery.json").read_text(encoding="utf8"))["lines"]}
    held = unlocks(trees, carriers, companion_lines)
    for flag in sorted(set(required) - held):
        errors.append(f"flag {flag} can never be earned: its requirements form a cycle")
    for name, tree in trees.items():
        for thread in tree["threads"]:
            if not thread_open(thread, held):
                errors.append(f"{name}: thread {thread['id']} can never open")
    for flag in SOLVE:
        if flag not in held:
            errors.append(f"the case cannot be finished: {flag} is unreachable")
    stats = {"speakers": len(trees), "threads": sum(len(t["threads"]) for t in trees.values()),
             "nodes": sum(len(t["nodes"]) for t in trees.values()),
             "words": sum(len(n.get("line", "").split()) for t in trees.values() for n in t["nodes"].values()),
             "banks": len(banks), "trees": trees}
    return errors, stats


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--render", type=pathlib.Path)
    args = parser.parse_args()
    errors, stats = run()
    errors += check_modern_terms(ROOT / "game/data")
    for error in errors:
        print("FAIL", error)
    print(f"{stats['speakers']} speakers, {stats['threads']} threads, {stats['nodes']} nodes, "
          f"{stats['words']} spoken words, {stats['banks']} bank lines placed, {len(errors)} failures")
    if args.render:
        args.render.write_text(render(stats["trees"]), encoding="utf8", newline="\n")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
