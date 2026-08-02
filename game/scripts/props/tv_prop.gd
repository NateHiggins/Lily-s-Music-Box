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
## Resident within this range counts as watching. Their routine parks them
## at the living-room centre, a couple of metres from their own set.
const WATCH_RANGE := 4.2

var unit := ""
var player_on := false
var possessed := false
var npc_watching := false
var powered := false

var director: Node
var glass: MeshInstance3D
var glow: OmniLight3D

var _off_mat: StandardMaterial3D
var _voice: AudioStreamPlayer3D
var _poll := 0.0


func setup(owner_director: Node, unit_id: String, shared: ShaderMaterial) -> void:
	director = owner_director
	unit = unit_id
	name = "TV_" + unit_id
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
	_voice.position = Vector3(0.0, 0.8, 0.0)
	_voice.unit_size = 3.0
	_voice.max_distance = 15.0
	add_child(_voice)
	# Thin interact target across the glass; the cabinet's own hull already
	# carries the furniture collision, so this adds no new obstacle.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GLASS_W + 0.05, GLASS_H + 0.06, 0.06)
	shape.shape = box
	shape.position = glass.position
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


func _process(delta: float) -> void:
	_poll += delta
	if _poll < 2.0:
		return
	_poll = 0.0
	var was := npc_watching
	npc_watching = false
	for res in get_tree().get_nodes_in_group("resident_placeholders"):
		if not (res is Node3D) or not res.visible:
			continue
		var d: Vector3 = res.global_position - global_position
		if absf(d.y) < 1.6 and Vector2(d.x, d.z).length() < WATCH_RANGE:
			npc_watching = true
			break
	if npc_watching != was:
		_refresh()


func _refresh() -> void:
	var want := player_on or possessed or npc_watching
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
