class_name TVProp
extends StaticBody3D
## One television. The cabinet and bezel live in the merged floor mesh; this
## prop is the part with a state — the glass, the glow, and the switch.
##
## A set is ON when any of three parties wants it on: the player pressed E,
## a resident is sitting in front of it, or a poltergeist took it. It is off
## otherwise, because fifteen sets murmuring away in empty rooms turns the
## haunted broadcast into wallpaper — a television you had to turn on, or
## walked in on a neighbour watching, is an event.
##
## The glass shows the director's shared feed: one signal, one decode,
## every lit set in the building tuned to the same interference. The glow
## is an OmniLight driven each sample toward the average colour actually on
## screen, so a red title card warms the room and a dropout starves it.

const GLASS_W := 0.50
const GLASS_H := 0.90

var unit := ""
var player_on := false
## A resident's own deliberate latch. Proximity used to power the set
## automatically, which meant nobody in the building ever actually TOUCHED
## a television — the routine now walks to the couch and switches it on
## like a person, and switches it off again when they've had enough.
var npc_on := false
var possessed := false
var powered := false

var director: Node
var glass: MeshInstance3D
var glow: OmniLight3D

var _off_mat: StandardMaterial3D
var _voice: AudioStreamPlayer3D


func setup(owner_director: Node, unit_id: String, shared: ShaderMaterial) -> void:
	director = owner_director
	unit = unit_id
	name = "TV_" + unit_id
	add_to_group("televisions")
	var quad := QuadMesh.new()
	quad.size = Vector2(GLASS_W, GLASS_H)
	glass = MeshInstance3D.new()
	glass.mesh = quad
	# Where the merged glass used to sit: proud of the bezel on local +Y
	# (godot -Z after b2g), centred at the panel's mid-height.
	glass.position = Vector3(0.0, 0.75, -0.038)
	glass.rotation.y = PI
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	_off_mat = StandardMaterial3D.new()
	_off_mat.albedo_color = Color(0.035, 0.04, 0.045)
	_off_mat.roughness = 0.12
	_off_mat.metallic = 0.35
	glass.material_override = _off_mat
	set_meta("shared_mat", shared)
	glow = OmniLight3D.new()
	glow.position = Vector3(0.0, 0.9, -0.35)
	glow.omni_range = 3.4
	glow.light_energy = 0.0
	glow.shadow_enabled = false
	glow.visible = false
	add_child(glow)
	_voice = AudioStreamPlayer3D.new()
	_voice.bus = "Broadcast"
	_voice.position = Vector3(0.0, 0.8, 0.0)
	_voice.unit_size = 3.0
	_voice.max_distance = 15.0
	add_child(_voice)
	# The interact skin sits PROUD of the cabinet's furniture hull. The
	# merged hull is 0.19 deep and swallowed the old glass-level box
	# entirely, so the player's 2.1 m interact ray always stopped on the
	# hull — a switch nobody could ever reach. A few centimetres in front
	# of the cabinet face, it is the first thing the crosshair meets.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GLASS_W + 0.05, GLASS_H + 0.06, 0.05)
	shape.shape = box
	shape.position = Vector3(glass.position.x, glass.position.y, -0.235)
	add_child(shape)


func interact_prompt() -> String:
	return "[E]  Turn the television " + ("off" if powered else "on")


func interact(_player: Node) -> void:
	player_on = not player_on
	# Switching it off in a possessed room does nothing, which is correct.
	_refresh()


func set_possessed(on: bool) -> void:
	possessed = on
	if on:
		_voice.stream = PropAudio.get_stream("agitate_loop")
		_voice.volume_db = -13.0
		_voice.play()
	else:
		_voice.stop()
	_refresh()


func set_glow(tint: Color, luminance: float) -> void:
	if not powered:
		return
	glow.light_color = tint.lerp(Color(0.75, 0.82, 1.0), 0.25)
	glow.light_energy = clampf(0.25 + luminance * 1.1, 0.2, 1.4)
	# The glow only SPENDS a light when the player can see it. GL compat
	# caps lights per OBJECT and each floor's walls are one merged mesh —
	# seven resident-watched sets each carrying an unbudgeted omni was
	# enough to bust the cap and silently starve the apartments' own room
	# fixtures. The emissive glass still reads from any distance.
	var cam := get_viewport().get_camera_3d()
	glow.visible = cam != null and cam.global_position.distance_to(
			global_position) < 9.0


func set_npc(on: bool) -> void:
	npc_on = on
	_refresh()


func _refresh() -> void:
	var want := player_on or possessed or npc_on
	if want == powered:
		return
	powered = want
	glass.material_override = get_meta("shared_mat") if powered else _off_mat
	glow.visible = powered
	if not powered:
		glow.light_energy = 0.0
	if director and director.has_method("tv_power_changed"):
		director.tv_power_changed()
	print("[TV] %s %s" % [unit, "on" if powered else "off"])
