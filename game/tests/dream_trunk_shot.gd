extends Node
## The Vantry trunk's lit confirmation: you can see why it kills you.
##
##     SHOT_DIR=<abs> godot --path game res://tests/DreamTrunkShot.tscn
##
## Gate C wants three things from every hazard — a sound before the danger, a
## visible confirmation under the service lamp, and one reconstructable cause.
## The trunk had the sound (`TRUNK HISS`, unconditional, measured at 0.52 s
## from the doorway) and neither of the others: it was an invisible point in an
## empty corridor that ended the run if your lamp happened to be on. The
## mechanism was proved in `DreamHazardTest` block D; the *reason* was visible
## to nobody.
##
## These frames are the other two. The conduit is the cause, standing where the
## catalog put the socket. The arc is the confirmation, and the last pair is
## the one that matters: the same spot, the same distance, lamp on and lamp
## off. If darkness does not visibly let go, the ruled lesson — light can
## activate the danger it reveals — is not being taught, only enforced.

const SEED_HEX := "f123456789abcdef"

var _root: DreamMazeRoot
var _out := ""


func _ready() -> void:
	_out = OS.get_environment("SHOT_DIR")
	if _out == "":
		_out = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_out)
	await _build()
	var trunk := _hazard("vantry_signal_trunk")
	if trunk == null:
		printerr("[DREAM TRUNK SHOT] the trunk is not armed in this profile")
		get_tree().quit(1)
		return
	# Distances are taken from the socket's OWN authored radii rather than
	# typed, so these frames keep describing the hazard if it is re-authored.
	var tell: float = trunk.tell_radius
	var clear: float = trunk.clearance_radius
	await _capture("01_tell_edge_lamp_on", trunk, tell * 0.92, true)
	await _capture("02_half_way_lamp_on", trunk, tell * 0.45, true)
	await _capture("03_almost_touching_lamp_on", trunk, clear + 0.45, true)
	# THE PAIR. Same spot, same distance, and the only difference is the lamp.
	await _capture("04_same_spot_lamp_off", trunk, clear + 0.45, false)
	print("[DREAM TRUNK SHOT] 4 frames saved")
	get_tree().quit(0)


func _build() -> void:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	_root = scene.instantiate() as DreamMazeRoot
	_root.autonomous = false
	_root.configure_dream({
		"case_id": "mina_caption_crisis",
		"profile_id": "mina_release_print", "window": {},
		"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
	})
	add_child(_root)
	await get_tree().process_frame
	_root.player.set_physics_process(false)
	# Park the Tenant at the far end. A borrowed shadow crossing these frames
	# would be a second subject in a photograph about one thing.
	var spawn: Array = _root.plan.spawn_player
	_root.pursuer.reset_run(Vector3(spawn[0], 0.0, spawn[1]))
	_root.player.camera.make_current()


func _module_rect(module_id: String) -> Array:
	for entry in _root.plan.modules:
		if str(entry.id) == module_id:
			return entry.rect
	return [0.0, 0.0, 0.0, 0.0]


func _hazard(hid: String) -> DreamHazard:
	for h in _root.hazards.hazards:
		if h.id == hid:
			return h
	return null


## Stand `distance` from the conduit along the module's long axis, look at it,
## and let the arc settle before the shutter.
func _capture(file_name: String, trunk: DreamHazard, distance: float,
		lamp_on: bool) -> void:
	# STEP ALONG THE MODULE'S LONG AXIS, and get the axis from the module.
	# The first version walked +X from the socket regardless: the trunk lives
	# in D05_SERVICE_RISER, which is 2.08 m across, so five metres of +X put
	# the camera inside a wall and photographed the beam splash on the far
	# side of it. Nothing was wrong with the arc; the camera was not in the
	# room.
	var rect: Array = _module_rect(trunk.module)
	var span_x: float = float(rect[2]) - float(rect[0])
	var span_z: float = float(rect[3]) - float(rect[1])
	var axis := Vector3(1.0, 0.0, 0.0) if span_x >= span_z \
			else Vector3(0.0, 0.0, 1.0)
	# Whichever way along that axis has room for the whole approach.
	var forward_room: float = (float(rect[2]) - trunk.position.x) \
			if span_x >= span_z else (float(rect[3]) - trunk.position.z)
	if forward_room < distance + 0.6:
		axis = -axis
	var at: Vector3 = trunk.position + axis * distance
	at.y = 0.0
	_root.player.position = at
	var forward := trunk.position - at
	forward.y = 0.0
	if forward.length() > 0.01:
		_root.player.rotation.y = atan2(forward.x, -forward.z)
	_root.player.set_lamp_enabled(lamp_on)
	# Physics frames, not process frames: the arc is updated in
	# _physics_process alongside the practical, so a process-only wait would
	# photograph whatever the arc looked like one station ago.
	for _frame in 20:
		await get_tree().physics_frame
	for _frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out.path_join(file_name + ".png"))
	print("   saved %s  (%.2f m, lamp %s)" %
			[file_name, distance, "on" if lamp_on else "off"])
