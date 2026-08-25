extends Node
## LC-6C — production-root visual proof for the modelled hero's shared stages
## and its visit-local empty sheath.

const Lifecycle := preload("res://scripts/dream/dream_organelle_lifecycle.gd")

var root: Node3D
var hero: DreamHeroTentacle
var residue: DreamResidue
var camera: Camera3D
var out_dir := ""
var frames := 0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "mina:0.9")
	OS.set_environment("LIVING_ALL", "1")
	OS.set_environment("DREAM_HERO", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_user_data_dir().path_join("dream_hero_lifecycle_lc6c")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = (load("res://scenes/building/orison_root.tscn") as PackedScene).instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(8.0).timeout
	var enc = root.get("apartment_encroachment")
	if enc == null or enc.get("hero") == null or enc.get("residue") == null:
		return _fail("production hero or residue owner was not built")
	hero = enc.get("hero")
	residue = enc.get("residue")
	# Freeze the ecology and the hero's approved pose. The production building
	# remains the noise source priced by the A/A pair.
	enc.set_physics_process(false)
	hero.set_process(false)
	residue.set_process(false)
	if not _move_to_camera_safe_wall():
		return _fail("no camera-safe wall in the production 2A room")
	for owner_name in ["margin", "palp_renderer", "critters", "ecology",
			"dream_field"]:
		var owner = enc.get(owner_name)
		if owner != null:
			owner.set_process(false)
			owner.set_physics_process(false)
	root.player.set_physics_process(false)
	root.player.set_process(false)
	root.player.set_lamp_enabled(true)
	root.player.pin_lamp_gutter_for_proof(1.0)
	for overlay in root.find_children("*", "CanvasLayer", true, false):
		overlay.visible = false
	if root.player.carried_device != null:
		root.player.carried_device.visible = false
	camera = Camera3D.new()
	camera.fov = 38.0
	root.add_child(camera)
	camera.make_current()
	root.view_override = camera
	root.player.flashlight.visible = true
	root.player._light_mask.visible = true
	root.player.flashlight.reparent(camera)
	root.player.flashlight.transform = Transform3D(Basis(),
			Vector3(0.14, -0.16, -0.05))
	hero.grow = 1.0
	hero.slice_close = 0.0
	for mesh in hero.meshes:
		mesh.visible = true
	for mat in hero.materials:
		mat.set_shader_parameter("grow", 1.0)
		mat.set_shader_parameter("slice_close", 0.0)
		mat.set_shader_parameter("proof_time", 7.25)
	_frame_body()

	if OS.get_environment("SHOT_SHEATH_ONLY") != "1":
		await _stage("00_mature_control_a", Lifecycle.Stage.MATURE)
		await _stage("00_mature_control_b", Lifecycle.Stage.MATURE)
		await _stage("01_folded_reserve", Lifecycle.Stage.FOLDED)
		await _stage("02_bud_perfused", Lifecycle.Stage.BUD)
		await _stage("03_juvenile_calibrating", Lifecycle.Stage.JUVENILE)
		await _stage("04_mature_seeking", Lifecycle.Stage.MATURE)
		await _stage("05_exchange_band", Lifecycle.Stage.EXCHANGE)
		await _stage("06_senescent_mineral_bloom", Lifecycle.Stage.SENESCENT)
		await _stage("07_shed_cross_section", Lifecycle.Stage.SHED)

	hero._exchanged_this_life = true
	hero._complete_lifecycle()
	for mesh in hero.meshes:
		mesh.visible = false
	residue._process(0.0)
	_frame_sheath()
	await _capture("08_sheath_control_a")
	await _capture("08_sheath_control_b")
	# More owner work cannot age a visit-memory away.
	residue._process(10000.0)
	await _capture("09_sheath_after_time")
	print("[LC6C SHOT] %d production-root frames -> %s" % [frames, out_dir])
	get_tree().quit(0)


func _stage(label: String, stage: int) -> void:
	for mat in hero.materials:
		mat.set_shader_parameter("lifecycle_stage", float(stage))
	await _capture(label)


func _frame_body() -> void:
	var normal := -(hero.global_transform.basis.z).normalized()
	var side := normal.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var look := hero.global_position + normal * 0.66
	var prefer := (normal + side * 0.55 + Vector3.UP * 0.10).normalized()
	var eye := _stand_in_room(look, prefer, 1.55)
	_place_camera(eye, look)


func _frame_sheath() -> void:
	var normal := -(hero.global_transform.basis.z).normalized()
	var side := normal.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var look := hero.global_position + normal * 0.01
	var prefer := (normal + side * 0.35 + Vector3.UP * 0.08).normalized()
	var eye := _stand_in_room(look, prefer, 1.18)
	camera.fov = 32.0
	_place_camera(eye, look)


func _place_camera(eye: Vector3, look: Vector3) -> void:
	camera.make_current()
	root.view_override = camera
	camera.global_position = eye
	camera.look_at(look, Vector3.UP)
	root.player.global_position = eye - Vector3.UP * root.player.STANDING_EYE


## The established production hero sweep proved that a plausible wall normal
## is not enough: it can point into the landing. Select a real 2A wall whose
## inward side stays inside the flat and offers a clear camera pocket.
func _move_to_camera_safe_wall() -> bool:
	var space := get_viewport().find_world_3d().direct_space_state
	var from := Vector3(-9.6, 4.55, 3.4)
	var best := {}
	var best_clear := 0.0
	for step in 24:
		var angle := float(step) / 24.0 * TAU
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var hit := space.intersect_ray(
				PhysicsRayQueryParameters3D.create(from, from + direction * 6.0))
		if hit.is_empty():
			continue
		var normal: Vector3 = (hit.normal as Vector3).normalized()
		if absf(normal.y) > 0.35:
			continue
		var probe: Vector3 = (hit.position as Vector3) + normal * 1.2
		if probe.x < -13.45 or probe.x > -5.75 or probe.z < 0.65 or probe.z > 6.05:
			continue
		var outside: Vector3 = (hit.position as Vector3) + normal * 0.08
		var block := space.intersect_ray(
				PhysicsRayQueryParameters3D.create(outside, outside + normal * 4.0))
		var clear := 4.0 if block.is_empty() \
				else outside.distance_to(block.position as Vector3)
		if clear > best_clear:
			best_clear = clear
			best = {"position": hit.position, "normal": normal}
	if best.is_empty():
		return false
	var normal: Vector3 = best.normal as Vector3
	var at: Vector3 = (best.position as Vector3) + normal * 0.04
	hero.look_at_from_position(at, at + normal, Vector3.UP)
	hero.anchor_normal = normal
	print("[LC6C SHOT] camera-safe wall %.2f m at %s normal %s" % [
			best_clear, at, normal])
	return true


func _stand_in_room(target: Vector3, prefer: Vector3, distance: float) -> Vector3:
	var lo := Vector3(-13.30, 3.60, 0.80)
	var hi := Vector3(-5.90, 5.90, 5.90)
	var space := get_viewport().find_world_3d().direct_space_state
	var best := target + prefer * distance
	var best_score := -1.0
	for i in 40:
		var candidate: Vector3
		if i == 0:
			candidate = target + prefer * distance
		else:
			var angle := float(i) / 40.0 * TAU
			var lift := 0.10 + 0.35 * float(i % 3) / 3.0
			var direction := (prefer + Vector3(cos(angle), lift, sin(angle))
					* 0.9).normalized()
			candidate = target + direction * distance
		if candidate.x < lo.x or candidate.y < lo.y or candidate.z < lo.z \
				or candidate.x > hi.x or candidate.y > hi.y or candidate.z > hi.z:
			continue
		if not space.intersect_ray(
				PhysicsRayQueryParameters3D.create(candidate, target)).is_empty():
			continue
		var score := prefer.dot((candidate - target).normalized())
		if score > best_score:
			best_score = score
			best = candidate
	return best


func _capture(label: String) -> void:
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(label + ".png")
	var err := get_viewport().get_texture().get_image().save_png(path)
	if err != OK:
		return _fail("could not write %s (%d)" % [path, err])
	frames += 1


func _fail(message: String) -> void:
	printerr("[LC6C SHOT] ", message)
	get_tree().quit(1)
