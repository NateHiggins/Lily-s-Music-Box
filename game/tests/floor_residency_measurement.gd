extends Node
## Measurement instrument, not a performance gate. Every row records the root,
## renderer/profile, simulation state and authored-floor scope so unlike numbers
## cannot be mistaken for regressions.

const FLOORS := ["01", "02", "03", "04", "05", "06", "b1"]
var rows: Array = []


func _ready() -> void:
	for floor_id in FLOORS:
		await _measure(floor_id)
	var payload := {
		"schema": "orison.floor-residency-measurement.v1",
		"root": "standalone_floor_resource",
		"profile": "headless Forward+ threaded ResourceLoader",
		"simulation_state": "measurement scene; no campaign simulation",
		"authored_floor_scope": FLOORS,
		"rows": rows,
	}
	var output := OS.get_environment("FLOOR_RESIDENCY_RECEIPT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(payload, "  ") + "\n")
	print("FLOOR RESIDENCY MEASUREMENT: PASS %d/%d" % [rows.size(), FLOORS.size()])
	get_tree().quit(0)


func _measure(floor_id: String) -> void:
	var path := "res://assets/building/floor_%s.gltf" % floor_id
	var absolute := ProjectSettings.globalize_path(path)
	var bytes := _resident_bytes(absolute)
	var started := Time.get_ticks_usec()
	var poll_usec := 0
	var request_error := ResourceLoader.load_threaded_request(path, "PackedScene", true)
	if request_error != OK:
		push_error("threaded request failed for %s: %d" % [path, request_error])
		get_tree().quit(1)
		return
	var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var before := Time.get_ticks_usec()
		status = ResourceLoader.load_threaded_get_status(path)
		poll_usec += Time.get_ticks_usec() - before
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("threaded load failed for %s: %d" % [path, status])
		get_tree().quit(1)
		return
	var before_get := Time.get_ticks_usec()
	var packed: PackedScene = ResourceLoader.load_threaded_get(path)
	var get_usec := Time.get_ticks_usec() - before_get
	var before_instance := Time.get_ticks_usec()
	var instance := packed.instantiate()
	var instance_usec := Time.get_ticks_usec() - before_instance
	var node_count := _count_nodes(instance)
	instance.free()
	var wall_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var mib := float(bytes) / 1048576.0
	rows.append({"floor": floor_id, "path": path, "bytes": bytes,
			"mib": mib, "threaded_wall_ms": wall_ms,
			"wall_ms_per_mib": wall_ms / maxf(mib, 0.001),
			"main_thread_poll_ms": float(poll_usec) / 1000.0,
			"main_thread_get_ms": float(get_usec) / 1000.0,
			"main_thread_instantiate_ms": float(instance_usec) / 1000.0,
			"node_count": node_count})


func _count_nodes(root: Node) -> int:
	var count := 1
	for child in root.get_children():
		count += _count_nodes(child)
	return count


func _resident_bytes(gltf_path: String) -> int:
	var total := FileAccess.get_file_as_bytes(gltf_path).size()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(gltf_path))
	if parsed is not Dictionary:
		return total
	var parent := gltf_path.get_base_dir()
	for buffer in parsed.get("buffers", []):
		if buffer is Dictionary:
			var uri := str(buffer.get("uri", ""))
			if not uri.is_empty() and not uri.begins_with("data:"):
				total += FileAccess.get_file_as_bytes(parent.path_join(uri)).size()
	return total
