"""Command line for the prop reference pipeline. See README.md."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import commons, manifest as mf, priority, sheets

DEFAULT_FETCHED = Path("art/reference/props/_fetched")


def _repo(args) -> Path:
    return Path(args.repo_root).resolve()


def cmd_fetch(args) -> int:
    root = _repo(args)
    data = mf.load_manifest(root / args.manifest)
    queries = mf.load_json(root / args.queries)
    dest_root = root / args.fetched
    only = set(filter(None, (args.kinds or "").split(",")))
    total = 0
    # Six door variants share the door kind's queries; ask Commons once per
    # distinct search in a run and reuse the answer. Downloads are still per
    # specimen, so each provenance record stays complete on its own.
    memo: dict[str, dict] = {}

    def fetch_json(url: str) -> dict:
        if url not in memo:
            memo[url] = commons.default_fetch_json(url)
        return memo[url]

    for record, specimen in zip(data["specimens"], mf.assign_ids(data["specimens"])):
        if only and record.get("kind") not in only:
            continue
        qs = mf.resolve_queries(record, queries)
        if not qs:
            print(f"[fetch] {specimen}: no queries for kind {record.get('kind')!r}")
            continue
        if args.sparse_only:
            have = len(commons._existing_provenance(dest_root / specimen))
            if have >= args.min_files:
                continue
        entry = (queries.get("kinds") or {}).get(record.get("kind"), {})
        fallbacks = commons.fallback_queries(entry.get("display_name", ""), record.get("kind", ""))
        result = commons.fetch_specimen(specimen, qs, dest_root / specimen,
                                        per_query=args.per_query, limit=args.limit,
                                        width=args.width, max_files=args.max_files,
                                        min_files=args.min_files, fallbacks=fallbacks,
                                        fetch_json=fetch_json)
        total += len(result.downloaded)
        print(f"[fetch] {specimen}: {len(result.downloaded)} kept, {len(result.refused)} refused, "
              f"{len(result.errors)} errors")
    print(f"[fetch] {total} reference files under {dest_root}")
    return 0


def cmd_sheets(args) -> int:
    root = _repo(args)
    data = mf.load_manifest(root / args.manifest)
    shot_dir = (root / args.manifest).parent
    queries = mf.load_json(root / args.queries)
    counts = mf.installed_counts(root / "game/data/building_layout.json")
    tiers = mf.load_tiers()
    fetched = root / args.fetched
    out_dir = root / args.out
    entries = []
    for record, ident in zip(data["specimens"], mf.assign_ids(data["specimens"])):
        facts = mf.describe(record, counts, tiers, queries, ident)
        our = []
        for bearing, rel in (record.get("frames") or {}).items():
            if not rel:
                continue
            source = shot_dir / rel
            copy = sheets.downscale(source, out_dir / "frames" / facts["id"] / f"{bearing}.jpg")
            our.append((source, bearing))
            facts.setdefault("frames_small", {})[bearing] = str(copy.relative_to(root).as_posix())
        refs = []
        provenance = fetched / facts["id"] / "provenance.json"
        if provenance.exists():
            prov = json.loads(provenance.read_text(encoding="utf-8"))
            for rec in prov.get("downloaded", []):
                path = fetched / facts["id"] / rec["file"]
                if path.exists():
                    refs.append((path, f"{rec['licence']} | {rec['title'].removeprefix('File:')}"))
                    facts.setdefault("references", []).append({
                        "title": rec["title"], "licence": rec["licence"],
                        "url": rec["descriptionurl"], "artist": rec.get("artist", ""),
                        "local": str(path.relative_to(root).as_posix())})
        facts.setdefault("references", [])
        sheet_path = fetched / facts["id"] / "sheet.jpg"
        if our:
            sheets.build_sheet(facts, our, refs, sheet_path)
            facts["sheet"] = str(sheet_path.relative_to(root).as_posix())
        entries.append(facts)
    json_path, md_path = sheets.write_index(entries, out_dir)
    print(f"[sheets] {len(entries)} specimens -> {json_path} and {md_path}")
    return 0


def cmd_score(args) -> int:
    root = _repo(args)
    index = mf.load_json(root / args.index)
    critiques = priority.load_critiques(root / args.critiques)
    ranked = priority.rank(index["specimens"], critiques)
    out = root / args.out
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"schema": "orison.prop-reference.ranking.v1",
                               "ranked": ranked}, indent=1), encoding="utf-8")
    missing = [r["id"] for r in ranked if not r["score"]["has_critique"]]
    print(f"[score] {len(ranked)} ranked -> {out}; {len(missing)} without a critique")
    for row in ranked[:15]:
        print(f"  {row['rank']:>2}. {row['score']['priority']:6.2f}  {row['kind']:<18} {row['label'][:40]}")
    return 0


def cmd_check(args) -> int:
    from .critiques import validate_directory
    root = _repo(args)
    index = mf.load_json(root / args.index)
    known = {e["id"] for e in index["specimens"]}
    report = validate_directory(root / args.critiques, known)
    bad = {name: errs for name, errs in report.items() if errs}
    covered = {name[:-5] for name in report} & known
    print(f"[check] {len(report)} critique files, {len(bad)} invalid, "
          f"{len(known) - len(covered)} specimens without a critique")
    for name, errs in sorted(bad.items()):
        for err in errs:
            print(f"  {name}: {err}")
    missing = sorted(known - covered)
    if missing:
        print("  missing: " + ", ".join(missing))
    return 1 if bad else 0


def cmd_brief(args) -> int:
    root = _repo(args)
    ranking = mf.load_json(root / args.ranking)
    from .brief import render_brief
    preface = (root / args.preface).read_text(encoding="utf-8") if args.preface else ""
    text = render_brief(ranking["ranked"], title_date=args.date, preface=preface)
    out = root / args.out
    out.write_text(text, encoding="utf-8")
    print(f"[brief] {out} ({len(ranking['ranked'])} specimens)")
    return 0


def cmd_shoot(args) -> int:
    from .review import shoot
    root = _repo(args)
    kinds = [k.strip() for k in args.kinds.split(",") if k.strip()]
    result = shoot(root, kinds, root / args.out, args.tag, lane_wait_s=args.lane_wait * 60)
    print(f"[shoot] exit {result['exit']} -> {result['dir']}")
    for line in result["tail"]:
        print(f"  {line}")
    return 0 if result["exit"] == 0 and result["manifest"] else 1


def cmd_pair(args) -> int:
    from .review import pair
    root = _repo(args)
    kinds = [k.strip() for k in args.kinds.split(",") if k.strip()] or None
    report = pair(root / args.before, root / args.after, root / args.out, args.threshold, kinds)
    flagged = [r for r in report["specimens"] if r["flags"] and r["flags"] != []]
    print(f"[pair] {len(report['specimens'])} specimens -> {root / args.out / 'pair_report.md'}")
    for row in report["specimens"]:
        print(f"  {row['id']}: max change {row['max_change']} {'; '.join(row['flags'])}")
    return 0


def cmd_diff(args) -> int:
    from .review import diff_runs, render_diff
    root = _repo(args)
    kinds = [k.strip() for k in args.kinds.split(",") if k.strip()] or None
    report = diff_runs(root / args.before, root / args.after, kinds)
    text = render_diff(report)
    if args.out:
        out = root / args.out
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text, encoding="utf-8")
        out.with_suffix(".json").write_text(json.dumps(report, indent=1) + "\n", encoding="utf-8")
    print(text)
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=str(mf.REPO_ROOT))
    sub = parser.add_subparsers(dest="command", required=True)

    fetch = sub.add_parser("fetch", help="download licensed references per specimen")
    fetch.add_argument("--manifest", required=True, help="warehouse_manifest.json, repo-relative")
    fetch.add_argument("--queries", default="tools/prop_reference/queries.json")
    fetch.add_argument("--fetched", default=str(DEFAULT_FETCHED))
    fetch.add_argument("--kinds", default="")
    fetch.add_argument("--per-query", type=int, default=3)
    fetch.add_argument("--limit", type=int, default=12)
    fetch.add_argument("--width", type=int, default=800)
    fetch.add_argument("--max-files", type=int, default=8,
                       help="stop once this many reference files exist for a specimen")
    fetch.add_argument("--min-files", type=int, default=3,
                       help="below this, derived plain fallback queries run after the authored ones")
    fetch.add_argument("--sparse-only", action="store_true",
                       help="only visit specimens that still have fewer than --min-files files")
    fetch.set_defaults(func=cmd_fetch)

    sh = sub.add_parser("sheets", help="contact sheets and comparison index")
    sh.add_argument("--manifest", required=True)
    sh.add_argument("--queries", default="tools/prop_reference/queries.json")
    sh.add_argument("--fetched", default=str(DEFAULT_FETCHED))
    sh.add_argument("--out", required=True, help="repo-relative output dir for the index and small frames")
    sh.set_defaults(func=cmd_sheets)

    sc = sub.add_parser("score", help="rank specimens from critiques")
    sc.add_argument("--index", required=True, help="comparison_index.json")
    sc.add_argument("--critiques", required=True, help="directory of per-specimen critique JSON")
    sc.add_argument("--out", required=True)
    sc.set_defaults(func=cmd_score)

    ck = sub.add_parser("check", help="validate critique files against the contract")
    ck.add_argument("--index", required=True)
    ck.add_argument("--critiques", required=True)
    ck.set_defaults(func=cmd_check)

    br = sub.add_parser("brief", help="assemble the markdown brief from the ranking")
    br.add_argument("--ranking", required=True)
    br.add_argument("--out", required=True)
    br.add_argument("--date", required=True)
    br.add_argument("--preface", default="", help="markdown inserted after the header: method, findings, limits")
    br.set_defaults(func=cmd_brief)

    so = sub.add_parser("shoot", help="photograph kinds in the shed for a before/after review")
    so.add_argument("--kinds", required=True, help="comma-separated prop kinds")
    so.add_argument("--out", required=True, help="repo-relative review dir, e.g. art/renders/stove_review")
    so.add_argument("--tag", required=True, help="subdirectory, e.g. before or after; never overwritten")
    so.add_argument("--lane-wait", type=int, default=30, help="minutes to wait for a busy lane")
    so.set_defaults(func=cmd_shoot)

    pa = sub.add_parser("pair", help="before/after sheets, pixel change and census deltas")
    pa.add_argument("--before", required=True, help="repo-relative shoot dir with warehouse_manifest.json")
    pa.add_argument("--after", required=True)
    pa.add_argument("--out", required=True)
    pa.add_argument("--kinds", default="")
    pa.add_argument("--threshold", type=float, default=0.01)
    pa.set_defaults(func=cmd_pair)

    df = sub.add_parser("diff", help="compare two critique runs axis by axis")
    df.add_argument("--before", required=True, help="run dir with ranking.json")
    df.add_argument("--after", required=True)
    df.add_argument("--kinds", default="")
    df.add_argument("--out", default="", help="markdown output (a .json beside it)")
    df.set_defaults(func=cmd_diff)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
