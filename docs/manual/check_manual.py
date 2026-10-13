#!/usr/bin/env python3
"""Hold the manual to its own rules. Standard library only; read-only.

    python docs/manual/check_manual.py

Checks, over the operating core and every reference file beside this script:
  MC01  every file states its evidence class in its first 30 lines
  MC02  every section pointer (a section sign with a number, or a core chapter
        such as A7) resolves to a section that exists
  MC03  every file the core's table names exists
  MC04  the core is inside its word budget (it is read in full on day zero)
  MC05  no listed third-party mark or project codename appears (the list is
        kept as SHA-256 digests, so this script spells none of them)
  MC06  no line is long enough to be truncated by an agent's file reader

Exit: 0 clean, 1 findings, 3 usage.
"""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CORE = HERE.parent / "AI_GAME_DEVELOPMENT_MANUAL.md"
CORE_WORD_BUDGET = 9000          # about 12,000 tokens
MAX_LINE = 1900                  # some readers truncate lines at 2,000 characters
SECTION = re.compile(r"§(\d+(?:\.\d+)?)")
CHAPTER = re.compile(r"\bA(\d{1,2})\b(?:\.(\d+))?")
# SHA-256 of each lower-case word that must not appear anywhere in the manual.
BANNED = {
    "0cd60a3213eed53901999817ff72458de5983d9958838b4168a35eb7ee278764",
    "35c60b86dbcfe890aa92a44c68d36debcbc2cc79924dc5d311937ab836c1458c",
    "4f30ca9821db8cfd3b23bf1efd6d707eca448e2e151eff918e9523ff507990ab",
    "6e649ccc4f5484fa486efbfcd59ffc2f2def03a71fa8376a96a0b6826d49677d",
    "8d01416611a03b7c979d6fdee3b16006da68e29b5bd5cbc8785bc0e10205b7e8",
    "9c41108a70ca58b5079cf65be78768af61fa0b04aa3ee1d5c0536dfcfcad8726",
    "c0a4942143e872cd1ae29fc759e04526de2e909ac1732734d38550a29c2e2516",
    "dffbe7770e17cd4f64838240cccbc0355b485f95df78a38cc7b0b9b9ddc2bcf4",
}


def files() -> list[Path]:
    return [CORE] + sorted(HERE.glob("*.md"))


def defined_sections(texts: dict[Path, str]) -> tuple[set[str], set[str]]:
    sections: set[str] = set()
    chapters: set[str] = set()
    for path, text in texts.items():
        in_fence = False
        for line in text.splitlines():
            if line.startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            m = re.match(r"^#{2,4} §(\d+(?:\.\d+)?)\b", line) or re.match(r"^- \*\*§(\d+(?:\.\d+)?)\b", line)
            if m:
                sections.add(m.group(1))
                sections.add(m.group(1).split(".")[0])
            m = re.match(r"^## A(\d{1,2})\. ", line)
            if m and path == CORE:
                chapters.add(m.group(1))
    return sections, chapters


def main() -> int:
    if len(sys.argv) > 1:
        print(__doc__)
        return 3
    findings: list[str] = []
    texts = {p: p.read_text(encoding="utf-8") for p in files() if p.is_file()}
    if CORE not in texts:
        print(f"MC03 the core is missing: {CORE}")
        return 1
    sections, chapters = defined_sections(texts)

    for path, text in texts.items():
        name = path.name
        lines = text.splitlines()
        if not any("Evidence class:" in line for line in lines[:30]):
            findings.append(f"MC01 {name}: no evidence class in the first 30 lines")
        in_fence = False
        for number, line in enumerate(lines, 1):
            if len(line) > MAX_LINE:
                findings.append(f"MC06 {name}:{number}: line of {len(line)} characters")
            if line.startswith("```"):
                in_fence = not in_fence
            # Lists of retired or first-edition numbers name sections that no longer exist here.
            exempt = ("Retired" in line or "First-edition sections its tree cites" in line
                      or (name == "CASES.md" and line.startswith("| §")) or "| First edition |" in line)
            if not exempt:
                for m in SECTION.finditer(line):
                    if m.group(1) not in sections:
                        findings.append(f"MC02 {name}:{number}: §{m.group(1)} is not a section of this edition")
                if not in_fence:
                    for m in CHAPTER.finditer(line):
                        if m.group(1) not in chapters:
                            findings.append(f"MC02 {name}:{number}: A{m.group(1)} is not a chapter of the core")
            for word in re.findall(r"[A-Za-z]+", line):
                if hashlib.sha256(word.lower().encode()).hexdigest() in BANNED:
                    findings.append(f"MC05 {name}:{number}: a listed mark or codename appears")

    for m in re.finditer(r"\| \*\*([A-Z_]+\.md)\*\* \|", texts[CORE]):
        if not (HERE / m.group(1)).is_file():
            findings.append(f"MC03 the core names {m.group(1)}, which is not beside this script")

    words = len(texts[CORE].split())
    if words > CORE_WORD_BUDGET:
        findings.append(f"MC04 the core is {words} words; its budget is {CORE_WORD_BUDGET}")

    total = sum(len(t.split()) for t in texts.values())
    for finding in findings:
        print(finding)
    print(f"check_manual: {'PASS' if not findings else 'FAIL'}  files={len(texts)} sections={len(sections)} "
          f"chapters={len(chapters)} core_words={words}/{CORE_WORD_BUDGET} all_words={total} findings={len(findings)}")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
