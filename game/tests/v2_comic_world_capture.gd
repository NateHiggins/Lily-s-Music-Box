extends "res://tests/v2_performance_matrix.gd"
## Evidence class: INERT capture (Lily 2026-11-28, the comic world). At each
## station's worst heading three arms are timed and captured:
##   cel          the look as it shipped before the comic world (soft palette)
##   comic        the comic world over every authored shadow
##   comic_lamp   the comic world as it ships: only the lamp casts shadows
## then comic_lamp is captured at the other three headings. Each arm records
## how many non-lamp lights hold a shadow, sampled every frame, so an owner
## that turns a shadow back on behind the policy shows up by name.
##
##   SHOT_DIR                 where comic_world.json and the PNGs are written
##   ORISON_COMIC_STATIONS    comma-separated station names

const ShadowPolicy := preload("res://scripts/rendering/shadow_policy.gd")
const Presentation := preload("res://scripts/visuals/cel_style_presentation.gd")
const DEFAULT_STATIONS := "lobby,third_floor_crossing,flat_4b_desk,basement_landing,street_arrival,roof_deck"
const ARM_WARMUP := 90
const ARM_FRAMES := 180

var _rows_out: Array = []
var _held: Array[Node] = []


func _measure(station: Dictionary) -> Dictionary:
	var wanted := OS.get_environment("ORISON_COMIC_STATIONS")
	if wanted.is_empty():
		wanted = DEFAULT_STATIONS
	if not (str(station.name) in wanted.split(",")):
		return {"name": str(station.name), "valid": true, "skipped": true}
	_look("cel")
	var row: Dictionary = await super._measure(station)
	if not row.get("valid", false) or not row.has("worst_heading"):
		_rows_out.append({"station": row.name, "skipped": "no valid settled stance"})
		return row
	var at := Vector3(row.position[0], row.position[1], row.position[2])
	var worst := float(row.worst_heading.yaw_degrees)
	var clear := _clear_stance(at)
	if clear.moved:
		print("[COMIC] %s: lens was inside %s; moved %.2f m to a clear stance" % [row.name, clear.inside, clear.offset_m])
		at = clear.position
	_quiet_story(true)
	var out := {"station": row.name, "room": row.room, "yaw_degrees": worst, "arms": {},
		"stance": {"moved": clear.moved, "inside": clear.inside, "offset_m": clear.offset_m}}
	for arm: String in ["cel", "comic", "comic_lamp"]:
		_look("cel" if arm == "cel" else "comic")
		await get_tree().process_frame
		await get_tree().process_frame
		if arm == "comic":
			ShadowPolicy.set_lamp_only(get_tree(), false)
		elif arm == "comic_lamp":
			ShadowPolicy.set_lamp_only(get_tree(), true)
		_pose(at, deg_to_rad(worst))
		for i in ARM_WARMUP:
			await get_tree().process_frame
		out.arms[arm] = await _sample(at)
		out.arms[arm]["look"] = _presentation().look() if _presentation() != null else "missing"
		out.arms[arm]["lamp_only"] = ShadowPolicy.lamp_only
		await _shot("%s_%s_%03d" % [row.name, arm, int(worst)])
		print("[COMIC] %-22s %-11s wall %6.2f  cpu %5.2f  gpu %5.2f  calls %6d  shadows %3d (lamp %d, worst non-lamp %d)" % [
			row.name, arm, out.arms[arm].wall_ms_median, out.arms[arm].render_cpu_ms_median,
			out.arms[arm].render_gpu_ms_median, int(out.arms[arm].draw_calls_median),
			out.arms[arm].shadow_lights, out.arms[arm].lamp_shadow_lights, out.arms[arm].non_lamp_shadow_max])
		if arm == "comic_lamp" and int(out.arms[arm].non_lamp_shadow_max) > 0:
			failures.append("%s: %d non-lamp lights held a shadow in the lamp-only arm: %s" % [
				row.name, out.arms[arm].non_lamp_shadow_max, out.arms[arm].non_lamp_names])
	for quarter in range(1, 4):
		var yaw := fmod(worst + 90.0 * quarter, 360.0)
		_pose(at, deg_to_rad(yaw))
		for i in 45:
			await get_tree().process_frame
		await _shot("%s_comic_lamp_%03d" % [row.name, int(yaw)])
	_look("cel")
	_quiet_story(false)
	_rows_out.append(out)
	return row


func _look(name: String) -> void:
	OS.set_environment("ORISON_WORLD_LOOK", name)


func _presentation() -> Presentation:
	for node: Node in player.find_children("*", "Node", true, false):
		if node.get_script() == Presentation:
			return node as Presentation
	return null


