"""Move blocked route points to the clear spots OrisonV2RouteProbe suggested.

Reads a probe log, finds every "[<file>] node <name>: ...; clear at [x, y, z]"
line and rewrites that point's coordinates in game/data/orison_v2/<file>,
keeping the file's one-route-per-line layout. When a point is reported twice
(closed doors, then open doors) the later suggestion wins: it clears the open
leaves as well as the furniture. Edges reported without a node are printed for
a hand fix; so are nodes with no clear spot within 0.8 m.

    python tools/apply_route_probe.py <probe.log> [--dry-run]
"""
from pathlib import Path
import argparse
import json
import re

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "game/data/orison_v2"
NODE = re.compile(r"ROUTE PROBE FAIL: \[(?P<file>[^\]]+)\] node (?P<name>\S+): .*clear at \[(?P<x>-?[\d.]+), (?P<y>-?[\d.]+), (?P<z>-?[\d.]+)\]")
OTHER = re.compile(r"ROUTE PROBE FAIL: (.*)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("log")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    moves = {}
    unresolved = []
    for line in Path(args.log).read_text(encoding="utf-8", errors="replace").splitlines():
        found = NODE.search(line)
        if found:
            moves.setdefault(found["file"], {})[found["name"]] = [float(found[a]) for a in "xyz"]
        elif OTHER.search(line):
            unresolved.append(OTHER.search(line).group(1))
    for file, points in sorted(moves.items()):
        path = DATA / file
        text = path.read_text(encoding="utf-8")
        for name, (x, y, z) in points.items():
            pattern = re.compile(r'\["%s",-?[\d.]+,-?[\d.]+,-?[\d.]+\]' % re.escape(name))
            replacement = json.dumps([name, round(x, 2), round(y, 2), round(z, 2)], separators=(",", ":"))
            text, count = pattern.subn(replacement, text)
            print("%s: %s -> [%.2f, %.2f, %.2f] (%d)" % (file, name, x, y, z, count))
        json.loads(text)
        if not args.dry_run:
            path.write_text(text, encoding="utf-8", newline="")
    print("\nnot moved automatically:" if unresolved else "\nall reported points moved")
    for line in unresolved:
        if " node " not in line or "no clear spot" in line:
            print("  " + line)


if __name__ == "__main__":
    main()
