"""Fresh repeat after a PID-reuse false failure; keep the original receipt."""
from pathlib import Path
import importlib.util
import json
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PREVIOUS = HERE.with_name("f01_provider_execution_06")
spec = importlib.util.spec_from_file_location("previous_provider", PREVIOUS / "run.py")
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)
assert not (HERE / "run.py").exists()
out = ROOT / "design/astra/evidence/f01_provider_execution_07"
assert not out.exists()
admission = run.verify_admission()
previous_result = ROOT / "design/astra/evidence/f01_provider_execution_06/03_candidate/result.json"
result = run.read(previous_result)
assert result["actual_native_exit"] == 0
assert result["assessment"]["checks"] == 32
assert result["assessment"]["reasons"] == ["native_lane_ancestry_failed"]
assert not result["lane_contract"]["foreign_engines"]
assert result["restoration"]["status"] == "EXACT_ORIGINAL_ROOT_RESTORED"
assert not run.engines(run.census())
installed = run.read(run.OUT / "install.json")
assert dict(run.core.all_game_rows()) == installed["game_files"]
source = (PREVIOUS / "run.py").read_text()
source = source.replace("evidence/f01_provider_execution_06", "evidence/f01_provider_execution_07")
assert source.count("if __name__=='__main__':") == 1
source = source.replace("if __name__=='__main__':", "from lane import census, classify_observations\n\nif __name__=='__main__':")
(HERE / "run.py").write_text(source, encoding="utf-8")
admission["additional_inputs"]["design/astra/work/f01_provider_execution_07/lane.py"] = run.sha(HERE / "lane.py")
run.dump(HERE / "preflight.json", admission)
(HERE / "inherited_art_warning.json").write_bytes((PREVIOUS / "inherited_art_warning.json").read_bytes())
out.mkdir()
(out / "original_root.gd").write_bytes((run.OUT / "original_root.gd").read_bytes())
installed["previous_failed_result_sha256"] = run.sha(previous_result)
installed["previous_failure_retained"] = True
installed["lane_change"] = "Track CreationDate with PID; retain foreign-engine and same-lifetime conflict refusal."
run.dump(out / "install.json", installed)
print(json.dumps({"status": "FRESH_LIFETIME_AWARE_SEQUENCE_PREPARED", "engine_launched": False}))
