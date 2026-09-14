extends Node
## Single test-scene entry point; mode is explicit and never a production
## selector or BuildingRoot default.


func _ready() -> void:
	var mode := OS.get_environment("M11C1_MODE").strip_edges().to_lower()
	if mode.is_empty():
		mode = "runtime"
	var path := "res://tests/orison_v2_m11c1_owner_first/m11c1_runtime_validation.gd"
	if mode == "capture":
		path = "res://tests/orison_v2_m11c1_owner_first/m11c1_capture.gd"
	elif mode != "runtime":
		push_error("M11C1 HARNESS: unsupported M11C1_MODE=%s" % mode)
		get_tree().quit(2)
		return
	var script := load(path) as Script
	if script == null:
		push_error("M11C1 HARNESS: could not load %s" % path)
		get_tree().quit(2)
		return
	var runner := Node.new()
	runner.name = "M11C1Capture" if mode == "capture" \
			else "M11C1RuntimeValidation"
	runner.set_script(script)
	add_child(runner)
