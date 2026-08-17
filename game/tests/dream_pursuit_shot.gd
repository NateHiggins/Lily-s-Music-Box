extends Node
## N6 production proof frames: the real DreamMazeRoot, the real service lamp,
## and the Tenant present only as Mina's borrowed shadow on module
## architecture. No frame may contain a beauty-pass body.

const SEED_HEX := "f123456789abcdef"

var _root: DreamMazeRoot
var _caption: Label
var _output_dir := ""


func _ready() -> void:
	_output_dir = OS.get_environment("SHOT_DIR")
	if _output_dir == "":
		_output_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_output_dir)
	await _build_world()
	await _capture("01_lamp_on_borrowed_shadow", true,
			"N6 PRODUCTION // LAMP ON // THE TENANT IS MINA'S SHADOW ONLY")
	await _capture("02_lamp_off_black_level", false,
			"N6 PRODUCTION // LAMP OFF // DARKNESS DELAYS, NEVER HIDES")
	print("[DREAM PURSUIT N6 SHOT] RESULT: PASS")
	get_tree().quit(0)


## THE SCENE NOW BRINGS ITS OWN LIGHT, so this harness stopped bringing any.
##
## Until 2026-08-17 this function built a WorldEnvironment and two OmniLight3Ds
## before photographing anything, because production had none of the three:
## `CampaignShell` frees the waking world that owns the waking environment, and
## `DreamMazeRoot` built no replacement. The controls were honestly named —
## `RecedingOrientationControl`, `NearestFloorBlackLevelControl` — but the
## consequence was that N6's proof frames demonstrated navigable darkness in a
## scene no player could enter, and the real one was pure black
## (`art/renders/dream_env_n7/before/`).
##
## `DreamMazeRoot` now owns a WorldEnvironment, a carried black level and the
## ruled receding practical. Keeping the controls here would double every one
## of them and leave these frames just as unlike production as before, in the
## other direction.
func _build_world() -> void:
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

	# Stage inside D01 against its solid long wall: the borrowed silhouette
	# stands between the player's carried lamp and the plaster. The frame is
	# the player's own production camera — the beam is a first-person
	# instrument (screen mask plus baked cookie) and only reads truthfully
	# from the eye that carries it.
	var d01: Array = []
	for entry in _root.plan.modules:
		if str(entry.id) == "D01_F04_LONG_HALL":
			d01 = entry.rect
	var hall_z: float = (d01[1] + d01[3]) * 0.5
	# The hall is 19.30 m long in x and only 2.08 m deep in z: the staging
	# axis is the long one, against the solid east end wall.
	var wall_x: float = d01[2]
	_root.player.position = Vector3(wall_x - 2.6, 0.0, hall_z)
	_root.player.rotation.y = -PI / 2.0
	_root.pursuer.reset_run(Vector3(wall_x - 1.2, 0.0, hall_z))

	# No orientation controls. The scene owns its black level and its receding
	# practical now; see the note on _build_world.

	_root.player.camera.make_current()

	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	_caption = Label.new()
	_caption.position = Vector2(24, 22)
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_color_override("font_color", Color("d9c996"))
	canvas.add_child(_caption)


func _capture(file_name: String, lamp_on: bool, caption: String) -> void:
	_root.player.set_lamp_enabled(lamp_on)
	_caption.text = caption
	for _frame in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _output_dir.path_join(file_name + ".png")
	var error := image.save_png(path)
	if error != OK:
		push_error("N6 shot failed to write %s" % path)
		get_tree().quit(1)
		return
	print("[DREAM PURSUIT N6 SHOT] saved %s" % path)
