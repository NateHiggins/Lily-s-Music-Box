extends RefCounted
## The dream programmes' own schema-2 runtime contract (RUL-003, RUL-011): the test writes it, binding the run to the
## repository head, the runtime-input digest and the LF-normalized bytes of the test and the sources it exercises,
## read before and after the run. A wrapper receipt is not this. Written to $DREAM_RECEIPT_DIR, never over earlier
## evidence.

const SOURCES := [
	"res://scripts/dream/dream_parkour.gd", "res://scripts/dream/dream_maze_root.gd",
	"res://scripts/dream/dream_body_trail.gd", "res://scripts/dream/dream_threshold_membranes.gd",
	"res://scripts/dream/dream_room_builder.gd", "res://scripts/dream/dream_pursuer.gd",
	"res://scripts/dream/dream_resident_day.gd", "res://scripts/dream/dream_atlas.gd",
	"res://scripts/player/player_controller.gd", "res://scripts/building/orison_v2_domestic_furniture.gd",
	"res://scripts/building/orison_v2_native_domestic_furniture.gd", "res://scripts/building/orison_v2_native_domestic_storage.gd",
	"res://scripts/building/orison_v2_native_domestic_objects.gd", "res://scripts/building/orison_v2_work_tables.gd",
	"res://data/orison_v2/domestic_furniture.json", "res://data/orison_v2/domestic_seating.json",
	"res://data/orison_v2/domestic_tables.json", "res://data/orison_v2/domestic_storage.json",
	"res://data/orison_v2/domestic_objects.json", "res://data/dream_module_catalog.json", "res://data/dream_profiles.json",
]

var _started := 0
var _before: Dictionary = {}
var _paths: Array = []


func begin(test_script: String, test_scene: String) -> void:
	_started = Time.get_ticks_msec()
	_paths = [test_script, test_scene, "res://tests/dream_contract_receipt.gd"] + SOURCES
	_before = sources()


func sources() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var digest: Array = []
	var head: Array = []
	OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], digest)
	OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head)
	var bound := {}
	for path: String in _paths:
		bound["game/" + path.trim_prefix("res://")] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text() \
				if FileAccess.file_exists(path) else ""
	return {"runtime_inputs_sha256": str(digest[0]).strip_edges() if not digest.is_empty() else "",
		"repository_head": str(head[0]).strip_edges() if not head.is_empty() else "", "dependencies_lf_sha256": bound}


## Writes the contract; returns extra failures (an unstable source, a missing binding, a refused write).
func finish(name: String, test_script: String, test_scene: String, scope: String, checks: int, failures: Array) -> Array[String]:
	var problems: Array[String] = []
	var after := sources()
	if after != _before:
		problems.append("runtime and LF source bindings changed during the run")
	for path: String in after.dependencies_lf_sha256:
		if str(after.dependencies_lf_sha256[path]).is_empty():
			problems.append("source binding missing: " + path)
	if str(after.runtime_inputs_sha256).is_empty() or str(after.repository_head).is_empty():
		problems.append("runtime digest or repository head unavailable")
	var directory := OS.get_environment("DREAM_RECEIPT_DIR")
	if directory.is_empty():
		problems.append("no DREAM_RECEIPT_DIR: no contract written")
		return problems
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join(name + "_contract.json")
	if FileAccess.file_exists(path):
		problems.append("contract would overwrite earlier evidence: " + path)
		return problems
	var all_failures: Array = failures + problems
	var bound: Dictionary = after.dependencies_lf_sha256
	var test_key := "game/" + test_script.trim_prefix("res://")
	var scene_key := "game/" + test_scene.trim_prefix("res://")
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2", "production_runtime": false,
		"scope": scope,
		"execution": {"completed": true, "exit_code": 0 if all_failures.is_empty() else 1, "timed_out": false,
			"elapsed_s": (Time.get_ticks_msec() - _started) / 1000.0},
		"source": {"test_path": test_key, "test_sha256": bound.get(test_key, ""), "test_scene_path": scene_key,
			"test_scene_lf_sha256": bound.get(scene_key, ""), "runtime_inputs_sha256": after.runtime_inputs_sha256,
			"repository_head": after.repository_head, "test_dependencies_lf_sha256": bound, "before": _before, "after": after},
		"contracts": {name: {"executed": true, "status": "PASS" if all_failures.is_empty() else "FAIL"}},
		"checks": checks, "failures": all_failures}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		problems.append("contract would not open: " + path)
		return problems
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	return problems
