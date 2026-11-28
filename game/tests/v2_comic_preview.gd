extends "res://tests/v2_performance_matrix.gd"
## Preview only (Lily 2026-11-28, INERT, not for merge as-is). Shows the V2
## world through a comic cel filter, and with every shadow-casting light
## silenced except Vantry's lamp (the player's beam, which keeps its shadow
## and its volumetric air). At each station's worst heading four arms are
## timed and captured, with the stock look first:
##   stock              the game as it ships
##   comic              the cel filter over the stock lighting
##   comic_lamp_shadow  the cel filter, only the lamp casts shadows
##   lamp_shadow        stock look, only the lamp casts shadows (the saving alone)
## then comic_lamp_shadow is captured at the other three headings.
##
##   SHOT_DIR                where comic_preview.json and the PNGs are written
##   ORISON_COMIC_STATIONS   comma-separated station names

const DEFAULT_STATIONS := "lobby,third_floor_crossing,flat_4b_desk,basement_landing,street_arrival,roof_deck"
const FILTER := preload("res://shaders/comic_cel_preview.gdshader")
const ARM_WARMUP := 90
const ARM_FRAMES := 180

var _rows_out: Array = []
var _quad: MeshInstance3D


func _measure(station: Dictionary) -> Dictionary:
	var wanted := OS.get_environment("ORISON_COMIC_STATIONS")
	if wanted.is_empty():
		wanted = DEFAULT_STATIONS
	if not (str(station.name) in wanted.split(",")):
		return {"name": str(station.name), "valid": true, "skipped": true}
	var row: Dictionary = await super._measure(station)
	if not row.get("valid", false) or not row.has("worst_heading"):
		_rows_out.append({"station": row.name, "skipped": "no valid settled stance"})
		return row
	var at := Vector3(row.position[0], row.position[1], row.position[2])
	var worst := float(row.worst_heading.yaw_degrees)
	# 11-28: the F03 stance put the lens inside a resident's body. Find a clear
	# stance nearby, and hold the sanity and fourth-wall directors still while
	# the arms are timed so a story event cannot land in one arm.
	var clear := _clear_stance(at)
	if clear.moved:
		print("[COMIC] %s: lens was inside %s; moved %.2f m to a clear stance" % [row.name, clear.inside, clear.offset_m])
		at = clear.position
	_quiet_story(true)
	var lights := _shadow_lights()
	var casting: int = (lights.all as Array).filter(func(l: Light3D) -> bool: return l.shadow_enabled).size()
	var out := {"station": row.name, "room": row.room, "yaw_degrees": worst,
		"shadow_lights_at_start": casting, "lights": lights.all.size(), "lamp_lights": lights.keep.size(), "arms": {},
		"stance": {"moved": clear.moved, "inside": clear.inside, "offset_m": clear.offset_m,
			"position": [snappedf(at.x, 0.001), snappedf(at.y, 0.001), snappedf(at.z, 0.001)]},
		"story_directors_held": _held.size()}
	for arm: String in ["stock", "comic", "comic_lamp_shadow", "lamp_shadow"]:
		_set_filter(arm.begins_with("comic"))
		_set_shadows(lights, not arm.ends_with("lamp_shadow"))
		_pose(at, deg_to_rad(worst))
		for i in ARM_WARMUP:
			await get_tree().process_frame
		out.arms[arm] = await _sample(at)
		out.arms[arm]["lens_inside"] = _body_around(player.camera.global_position)
		out.arms[arm]["mirror"] = _mirror_report()
		await _shot("%s_%s_%03d" % [row.name, arm, int(worst)])
		print("[COMIC] %-22s %-18s wall %6.2f  cpu %5.2f  gpu %5.2f  calls %6d" % [row.name, arm,
			out.arms[arm].wall_ms_median, out.arms[arm].render_cpu_ms_median, out.arms[arm].render_gpu_ms_median,
			int(out.arms[arm].draw_calls_median)])
	_set_filter(true)
	_set_shadows(lights, false)
	for quarter in 4:
		var yaw := fmod(worst + 90.0 * quarter, 360.0)
		if quarter == 0:
			continue
		_pose(at, deg_to_rad(yaw))
		for i in 45:
			await get_tree().process_frame
		await _shot("%s_comic_lamp_shadow_%03d" % [row.name, int(yaw)])
	_set_filter(false)
	_set_shadows(lights, true)
	_quiet_story(false)
	_rows_out.append(out)
	return row


var _held: Array[Node] = []


