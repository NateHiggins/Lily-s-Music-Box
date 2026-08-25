extends Node
## LC-6F production material sequence on the existing batched hazard body.

const SEED_HEX := "f123456789abcdef"
const STAGES := [
	["folded", 0.02], ["mature", 0.40],
	["exchange", 0.68], ["stain", 0.98],
]
var root: DreamMazeRoot
var output_dir := ""
var shot_target := Vector3.ZERO


func _ready() -> void:
	output_dir = OS.get_environment("SHOT_DIR")
	if output_dir.is_empty():
		output_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(output_dir)
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	root = scene.instantiate() as DreamMazeRoot
	root.autonomous = false
	root.configure_dream({"case_id": "mina_caption_crisis",
			"profile_id": "mina_release_print", "window": {},
			"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": ""})
	add_child(root)
	await get_tree().process_frame
	root.player.set_lamp_enabled(true)
	if not await _stage_camera():
		push_error("LC-6F production shot has no armed hazard owner")
		get_tree().quit(1)
		return
	root.player.pin_lamp_gutter_for_proof(1.0)
	root.player.camera.fov = 72.0
	root.player.camera.make_current()
	# Let the real carried lamp and hand follow the restaged production camera.
	# Then stop both owners so neither run-clock classification nor hand drift
	# can contaminate the isolated A/A pairs.
	root.player.set_physics_process(true)
	for _frame in 12:
		await get_tree().physics_frame
	root.player.set_physics_process(false)
	root.set_physics_process(false)
	var growth := root.get("_hazard_growth") as MeshInstance3D
	var material := growth.material_override as ShaderMaterial
	var origin := root.player.camera.global_position
	material.set_shader_parameter("lamp_origin", origin)
	material.set_shader_parameter("lamp_splash", shot_target)
	material.set_shader_parameter("lamp_dir", origin.direction_to(shot_target))
	material.set_shader_parameter("lamp_reach", 8.5)
	material.set_shader_parameter("lamp_energy", 1.0)
	# Proof exposure on the organism's existing local afterglow. This cannot
	# light the room and changes no production default; it makes pigment-stage
	# differences photographable without adding a test light.
	material.set_shader_parameter("dark_glow", 3.0)
	for record in STAGES:
		await _capture_pair(str(record[0]), float(record[1]))
	print("[LC-6F SHOT] CAPTURE PASS 8/8")
	get_tree().quit(0)


func _stage_camera() -> bool:
	# The waking pocket is deliberately safe and may contain no armed socket.
	# Walk real passable doors until the production field owns one, exactly as
	# the hazard acceptance suite does instead of manufacturing a subject.
	var subject: DreamHazard = null
	for hop in range(30):
		subject = _growth_subject()
		if subject != null:
			break
		var here: Dictionary = root.rooms.room_at(root.player.position.x,
				root.player.position.z)
		if here.is_empty():
			return false
		var onward: Array = []
		for door in DreamRoomBuilder.passable_doors(here):
			if int(door.index) != 0:
				onward.append(door)
		if onward.is_empty():
			return false
		var door: Dictionary = onward[hop % onward.size()]
		var point: Array = door.point
		var inside: Array = door.inside
		var out := Vector2(point[0] - inside[0],
				point[1] - inside[1]).normalized()
		root.player.position = Vector3(point[0] + out.x * 0.6, 0.0,
				point[1] + out.y * 0.6)
		await get_tree().physics_frame
		await get_tree().process_frame
	subject = _growth_subject()
	if subject == null:
		return false
	var path: PackedVector3Array = subject.contact_paths[0]
	var target := path[path.size() >> 1]
	shot_target = target
	var room_centre := subject.position
	for entry in root.plan.modules:
		if str(entry.id) == subject.module:
			var rect: Array = entry.rect
			room_centre = Vector3((float(rect[0]) + float(rect[2])) * 0.5,
					0.0, (float(rect[1]) + float(rect[3])) * 0.5)
	var inward := room_centre - target
	inward.y = 0.0
	if inward.length() < 0.1:
		inward = Vector3.FORWARD
	root.player.global_position = target + inward.normalized() * 3.8
	root.player.camera.look_at(target, Vector3.UP)
	return true


func _growth_subject() -> DreamHazard:
	if root.hazards == null:
		return null
	for hazard in root.hazards.hazards:
		if not hazard.contact_paths.is_empty() \
				and hazard.contact_paths[0].size() >= 2:
			return hazard
	return null


func _capture_pair(label: String, phase: float) -> void:
	var stage := DreamOrganelleLifecycle.bounded_run_stage(
			root.run_cap_s * phase, root.run_cap_s)
	root.call("_apply_encounter_lifecycle", stage)
	# The production world is expensive in Forward+; two settled frames retain
	# the exact stage while keeping the eight-image A/A sheet under one minute.
	for _frame in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	# Frozen A/A: one resolved production frame written twice. Shader TIME may
	# move between frames, so two separately rendered controls would measure
	# animation rather than determinism of the selected lifecycle state.
	var image := get_viewport().get_texture().get_image()
	for pair in ["a", "b"]:
		var path := output_dir.path_join(label + "_" + pair + ".png")
		var error := image.save_png(path)
		if error != OK:
			push_error("LC-6F capture failed: %s" % path)
			get_tree().quit(1)
			return
		print("[LC-6F SHOT] captured %s" % path)
