extends Node
## INERT review capture of the possessed-object tells on V2's own objects
## (v1r_witness_tells_20261109). Windowed only, SHOT_DIR required. Each object
## is taken at rest and during its tell. Not runtime proof.
var directory: String
var world: Node3D
var _feet := Vector3.ZERO
var _look := Vector3.ZERO
var _pinned := false


func _ready() -> void:
	process_priority = 1000
	_run.call_deferred()


func _process(_delta: float) -> void:
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
		push_error("Witness review requires windowed capture and SHOT_DIR")
		get_tree().quit(1)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	var witnesses: Node = world.domestic_witnesses
	witnesses.player = null
	world.player.set_physics_process(false)
	for canvas: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		canvas.hide()
	world.player.camera.make_current()
	for row: Array in [["malcolm_plant", "malcolm_memory_plants", Vector3(-1.6, 0, 1.2)],
			["sacha_camera", "sacha_camera_delay", Vector3(1.4, 0, 1.4)],
			["iris_picture_frame", "iris_runaway_paint", Vector3(1.5, 0, 0.4)]]:
		var tell: Node = witnesses.tells[str(row[0])]
		var box := AABB()
		var first := true
		for draw: MeshInstance3D in tell.target.find_children("*", "MeshInstance3D", true, false):
			var world_box := draw.global_transform * draw.get_aabb()
			box = world_box if first else box.merge(world_box)
			first = false
		var centre := box.get_center()
		var storey := floorf((centre.y + 0.05) / 3.2) * 3.2
		for offset: Vector3 in [row[2] as Vector3, -(row[2] as Vector3)]:
			_feet = Vector3(centre.x, storey, centre.z) + offset
			_look = centre
			_pinned = true
			var side := "a" if offset == row[2] else "b"
			await _snap("%s_%s_rest" % [row[0], side])
			witnesses.force(str(row[1]), 2)
			await _snap("%s_%s_tell" % [row[0], side])
			witnesses.restore_all()
	_pinned = false
	await get_tree().process_frame
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	get_tree().quit(0)


func _snap(label: String) -> void:
	for i in 60:
		await get_tree().process_frame
	for i in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	print("WITNESS SHOT: ", label)
