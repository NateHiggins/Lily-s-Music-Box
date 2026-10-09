"""Build the V2 environment design dossier: PDF, HTML companion, dossier.json,
coverage checklist and the editable change register (CSV, JSON, XLSX when
openpyxl is available).

Inputs (all beside this script):
  content/*.py            authored areas (AREAS lists) and FRONT matter
  review_notes.json       per-area observed/interpretation notes from image review
  evidence/sweep_*.json   dossier_sweep.json copies from the capture runs
  evidence/captures/      full-resolution PNG captures (local, not committed)
  census.json             per-space inventory (build_census.py)
  plans/plan_*.png        per-level plan drawings (build_plans.py)

Outputs:
  images/<AREA>_<VIEW>.jpg   review tiles (committed)
  dossier.json, change_register.{csv,json,xlsx}, coverage_checklist.csv
  V2_environment_design_dossier.pdf, dossier.html

Evidence class INERT. Nothing here promotes a ledger status.
"""
from pathlib import Path
import json, csv, hashlib, html, importlib.util, sys, io, re, datetime

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / "game/project.godot").is_file())
PDF = HERE / "V2_environment_design_dossier.pdf"
IMAGES = HERE / "images"; IMAGES.mkdir(exist_ok=True)
EVIDENCE = HERE / "evidence"
import os
CAPTURE_DIRS = [Path(x) for x in os.environ.get("DOSSIER_CAPTURES", "C:/ov/envdossier_out/run1/shots;C:/ov/envdossier_out/run2/shots;C:/ov/envdossier_out/smoke3/shots").split(";")]
TILE_W = 640

def find_capture(name):
    for d in CAPTURE_DIRS:
        if (d / name).is_file():
            return d / name
    return None

from PIL import Image
from reportlab.lib.pagesizes import landscape, A4
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor, white, black
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image as RLImage,
                                PageBreak, KeepTogether, Flowable, CondPageBreak)
from reportlab.lib import enums
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

pdfmetrics.registerFont(TTFont("UI", "C:/Windows/Fonts/segoeui.ttf"))
pdfmetrics.registerFont(TTFont("UIB", "C:/Windows/Fonts/segoeuib.ttf"))
pdfmetrics.registerFont(TTFont("UII", "C:/Windows/Fonts/segoeuii.ttf"))
INK = HexColor("#172d38"); MUTED = HexColor("#52666d"); TEAL = HexColor("#086b74"); GOLD = HexColor("#a26123")
LINE = HexColor("#d1dce0"); PALE = HexColor("#f1f5f7"); RED = HexColor("#8a2d2d")
PAGE = landscape(A4); M = 12 * mm
BODY_W = PAGE[0] - 2 * M

def style(name, **kw):
    base = dict(fontName="UI", fontSize=9.2, leading=12, textColor=INK)
    base.update(kw)
    return ParagraphStyle(name, **base)

S = {
    "h1": style("h1", fontName="UIB", fontSize=22, leading=26),
    "h2": style("h2", fontName="UIB", fontSize=15, leading=18, textColor=TEAL, spaceBefore=6, spaceAfter=3),
    "h3": style("h3", fontName="UIB", fontSize=10.5, leading=13, textColor=TEAL, spaceBefore=5, spaceAfter=2),
    "body": style("body"),
    "small": style("small", fontSize=7.8, leading=9.6, textColor=MUTED),
    "cap": style("cap", fontSize=7.4, leading=9, textColor=MUTED),
    "mono": style("mono", fontName="UI", fontSize=8, leading=10, textColor=INK),
    "eyebrow": style("eyebrow", fontName="UIB", fontSize=8, leading=10, textColor=GOLD),
    "cell": style("cell", fontSize=7.6, leading=9.4),
    "cellb": style("cellb", fontName="UIB", fontSize=7.6, leading=9.4),
    "bullet": style("bullet", fontSize=8.6, leading=11, leftIndent=9, bulletIndent=0),
    "warn": style("warn", fontSize=8.6, leading=11, textColor=RED),
}

