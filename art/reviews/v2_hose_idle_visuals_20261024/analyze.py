"""INERT idle control distributions and installed-input diagnostic counts."""
import hashlib
import json
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def distribution(values):
    ordered = sorted(values)
    return dict(n=len(ordered), p50=statistics.median(ordered),
                p95=ordered[int((len(ordered)-1)*.95)],
                p99=ordered[int((len(ordered)-1)*.99)], maximum=max(ordered))


idle_path = ROOT / "before_v1/idle_visuals.json"
idle = json.loads(idle_path.read_text(encoding="utf-8"))
result = dict(evidence_class="INERT",
              scope="No production optimization. Median uses the central pair; p95/p99 use floor((n-1)*p). No whole-route performance or runtime qualification claim.",
              source_sha256=hashlib.sha256(idle_path.read_bytes()).hexdigest(),
              helpers=idle["helpers"], scheduled_helpers=idle["scheduled_original"],
              manual_calls_ms=distribution(idle["manual_all_helpers_ms"]),
              treatments=[dict(name=row["name"], wall_ms=distribution(row["wall_ms"]))
                          for row in idle["treatments"]], runs=[])
for name in ["before_v1", "union_v1", "gasket_v1", "nozzle_v1", "chain_v1"]:
    receipt_path = ROOT / (name + ".log.receipt.json")
    if not receipt_path.exists():
        continue
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    checks = json.loads((ROOT/name/"hose_checks.json").read_text(encoding="utf-8"))
    row = dict(name=name, execution=receipt["execution"],
               top_level_checks=len(checks["checks"]), failures=checks["failures"])
    union_path = ROOT/name/"installed_union.json"
    if union_path.exists():
        union = json.loads(union_path.read_text(encoding="utf-8"))
        for part in ["nozzle", "gasket"]:
            row[part+"_checks"] = len(union.get(part+"_checks", []))
            row[part+"_failures"] = union.get(part+"_failures", [])
    result["runs"].append(row)
(ROOT/"analysis.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8", newline="\n")
print(json.dumps(result, indent=2))
