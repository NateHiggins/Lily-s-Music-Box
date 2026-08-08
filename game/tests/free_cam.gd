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
## SHOT_LIGHTS=1: shoot each room under its own fixtures, not the fill.
var _lights_on := false
var _hud: Label


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	# The free camera IS the inspection tool, so it gets the inspection
	# facilities: debug launch mode builds the prop warehouse.
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
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
	# SHOT_TORCH=0 has to actively put the phone away. Skipping the enable
	# left the light mask on at whatever it defaulted to, which is a soft
	# radial vignette over the whole frame - every "torch off" shot came
	# back as a dim blob and looked like a lighting problem in the room.
	if OS.get_environment("SHOT_TORCH") == "0":
		player.flashlight.visible = false
		player._light_mask.visible = false
	if OS.get_environment("SHOT_TORCH") != "0":
		player.flashlight.visible = true
		player._light_mask.visible = true
		# carry the torch with the free camera, not the parked body
		player.flashlight.reparent(cam)
		player.flashlight.transform = Transform3D(
				Basis(), Vector3(0.16, -0.19, -0.06))
	if OS.get_environment("SHOT_FILL") == "1":
		# A judging light, not a flashgun. At 3.0 with a 14 m range this
		# blew out roughly a third of the building's rooms to a white
		# disc - which hides exactly the defects it was turned on to
		# find, and makes a tool fault look like a lighting fault.
		fill.light_energy = 1.05
		fill.omni_attenuation = 1.0
		fill.omni_range = 9.0
	# SHOT_PROBE="x,y,z" — name every visual whose world AABB contains a
	# point. A raycast only finds things with collision, and the passes
	# that dress this building add plenty of geometry without any, so a
	# render can show a thing that no ray will ever hit. This walks the
	# tree instead and answers "what is actually there".
	var probe := OS.get_environment("SHOT_PROBE")
	if probe != "":
		var pc := probe.split(",")
		if pc.size() >= 3:
			var at := Vector3(float(pc[0]), float(pc[1]), float(pc[2]))
			print("[PROBE] at ", at)
			_probe(root, at)
		get_tree().quit(0)
		return
	# SHOT_HIDE="a,b,c" — hide every node whose name contains any of these
	# before shooting. Merged meshes make an AABB probe ambiguous (one
	# mesh per material per floor, so its box covers the building); the
	# only unambiguous answer to "is THIS what I am looking at" is to
	# turn it off and look again.
	var hide := OS.get_environment("SHOT_HIDE")
	if hide != "":
		var n_hidden := _hide_matching(root, hide.split(","))
		print("[HIDE] %d node(s) hidden for %s" % [n_hidden, hide])
	# SHOT_FRIDGE_POSE="4B:open_tray" — put a real installed cold box in
	# its maintenance pose before framing it. Source inspection cannot prove
	# that a leaf clears the counter or that the drip tray comes toward the
	# player instead of through the wall; the render has to carry that proof.
	var fridge_pose := OS.get_environment("SHOT_FRIDGE_POSE")
	if fridge_pose != "":
		var fp := fridge_pose.split(":")
		_pose_fridges(root, String(fp[0]),
				String(fp[1]) if fp.size() > 1 else "open")
		await get_tree().create_timer(0.08).timeout
	_lights_on = OS.get_environment("SHOT_LIGHTS") == "1"
	var rooms := OS.get_environment("SHOT_ROOMS")
	if rooms != "":
		_interactive = false
		# Shot mode wants the world, not the instrumentation. Naming each
		# HUD as it turns up does not scale - the debug panel, the music
		# player, the station bug, the objective tracker and the phone are
		# five separate layers and there will be a sixth. Hide the class.
		var hidden := _hide_all_ui(root)
		print("[FREECAM] %d UI layer(s) hidden for shooting" % hidden)
		await _shoot_rooms(rooms)
		get_tree().quit(0)
		return
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _pose_fridges(node: Node, wanted_unit: String, pose: String) -> void:
	if node is FridgeProp:
		var fridge := node as FridgeProp
		if wanted_unit == "*" or fridge.unit == wanted_unit:
			fridge.set_door_open(true, 0.01)
			if pose.contains("tray"):
				fridge.set_tray_open(true, 0.01)
			if pose.contains("ice"):
				fridge.set_ice_door_open(true, 0.01)
	for child in node.get_children():
		_pose_fridges(child, wanted_unit, pose)


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
		# SHOT_LIGHTS=1 turns the room's OWN fixtures on before shooting.
		#
		# The judging fill is a lamp stuck to the camera: it flattens
		# everything toward it and lights surfaces from an angle no
		# fixture in the building ever will. Rooms shot that way are not
		# rooms a player has ever seen, and a defect list built from them
		# is a list about the rig. The switches exist now, so use them.
		if _lights_on and root.switch_system:
			if not root.switch_system.toggle_room(rid):
				root.switch_system.toggle_room(rid)
		if rid.begins_with("@"):
			# @x_y_z:yaw — a raw stand, for views with no room to name
			# (the street, the roof edge, the light court from above).
			# Underscores, not commas: comma separates the shot list.
			var raw := rid.substr(1).split("_")
			if raw.size() >= 3:
				# framing carries "yaw" or "yaw|pitch"
				var bits := framing.split("|")
				var yaw := float(bits[0]) if bits[0].is_valid_float() else 0.0
				var pitch := -4.0
				if bits.size() > 1 and bits[1].is_valid_float():
					pitch = float(bits[1])
				_place(Vector3(float(raw[0]), float(raw[1]), float(raw[2])),
						Vector3(yaw, pitch, 0))
				await get_tree().create_timer(0.35).timeout
				# Name it after the stand AND the framing. Naming it after
				# the framing alone meant any two stands shot from
				# different places at the same angle wrote the same file,
				# and the run silently returned one image instead of two.
				await _snap("stand_%s_%s.png" % [rid.substr(1), framing])
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
				# Three-quarter: back into a corner and take in the volume.
				# In a small room there is no corner to back into - a 2 m
				# bathroom put the lens 0.7 m off the wall with the torch
				# on it, and every such shot came back as a white disc. A
				# room that cannot be framed from inside gets framed from
				# above instead, which is a view no wall can block.
				if minf(w, d) < 3.0:
					# 2.30 is where the ceiling fixtures hang. The office
					# and the small baths put the lens INSIDE the pendant
					# and came back 90% white - a shot that says nothing
					# about the room and reads as a lighting blowout. Drop
					# under the fixtures and off-centre, so the pendant is
					# above the lens rather than around it.
					_place(GameBoot.b2g([cx - w * 0.22, cy - d * 0.22,
							z + 1.78]), Vector3(24, -38, 0))
				else:
					var bx := cx - w * 0.34
					var by := cy - d * 0.34
					_place(GameBoot.b2g([bx, by, z + 1.55]),
							Vector3(atan2(cx - bx, cy - by) * 57.2958 + 180.0,
									-8, 0))
		await get_tree().create_timer(0.35).timeout
		await _snap("%s_%s.png" % [rid.to_lower(), framing])