def esc(t):
    return html.escape(str(t if t is not None else ""), quote=False)

def P(text, st="body"):
    return Paragraph(esc(text).replace("\n", "<br/>"), S[st])

def PB(text, st="body"):
    """Paragraph allowing inline <b>/<i> tags already present in text."""
    return Paragraph(str(text).replace("\n", "<br/>"), S[st])

def bullets(items, st="bullet"):
    return [Paragraph("&bull; " + esc(i), S[st]) for i in items]

class Bookmark(Flowable):
    def __init__(self, key, title, level=0):
        super().__init__(); self.key, self.title, self.level = key, title, level
        self.width = 0; self.height = 0
    def draw(self):
        self.canv.bookmarkPage(self.key)
        self.canv.addOutlineEntry(self.title, self.key, level=self.level, closed=(self.level == 0))

# ---------------------------------------------------------------- content
def load_module(path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); return mod

content_dir = HERE / "content"
sys.path.insert(0, str(content_dir))
FRONT = load_module(content_dir / "front_matter.py").FRONT
AREAS = []
for p in sorted(content_dir.glob("areas_*.py")):
    AREAS.extend(load_module(p).AREAS)
ids = [a["id"] for a in AREAS]
dups = {i for i in ids if ids.count(i) > 1}
assert not dups, f"duplicate area ids: {dups}"
# review-driven addenda: appended to the named area's changes
if (content_dir / "addenda.py").is_file():
    ADDENDA = load_module(content_dir / "addenda.py").ADDENDA
    by_id = {a["id"]: a for a in AREAS}
    for aid, extra in ADDENDA.items():
        assert aid in by_id, f"addenda for unknown area {aid}"
        by_id[aid].setdefault("changes", []).extend(extra)
    all_change_ids = [c["id"] for a in AREAS for c in a.get("changes", []) if "id" in c]
    cdups = {i for i in all_change_ids if all_change_ids.count(i) > 1}
    assert not cdups, f"duplicate change ids: {cdups}"

notes = json.loads((HERE / "review_notes.json").read_text(encoding="utf-8")) if (HERE / "review_notes.json").is_file() else {}
census = json.loads((HERE / "census.json").read_text(encoding="utf-8"))
sweeps = []
for p in sorted(EVIDENCE.glob("sweep_*.json")):
    sweeps.append(json.loads(p.read_text(encoding="utf-8")))

captures = {}   # area id -> list of capture dicts
for sw in sweeps:
    for sp in sw.get("spaces", []):
        for c in sp.get("captures", []):
            if "image" in c:
                captures.setdefault(sp["id"], []).append(dict(c, space=sp["id"]))
    for c in sw.get("city", []):
        if "image" in c:
            captures.setdefault("city:" + c.get("bucket", "city"), []).append(dict(c))

def city_captures(area):
    """City areas declare which capture ids (or prefixes) belong to them."""
    out = []
    wanted = area.get("capture_ids", [])
    pool = [c for k, v in captures.items() if k.startswith("city:") for c in v]
    for w in wanted:
        for c in pool:
            if c["id"] == w or (w.endswith("*") and c["id"].startswith(w[:-1])):
                if c not in out:
                    out.append(c)
    return out

def tile(src_name, out_name):
    src = find_capture(src_name)
    dst = IMAGES / out_name
    if src is None:
        return None
    if not dst.is_file() or dst.stat().st_mtime < src.stat().st_mtime:
        im = Image.open(src).convert("RGB")
        im.thumbnail((TILE_W, TILE_W))
        im.save(dst, "JPEG", quality=76, optimize=True)
    return dst

KIND_LABEL = {"overview": "Overview", "reverse": "Reverse view", "threshold": "Threshold (from the door)", "detail": "Detail"}

