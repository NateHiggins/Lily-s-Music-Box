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
    for record in data["specimens"]:
        if only and record.get("kind") not in only:
            continue
        specimen = mf.specimen_id(record)
        qs = mf.resolve_queries(record, queries)
        if not qs:
            print(f"[fetch] {specimen}: no queries for kind {record.get('kind')!r}")
            continue
        result = commons.fetch_specimen(specimen, qs, dest_root / specimen,
                                        per_query=args.per_query, limit=args.limit,
                                        width=args.width)
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
    for record in data["specimens"]:
        facts = mf.describe(record, counts, tiers, queries)
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


def cmd_brief(args) -> int:
    root = _repo(args)
    ranking = mf.load_json(root / args.ranking)
    from .brief import render_brief
    text = render_brief(ranking["ranked"], title_date=args.date)
    out = root / args.out
    out.write_text(text, encoding="utf-8")
    print(f"[brief] {out} ({len(ranking['ranked'])} specimens)")
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

    br = sub.add_parser("brief", help="assemble the markdown brief from the ranking")
    br.add_argument("--ranking", required=True)
    br.add_argument("--out", required=True)
    br.add_argument("--date", required=True)
    br.set_defaults(func=cmd_brief)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
