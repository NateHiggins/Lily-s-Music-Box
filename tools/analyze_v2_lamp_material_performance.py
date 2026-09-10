"""Summarize the scoped native shader and paired GPU evidence; never award V2 acceptance."""
import hashlib
import json
import statistics
from pathlib import Path
from PIL import Image, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parents[1]
PACKET = ROOT / "design/astra/evidence/v2_lamp_material_performance_01"


def summarize():
    result = {"scope": "air/dust material response and 1280x720 composed paired GPU timing",
              "release_acceptance": False, "paired_runs": {}}
    for name in ("material_02", "composed_02", "paired_02", "paired_03"):
        assert (PACKET / (name + ".log.stderr")).read_bytes() == b"", name
    assert "5 checks; 0 failures" in (PACKET / "material_02.log").read_text()
    assert "35 checks; 0 failures" in (PACKET / "composed_02.log").read_text()
    for name in ("paired_02", "paired_03"):
        data = json.loads((PACKET / name / "paired_profile.json").read_text())
        rows = []
        for item in data["intervals"]:
            pairs = item["pairs_view0_view1_ms"]
            assert len(pairs) == 120 and all(a > 0 and b > 0 for a, b in pairs)
            delta = sorted(b-a for a, b in pairs)
            rows.append({"fog_by_view": item["fog_by_view"],
                         "view1_minus_view0_median_ms": statistics.median(delta),
                         "view1_minus_view0_p95_ms": delta[114]})
        medians = [x["view1_minus_view0_median_ms"] for x in rows]
        # Opposite assignments cancel a constant renderer-order bias.
        # Null controls retain evidence that the bias is not fully constant.
        estimates = [(medians[2]-medians[1])/2, (medians[4]-medians[5])/2]
        result["paired_runs"][name] = {"intervals": rows,
            "balanced_atmosphere_estimates_ms": estimates,
            "injection_gpu_median_us": statistics.median(data["injection_gpu_us"]),
            "injection_gpu_max_us": max(data["injection_gpu_us"])}
    a = Image.open(PACKET / "paired_03/fog_optimization_reference.png").convert("RGB")
    b = Image.open(PACKET / "paired_03/fog_optimization_candidate.png").convert("RGB")
    assert a.size == b.size == (1280, 720)
    difference = ImageChops.difference(a, b)
    maximum = max(high for low, high in difference.getextrema())
    assert maximum <= 1, "optimization changed image beyond one 8-bit code value"
    result["fog_optimization_image_difference"] = {
        "max_8bit_code_value": maximum,
        "mean_rgb_8bit_code_values": ImageStat.Stat(difference).mean}
    result["dust_measurements"] = json.loads((PACKET / "material_02/measurements.json").read_text())
    state = ROOT / "game/scripts/lamp/lamp_optical_state.gd"
    result["preserved_controller_sha256"] = hashlib.sha256(state.read_bytes()).hexdigest()
    assert result["preserved_controller_sha256"] == "ffda7e1f985e72ceb18b62d2959a9cd13c743bfba653b31d2be74ab6e82e8604"
    (PACKET / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


if __name__ == "__main__":
    summarize()
    print("Lamp material/performance evidence verified; full material and release gates remain open.")