def caption_for(c, area):
    kind = c.get("kind", c.get("bucket", "station"))
    label = KIND_LABEL.get(kind, kind)
    owner = c.get("owner", "")
    feet = c.get("feet", [0, 0, 0])
    custom = (area.get("captions") or {}).get(c.get("image", "")[:-4], "")
    base = f"{label}" + (f" toward {owner}" if kind == "detail" and owner else "") + (f" at {owner}" if kind == "threshold" and owner else "")
    base += f". Station ({feet[0]:.1f}, {feet[1]:.1f}, {feet[2]:.1f}). Teleported inspection, production fixtures, player lamp on."
    return (custom + " " if custom else "") + base

# ---------------------------------------------------------------- assemble areas with evidence
build_sha = FRONT["build"]["sha"]
coverage_rows = []
register = []
for a in AREAS:
    sid = a["id"]
    sp = census["spaces"].get(sid)
    a.setdefault("level", sp["level"] if sp else a.get("level", ""))
    if sp:
        a.setdefault("size_m", sp["size_m"]); a.setdefault("area_m2", sp["area_m2"])
        a.setdefault("resident", sp["resident"]); a.setdefault("unit", sp["unit"])
        a.setdefault("purpose", sp["purpose"]); a.setdefault("class", sp["class"])
        a["inventory"] = {
            "anchors": [x["id"] + ((" [" + str(x["variant"]) + "]") if x.get("variant") else "") for x in sp["anchors"] if x["kind"] != "clearance"],
            "placed": [x["id"] + " (" + str(x["kind"]) + ")" for x in sp["placed"]],
            "doors": [d["id"] for d in sp["doors"]], "openings": [o["id"] for o in sp["openings"]],
            "windows": [w["id"] for w in sp["windows"]], "lighting": [l["kind"] for l in sp.get("room_lighting", [])],
        }
    caps = captures.get(sid, []) if not sid.startswith("CITY_") else city_captures(a)
    a["captures"] = []
    for c in caps:
        out = tile(c["image"], (sid if not sid.startswith("CITY_") else c["id"]) + ("" if sid.startswith("CITY_") else "") + "_" + c["image"][:-4].split("_")[-1] + ".jpg") if not sid.startswith("CITY_") else tile(c["image"], c["image"][:-4] + ".jpg")
        if out is None:
            continue
        a["captures"].append({"file": "images/" + out.name, "source": c["image"], "kind": c.get("kind", c.get("bucket")), "owner": c.get("owner", ""), "feet": c.get("feet"), "caption": caption_for(c, a)})
    n = notes.get(sid, {})
    a.setdefault("evidence", {})
    a["evidence"].setdefault("observed", [])
    a["evidence"].setdefault("interpretations", [])
    a["evidence"]["observed"] = list(n.get("observed", [])) + list(a["evidence"]["observed"])
    a["evidence"]["interpretations"] = list(n.get("interpretations", [])) + list(a["evidence"]["interpretations"])
    # a reviewer may downgrade to partial; authored classes (teleported, n/a) are never upgraded to inspected
    if n.get("coverage") == "partial" and not a.get("coverage"):
        a["coverage"] = "partial"
    a.setdefault("coverage", "inspected" if a["captures"] else "unreviewed")
    a["evidence"]["build"] = FRONT["build"]
    for i, ch in enumerate(a.get("changes", []), 1):
        ch.setdefault("id", f"{sid}-{i:03d}")
        ch["area"] = sid
        register.append(dict(ch))
    coverage_rows.append({"area": sid, "group": a.get("group", ""), "zone": a.get("zone", ""), "level": a.get("level", ""), "coverage": a["coverage"], "captures": len(a["captures"]), "changes": len(a.get("changes", [])), "resident": a.get("resident", "")})

# every semantic space must have an entry
missing_spaces = [s for s in census["spaces"] if s not in ids]
assert not missing_spaces, f"spaces without an area entry: {missing_spaces}"

# ---------------------------------------------------------------- machine-readable outputs
dossier = {"evidence_class": "INERT", "schema": "orison.environment-design-dossier.v1", "title": FRONT["title"], "date": FRONT["date"],
           "build": FRONT["build"], "lighting_state": FRONT["lighting_state"], "method": FRONT["method"], "areas": AREAS, "coverage": coverage_rows,
           "front_matter": {k: v for k, v in FRONT.items() if k not in ("title", "date", "build", "lighting_state", "method")}}
