"""Family review kit: before/after shoots, pixel and census deltas, run diffs.

Three jobs, used per family while props are rebuilt (RUL-006):

  shoot  photograph one or more kinds in the inspection shed into
         <out>/<tag>/ (warehouse_manifest.json plus frames), through the
         ordinary long runner, so the run keeps the lane contract and its log
         (and its receipt, where the runner writes one).
  pair   match two shoots by specimen id and, for every bearing, measure how
         much the picture changed; tile a before/after sheet per specimen and
         diff the material census (triangles, surfaces, textured surfaces,
         flat-colour share).  A specimen whose census changed but whose
         pixels did not is flagged: the change is not visible from the shed.
  diff   compare two whole critique runs (ranking.json of each): every axis,
         the gap, the priority and the rank, per specimen.

Pixel change is the mean absolute difference of two greyscale thumbnails,
0..1.  The shed is deterministic enough that an unchanged prop measures at
the noise floor; `pair` prints the value, never only a verdict, and the
threshold is a flag, not proof of improvement.  Improvement is the critique's
call, re-scored against the new frames under CRITIQUE_CONTRACT.md.
"""
from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path

from .manifest import assign_ids

THUMB = (320, 240)
DEFAULT_THRESHOLD = 0.01
CENSUS_KEYS = ("triangles", "surfaces", "textured_surfaces", "flat_colour_share")
AXES = ("object_class", "proportion", "silhouette", "detail", "material", "wear", "mount")
EXIT_LANE_BUSY = 73
# The harness's own order (PropWarehouseShot BEARINGS); unknown names follow.
BEARING_ORDER = ("three_quarter", "front", "side", "high_quarter", "back")


def _ordered(bearings) -> list[str]:
    known = [b for b in BEARING_ORDER if b in bearings]
    return known + sorted(b for b in bearings if b not in BEARING_ORDER)


# ---------------------------------------------------------------------------
# shoot
# ---------------------------------------------------------------------------

def shoot(repo: Path, kinds: list[str], out: Path, tag: str, lane_wait_s: int = 1800,
          timeout: int = 1500) -> dict:
    target = (out / tag).resolve()
    if target.exists() and any(target.iterdir()):
        raise ValueError(f"{target} is not empty; shoots never overwrite (use a new tag)")
    target.mkdir(parents=True, exist_ok=True)
    log = target / "shot.log"
    runner = repo / "tools/run_godot_long_suite.ps1"
    command = (f"$env:SHOT_WAREHOUSE_ONLY = '{','.join(kinds)}'; "
               f"& '{runner}' -Scene res://tests/PropWarehouseShot.tscn -ProjectPath '{repo / 'game'}' "
               f"-LogPath '{log}' -TimeoutSeconds {timeout} -Windowed -ShotDir '{target}'; "
               "exit $LASTEXITCODE")
    deadline = time.monotonic() + lane_wait_s
    while True:
        proc = subprocess.run(["pwsh", "-NoProfile", "-Command", command], capture_output=True,
                              text=True, encoding="utf-8", errors="replace")
        if proc.returncode != EXIT_LANE_BUSY or time.monotonic() >= deadline:
            break
        time.sleep(30)
    manifest = target / "warehouse_manifest.json"
    return {"exit": proc.returncode, "dir": target.as_posix(), "log": log.as_posix(),
            "manifest": manifest.as_posix() if manifest.is_file() else None,
            "tail": (proc.stdout + proc.stderr).strip().splitlines()[-4:]}


# ---------------------------------------------------------------------------
# pair
# ---------------------------------------------------------------------------

def _load_manifest(shoot_dir: Path) -> dict:
    path = shoot_dir / "warehouse_manifest.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    ids = assign_ids(data.get("specimens", []))
    return {ident: record for ident, record in zip(ids, data.get("specimens", []))}


def census(record: dict | None) -> dict:
    materials = (record or {}).get("materials") or {}
    return {key: materials.get(key) for key in CENSUS_KEYS}


