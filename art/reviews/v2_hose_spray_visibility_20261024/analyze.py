"""INERT spray controls. Signal intervals are not display/input latency."""
import hashlib
import json
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def distribution(values):
    ordered = sorted(values)
    if not ordered:
        return {}
    return dict(n=len(ordered), p50=statistics.median(ordered),
                p95=ordered[int((len(ordered)-1)*.95)],
                p99=ordered[int((len(ordered)-1)*.99)], maximum=max(ordered),
                above100=sum(value > 100 for value in ordered))


result = dict(evidence_class="INERT",
              scope="Actual inherited route and fixed-view signal intervals. Median uses central pair; p95/p99 floor((n-1)*p). Renderer estimates are not exclusive CPU/GPU attribution. No whole-world speedup or runtime qualification claim.",
              runs=[])
for receipt_path in sorted(ROOT.glob("*.log.receipt.json")):
    name = receipt_path.name.removesuffix(".log.receipt.json")
    receipt = read(receipt_path)
    row = dict(name=name, execution=receipt["execution"],
               stderr_bytes=(ROOT/(name+".log.stderr")).stat().st_size)
    folder = ROOT/name
    checks_path = folder/"hose_checks.json"
    if checks_path.exists():
        checks = read(checks_path)
        row.update(checks=len(checks["checks"]), failures=checks["failures"])
    profile_path = folder/"frames.json"
    if profile_path.exists():
        profile = read(profile_path)
        row["input_frame_rows"] = [sample[:7] for sample in profile["samples"]
                                   if sample[0] == "first_spray_input"]
        row["first_spray_input_ms"] = distribution([sample[1] for sample in profile["samples"]
                                                    if sample[0] == "first_spray_input"])
        row["steady_spray_ms"] = distribution([sample[1] for sample in profile["samples"]
                                                if sample[0] == "steady_spray"])
        row["profile_sha256"] = hashlib.sha256(profile_path.read_bytes()).hexdigest()
    row["controls"] = []
    for filename, key in [("spray_visibility.json", "controls"), ("spray_final.json", "views")]:
        path = folder/filename
        if not path.exists():
            continue
        data = read(path)
        for control in data[key]:
            row["controls"].append(dict(name=control.get("name", control.get("id")),
                distributions={column:distribution([sample[column] for sample in control["samples"]])
                               for column in ["wall_ms", "render_cpu_ms", "render_gpu_ms"]}))
    result["runs"].append(row)
(ROOT/"analysis.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8", newline="\n")
for row in result["runs"]:
    print(row["name"], row["execution"]["exit_code"], row.get("checks"), row.get("first_spray_input_ms"))