(HERE / "dossier.json").write_text(json.dumps(dossier, indent=1, ensure_ascii=False), encoding="utf-8")
try:
    from status import STATUS  # content/status.py: implementation status per change id
except ImportError:
    STATUS = {}
for r in register:
    r.update({k: v for k, v in STATUS.get(r.get("id"), {}).items() if k in ("status", "owner_notes")})
FIELDS = ["id", "area", "priority", "action", "title", "objects", "placement", "dimensions", "construction", "materials", "wear", "lighting", "sound", "purpose", "sources", "dependencies", "preserve", "acceptance", "status", "owner_notes"]
with (HERE / "change_register.csv").open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=FIELDS, extrasaction="ignore")
    w.writeheader()
    for r in register:
        row = {k: ("; ".join(v) if isinstance(v, list) else v) for k, v in r.items()}
        row.setdefault("status", "proposed"); row.setdefault("owner_notes", "")
        w.writerow(row)
(HERE / "change_register.json").write_text(json.dumps({"evidence_class": "INERT", "schema": "orison.environment-change-register.v1", "fields": FIELDS, "changes": register}, indent=1, ensure_ascii=False), encoding="utf-8")
try:
    import openpyxl
    from openpyxl.styles import Font, Alignment
    wb = openpyxl.Workbook(); ws = wb.active; ws.title = "changes"
    ws.append(FIELDS)
    for r in register:
        row = {k: ("; ".join(v) if isinstance(v, list) else v) for k, v in r.items()}
        row.setdefault("status", "proposed"); row.setdefault("owner_notes", "")
        ws.append([row.get(k, "") for k in FIELDS])
    for cell in ws[1]:
        cell.font = Font(bold=True)
    for col, width in zip("ABCDEFGHIJKLMNOPQRST", [18, 20, 7, 8, 32, 30, 36, 20, 30, 28, 24, 24, 20, 36, 30, 24, 24, 36, 10, 24]):
        ws.column_dimensions[col].width = width
    for row in ws.iter_rows(min_row=2):
        for cell in row:
            cell.alignment = Alignment(wrap_text=True, vertical="top")
    ws2 = wb.create_sheet("coverage"); ws2.append(list(coverage_rows[0].keys()))
    for r in coverage_rows:
        ws2.append(list(r.values()))
    wb.save(HERE / "change_register.xlsx")
except ImportError:
    pass
with (HERE / "coverage_checklist.csv").open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(coverage_rows[0].keys())); w.writeheader(); w.writerows(coverage_rows)
if "--register-only" in sys.argv:
    print(json.dumps({"register_only": True, "changes": len(register), "with_status": sum(1 for r in register if r.get("status") not in (None, "proposed"))}))
    sys.exit(0)

