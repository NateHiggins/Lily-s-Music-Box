class_name StoveProp
extends FunctionalProp
## The enamel range. Its BODY is baked into the floor mesh with the rest
## of the cabinetry (asm_stove); this prop supplies only the parts that
## move or glow — the oven door on its bottom hinge and the four burner
## rings — so nothing is drawn twice and the door can still open.
##
## Normal: a pilot tick every so often, and whatever burner the tenant
## left on. Possessed: every ring blooms at once and the door beats.

const DOOR_W := 0.55
const DOOR_H := 0.365
const DOOR_Z := 0.335

var _door: Node3D
var _open := false
var _possessed := false
var _rings: Array[OmniLight3D] = []
var _ring_meshes: Array[MeshInstance3D] = []
var _tick: AudioStreamPlayer3D
var _burn: AudioStreamPlayer3D


func _build_visual() -> void:
	var enamel := Color(0.88, 0.87, 0.84)
	# Hinged at the BOTTOM edge, because an oven door falls open toward
	# you; the hinge sits at the door's foot on the front face.
	_door = Node3D.new()
	_door.name = "OvenDoor"
	_door.position = Vector3(0, DOOR_Z, -0.31)
	add_child(_door)
	var face := make_box(Vector3(DOOR_W, DOOR_H, 0.024),
			Vector3(0, DOOR_H * 0.5, 0), enamel)
	face.reparent(_door, false)
	face.position = Vector3(0, DOOR_H * 0.5, 0)
	var glass := make_box(Vector3(0.30, 0.13, 0.008),
			Vector3(0, 0.0, 0), Color(0.10, 0.10, 0.11))
	glass.reparent(_door, false)
	glass.position = Vector3(0, DOOR_H * 0.62, -0.016)
	var rail := make_cyl(0.012, 0.012, 0.48,
			Vector3(0, 0, 0), Color(0.80, 0.82, 0.85), 0.12, 1.0)
	rail.reparent(_door, false)
	rail.rotation_degrees = Vector3(0, 0, 90)
	rail.position = Vector3(0, DOOR_H - 0.03, -0.046)
	# Four rings: a dark plate that glows, and the light it throws.
	for spot in [Vector2(-0.15, -0.12), Vector2(0.15, -0.12),
			Vector2(-0.15, 0.14), Vector2(0.15, 0.14)]:
		var ring := make_cyl(0.085, 0.085, 0.012,
				Vector3(spot.x, 0.906, spot.y), Color(0.12, 0.11, 0.10))
		_ring_meshes.append(ring)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.42, 0.16)
		glow.light_energy = 0.0
		glow.omni_range = 1.1
		glow.position = Vector3(spot.x, 0.93, spot.y)
		add_child(glow)
		_rings.append(glow)
	retexture(self, [
		[enamel, "appliance", Color.WHITE],
		[Color(0.80, 0.82, 0.85), "chrome", Color.WHITE],
	])
	_tick = make_emitter("tick", -20.0)
	_burn = make_emitter("hum_loop", -30.0, true)


func interact_prompt() -> String:
	return "[E]  %s the oven" % ("Close" if _open else "Open")


func interact(_player: Node) -> void:
	set_door_open(not _open)


## One path for the hand and the haunting, so a possessed door and the
## prompt can never disagree about the latch.
func set_door_open(open: bool, seconds := 0.5) -> void:
	if _door == null:
		return
	_open = open
	_tick.pitch_scale = 0.85 if open else 1.1
	_tick.play()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	# falls forward and down about its foot
	tween.tween_property(_door, "rotation:x",
			deg_to_rad(-84.0) if open else 0.0, seconds)


func set_ring(index: int, on: bool, seconds := 0.8) -> void:
	if index < 0 or index >= _rings.size():
		return
	create_tween().tween_property(_rings[index], "light_energy",
			1.5 if on else 0.0, seconds)
	var mat := _ring_meshes[index].material_override as StandardMaterial3D
	if mat:
		mat.emission_enabled = true
		create_tween().tween_property(mat, "emission_energy_multiplier",
				2.4 if on else 0.0, seconds)


## Possession: every ring at once and the door beating under them. A
## range has four voices and no mouth.
func possess_fit(beats := 4) -> void:
	if _possessed:
		return
	_possessed = true
	for i in range(_rings.size()):
		set_ring(i, true, 0.25)
	create_tween().tween_property(_burn, "volume_db", -14.0, 0.4)
	for i in range(beats):
		set_door_open(true, 0.15)
		await get_tree().create_timer(0.21, false).timeout
		if not is_inside_tree():
			return
		set_door_open(false, 0.12)
		await get_tree().create_timer(0.28 if i % 2 else 0.17,
				false).timeout
		if not is_inside_tree():
			return
	for i in range(_rings.size()):
		set_ring(i, false, 1.4)
	create_tween().tween_property(_burn, "volume_db", -30.0, 1.4)
	_possessed = false


func _start_normal_function() -> void:
	state = PState.OPERATING
	# Somebody left a ring on. Which one is a per-stove accident.
	if rng.randf() < 0.35:
		set_ring(rng.randi_range(0, 3), true, 2.0)


func _perform_synced_event(index: int, _accent: float, _pitch: float) -> void:
	set_ring(index % maxi(1, _rings.size()), true, 0.18)
	_tick.pitch_scale = rng.randf_range(0.9, 1.1)
	_tick.play()
