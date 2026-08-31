extends Node
## Entry point for the disposable project. Select with M11C0_MODE=runtime or
## M11C0_MODE=capture. Keeping one main scene makes the splitter independent of
## platform-specific command-line script invocation details.


func _ready() -> void:
	var mode := OS.get_environment("M11C0_MODE").strip_edges().to_lower()
	if mode.is_empty():
		mode = "runtime"
	var runner_path := "res://m11c0_runtime_validation.gd"
	if mode == "capture":
		runner_path = "res://m11c0_capture.gd"
	elif mode != "runtime":
		push_error("M11C0 HARNESS: unsupported M11C0_MODE=%s" % mode)
		get_tree().quit(2)
		return
	var runner_script := load(runner_path) as Script
	if runner_script == null:
		push_error("M11C0 HARNESS: could not load %s" % runner_path)
		get_tree().quit(2)
		return
	var runner := Node.new()
	runner.name = "M11C0RuntimeValidation" if mode == "runtime" \
			else "M11C0Capture"
	runner.set_script(runner_script)
	add_child(runner)
