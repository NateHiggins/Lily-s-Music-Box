"""Read-only annual Living Sky image audit. No calendar or game state writes.

python tools/analyze_weather_gallery.py --gallery <annual_final> --out <review>
Requires the project's existing Pillow and NumPy art-tool dependencies.
"""
import argparse
from collections import Counter, defaultdict
from datetime import date, timedelta
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


def analyze(gallery: Path, out: Path) -> dict:
    manifest = gallery / "annual_gallery.json"
    data = json.loads(manifest.read_text(encoding="utf-8"))
    if data.get("samples") != 2190 or len(data.get("days", [])) != 365:
        raise ValueError("Expected the complete six-period, 365-day gallery")
    expected_periods = ["dawn", "morning", "solar_noon", "afternoon", "dusk", "night"]
    if data.get("periods") != expected_periods:
        raise ValueError("Missing or reordered solar periods")
    out.mkdir(parents=True, exist_ok=True)
    pages = {}
    pictures, rows, features, colours = [], [], [], []
    genera, arrangements, regimes, scenarios = Counter(), Counter(), Counter(), Counter()
    seasons = defaultdict(Counter)
    eligible, crosses = Counter(), defaultdict(Counter)
    for expected_day, day in enumerate(data["days"]):
        number = int(day["day"])
        if number != expected_day:
            raise ValueError("Repeated, missing or reordered annual day")
        page_number = number // 16
        if page_number not in pages:
            pages[page_number] = Image.open(gallery / f"year_{page_number:02d}.png").convert("RGB")
            if pages[page_number].size != (960, 1440):
                raise ValueError("Unexpected gallery atlas dimensions")
        if len(day["samples"]) != 6:
            raise ValueError(f"Missing period on day {number}")
        for column, sample in enumerate(day["samples"]):
            expected_date = (date(1928, 11, 10)+timedelta(days=number)).isoformat()
            if str(sample.get("date", ""))[:10] != expected_date or sample.get("period") != expected_periods[column]:
                raise ValueError("Annual sample date/period disagrees with its tile")
            tile = pages[page_number].crop((column*160, number % 16*90, (column+1)*160, number % 16*90+90))
            upper = tile.crop((0, 0, 160, 60))
            pixels = np.asarray(upper, dtype=np.float32) / 255
            mean = pixels.mean(axis=(0, 1))
            gray = np.asarray(upper.convert("L").resize((32, 12), Image.Resampling.BOX), dtype=np.float32)/255
            contrast = float(gray.std())
            centered = gray.flatten()-gray.mean()
            centered /= max(float(np.linalg.norm(centered)), 1e-6)
            features.append(centered)
            colours.append(mean)
            pictures.append(tile)
            state = sample["state"]
            period = str(sample["period"])
            row = {"date": sample["date"], "day": number, "period": period,
                   "regime": state["regime"], "scenario": state["scenario_label"],
                   "scenario_id": state["scenario_id"],
                   "declared_coverage": state["combined_coverage"],
                   "mean_rgb": mean.tolist(), "upper_contrast": contrast,
                   "pixel_sha256": hashlib.sha256(upper.tobytes()).hexdigest()}
            rows.append(row)
            regimes[state["regime"]] += 1
            month = int(sample["date"][5:7])
            season = "winter" if month in (12,1,2) else "spring" if month in (3,4,5) else "summer" if month in (6,7,8) else "autumn"
            seasons[season][period+":"+state["regime"]] += 1
            scenarios[str(state["scenario_id"])] += 1
            eligible.update(map(str, state["eligible_scenarios"]))
            for layer in state["layers"]:
                if float(layer["coverage"]) <= .03:
                    continue
                genus = str(layer["genus"])
                genera[genus] += 1
                arrangements[str(layer["arrangement"])] += 1
                crosses[period][genus] += 1

    matrix, rgb = np.stack(features), np.stack(colours)
    correlation = matrix @ matrix.T
    pairs, by_period = [], {}
    for period in data["periods"]:
        indices = [i for i, r in enumerate(rows) if r["period"] == period]
        nearest = []
        for i in indices:
            candidates = [j for j in indices if abs(rows[j]["day"]-rows[i]["day"]) >= 14]
            j = max(candidates, key=lambda k: float(correlation[i, k]))
            score = float(correlation[i, j])
            distance = float(np.linalg.norm(rgb[i]-rgb[j]))
            nearest.append(score)
            # Low-contrast night/overcast similarity is expected, not automatically a defect.
            if i < j and score > .985 and distance < .08 and min(rows[i]["upper_contrast"], rows[j]["upper_contrast"]) > .015:
                pairs.append({"a": i, "b": j, "correlation": score, "palette_distance": distance})
        contrast = [rows[i]["upper_contrast"] for i in indices]
        by_period[period] = {"count": len(indices), "contrast_p10_p50_p90": np.percentile(contrast, [10, 50, 90]).tolist(),
                             "low_contrast_below_0015": sum(x < .015 for x in contrast),
                             "nonadjacent_nearest_correlation_p50_p90": np.percentile(nearest, [50, 90]).tolist(),
                             "mean_rgb": rgb[indices].mean(axis=0).tolist(), "visible_genera": dict(crosses[period])}
    pairs.sort(key=lambda p: p["correlation"], reverse=True)
    sheet = Image.new("RGB", (1280, max(1, min(12, len(pairs)))*186), "#16181e")
    draw = ImageDraw.Draw(sheet)
    for line, pair in enumerate(pairs[:12]):
        for side, key in enumerate(["a", "b"]):
            index = pair[key]
            sheet.paste(pictures[index].resize((320, 180)), (side*640, line*186))
            draw.text((side*640+324, line*186+4), rows[index]["date"], fill="white")
            draw.text((side*640+324, line*186+22), rows[index]["regime"], fill="white")
            draw.text((side*640+324, line*186+40), f"r={pair['correlation']:.4f}", fill="white")
    sheet.save(out / "repetition_candidates.png")
    # Explicitly inspect flat fields; a small standard deviation does not prove bad cloud relief.
    flat = sorted(range(len(rows)), key=lambda i: rows[i]["upper_contrast"])
    daylight = [i for i in flat if rows[i]["period"] in ("morning", "solar_noon", "afternoon")][:24]
    sheet = Image.new("RGB", (960, 6*120), "#16181e")
    draw = ImageDraw.Draw(sheet)
    for n, i in enumerate(daylight):
        x, y = (n % 4)*240, (n//4)*120
        sheet.paste(pictures[i], (x, y))
        draw.text((x, y+91), rows[i]["date"], fill="white")
        draw.text((x, y+105), f"std={rows[i]['upper_contrast']:.4f} {rows[i]['regime']}", fill="white")
    sheet.save(out / "low_contrast_daylight.png")
    for period in data["periods"]:
        indices = [i for i, row in enumerate(rows) if row["period"] == period]
        panel = Image.new("RGB", (18*160, 21*104), "#16181e")
        pen = ImageDraw.Draw(panel)
        for n, i in enumerate(indices):
            x, y = n % 18*160, n//18*104
            panel.paste(pictures[i], (x, y))
            pen.text((x+2, y+91), rows[i]["date"][:10], fill="white")
        panel.save(out / ("annual_"+period+".jpg"), quality=90, subsampling=0)
    report = {"evidence_class": "INERT", "samples": len(rows), "seed": data["seed"],
              "source_sha256": hashlib.sha256(manifest.read_bytes()).hexdigest(),
              "calendar_sha256": data["calendar_sha256"],
              "scope": "Actual 160x90 atlas thumbnails; upper 160x60 RGB/contrast and brightness-normalized 32x12 similarity. No cloud segmentation, full-resolution relief proof, precipitation qualification or human acceptance.",
              "limitations": ["One bearing and seed; six moments per date, not continuous daily weather.",
                              "Camera/lighting/palette affect correlations. Candidate pairs require visual judgment.",
                              "Declared coverage is authored optical union, not measured cloud pixel coverage.",
                              "Annual bench observer uses fallback precipitation, not the playable FPS GPU path."],
              "genera": dict(genera), "arrangements": dict(arrangements), "regimes": dict(regimes),
              "selected_scenarios": dict(scenarios), "eligible_scenarios": dict(eligible),
              "by_season_period_regime": dict(seasons), "by_period": by_period, "repetition_candidates": pairs, "rows": rows}
    (out / "annual_assessment.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gallery", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    result = analyze(args.gallery, args.out)
    print(json.dumps({"samples": result["samples"], "genera": result["genera"],
                      "selected_scenarios": len(result["selected_scenarios"]),
                      "eligible_scenarios": len(result["eligible_scenarios"]),
                      "repetition_candidates": len(result["repetition_candidates"]),
                      "low_contrast_daylight": sum(v["low_contrast_below_0015"] for k,v in result["by_period"].items() if k in ("morning","solar_noon","afternoon"))}, indent=2))
