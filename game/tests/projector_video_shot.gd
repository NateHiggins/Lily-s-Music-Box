extends Node
## A reel thrown on a real wall, in the building, as video.
##
##     SHOT_DIR=<abs> REEL=ch_01 godot --path game res://tests/ProjectorVideoShot.tscn
##
## Everything the still tests could not answer lives here: whether the long
## exposure reads as a ghost when it is actually moving, whether a projection
## survives landing on plaster that has its own colour and its own light, and
## whether the mould looks like damage or like a smudge on the lens once the
## picture underneath it is alive.
##
## THE ACCUMULATION IS THE POINT. `ArcadeMachine._build_phosphor()` already does
## this - SubViewport, CLEAR_MODE_NEVER, a low-alpha black rect to decay the
## previous frame, then the new frame drawn over it at partial alpha. The
## arcade's version forgets in milliseconds because a scope trace should. This
## one forgets in seconds, which is the difference between a phosphor and an
## eight-hour exposure, and it is the whole effect.

## Decay per frame. Lower = longer memory = more ghost. 0.055 holds roughly a
## second and a half at 60 fps, which is where a walking figure stops having a
## head.
const DECAY := 0.055
const LIVE_ALPHA := 0.5
const RES := Vector2i(384, 640)
const FRAMES := 150

var _accum: SubViewport
var _shot_dir := ""
var _saved := 0


func _ready() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	var reel := OS.get_environment("REEL")
	if reel == "":
		reel = "ch_01"

	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root: Node3D = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.4).timeout
	root.show_all_floors = true
	# The HUD is not the subject, and hiding root's direct children is not
	# enough - the fourth-wall titles live deeper and re-show themselves, so
	# they get swept again every frame in _process.
	_hide_overlays()
	# PUT THE ROOM OUT. A projector competing with a lit ceiling pendant loses,
	# and the whole argument for blend_add is that the image cannot be brighter
	# than the lamp throwing it. Darkness is not mood here, it is the premise.
	for f in get_tree().get_nodes_in_group("light_fixtures"):
		if "powered" in f:
			f.set_powered(false)
	Conductor.infection = 0.0
	if root.sanity:
		root.sanity.stand_down()
		root.sanity.enabled = false
	if root.fourth_wall:
		root.fourth_wall.force_finish()

	# --- the film, into a viewport so it becomes a texture ------------------
	var feed := SubViewport.new()
	feed.size = RES
	feed.disable_3d = true
	feed.transparent_bg = false
	feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(feed)
	var player := VideoStreamPlayer.new()
	player.stream = load("res://assets/video/clips/%s.ogv" % reel)
	player.expand = true
	player.loop = true
	player.volume_db = -80.0
	player.size = Vector2(RES)
	feed.add_child(player)
	player.play()

	# --- the plate: the same construction as the arcade phosphor ------------
	_accum = SubViewport.new()
	_accum.size = RES
	_accum.disable_3d = true
	_accum.transparent_bg = false
	_accum.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_accum.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_accum)
	var decay := ColorRect.new()
	decay.color = Color(0.0, 0.0, 0.0, DECAY)
	decay.size = Vector2(RES)
	_accum.add_child(decay)
	var live := TextureRect.new()
	live.texture = feed.get_texture()
	live.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	live.size = Vector2(RES)
	live.modulate = Color(1, 1, 1, LIVE_ALPHA)
	_accum.add_child(live)

	# --- the wall it lands on ----------------------------------------------
	# 2A's main room, west wall - on the PLASTER, north of the window.
	#
	# The first attempt centred on the wall at y -3.35, which is exactly where
	# the window is: the ghost landed across a venetian blind and read as a
	# projection onto glass, which is the one surface a projector cannot use.
	# Screen-right from this camera is +Y in Blender, so the clear plaster run
	# is north of centre.
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.42, 2.10)
	quad.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/projected_film.gdshader")
	mat.set_shader_parameter("frame", _accum.get_texture())
	mat.set_shader_parameter("plate", 1.0)
	mat.set_shader_parameter("mono", 1.0)
	mat.set_shader_parameter("reel_tint", Color(1.06, 0.98, 0.84))
	mat.set_shader_parameter("mould", 0.42)
	mat.set_shader_parameter("mould_origin", Vector2(0.14, 0.82))
	mat.set_shader_parameter("gain", 1.15)
	mat.set_shader_parameter("falloff", 1.05)
	mat.set_shader_parameter("grain_amount", 0.16)
	mat.set_shader_parameter("dust_amount", 0.10)
	quad.material_override = mat
	quad.position = GameBoot.b2g([-13.62, -1.62, 4.55])
	quad.rotation.y = PI * 0.5     # QuadMesh faces +Z; turn it to face east
	add_child(quad)

	# The lamp that is throwing it. Warm, weak, and behind the camera.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.90, 0.72)
	lamp.light_energy = 0.32
	lamp.omni_range = 3.6
	lamp.position = GameBoot.b2g([-10.6, -1.62, 5.00])
	add_child(lamp)

	var cam := Camera3D.new()
	cam.fov = 58
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	# Back and up. At x -9.2 the camera stood inside the sofa and shot the
	# projection past a tabletop.
	cam.position = GameBoot.b2g([-7.45, -2.35, 4.98])
	cam.look_at(GameBoot.b2g([-13.62, -1.70, 4.45]))

	# Let the plate build up before recording, or the first second is a
	# perfectly sharp video frame and gives the whole trick away.
	# Long enough for the floor to finish streaming AND for the plate to build.
	# The first run recorded its opening second in the lobby.
	await get_tree().create_timer(4.5).timeout
	set_process(true)


func _hide_overlays() -> void:
	for node in get_tree().get_nodes_in_group("_all_"):
		pass
	_sweep(get_tree().root)


func _sweep(n: Node) -> void:
	if n is CanvasLayer:
		n.visible = false
	# The prop nameplates are Label3D in the world, not HUD, so hiding canvas
	# layers never touched them.
	if n is Label3D:
		n.visible = false
	for c in n.get_children():
		_sweep(c)


func _process(_delta: float) -> void:
	if _shot_dir == "":
		return
	_hide_overlays()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
			"%s/pv_%04d.png" % [_shot_dir, _saved])
	_saved += 1
	if _saved >= FRAMES:
		print("[PROJ] %d frames" % _saved)
		get_tree().quit(0)
