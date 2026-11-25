extends "res://tests/v2_shaft_shadow_installed_test.gd"
## Exercise the installed exclusion mask without interrupting lamp depth capture.

const Receivers := preload("res://scripts/lamp/lamp_optical_receivers.gd")


func _measure(station: Dictionary) -> Dictionary:
	var placed := _place(station)
	player.rotation.y = YAW
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not placed.ok or not await _settle():
		failures.append("The F03 crossing did not settle")
		return {}
	var atmosphere := world.get_node_or_null("LampAtmosphere")
	var binding: RefCounted = atmosphere.get("receivers") if atmosphere != null else null
	var depth: Node = atmosphere.get("scene_shadow") if atmosphere != null else null
	if binding == null or depth == null or not binding.get("isolate_depth_lights"):
		failures.append("The installed lamp depth view did not bind light isolation")
		return {}
	var mask: int = binding.get("depth_exclusion_mask")
	var camera: Camera3D = depth.get("camera")
	var viewport: SubViewport = depth.get("viewport")
	var effect: CompositorEffect = depth.get("effect")
	if mask != Receivers.DEPTH_LIGHT_LAYER or camera == null or viewport == null or effect == null:
		failures.append("The mixed stock layer case did not produce an independent ordinary-light exclusion (%d)" % mask)
		return {}
	var occupied_transient: Array[String] = []
	for draw: GeometryInstance3D in world.find_children("*", "GeometryInstance3D", true, false):
		if draw.layers & mask:
			failures.append("The excluded ordinary-light layer contains scene geometry")
		if draw.layers & (Receivers.DEPTH_CAMERA_EXCLUSIONS & ~mask):
			occupied_transient.append(str(world.get_path_to(draw)))
	if occupied_transient.is_empty():
		failures.append("The test did not exercise geometry that retains the transient bit")
		return {}
	var arms: Array[Dictionary] = []
	var stock_cull_mask := 0
	for label: String in ["stock", "separate_light_bits", "stock_restored"]:
		var expected := mask if label == "separate_light_bits" else 0
		binding.set("depth_exclusion_mask", expected)
		var before_passes: int = effect.get("passes")
		var sample := await _sample()
		sample.arm = label
		sample.excluded = int(depth.get("excluded_light_layers"))
		sample.camera_mask = camera.cull_mask
		sample.depth_passes = int(effect.get("passes")) - before_passes
		if label == "stock":
			stock_cull_mask = camera.cull_mask
		if viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS or sample.excluded != expected \
				or camera.cull_mask != (stock_cull_mask & ~expected) or sample.depth_passes < 5:
			failures.append("Live depth or the installed camera mask did not hold through %s" % label)
		if player.global_position.distance_to(placed.position) > 0.05 or absf(angle_difference(player.rotation.y, YAW)) > 0.002:
			failures.append("The F03 camera drifted during %s" % label)
		arms.append(sample)
		print("[LAMP DEPTH ISOLATION] %s mask %d passes %d shadows %.0f wall %.3f ms" % [
			label, sample.excluded, sample.depth_passes, sample.shadow_calls, sample.wall_ms])
		await _corridor_frame(label)
	binding.set("depth_exclusion_mask", mask)
	return {"station": station.name, "room": world.room_at_world(placed.position),
		"occupied_transient_geometry": occupied_transient, "arms": arms}


func _write(startup: Dictionary, rows: Array) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK:
		failures.append("The lamp depth report destination is unavailable")
		return
	var output := FileAccess.open(directory.path_join("lamp_depth_isolation.json"), FileAccess.WRITE)
	if output == null:
		failures.append("The lamp depth report could not be written")
		return
	output.store_string(JSON.stringify({"resolution": [TARGET_SIZE.x, TARGET_SIZE.y],
		"renderer": RenderingServer.get_current_rendering_method(), "startup": startup,
		"stations": rows, "failures": failures}, "\t") + "\n")
	output.close()
	print("LAMP DEPTH ISOLATION: " + ("PASS" if failures.is_empty() else "FAIL"))