## Which planar mirror, if any, is rendering the world a second time for this
## lens, and how far its glass is from the eye.
func _mirror_report() -> Dictionary:
	for node: Node in world.find_children("*", "Node", true, false):
		if not (node is PlanarMirrorRenderer):
			continue
		var renderer := node as PlanarMirrorRenderer
		var cabinet: Variant = renderer.active_mirror()
		if cabinet == null or not is_instance_valid(cabinet) or renderer.active_camera() == null:
			continue
		var cabinet_node := cabinet as Node3D
		var center: Vector3 = cabinet.mirror_center()
		var eye := player.camera.global_position
		var report := {"cabinet": str(cabinet_node.get_path()).right(140), "glass_m": snappedf(eye.distance_to(center), 0.01),
			"center": [snappedf(center.x, 0.01), snappedf(center.y, 0.01), snappedf(center.z, 0.01)]}
		print("[COMIC] active mirror %s at %.2f m" % [report.cabinet, report.glass_m])
		return report
	return {}


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


## The name of a character whose body (any skinned figure) encloses this
## point, or "" when the point is clear.
func _body_around(point: Vector3) -> String:
	for node: Node in world.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		# The player's own mirror double travels with the lens; it is not a body in the way.
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
			var owner_node: Node = figure
			while owner_node.get_parent() != null and owner_node.get_parent() != world and owner_node.get_parent().get_parent() != world:
				owner_node = owner_node.get_parent()
			return str(figure.name) + " (" + str(owner_node.name) + ")"
	return ""


## The stance itself when the lens is clear, else the nearest point on a ring
## around it with floor under it and no body around the lens.
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
			var floor_hit := space.intersect_ray(down)
			if floor_hit.is_empty():
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


var _enforced: Dictionary = {}


## Several world scripts (light rig budgets, far-light shadows, day and night)
## turn shadows back on as they run, so an arm that silences them re-applies
## the choice every frame after every other processor.
func _process(delta: float) -> void:
	super._process(delta)
	if _enforced.is_empty():
		return
	for light: Light3D in _enforced.all:
		if is_instance_valid(light) and light.shadow_enabled and not (light in _enforced.keep):
			light.shadow_enabled = false


## Every light in the tree (a script may switch its shadow on later), split
## into the lamp's (kept) and the rest.
func _shadow_lights() -> Dictionary:
	process_priority = 1 << 30
	var all: Array[Light3D] = []
	var keep: Array[Light3D] = []
	for node: Node in get_tree().root.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		all.append(light)
		var lamp := light == player.flashlight or player.is_ancestor_of(light)
		var parent := light.get_parent()
		while parent != null and not lamp:
			lamp = parent is LampOpticalInstrument
			parent = parent.get_parent()
		if lamp:
			keep.append(light)
	return {"all": all, "keep": keep}


## Stock hands every light back to its own owner; scripts restore their state.
func _set_shadows(lights: Dictionary, stock: bool) -> void:
	if stock:
		for light: Light3D in _enforced.get("off", []):
			if is_instance_valid(light):
				light.shadow_enabled = true
		_enforced = {}
		return
	var off: Array[Light3D] = []
	for light: Light3D in lights.all:
		if is_instance_valid(light) and light.shadow_enabled and not (light in lights.keep):
			off.append(light)
	_enforced = {"all": lights.all, "keep": lights.keep, "off": off}
	_process(0.0)


func _set_filter(on: bool) -> void:
	if _quad == null:
		_quad = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		_quad.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = FILTER
		_quad.material_override = material
		_quad.extra_cull_margin = 16384.0
		_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mask := player.camera.cull_mask
		_quad.layers = mask & -mask if mask != 0 else 1
		player.camera.add_child(_quad)
		_quad.position = Vector3(0, 0, -0.5)
	_quad.visible = on


func _sample(at: Vector3) -> Dictionary:
	_frame_usec = PackedInt64Array()
	_cpu_ms = PackedFloat64Array()
	_gpu_ms = PackedFloat64Array()
	_last_usec = 0
	var calls := PackedFloat64Array()
	var shadow_calls := PackedFloat64Array()
	_sampling = true
	for i in ARM_FRAMES:
		await get_tree().process_frame
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		shadow_calls.append(RenderingServer.viewport_get_render_info(_viewport_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	_sampling = false
	var wall := _summary_usec(_frame_usec)
	return {"wall_ms_median": wall.median, "wall_ms_p95": wall.p95,
		"render_cpu_ms_median": _median(_cpu_ms), "render_gpu_ms_median": _median(_gpu_ms),
		"draw_calls_median": _median(calls), "shadow_draws_median": _median(shadow_calls),
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
	var record := {"schema": "orison.v2-comic-preview.v1", "evidence_class": "INERT",
		"engine": Engine.get_version_info().get("string", ""), "adapter": RenderingServer.get_video_adapter_name(),
		"resolution": [2560, 1440], "arm_warmup": ARM_WARMUP, "arm_frames": ARM_FRAMES, "startup": startup,
		"stations": _rows_out, "failures": failures}
	var file := FileAccess.open(directory.path_join("comic_preview.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