## Every CanvasLayer under the building, plus the free camera's own HUD.
## A screenshot that carries a track title is a screenshot of the HUD.
func _hide_all_ui(node: Node) -> int:
	var n := 0
	if node is CanvasLayer:
		(node as CanvasLayer).visible = false
		return 1
	for c in node.get_children():
		n += _hide_all_ui(c)
	return n


func _hide_matching(node: Node, needles: PackedStringArray) -> int:
	var n := 0
	for needle in needles:
		var key := needle.strip_edges()
		if key != "" and String(node.name).contains(key):
			if node is Node3D:
				(node as Node3D).visible = false
				return 1
	for c in node.get_children():
		n += _hide_matching(c, needles)
	return n


func _probe(node: Node, at: Vector3, depth := 0) -> void:
	if node is VisualInstance3D:
		var vi := node as VisualInstance3D
		var box: AABB = vi.get_aabb()
		var world: AABB = vi.global_transform * box
		# Skip the merged per-material meshes: one of those covers the
		# whole building, so it "contains" every probe point and buries
		# the small thing you are actually looking for.
		var span: float = maxf(world.size.x, maxf(world.size.y, world.size.z))
		if span < 4.0 and world.grow(0.08).has_point(at):
			var trail: Array[String] = []
			var walk: Node = node
			for _i in 6:
				if walk == null:
					break
				trail.push_front(String(walk.name))
				walk = walk.get_parent()
			var mat := ""
			if node is MeshInstance3D:
				var mi := node as MeshInstance3D
				if mi.material_override:
					mat = " mat=%s" % mi.material_override.resource_name
				if mi.mesh:
					mat += " mesh=%s" % mi.mesh.get_class()
			print("[PROBE] %s | aabb %s%s | visible=%s"
					% ["/".join(trail), world, mat, vi.visible])
	for c in node.get_children():
		_probe(c, at, depth + 1)


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
	# Stand names carry the pose that produced them, and a pose is full of
	# characters Windows will not accept in a filename. save_png fails
	# silently enough that the run looks like it produced nothing at all,
	# which is exactly how this went unnoticed.
	var safe := file_name
	for bad in ["|", ":", "*", "?", "\"", "<", ">", "@"]:
		safe = safe.replace(bad, "_")
	# Report what the reticle is actually on. Diagnosing geometry from a
	# render means guessing; a node path and a world coordinate do not.
	var cam3d := get_viewport().get_camera_3d()
	if cam3d:
		var eye := cam3d.global_position
		var q := PhysicsRayQueryParameters3D.create(
				eye, eye - cam3d.global_transform.basis.z * 40.0)
		var hit: Dictionary = cam3d.get_world_3d().direct_space_state 				.intersect_ray(q)
		if hit.has("collider") and is_instance_valid(hit["collider"]):
			var trail: Array[String] = []
			var walk: Node = hit["collider"]
			for _i in 5:
				if walk == null:
					break
				trail.push_front(String(walk.name))
				walk = walk.get_parent()
			var at: Vector3 = hit["position"]
			print("[AIM] %s | world (%.3f, %.3f, %.3f) | layout (%.3f, %.3f) z %.3f"
					% ["/".join(trail), at.x, at.y, at.z, at.x, -at.z, at.y])
		else:
			print("[AIM] nothing under the reticle")
	var path := _dir.path_join(safe)
	var err := image.save_png(path)
	if err != OK:
		push_error("[FREECAM] could not write %s (error %d)" % [path, err])
		return
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
