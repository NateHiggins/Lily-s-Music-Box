extends "res://tests/orison_v2_m11c2_production_matrix.gd"
## Bounded renderer-lifecycle comparison for the unchanged production matrix.
## Reuses its exact two warmup lifecycles; no traversal, reconstruction or M11A.
## SCRIPT_CHECKS_PASS does not certify stderr. Engine errors require separate review.

const REPRO_RECEIPT_ENV := "M11C2_LIFECYCLE_RECEIPT"
const REPRO_PATH := "res://tests/orison_v2_m11c2_lifecycle_repro.gd"

func _run() -> void:
	var globals := _snapshot_globals()
	var cycles: Array[Dictionary] = []
	OS.set_environment("DAYNIGHT_FORCE", PROOF_CLOCK)
	var renderer := str(RenderingServer.get_current_rendering_method())
	print("[M11C2-LIFECYCLE-BEGIN] engine=%s renderer=%s" % [
			Engine.get_version_info().get("string", "unknown"), renderer])
	_check(renderer == "forward_plus", "lifecycle control uses Forward+")
	if renderer != "forward_plus" or not _load_sources():
		_finish_lifecycle(globals, cycles)
		return
	_configuration = load(CONFIGURATION_PATH) as Script
	_check(_configuration != null, "production geometry configuration loads")
	if _configuration == null:
		_finish_lifecycle(globals, cycles)
		return
	Selector.reset_for_tests("v1")
	_check(Selector.DEFAULT_ID == "v2", "production selector default is v2")
	_check(Selector.scene_path() == "res://scenes/building/orison_root.tscn",
			"lifecycle control mounts the complete production V1 root")
	for mode: StringName in MODES:
		print("[M11C2-LIFECYCLE-CYCLE-BEGIN] %s" % mode)
		# Keep the same helper, arguments, ordering, public geometry teardown,
		# scene removal and six-frame retirement boundary as matrix warmup.
		var cycle := await _run_direct_cycle(str(mode), "warmup", false, false)
		cycles.append(cycle)
		_check(str(cycle.get("status", "FAIL")) == "PASS",
				"%s exact matrix warmup contract and owner lifetimes" % mode)
		print("[M11C2-LIFECYCLE-CYCLE-END] mode=%s status=%s components=%s" % [
				mode, cycle.get("status", "FAIL"), JSON.stringify(cycle.get("ok_components", {}))])
	_finish_lifecycle(globals, cycles)

func _finish_lifecycle(globals: Dictionary, cycles: Array[Dictionary]) -> void:
	_restore_globals(globals)
	var receipt := {
		"schema": "orison.m11c2.lifecycle-repro.v1",
		"scope": "two exact unmeasured V1 direct cycles; no traversal, reconstruction or M11A claim",
		"engine_version": Engine.get_version_info(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"matrix_harness_sha256": FileAccess.get_sha256(MATRIX_HARNESS_PATH),
		"repro_harness_sha256": FileAccess.get_sha256(REPRO_PATH),
		"source_contract": _receipt.source_contract,
		"cycles": cycles,
		"checks": _checks,
		"failures": _failures,
		"engine_stderr_evaluated": false,
		"stderr_requirement": "Review captured stderr independently; script checks do not count renderer errors.",
	}
	var path := OS.get_environment(REPRO_RECEIPT_ENV).strip_edges()
	if path.is_empty(): path = "user://m11c2/lifecycle_repro_receipt.json"
	if not path.begins_with("user://") and not path.is_absolute_path():
		_fail("lifecycle receipt path must be absolute or user://")
	else:
		var absolute := ProjectSettings.globalize_path(path) if path.begins_with("user://") else path
		var made := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		_check(made == OK, "lifecycle receipt directory is available")
		var file := FileAccess.open(absolute, FileAccess.WRITE) if made == OK else null
		_check(file != null, "lifecycle receipt opens")
		if file != null:
			receipt["status"] = "SCRIPT_CHECKS_PASS" if _failures.is_empty() else "SCRIPT_CHECKS_FAIL"
			file.store_string(JSON.stringify(receipt, "\t"))
	var status := "SCRIPT_CHECKS_PASS" if _failures.is_empty() else "SCRIPT_CHECKS_FAIL"
	print("[M11C2-LIFECYCLE-RESULT] %s cycles=%d checks=%d failures=%d; STDERR_REVIEW_REQUIRED" % [
			status, cycles.size(), _checks.size(), _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)
