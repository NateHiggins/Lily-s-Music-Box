extends Node
## INERT review capture of the V2 night glows (v1r_night_glows_20261109).
## Windowed only, SHOT_DIR required. The player stands in the hall, so the
## building lights it as it would in play. Each view is taken with the glow
## and with it suppressed, so the effect can be told from the room's own
## light. Not runtime proof and no acceptance grant.
var directory: String
var world: Node3D
var _feet := Vector3.ZERO
var _look := Vector3.ZERO
var _pinned := false


func _ready() -> void:
	# After the player's own frame, so the stance set here is the one drawn.
	process_priority = 1000
	_run.call_deferred()


func _process(_delta: float) -> void:
	# The opening moves the player after startup; hold the stance every frame.
	if not _pinned or world == null or not is_instance_valid(world.player):
		return
	world.player.global_position = _feet
	world.player.camera.look_at(_look)
	var companion: Variant = world.get("service_set_carrier")
	if companion is Node3D:
		(companion as Node3D).visible = false


func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless" \
			or DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Night glow review requires windowed capture and SHOT_DIR")
		get_tree().quit(1)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928, 11, 20, 1380)
	world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	if world.startup_failed:
		push_error("Production world failed")
		get_tree().quit(1)
		return
	var glows: Node3D = world.night_glows
	var blockout: Node3D = glows.blockout
	var switches := world.get_node("V2RoomSwitches") as SwitchSystem
	var layout: Dictionary = world.layout
	var rects: Dictionary = {}
	var floors: Dictionary = {}
	var levels: Dictionary = {}
	for level: Dictionary in layout.levels:
		levels[str(level.id)] = float(level.y)
	for space: Dictionary in layout.spaces:
		rects[str(space.id)] = space.rect
		floors[str(space.id)] = levels[str(space.level)]
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for canvas: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		canvas.hide()
	world.player.camera.make_current()
	for i in 240:
		await get_tree().process_frame

	for door_id: String in ["F04_B_BATH_DOOR", "F04_DOOR_03", "F03_DOOR_02", "F02_B_ENTRY_DOOR"]:
		if not glows.spills.has(door_id):
			print("NIGHT GLOW SHOT: no spill bound for ", door_id)
			continue
		var spill: Dictionary = glows.spills[door_id]
		var hall := str(spill.hall)
		var room := str(spill.room)
		var rect: Array = rects[hall]
		var to_plan := blockout.global_transform.affine_inverse() * (spill.anchor as Node3D).global_transform
		var door_at := to_plan.origin
		var out := (to_plan.basis * Vector3(0.0, 0.0, float(spill.side))).normalized()
		var along := out.cross(Vector3.UP).normalized()
		# Stand inside the hall: back from the door as far as the hall allows,
		# and to one side when it is too narrow to stand square to the leaf.
		var stand := door_at + out * 1.9 + along * 0.5
		stand.x = clampf(stand.x, float(rect[0]) + 0.35, float(rect[2]) - 0.35)
		stand.z = clampf(stand.z, float(rect[1]) + 0.35, float(rect[3]) - 0.35)
		if Vector2(stand.x - door_at.x, stand.z - door_at.z).length() < 1.3:
			stand += along * 1.6
			stand.x = clampf(stand.x, float(rect[0]) + 0.35, float(rect[2]) - 0.35)
			stand.z = clampf(stand.z, float(rect[1]) + 0.35, float(rect[3]) - 0.35)
		stand.y = floors[hall]
		var feet := blockout.to_global(stand)
		var target := blockout.to_global(Vector3(door_at.x, float(floors[hall]) + 0.45, door_at.z))
		(spill.door as DoorProp).restore_mechanism({"angle": 0.0})
		if not glows.is_lit(room):
			switches.toggle_room(room)
		if not glows.is_lit(hall):
			switches.toggle_room(hall)
		_stand(feet, target)
		await _snap(door_id + "_hall_lit_spill")
		glows.visible = false
		await _snap(door_id + "_hall_lit_no_spill")
		glows.visible = true
		var hall_has_lamps: bool = glows.is_lit(hall)
		if hall_has_lamps:
			switches.toggle_room(hall)
		await _snap(door_id + "_hall_dark_spill")
		glows.visible = false
		await _snap(door_id + "_hall_dark_no_spill")
		glows.visible = true
		switches.toggle_room(room)
		for i in 30:
			await get_tree().process_frame
		await _snap(door_id + "_room_dark")
		switches.toggle_room(room)
		if hall_has_lamps:
			switches.toggle_room(hall)

	# The moon fill in a windowed room with its lamps out, and without it.
	if rects.has("F04_B_MAIN"):
		if glows.is_lit("F04_B_MAIN"):
			switches.toggle_room("F04_B_MAIN")
		var rect: Array = rects["F04_B_MAIN"]
		var mid := lerpf(float(rect[1]), float(rect[3]), 0.5)
		_stand(blockout.to_global(Vector3(lerpf(float(rect[0]), float(rect[2]), 0.72), 9.6, mid)),
				blockout.to_global(Vector3(float(rect[0]), 9.6 + 1.3, mid)))
		for i in 120:
			await get_tree().process_frame
		await _snap("moon_4B_main_fill")
		print("NIGHT GLOW SHOT: moon fill energy %.3f visible %s" % [world.moon_fill.light_energy, world.moon_fill.visible])
		glows.set_process(false)
		world.moon_fill.light_energy = 0.0
		world.moon_fill.visible = false
		await _snap("moon_4B_main_no_fill")
		glows.set_process(true)
		switches.toggle_room("F04_B_MAIN")
	world.shutdown_for_tests()
	CampaignTime.set_frozen_for_tests(false)
	print("NIGHT GLOW REVIEW: captures written; no acceptance grant")
	get_tree().quit(0)


func _stand(feet: Vector3, target: Vector3) -> void:
	_feet = feet
	_look = target
	_pinned = true


func _snap(label: String) -> void:
	for i in 14:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	print("NIGHT GLOW SHOT: ", label)