# ---------------------------------------------------------------- PDF
def header_footer(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(TEAL); canvas.rect(0, PAGE[1] - 6, PAGE[0], 6, fill=1, stroke=0)
    canvas.setFont("UIB", 8); canvas.setFillColor(INK); canvas.drawString(M, PAGE[1] - 18, "ORISON V2 / ENVIRONMENT DESIGN DOSSIER")
    canvas.setFont("UI", 8); canvas.setFillColor(MUTED)
    canvas.drawRightString(PAGE[0] - M, PAGE[1] - 18, f"build {build_sha[:12]} / {FRONT['date']} / INERT review and design, not acceptance")
    canvas.setStrokeColor(LINE); canvas.line(M, 22, PAGE[0] - M, 22)
    canvas.drawString(M, 11, "Teleported inspection views under production lighting unless a caption says otherwise. Proposed backstory is labelled; canon is cited.")
    canvas.drawRightString(PAGE[0] - M, 11, str(doc.page))
    canvas.restoreState()

doc = SimpleDocTemplate(str(PDF), pagesize=PAGE, leftMargin=M, rightMargin=M, topMargin=M + 10, bottomMargin=M + 8,
                        title=FRONT["title"], author="Orison development / environment design review", subject=FRONT["subtitle"])
story = []
# cover
story.append(Bookmark("cover", "Cover"))
story.append(Spacer(1, 30)); story.append(P(FRONT["title"], "h1")); story.append(Spacer(1, 4))
story.append(P(FRONT["subtitle"], "h2")); story.append(Spacer(1, 8))
story.append(P(f"Build {FRONT['build']['sha']} ({FRONT['build']['branch']}), captured {FRONT['build']['captured']}. {FRONT['lighting_state']}", "body"))
story.append(Spacer(1, 6))
n_areas = len(AREAS); n_caps = sum(len(a["captures"]) for a in AREAS); n_changes = len(register)
story.append(P(f"{n_areas} areas / {n_caps} captioned views / {n_changes} numbered changes / evidence class INERT", "eyebrow"))
story.append(Spacer(1, 10))
for para in FRONT["cover_paragraphs"]:
    story.append(P(para)); story.append(Spacer(1, 4))
story.append(PageBreak())

# front sections
for sec in FRONT["sections"]:
    story.append(Bookmark("front_" + re.sub(r"\W+", "_", sec["title"]).lower(), sec["title"]))
    story.append(P(sec["title"], "h2"))
    for block in sec["blocks"]:
        if isinstance(block, str):
            story.append(PB(block)); story.append(Spacer(1, 4))
        elif block.get("bullets"):
            story.extend(bullets(block["bullets"])); story.append(Spacer(1, 4))
        elif block.get("table"):
            data = [[Paragraph(esc(c), S["cellb"]) for c in block["table"][0]]] + [[Paragraph(esc(c), S["cell"]) for c in r] for r in block["table"][1:]]
            widths = block.get("widths")
            t = Table(data, colWidths=[BODY_W * w for w in widths] if widths else None, repeatRows=1)
            t.setStyle(TableStyle([("GRID", (0, 0), (-1, -1), 0.3, LINE), ("BACKGROUND", (0, 0), (-1, 0), PALE), ("VALIGN", (0, 0), (-1, -1), "TOP")]))
            story.append(t); story.append(Spacer(1, 6))
        elif block.get("warning"):
            story.append(P(block["warning"], "warn")); story.append(Spacer(1, 4))
    story.append(PageBreak())

# plans
plans = sorted((HERE / "plans").glob("plan_*.png")) if (HERE / "plans").is_dir() else []
if plans:
    story.append(Bookmark("plans", "Level plans with capture stations"))
    story.append(P("Level plans with capture stations", "h2"))
    story.append(P("Drawn from game/data/orison_v2_blockout.json: fills by class, orange doors, grey openings, blue windows; dots are authored anchors (brown furniture, violet fixture, red interaction); capture stations are coloured by view kind with a short line showing the camera direction (green overview, blue reverse, orange threshold, purple detail)."))
    for pl in plans:
        im = Image.open(pl); ratio = im.height / im.width
        w = BODY_W; h = w * ratio
        if h > PAGE[1] - 2 * M - 60:
            h = PAGE[1] - 2 * M - 60; w = h / ratio
        story.append(KeepTogether([Spacer(1, 4), RLImage(str(pl), width=w, height=h), P(pl.stem.replace("plan_", "Level "), "cap")]))
    story.append(PageBreak())

# coverage checklist
story.append(Bookmark("coverage", "Area checklist"))
story.append(P("Complete area checklist", "h2"))
story.append(P("Every semantic space of the V2 blockout (200) plus the city, bar, bodega and street areas. Coverage: inspected = captured and reviewed in this pass; teleported = interior reached only by teleport (sealed, restricted or inaccessible in play); partial = captured but obstructed or incomplete; unreviewed = no usable capture."))
rows = [["Area", "Group", "Zone", "Coverage", "Views", "Changes"]] + [[r["area"], r["group"], r["zone"], r["coverage"], str(r["captures"]), str(r["changes"])] for r in coverage_rows]
data = [[Paragraph(esc(c), S["cellb" if i == 0 else "cell"]) for c in row] for i, row in enumerate(rows)]
t = Table(data, colWidths=[BODY_W * w for w in (0.17, 0.30, 0.10, 0.17, 0.08, 0.08)], repeatRows=1)
t.setStyle(TableStyle([("GRID", (0, 0), (-1, -1), 0.25, LINE), ("BACKGROUND", (0, 0), (-1, 0), PALE), ("VALIGN", (0, 0), (-1, -1), "TOP")]))
story.append(t); story.append(PageBreak())

# areas
current_group = None
for a in AREAS:
    sid = a["id"]
    if a.get("group") != current_group:
        current_group = a.get("group")
        story.append(Bookmark("group_" + re.sub(r"\W+", "_", current_group), current_group, 0))
        if a.get("group_intro"):
            story.append(P(current_group, "h2")); story.append(PB(a["group_intro"])); story.append(PageBreak())
    story.append(CondPageBreak(120))
    story.append(Bookmark("area_" + sid, f"{sid}  {a.get('title','')}", 1))
    story.append(P(a.get("group", ""), "eyebrow"))
    story.append(P(f"{sid}  -  {a.get('title', '')}", "h2"))
    ident = []
    ident.append(f"Location: {a.get('location', '')}")
    ident.append(f"Users: {a.get('users', a.get('resident', ''))}")
    if a.get("size_m"):
        ident.append(f"Authored rect {a['size_m'][0]} x {a['size_m'][1]} m ({a.get('area_m2','')} m2); class {a.get('class','')}; purpose: {a.get('purpose','')}")
    ident.append(f"Coverage: {a['coverage']}. Build {build_sha[:12]}; {FRONT['lighting_state_short']}")
    story.extend(bullets(ident, "small"))
    # images
    caps = a["captures"][:6]
    if caps:
        cols = 3 if len(caps) > 2 else len(caps)
        cw = (BODY_W - 6 * (cols - 1)) / cols
        cells = []
        for c in caps:
            img_path = HERE / c["file"]
            im = Image.open(img_path); ratio = im.height / im.width
            cells.append([RLImage(str(img_path), width=cw, height=cw * ratio), Paragraph(esc(c["caption"]), S["cap"])])
        rows_ = [cells[i:i + cols] for i in range(0, len(cells), cols)]
        for r in rows_:
            while len(r) < cols:
                r.append("")
        t = Table(rows_, colWidths=[cw] * cols, hAlign="LEFT")
        t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 6), ("TOPPADDING", (0, 0), (-1, -1), 2), ("BOTTOMPADDING", (0, 0), (-1, -1), 4)]))
        story.append(t)
    elif not str(a["coverage"]).startswith("n/a"):
        story.append(P("No usable capture for this area in this pass (see coverage).", "warn"))
    ev = a["evidence"]
    obs = ev.get("observed") or (["No specific defect observed at overview distance; detail acceptance is not implied."] if not str(a["coverage"]).startswith("n/a") else ["See the room pages cited in each change."])
    interp = ev.get("interpretations") or []
    left = [P("OBSERVED (what the frames show)", "h3")] + bullets(obs)
    right = [P("INTERPRETATION (what it means for this room)", "h3")] + bullets(interp)
    t = Table([[left, right]], colWidths=[BODY_W * 0.5, BODY_W * 0.5])
    t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 0)]))
    story.append(t)
    if ev.get("limits"):
        story.append(P("Limits: " + ev["limits"], "small"))
    story.append(P("ROOM NARRATIVE", "h3")); story.append(PB(a.get("narrative", "")))
    if a.get("canon"):
        story.append(P("Canon used: " + "; ".join(a["canon"]), "small"))
    if a.get("proposed_backstory"):
        story.append(P("PROPOSED BACKSTORY (not canon until ruled)", "h3")); story.extend(bullets(a["proposed_backstory"]))
    inv = a.get("inventory")
    if inv and (inv["anchors"] or inv["placed"]):
        story.append(P("Installed today (census): " + "; ".join(inv["anchors"] + inv["placed"]), "small"))
    changes = a.get("changes", [])
    if changes:
        story.append(CondPageBreak(110))
        story.append(P("NUMBERED CHANGES", "h3"))
        rows_ = [[Paragraph(x, S["cellb"]) for x in ["ID / priority / action", "Change", "Placement, dimensions, construction", "Materials, wear, light, sound", "Purpose / acceptance"]]]
        for ch in changes:
            objs = ch.get("objects", [])
            c1 = f"<b>{esc(ch['id'])}</b><br/>{esc(ch.get('priority',''))} {esc(ch.get('action',''))}"
            c2 = f"<b>{esc(ch.get('title',''))}</b>" + (f"<br/><i>Objects:</i> {esc(', '.join(objs) if isinstance(objs, list) else objs)}" if objs else "")
            c3 = "<br/>".join(f"<i>{k.capitalize()}:</i> {esc(ch[k])}" for k in ("placement", "dimensions", "construction") if ch.get(k))
            c4 = "<br/>".join(f"<i>{k.capitalize()}:</i> {esc(ch[k])}" for k in ("materials", "wear", "lighting", "sound") if ch.get(k))
            c5 = "<br/>".join(f"<i>{k.capitalize()}:</i> {esc(ch[k]) if not isinstance(ch[k], list) else esc('; '.join(ch[k]))}" for k in ("purpose", "sources", "dependencies", "preserve", "acceptance") if ch.get(k))
            rows_.append([Paragraph(c1, S["cell"]), Paragraph(c2, S["cell"]), Paragraph(c3, S["cell"]), Paragraph(c4, S["cell"]), Paragraph(c5, S["cell"])])
        t = Table(rows_, colWidths=[BODY_W * w for w in (0.11, 0.19, 0.24, 0.22, 0.24)], repeatRows=1)
        t.setStyle(TableStyle([("GRID", (0, 0), (-1, -1), 0.25, LINE), ("BACKGROUND", (0, 0), (-1, 0), PALE), ("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 3), ("RIGHTPADDING", (0, 0), (-1, -1), 3)]))
        story.append(t)
    impl = a.get("implementation")
    if impl:
        story.append(P("IMPLEMENTATION AND ACCEPTANCE", "h3"))
        lines = []
        if impl.get("sources"):
            lines.append("Sources: " + "; ".join(impl["sources"]))
        for k in ("dependencies", "preserved", "acceptance"):
            if impl.get(k):
                lines.append(k.capitalize() + ": " + impl[k])
        story.extend(bullets(lines, "small"))
    story.append(Spacer(1, 10))
    story.append(PageBreak())

doc.build(story, onFirstPage=header_footer, onLaterPages=header_footer)

# ---------------------------------------------------------------- HTML companion
parts = []
for a in AREAS:
    figs = "".join(f'<figure><a href="{esc(c["file"])}" target="_blank"><img loading="lazy" src="{esc(c["file"])}"></a><figcaption>{esc(c["caption"])}</figcaption></figure>' for c in a["captures"])
    chs = "".join(f'<tr><td><b>{esc(ch["id"])}</b><br>{esc(ch.get("priority",""))} {esc(ch.get("action",""))}</td><td><b>{esc(ch.get("title",""))}</b><br>{esc(", ".join(ch.get("objects",[])) if isinstance(ch.get("objects"),list) else esc(ch.get("objects","")))}</td><td>' + "<br>".join(f"<i>{k}:</i> {esc(ch[k])}" for k in ("placement","dimensions","construction") if ch.get(k)) + '</td><td>' + "<br>".join(f"<i>{k}:</i> {esc(ch[k])}" for k in ("materials","wear","lighting","sound") if ch.get(k)) + '</td><td>' + "<br>".join(f"<i>{k}:</i> {esc(ch[k]) if not isinstance(ch[k],list) else esc('; '.join(ch[k]))}" for k in ("purpose","sources","dependencies","preserve","acceptance") if ch.get(k)) + '</td></tr>' for ch in a.get("changes", []))
    obs = "".join(f"<li>{esc(x)}</li>" for x in a["evidence"].get("observed", []))
    interp = "".join(f"<li>{esc(x)}</li>" for x in a["evidence"].get("interpretations", []))
    bs = "".join(f"<li>{esc(x)}</li>" for x in a.get("proposed_backstory", []))
    parts.append(f'<article id="{esc(a["id"])}"><div class="eyebrow">{esc(a.get("group",""))}</div><h2>{esc(a["id"])} <span>{esc(a.get("title",""))}</span></h2><p class="meta">{esc(a.get("location",""))} / users: {esc(a.get("users", a.get("resident","")))} / coverage: {esc(a["coverage"])}</p><div class="images">{figs}</div><div class="cols"><div><h3>Observed</h3><ul>{obs}</ul></div><div><h3>Interpretation</h3><ul>{interp}</ul></div></div><h3>Narrative</h3><p>{a.get("narrative","")}</p>' + (f'<h3>Proposed backstory</h3><ul>{bs}</ul>' if bs else "") + (f'<h3>Changes</h3><table><tr><th>ID</th><th>Change</th><th>Placement / dimensions / construction</th><th>Materials / wear / light / sound</th><th>Purpose / sources / acceptance</th></tr>{chs}</table>' if chs else "") + '</article>')
nav = "".join(f'<a href="#{esc(a["id"])}">{esc(a["id"])}</a> ' for a in AREAS)
doc_html = f'''<!doctype html><html lang="en"><meta charset="utf-8"><title>{esc(FRONT["title"])}</title><style>
body{{margin:0;background:#eaf0f2;color:#172d38;font:15px/1.5 Segoe UI,Arial,sans-serif}}header{{background:#102f3a;color:#fff;padding:28px 32px}}main{{max-width:1500px;margin:auto;padding:20px}}nav{{font-size:12px;line-height:2;padding:10px 0}}nav a{{color:#0a6873;margin-right:4px}}article{{background:#fff;border-radius:10px;padding:22px;margin:22px 0;scroll-margin-top:16px}}.eyebrow{{color:#a26123;font-size:12px;text-transform:uppercase;letter-spacing:.08em}}h2 span{{color:#52666d;font-weight:normal;font-size:18px}}.meta{{color:#52666d;font-size:13px}}.images{{display:flex;flex-wrap:wrap;gap:10px}}figure{{margin:0;width:31%;min-width:260px}}img{{width:100%;background:#111}}figcaption{{font-size:11px;color:#52666d}}.cols{{display:grid;grid-template-columns:1fr 1fr;gap:20px}}table{{border-collapse:collapse;width:100%;font-size:12px}}td,th{{border:1px solid #d1dce0;padding:5px;vertical-align:top;text-align:left}}th{{background:#f1f5f7}}
</style><header><h1>{esc(FRONT["title"])}</h1><p>{esc(FRONT["subtitle"])} / build {esc(build_sha)} / {esc(FRONT["date"])} / INERT</p></header><main><nav>{nav}</nav>{"".join(parts)}</main></html>'''
(HERE / "dossier.html").write_text(doc_html, encoding="utf-8", newline="\n")

from pypdf import PdfReader
reader = PdfReader(str(PDF))
summary = {"evidence_class": "INERT", "pdf": PDF.name, "pages": len(reader.pages), "sha256": hashlib.sha256(PDF.read_bytes()).hexdigest(), "size_mb": round(PDF.stat().st_size / 1024 ** 2, 2),
           "areas": n_areas, "captures": n_caps, "changes": n_changes, "built": datetime.datetime.now().isoformat(timespec="seconds")}
(HERE / "pdf_validation.json").write_text(json.dumps(summary, indent=1), encoding="utf-8")
print(json.dumps(summary))
