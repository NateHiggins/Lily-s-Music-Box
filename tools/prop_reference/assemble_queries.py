"""Fold the query-authoring workflow's output into queries.json.

Input is the workflow's returned list: one item per prop script family with
``authored`` (the proposal) and ``verdict`` (the adversarial check). The
verdict wins: refuted queries are dropped, replacements appended, and a
declared object-class mismatch replaces the proposed real object. Nothing is
invented here; a family whose verdict is missing is kept as proposed and
flagged ``unverified`` so the brief can say so.

    python tools/prop_reference/assemble_queries.py <workflow_result.json> tools/prop_reference/queries.json
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def _clean(queries: list[str]) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for query in queries:
        text = " ".join(str(query).split())
        key = text.lower()
        if text and key not in seen:
            seen.add(key)
            out.append(text)
    return out


def fold(items: list[dict]) -> dict:
    kinds: dict[str, dict] = {}
    families: list[dict] = []
    for item in items:
        if not item:
            continue
        authored = item.get("authored") or {}
        verdict = item.get("verdict") or {}
        verdict_by_kind = {v.get("kind"): v for v in (verdict.get("kinds") or [])}
        family = {"script": item.get("fam"), "kinds": [], "verified": bool(verdict)}
        for proposal in authored.get("kinds") or []:
            kind = proposal.get("kind")
            if not kind:
                continue
            check = verdict_by_kind.get(kind, {})
            refuted = {r.get("query", "").strip().lower() for r in check.get("refuted_queries", [])}
            queries = [q for q in proposal.get("queries", []) if q.strip().lower() not in refuted]
            queries = _clean(queries + list(check.get("replacement_queries", [])))
            real_object = proposal.get("real_object", "")
            mismatch = (check.get("object_class_mismatch") or "").strip()
            if mismatch and check.get("corrected_real_object"):
                real_object = check["corrected_real_object"]
            variants = []
            for variant in proposal.get("variants", []):
                v_queries = [q for q in variant.get("queries", []) if q.strip().lower() not in refuted]
                variants.append({
                    "label_match": variant.get("label_match", "*"),
                    "real_object": variant.get("real_object", ""),
                    "queries": _clean(v_queries),
                    "key_dimensions_m": variant.get("key_dimensions_m", ""),
                    "materials_expected": variant.get("materials_expected", []),
                    "distinguishing_features": variant.get("distinguishing_features", []),
                })
            entry = {
                "display_name": proposal.get("display_name", kind),
                "real_object": real_object,
                "period_note": proposal.get("period_note", ""),
                "queries": queries,
                "materials_expected": proposal.get("materials_expected", []),
                "distinguishing_features": proposal.get("distinguishing_features", []),
                "variants": variants,
                "what_the_script_builds": proposal.get("what_the_script_builds", ""),
                "reviewed_in_notes": bool(proposal.get("reviewed_in_notes", False)),
                "notes_section": proposal.get("notes_section", ""),
                "already_ruled": proposal.get("already_ruled", []),
                "script": item.get("fam"),
                "verified": bool(check),
                "verifier_confidence": check.get("confidence", "unverified"),
                "object_class_mismatch": mismatch,
                "refuted": sorted(refuted),
            }
            kinds[kind] = entry
            family["kinds"].append(kind)
        families.append(family)
    return {
        "schema": "orison.prop-reference.queries.v1",
        "source": "authored per prop script from the script's header, its build code and "
                  "design/PROP_REFERENCE_NOTES.md; adversarially verified against the "
                  "geometry the script builds; folded by assemble_queries.py",
        "families": families,
        "kinds": dict(sorted(kinds.items())),
    }


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    items = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    if isinstance(items, dict) and "result" in items:
        items = items["result"]
    data = fold(items)
    Path(argv[2]).write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    verified = sum(1 for k in data["kinds"].values() if k["verified"])
    print(f"[assemble] {len(data['kinds'])} kinds from {len(data['families'])} families; "
          f"{verified} verified, {len(data['kinds']) - verified} unverified -> {argv[2]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
