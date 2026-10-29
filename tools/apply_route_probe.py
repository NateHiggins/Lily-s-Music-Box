"""Move blocked route points to the clear spots OrisonV2RouteProbe suggested.

Reads a probe log, finds every "[<file>] node <name>: ...; clear at [x, y, z]"
line and rewrites that point's coordinates in game/data/orison_v2/<file>,
keeping the file's one-route-per-line layout. When a point is reported twice
(closed doors, then open doors) the later suggestion wins: it clears the open
leaves as well as the furniture. A blocked edge reported with "route via"
gains those waypoints, named <a>_to_<b>_<n>; one reported with only "detour
at" gains a <a>_via_<b> waypoint there. Findings with no clear spot within
0.8 m are printed for a hand fix.

    python tools/apply_route_probe.py <probe.log> [--dry-run]
"""
from pathlib import Path
import argparse
import json
import re

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "game/data/orison_v2"
NODE = re.compile(r"ROUTE PROBE FAIL: \[(?P<file>[^\]]+)\] node (?P<name>\S+): .*clear at \[(?P<x>-?[\d.]+), (?P<y>-?[\d.]+), (?P<z>-?[\d.]+)\]")
EDGE = re.compile(r"ROUTE PROBE FAIL: \[(?P<file>[^\]]+)\] edge (?P<a>\S+) -> (?P<b>\S+) at .*(?:detour at|route via) (?P<points>(?:\[-?[\d.]+, -?[\d.]+, -?[\d.]+\] ?)+)")
TRIPLE = re.compile(r"\[(-?[\d.]+), (-?[\d.]+), (-?[\d.]+)\]")
POINT = r'\["%s",-?[\d.]+,-?[\d.]+,-?[\d.]+\]'
OTHER = re.compile(r"ROUTE PROBE FAIL: (.*)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("log")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    moves = {}
    detours = {}
    unresolved = []
    for line in Path(args.log).read_text(encoding="utf-8", errors="replace").splitlines():
        found = NODE.search(line)
        edge = EDGE.search(line)
        if found:
            moves.setdefault(found["file"], {})[found["name"]] = [float(found[a]) for a in "xyz"]
        elif edge:
            detours.setdefault(edge["file"], {})[(edge["a"], edge["b"])] = [
                [float(v) for v in triple] for triple in TRIPLE.findall(edge["points"])]
        elif OTHER.search(line):
            unresolved.append(OTHER.search(line).group(1))
    for file in sorted(set(moves) | set(detours)):
        path = DATA / file
        text = path.read_text(encoding="utf-8")
        for name, (x, y, z) in moves.get(file, {}).items():
            pattern = re.compile(POINT % re.escape(name))
            replacement = json.dumps([name, round(x, 2), round(y, 2), round(z, 2)], separators=(",", ":"))
            text, count = pattern.subn(replacement, text)
            print("%s: %s -> [%.2f, %.2f, %.2f] (%d)" % (file, name, x, y, z, count))
        # A blocked edge gains the probe's waypoints, inserted wherever that
        # edge is walked in that direction.
        for (a, b), points in detours.get(file, {}).items():
            pattern = re.compile("(%s)(,)(%s)" % (POINT % re.escape(a), POINT % re.escape(b)))
            if len(points) == 1:
                names = ["%s_via_%s" % (a, b)]
            else:
                names = ["%s_to_%s_%d" % (a, b, n + 1) for n in range(len(points))]
            via = ",".join(json.dumps([name, round(x, 2), round(y, 2), round(z, 2)], separators=(",", ":"))
                           for name, (x, y, z) in zip(names, points))
            text, count = pattern.subn(lambda m: m.group(1) + "," + via + "," + m.group(3), text)
            print("%s: %s -> %s via %s (%d)" % (file, a, b, points, count))
        json.loads(text)
        if not args.dry_run:
            path.write_text(text, encoding="utf-8", newline="")
    print("\nnot moved automatically:" if unresolved else "\nall reported points moved")
    for line in unresolved:
        if " node " not in line or "no clear spot" in line:
            print("  " + line)


if __name__ == "__main__":
    main()