def pixel_change(a: Path, b: Path) -> float | None:
    from PIL import Image, ImageChops, ImageStat
    if not a.is_file() or not b.is_file():
        return None
    with Image.open(a) as ia, Image.open(b) as ib:
        ga = ia.convert("L").resize(THUMB)
        gb = ib.convert("L").resize(THUMB)
        return round(ImageStat.Stat(ImageChops.difference(ga, gb)).mean[0] / 255.0, 5)


def _sheet(ident: str, bearings: list[str], before: Path, after: Path,
           rb: dict | None, ra: dict | None, changes: dict, out: Path) -> None:
    from PIL import Image, ImageDraw
    pad, label_h = 6, 18
    width = len(bearings) * (THUMB[0] + pad) + pad
    height = 2 * (THUMB[1] + label_h + pad) + label_h + pad
    sheet = Image.new("RGB", (width, height), (24, 24, 24))
    draw = ImageDraw.Draw(sheet)
    draw.text((pad, 2), ident, fill=(230, 230, 230))
    for row, (base, record, name) in enumerate(((before, rb, "before"), (after, ra, "after"))):
        y = label_h + pad + row * (THUMB[1] + label_h + pad)
        for col, bearing in enumerate(bearings):
            x = pad + col * (THUMB[0] + pad)
            rel = ((record or {}).get("frames") or {}).get(bearing)
            caption = f"{name} {bearing}"
            if row == 1 and changes.get(bearing) is not None:
                caption += f"  change {changes[bearing]:.3f}"
            draw.text((x, y), caption, fill=(200, 200, 200))
            if rel and (base / rel).is_file():
                with Image.open(base / rel) as img:
                    sheet.paste(img.convert("RGB").resize(THUMB), (x, y + label_h))
            else:
                draw.rectangle([x, y + label_h, x + THUMB[0], y + label_h + THUMB[1]],
                               outline=(90, 90, 90))
                draw.text((x + 8, y + label_h + 8), "no frame", fill=(160, 160, 160))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, quality=88)


def pair(before: Path, after: Path, out: Path, threshold: float = DEFAULT_THRESHOLD,
         kinds: list[str] | None = None) -> dict:
    mb, ma = _load_manifest(before), _load_manifest(after)
    rows = []
    for ident in sorted(set(mb) | set(ma)):
        rb, ra = mb.get(ident), ma.get(ident)
        kind = (rb or ra).get("kind")
        if kinds and kind not in kinds:
            continue
        bearings = _ordered(set((rb or {}).get("frames", {})) | set((ra or {}).get("frames", {})))
        changes = {}
        for bearing in bearings:
            fb = before / (rb or {}).get("frames", {}).get(bearing, "__missing__")
            fa = after / (ra or {}).get("frames", {}).get(bearing, "__missing__")
            changes[bearing] = pixel_change(fb, fa)
        cb, ca = census(rb), census(ra)
        measured = [v for v in changes.values() if v is not None]
        pixels_changed = any(v > threshold for v in measured)
        census_changed = cb != ca
        flags = []
        if rb is None:
            flags.append("new specimen")
        elif ra is None:
            flags.append("specimen gone")
        elif census_changed and not pixels_changed:
            flags.append("census changed but no bearing shows it")
        elif not census_changed and not pixels_changed:
            flags.append("unchanged")
        missing = [b for b, v in changes.items() if v is None]
        if missing and rb is not None and ra is not None:
            flags.append(f"bearing missing on one side: {', '.join(missing)}")
        sheet = out / "sheets" / f"{ident}.jpg"
        _sheet(ident, bearings, before, after, rb, ra, changes, sheet)
        rows.append({"id": ident, "kind": kind, "label": (ra or rb).get("label"),
                     "census_before": cb, "census_after": ca, "pixel_change": changes,
                     "max_change": max(measured) if measured else None,
                     "flags": flags, "sheet": sheet.as_posix()})
    report = {"schema": "orison.prop-review-pair.v1", "before": before.as_posix(),
              "after": after.as_posix(), "threshold": threshold, "specimens": rows}
    out.mkdir(parents=True, exist_ok=True)
    (out / "pair_report.json").write_text(json.dumps(report, indent=1) + "\n", encoding="utf-8")
    (out / "pair_report.md").write_text(render_pair(report), encoding="utf-8")
    return report


