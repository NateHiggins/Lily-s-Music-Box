extends Node
## Free camera: fly the building, or shoot it from anywhere.
##
## Replaces the guess-a-coordinate screenshot workflow. Two modes:
##
## INTERACTIVE (default) — boots the building with a noclip godmode
## camera. WASD + mouse to fly, Shift boosts, Q/E drop and rise, F the
## torch, L a headlamp fill so surfaces can be judged without the game's
## dark, P writes a screenshot to the shot directory, Tab cycles floor
## visibility, Esc frees the mouse.
##
##     godot --path game res://tests/FreeCam.tscn
##
## SHOT — renders a list of framings and quits, so a texture pass can be
## audited without piloting anything. Frame by ROOM ID, which is the
## point: the tool computes a camera pose from the room's own rectangle
## instead of asking anyone to guess metres.
##
##     SHOT_DIR=<abs> SHOT_ROOMS="F01_LOBBY:up,F02_A_BATH:down,F04_B_KITCHEN"
##         godot --path game res://tests/FreeCam.tscn
##
## Framings: `up` (soffit), `down` (floor), `wall` (the long wall), or
## omitted for an eye-level three-quarter view of the whole room.
## SHOT_FILL=1 adds the judging light; SHOT_TORCH=0 kills the phone.

const SPEED := 4.0
const BOOST := 4.0

var root: Node3D
var cam: Camera3D
var fill: OmniLight3D
var _dir := ""
var _yaw := 0.0
var _pitch := 0.0
var _interactive := true
var _hud: Label


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.2).timeout
	if root.sanity:
		root.sanity.stand_down()
		root.sanity.enabled = false
	if root.fourth_wall:
		root.fourth_wall.force_finish()
	# The player stays, but parked and inert: its torch is the light we
	# want and its controller would otherwise fight us for the mouse.
	var player: PlayerController = root.player
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 220.0
	add_child(cam)
	cam.make_current()
	# The camera drives floor streaming, not the parked body. Forcing the
	# whole stack visible made the first frame effectively never finish.
	root.view_override = cam
	fill = OmniLight3D.new()
	fill.light_energy = 0.0
	fill.omni_range = 14.0
	fill.light_color = Color(1.0, 0.96, 0.92)
	cam.add_child(fill)
	if OS.get_environment("SHOT_TORCH") != "0":
		player.flashlight.visible = true
		player._light_mask.visible = true
		# carry the torch with the free camera, not the parked body
		player.flashlight.reparent(cam)
		player.flashlight.transform = Transform3D(
				Basis(), Vector3(0.16, -0.19, -0.06))
	if OS.get_environment("SHOT_FILL") == "1":
		fill.light_energy = 3.0
	var rooms := OS.get_environment("SHOT_ROOMS")
	if rooms != "":
		_interactive = false
		await _shoot_rooms(rooms)
		get_tree().quit(0)
		return
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Every room's rectangle, by id, in plan coordinates.
func _room_rects() -> Dictionary:
	var out := {}
	for fl in root.layout["floors"]:
		for r in fl["rooms"]:
			out[str(r["id"])] = {"rect": r["rect"], "z": float(fl["z"])}
	return out


func _shoot_rooms(spec: String) -> void:
	var rects := _room_rects()
	for entry in spec.split(","):
		var parts := entry.strip_edges().split(":")
		var rid := parts[0]
		var framing := parts[1] if parts.size() > 1 else "room"
		if rid.begins_with("@"):
			# @x_y_z:yaw — a raw stand, for views with no room to name
			# (the street, the roof edge, the light court from above).
			# Underscores, not commas: comma separates the shot list.
			var raw := rid.substr(1).split("_")
			if raw.size() >= 3:
				var yaw := float(framing) if framing.is_valid_float() else 0.0
				_place(Vector3(float(raw[0]), float(raw[1]), float(raw[2])),
						Vector3(yaw, -4, 0))
				await get_tree().create_timer(0.35).timeout
				await _snap("stand_%s.png" % framing)
			continue
		if not rects.has(rid):
			printerr("[FREECAM] unknown room: ", rid)
			continue
		var info: Dictionary = rects[rid]
		var rect: Array = info.rect
		var z: float = info.z
		var cx := (float(rect[0]) + float(rect[2])) * 0.5
		var cy := (float(rect[1]) + float(rect[3])) * 0.5
		var w := absf(float(rect[2]) - float(rect[0]))
		var d := absf(float(rect[3]) - float(rect[1]))
		match framing:
			"up":
				_place(GameBoot.b2g([cx, cy, z + 1.35]), Vector3(0, 55, 0))
			"down":
				_place(GameBoot.b2g([cx, cy, z + 1.75]), Vector3(0, -62, 0))
			"wall":
				# stand off the long wall and face it square
				var along_x: bool = w >= d
				var off: float = minf(2.4, (d if along_x else w) * 0.42)
				var px: float = cx if along_x else cx + off
				var py: float = cy + off if along_x else cy
				var yaw: float = 180.0 if along_x else -90.0
				_place(GameBoot.b2g([px, py, z + 1.45]),
						Vector3(yaw, -6, 0))
			_:
				# three-quarter: back into a corner, take in the volume
				var bx := cx - w * 0.34
				var by := cy - d * 0.34
				_place(GameBoot.b2g([bx, by, z + 1.55]),
						Vector3(atan2(cx - bx, cy - by) * 57.2958 + 180.0,
								-8, 0))
		await get_tree().create_timer(0.35).timeout
		await _snap("%s_%s.png" % [rid.to_lower(), framing])


func _place(pos: Vector3, look_deg: Vector3) -> void:
	cam.global_position = pos
	cam.rotation = Vector3.ZERO
	cam.rotate_y(deg_to_rad(look_deg.x))
	cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(look_deg.y))
	_yaw = cam.rotation.y
	_pitch = cam.rotation.x


func _snap(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _dir.path_join(file_name)
	image.save_png(path)
	print("[FREECAM] ", path)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(16, 16)
	_hud.add_theme_font_size_override("font_size", 13)
	_hud.modulate = Color(0.85, 0.92, 0.88)
	layer.add_child(_hud)


func _process(delta: float) -> void:
	if not _interactive or cam == null:
		return
	var speed := SPEED * (BOOST if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	var wish := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		wish -= cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		wish += cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		wish -= cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		wish += cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_E):
		wish += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		wish -= Vector3.UP
	cam.global_position += wish * speed * delta
	if _hud:
		var p := cam.global_position
		_hud.text = ("FREECAM  %.1f, %.1f, %.1f   plan %.1f, %.1f  z %.1f\n"
				% [p.x, p.y, p.z, p.x, -p.z, p.y]
				+ "WASD fly · QE down/up · Shift boost · F torch · "
				+ "L fill %.0f · P shot · Esc mouse"
				% fill.light_energy)


func _unhandled_input(event: InputEvent) -> void:
	if not _interactive:
		return
	if event is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.0025
		_pitch = clampf(_pitch - event.relative.y * 0.0025, -1.5, 1.5)
		cam.rotation = Vector3(_pitch, _yaw, 0.0)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F:
				var t: SpotLight3D = root.player.flashlight
				t.visible = not t.visible
				root.player._light_mask.visible = t.visible
			KEY_L:
				fill.light_energy = 0.0 if fill.light_energy > 0.0 else 3.0
			KEY_P:
				_snap("freecam_%d.png" % Time.get_ticks_msec())
			KEY_TAB:
				root.show_all_floors = not root.show_all_floors
				_hud.text = "all floors: %s" % root.show_all_floors
