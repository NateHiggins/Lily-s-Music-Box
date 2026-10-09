"""Merge the per-group image-review JSON files (written by the review agents from
the contact sheets) into review_notes.json for the dossier builder.

Space-keyed reviews (review_B1_F01, review_F02 ... review_F06_ROOF) map directly
to area ids. The city review is keyed by sheet and lists stations; each station
is routed to the CITY_* area whose capture_ids patterns match its id (the same
matching the builder uses). Defects become observed bullets prefixed 'Defect:'.
Evidence class INERT.

usage: merge_reviews.py REVIEW_DIR OUT_JSON
"""
from pathlib import Path
import json, sys, importlib.util

review_dir = Path(sys.argv[1]); out = Path(sys.argv[2])
HERE = Path(__file__).resolve().parent.parent
content_dir = HERE / "content"
sys.path.insert(0, str(content_dir))

def load_module(path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); return mod

city_areas = []
for p in sorted(content_dir.glob("areas_*.py")):
    for a in load_module(p).AREAS:
        if a["id"].startswith("CITY_"):
            city_areas.append(a)

def matches(area, station_id):
    for w in area.get("capture_ids", []):
        if station_id == w or (w.endswith("*") and station_id.startswith(w[:-1])):
            return True
    return False

notes = {}
for p in sorted(review_dir.glob("review_*.json")):
    data = json.loads(p.read_text(encoding="utf-8"))
    if p.stem == "review_CITY":
        for sheet, rec in data.items():
            for st in rec.get("stations", []):
                sid = st.get("id", "")
                for a in city_areas:
                    if matches(a, sid):
                        n = notes.setdefault(a["id"], {"observed": [], "interpretations": [], "coverage": "inspected", "stations": 0, "dark": 0})
                        n["stations"] += 1
                        if st.get("lighting") == "dark":
                            n["dark"] += 1
                        for o in st.get("observed", []):
                            n["observed"].append(f"[{sid}] {o}")
                        for d in st.get("defects", []):
                            n["observed"].append(f"[{sid}] Defect: {d}")
            for a in city_areas:
                if any(matches(a, st.get("id", "")) for st in rec.get("stations", [])):
                    n = notes.setdefault(a["id"], {"observed": [], "interpretations": [], "coverage": "inspected", "stations": 0, "dark": 0})
                    for i in rec.get("sheet_interpretation", []):
                        if i not in n["interpretations"]:
                            n["interpretations"].append(i)
        continue
    for sid, rec in data.items():
        n = notes.setdefault(sid, {"observed": [], "interpretations": [], "coverage": "inspected"})
        n["observed"].extend(rec.get("observed", []))
        n["observed"].extend("Defect: " + d for d in rec.get("defects", []))
        n["interpretations"].extend(rec.get("interpretations", []))
        if rec.get("coverage") == "partial":
            n["coverage"] = "partial"
        extras = []
        if rec.get("lighting"):
            extras.append(f"lighting {rec['lighting']}")
        if rec.get("resident_in_frame"):
            extras.append("resident in frame")
        if rec.get("best_tile"):
            extras.append(f"best tile {rec['best_tile']}")
        if extras:
            n["limits"] = "; ".join(extras)
for sid, n in notes.items():
    # de-duplicate while keeping order; cap to keep pages readable
    seen = set(); obs = []
    for o in n["observed"]:
        if o not in seen:
            seen.add(o); obs.append(o)
    n["observed"] = obs[:14]
    seen = set(); itp = []
    for i in n["interpretations"]:
        if i not in seen:
            seen.add(i); itp.append(i)
    n["interpretations"] = itp[:6]
    if n.get("stations") and n.get("dark", 0) >= max(1, n["stations"] * 0.6):
        n["coverage"] = "partial"
    n.pop("stations", None); n.pop("dark", None)
out.write_text(json.dumps({"evidence_class": "INERT", "note": "Image-review notes merged from the per-group contact-sheet reviews; observed bullets are what the frames show, interpretations are readings.", **notes} if False else notes, indent=1, ensure_ascii=False), encoding="utf-8")
print(json.dumps({"areas_with_notes": len(notes), "out": str(out)}))