func _quiet_story(hold: bool) -> void:
	if hold:
		_held.clear()
		for node: Node in world.find_children("*", "", true, false):
			var script: Script = node.get_script()
			if script != null and script.resource_path.get_file() in ["sanity_director.gd", "fourth_wall.gd"]:
				_held.append(node)
				node.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		for node: Node in _held:
			if is_instance_valid(node):
				node.process_mode = Node.PROCESS_MODE_INHERIT
		_held.clear()


## The name of a character whose body encloses this point, or "".
func _body_around(point: Vector3) -> String:
	for node: Node in world.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		if not skeleton.is_visible_in_tree() or player.is_ancestor_of(skeleton):
			continue
		var figure := skeleton.get_parent() as Node3D
		if figure == null:
			continue
		var box := AABB()
		var first := true
		for mesh_node: Node in figure.find_children("*", "MeshInstance3D", true, false):
			var draw := mesh_node as MeshInstance3D
			if not draw.is_visible_in_tree():
				continue
			var world_box := draw.global_transform * draw.get_aabb()
			box = world_box if first else box.merge(world_box)
			first = false
		if not first and box.grow(0.15).has_point(point):
			return str(figure.name)
	return ""


func _clear_stance(at: Vector3) -> Dictionary:
	var eye_rise := player.camera.global_position - player.global_position
	var inside := _body_around(at + eye_rise)
	if inside.is_empty():
		return {"moved": false, "inside": "", "offset_m": 0.0, "position": at}
	var space := player.get_world_3d().direct_space_state
	for radius: float in [0.6, 0.9, 1.2, 1.6, 2.0]:
		for i in 12:
			var candidate := at + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 12.0) * radius
			var down := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 0.6, candidate + Vector3.DOWN * 0.4)
			down.exclude = [player.get_rid()]
			if space.intersect_ray(down).is_empty():
				continue
			var across := PhysicsRayQueryParameters3D.create(at + eye_rise, candidate + eye_rise)
			across.exclude = [player.get_rid()]
			if not space.intersect_ray(across).is_empty():
				continue
			if not _body_around(candidate + eye_rise).is_empty():
				continue
			return {"moved": true, "inside": inside, "offset_m": radius, "position": candidate}
	return {"moved": false, "inside": inside, "offset_m": 0.0, "position": at}


func _pose(at: Vector3, yaw: float) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = yaw
	player.camera.rotation.x = 0.0


## Shadow-holding lights now: all, the lamp's, and the names of the rest.
func _shadow_census() -> Dictionary:
	var total := 0
	var lamp := 0
	var others: Array[String] = []
	for node: Node in get_tree().root.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if not light.shadow_enabled or not light.is_visible_in_tree():
			continue
		total += 1
		if ShadowPolicy.is_kept(light):
			lamp += 1
		else:
			others.append(str(light.get_path()).right(90))
	return {"total": total, "lamp": lamp, "others": others}


func _sample(at: Vector3) -> Dictionary:
	_frame_usec = PackedInt64Array()
	_cpu_ms = PackedFloat64Array()
	_gpu_ms = PackedFloat64Array()
	_last_usec = 0
	var calls := PackedFloat64Array()
	var shadow_calls := PackedFloat64Array()
	var worst_others: Array[String] = []
	var census := {}
	_sampling = true
	for i in ARM_FRAMES:
		await get_tree().process_frame
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		shadow_calls.append(RenderingServer.viewport_get_render_info(_viewport_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		if i % 6 == 0:
			census = _shadow_census()
			if (census.others as Array).size() > worst_others.size():
				worst_others = census.others
	_sampling = false
	census = _shadow_census()
	var wall := _summary_usec(_frame_usec)
	return {"wall_ms_median": wall.median, "wall_ms_p95": wall.p95,
		"render_cpu_ms_median": _median(_cpu_ms), "render_gpu_ms_median": _median(_gpu_ms),
		"draw_calls_median": _median(calls), "shadow_draws_median": _median(shadow_calls),
		"shadow_lights": census.total, "lamp_shadow_lights": census.lamp,
		"non_lamp_shadow_max": worst_others.size(), "non_lamp_names": worst_others.slice(0, 8),
		"drift_m": snappedf(player.global_position.distance_to(at), 0.001)}


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var image := get_viewport().get_texture().get_image()
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	if image.save_png(directory.path_join(label + ".png")) != OK:
		failures.append("could not save " + label)


func _write(startup: Dictionary, rows: Array) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty():
		failures.append("SHOT_DIR is not set; nothing was written")
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var record := {"schema": "orison.v2-comic-world-capture.v1", "evidence_class": "INERT",
		"engine": Engine.get_version_info().get("string", ""), "adapter": RenderingServer.get_video_adapter_name(),
		"resolution": [2560, 1440], "arm_warmup": ARM_WARMUP, "arm_frames": ARM_FRAMES, "startup": startup,
		"stations": _rows_out, "failures": failures}
	var file := FileAccess.open(directory.path_join("comic_world.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