def _fmt(value) -> str:
    if value is None:
        return "-"
    return f"{value:.2f}" if isinstance(value, float) else str(value)


def render_pair(report: dict) -> str:
    lines = [f"# Before/after - {Path(report['before']).name} vs {Path(report['after']).name}", "",
             f"Pixel change is mean absolute greyscale difference (0-1); flag threshold "
             f"{report['threshold']}.", "",
             "| specimen | max change | triangles | textured surfaces | flat colour | flags |",
             "|---|---:|---|---|---|---|"]
    for row in report["specimens"]:
        b, a = row["census_before"], row["census_after"]
        lines.append(
            f"| {row['id']} | {_fmt(row['max_change'])} | "
            f"{_fmt(b['triangles'])} -> {_fmt(a['triangles'])} | "
            f"{_fmt(b['textured_surfaces'])} -> {_fmt(a['textured_surfaces'])} | "
            f"{_fmt(b['flat_colour_share'])} -> {_fmt(a['flat_colour_share'])} | "
            f"{'; '.join(row['flags'])} |")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# diff (two critique runs)
# ---------------------------------------------------------------------------

def _ranked(run: Path) -> dict:
    data = json.loads((run / "ranking.json").read_text(encoding="utf-8"))
    return {row["id"]: row for row in data.get("ranked", [])}


def diff_runs(before: Path, after: Path, kinds: list[str] | None = None) -> dict:
    rb, ra = _ranked(before), _ranked(after)
    rows = []
    for ident in sorted(set(rb) | set(ra)):
        b, a = rb.get(ident), ra.get(ident)
        kind = (b or a)["kind"]
        if kinds and kind not in kinds:
            continue
        axes_b = ((b or {}).get("critique") or {}).get("axes") or {}
        axes_a = ((a or {}).get("critique") or {}).get("axes") or {}
        rows.append({
            "id": ident, "kind": kind,
            "rank": [(b or {}).get("rank"), (a or {}).get("rank")],
            "priority": [((b or {}).get("score") or {}).get("priority"),
                         ((a or {}).get("score") or {}).get("priority")],
            "gap": [((b or {}).get("score") or {}).get("gap"),
                    ((a or {}).get("score") or {}).get("gap")],
            "axes": {axis: [axes_b.get(axis), axes_a.get(axis)] for axis in AXES},
            "census": {key: [(b or {}).get(key), (a or {}).get(key)] for key in CENSUS_KEYS},
            "confidence": [((b or {}).get("critique") or {}).get("confidence"),
                           ((a or {}).get("critique") or {}).get("confidence")],
        })
    return {"schema": "orison.prop-review-diff.v1", "before": before.as_posix(),
            "after": after.as_posix(), "specimens": rows}


def render_diff(report: dict) -> str:
    lines = [f"# Critique diff - {Path(report['before']).name} vs {Path(report['after']).name}", "",
             "Axes are 0-5, higher is closer to the real object; gap is the weighted "
             "shortfall, lower is better.", "",
             "| specimen | gap | priority | rank | " + " | ".join(AXES) + " |",
             "|---|---|---|---|" + "---|" * len(AXES)]
    for row in report["specimens"]:
        def pair_text(values):
            b, a = values
            return f"{_fmt(b)} -> {_fmt(a)}" if b != a else _fmt(b)
        lines.append(f"| {row['id']} | {pair_text(row['gap'])} | {pair_text(row['priority'])} | "
                     f"{pair_text(row['rank'])} | " +
                     " | ".join(pair_text(row["axes"][axis]) for axis in AXES) + " |")
    return "\n".join(lines) + "\n"
