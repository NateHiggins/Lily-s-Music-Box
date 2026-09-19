"""Retain null retirement fields as unknown; never treat them as changed identity."""
from pathlib import Path
import json
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PREVIOUS = HERE.with_name("f01_provider_capture_03")
assert not (HERE / "run.py").exists()
assert (ROOT / "game/tests/vulkan_composed_root_test.gd").read_bytes() == (PREVIOUS / "fixture_original.gd").read_bytes()
source = (PREVIOUS / "run.py").read_text()
source = source.replace("name='f01_provider_'+mode+'_03'", "name='f01_provider_'+mode+'_04'")
source = source.replace("import run as execution", "import run as execution\nfrom capture_lane import census, classify_observations\nexecution.census = census\nexecution.classify_observations = classify_observations")
(HERE / "run.py").write_text(source, encoding="utf-8")
for name in ["fixture_original.gd", "fixture_candidate.gd"]:
    (HERE / name).write_bytes((PREVIOUS / name).read_bytes())
lane = (HERE.with_name("f01_provider_execution_07") / "lane.py").read_text()
lane = lane.replace('text=True)', 'text=True, timeout=15)')
old = '''            if identity in rows and any(rows[identity].get(k) != row.get(k)
                    for k in ("ParentProcessId", "Name", "CommandLine")):
                conflicts.append(row)
            rows[identity] = row'''
new = '''            previous = rows.get(identity, {})
            if any(previous.get(k) is not None and row.get(k) is not None
                    and previous[k] != row[k] for k in ("ParentProcessId", "Name", "CommandLine")):
                conflicts.append(row)
            # CIM may lose CommandLine as a process exits. Preserve the last
            # known value for this exact (PID, creation-time) lifetime.
            rows[identity] = {**previous, **{k: v for k, v in row.items() if v is not None}}'''
assert old in lane
lane = lane.replace(old, new)
lane = lane.replace('if "godot" in row["Name"].lower()]', 'if any(name in row["Name"].lower() for name in ("godot", "blender"))]')
(HERE / "capture_lane.py").write_text(lane, encoding="utf-8")
(HERE / "preparation.json").write_text(json.dumps({"changes": ["preserve known fields when CIM returns null during retirement", "retain Blender refusal", "bound census command time"], "game_changed": False, "engine_launched": False}, indent=2) + "\n")
print("Retirement-aware capture observer prepared; production fixtures unchanged.")
