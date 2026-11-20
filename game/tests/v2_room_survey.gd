extends Node
## Survey captures for the lived-in furnishing pass (review only; writes pictures, asserts nothing about the game).
## For each apartment room in the blockout (or the rooms named in ROOMS, comma-separated): the player is pinned at
## the room's centre so its geometry is resident, and a separate camera takes a plan view from under the ceiling and
## two views from opposite corners. A temporary even light is added for the review and removed after.

var world: Node
var _feet := Vector3.ZERO
var _pinned := false
var _eye: Camera3D
var _lamp: OmniLight3D


func _process(_delta: float) -> void:
	if _pinned and world != null and is_instance_valid(world.player):
		world.player.global_position = _feet
		var companion: Variant = world.get("service_set_carrier")
		if companion is Node3D:
			(companion as Node3D).visible = false


func _frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func _shot(directory: String, label: String) -> void:
	for index in 6:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))


func _ready() -> void:
	process_priority = 1000
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		print("ROOM SURVEY: needs SHOT_DIR and a window")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json"))
	var level_y := {}
	for level: Dictionary in layout.levels:
		level_y[str(level.id)] = float(level.get("elevation", level.get("y", 0.0)))
	var wanted := OS.get_environment("ROOMS").split(",", false)
	var pattern := RegEx.create_from_string("^F0[1-6]_[A-D]_(MAIN|KITCHEN|BED|BED1|BED2|STUDY|STUDIO|ALCOVE|BATH|VESTIBULE|PRIVATE_HALL)$")
	var rooms: Array = []
	for space: Dictionary in layout.spaces:
		var identity := str(space.id)
		if (wanted.is_empty() and pattern.search(identity) != null) or wanted.has(identity):
			rooms.append(space)
	world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	if world.startup_failed:
		print("ROOM SURVEY: the world did not start")
		get_tree().quit(1)
		return
	world.player.set_physics_process(false)
	world.player.visible = false
	world.campaign_clock.configure_date(1929, 6, 12, 13 * 60)
	_eye = Camera3D.new()
	add_child(_eye)
	_lamp = OmniLight3D.new()
	_lamp.omni_range = 9.0
	_lamp.light_energy = 1.4
	_lamp.shadow_enabled = false
	add_child(_lamp)
	_pinned = true
	var taken := 0
	for space: Dictionary in rooms:
		var rect: Array = space.rect
		var x0 := minf(float(rect[0]), float(rect[2]))
		var x1 := maxf(float(rect[0]), float(rect[2]))
		var z0 := minf(float(rect[1]), float(rect[3]))
		var z1 := maxf(float(rect[1]), float(rect[3]))
		var floor_y := float(level_y.get(str(space.level), 0.0))
		var root: Node3D = world.adapter.root
		var local_centre := Vector3((x0 + x1) * 0.5, floor_y, (z0 + z1) * 0.5)
		var centre := root.to_global(local_centre)
		var frame := root.global_basis.orthonormalized()
		_feet = centre + Vector3.UP * 0.05
		_lamp.global_position = centre + Vector3.UP * 2.1
		await _frames(45)
		_eye.make_current()
		# Plan: orthographic, from just under the ceiling, north up.
		_eye.projection = Camera3D.PROJECTION_ORTHOGONAL
		_eye.size = maxf(z1 - z0 + 0.6, (x1 - x0 + 0.6) / 1.78)
		_eye.near = 0.05
		_eye.global_position = centre + Vector3.UP * 2.6
		_eye.look_at(centre, frame * Vector3.FORWARD)
		await _shot(directory, "%s_plan" % space.id)
		# Two views along the long axis: from a third of the way in, to the far end, then the reverse.
		_eye.projection = Camera3D.PROJECTION_PERSPECTIVE
		_eye.fov = 80.0
		var along := frame * (Vector3.RIGHT if x1 - x0 >= z1 - z0 else Vector3.BACK)
		var half := maxf(x1 - x0, z1 - z0) * 0.5
		for index in 2:
			var sign := -1.0 if index == 0 else 1.0
			_eye.global_position = centre + Vector3.UP * 1.55 + along * sign * half * 0.55
			_eye.look_at(centre + Vector3.UP * 0.6 - along * sign * half)
			await _shot(directory, "%s_view%d" % [space.id, index + 1])
		taken += 1
		print("ROOM SURVEY SHOT: ", space.id)
	_pinned = false
	print("ROOM SURVEY: %d rooms" % taken)
	if world.has_method("shutdown_for_tests"):
		world.shutdown_for_tests()
	get_tree().quit(0)
