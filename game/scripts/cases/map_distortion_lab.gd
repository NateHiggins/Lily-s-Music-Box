class_name MapDistortionLab
extends Node3D
## Reversible visual reality laboratory. It deforms every rendered mesh on the
## player's current floor while leaving canonical collision in place, producing
## the sensation that the building and its physical memory disagree.

const MODES := [
	"none", "upside_down", "folded", "accordion", "dollhouse",
	"fractured", "breathing"
]
const CHAOS_WEIGHTS := {
	"upside_down": 0.12, "folded": 0.20, "accordion": 0.18,
	"dollhouse": 0.12, "fractured": 0.22, "breathing": 0.16,
}
const CHAOS_MESSAGES := [
	"THE FLOOR HAS RECONSIDERED",
	"COLLISION REMEMBERS ANOTHER BUILDING",
	"PLEASE REMAIN GEOMETRIC",
	"MAP REVISION IN PROGRESS",
	"YOUR LOCATION HAS BEEN APPEALED",
	"THIS HALLWAY IS TEMPORARILY METAPHORICAL",
]

var building: Node3D
var mode := "none"
var _floor_id := ""
var _canonical: Dictionary = {}
var _pivot := Vector3.ZERO
var _announcement: Label
var chaos_enabled := false
var _chaos_clock := 0.0
var _chaos_duration := 2.5
var _chaos_strength := 1.0
var _chaos_target := 1.0
var _chaos_phase := 0
var _rng := RandomNumberGenerator.new()


func setup(root: Node3D) -> void:
	building = root


func _ready() -> void:
	add_to_group("map_distortion_lab")
	_rng.randomize()
	_build_announcement()


func _build_announcement() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	_announcement = Label.new()
	_announcement.position = Vector2(450, 52)
	_announcement.size = Vector2(380, 50)
	_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement.add_theme_font_size_override("font_size", 17)
	_announcement.modulate = Color(0.72, 0.88, 0.84, 0.0)
	layer.add_child(_announcement)


func cycle_mode() -> void:
	if chaos_enabled:
		set_chaos(false)
	var next := (MODES.find(mode) + 1) % MODES.size()
	set_mode(MODES[next])


func set_mode(next_mode: String) -> void:
	if next_mode not in MODES:
		return
	restore()
	mode = next_mode
	if mode != "none":
		_capture_active_floor()
	_announce("MAP MEMORY: " + mode.replace("_", " ").to_upper())


func toggle_chaos() -> void:
	set_chaos(not chaos_enabled)


func set_chaos(on: bool) -> void:
	if chaos_enabled == on:
		return
	chaos_enabled = on
	restore()
	if on:
		_chaos_clock = 0.0
		_chaos_duration = 0.6
		_chaos_strength = 0.0
		_chaos_target = 1.0
		_chaos_phase = 0
		mode = "breathing"
		_capture_active_floor()
		_announce("CHAOS MODE: REALITY AUTOPILOT ENGAGED")
	else:
		mode = "none"
		_chaos_strength = 1.0
		_chaos_target = 1.0
		_announce("CHAOS MODE: CANONICAL MAP RESTORED")


func restore() -> void:
	for mesh in _canonical:
		if is_instance_valid(mesh):
			mesh.global_transform = _canonical[mesh]
	_canonical.clear()
	_floor_id = ""


func _exit_tree() -> void:
	restore()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("distort_map"):
		cycle_mode()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("chaos_mode"):
		toggle_chaos()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if building == null or building.player == null:
		return
	if chaos_enabled:
		_update_chaos(delta)
	if mode == "none":
		return
	var active := _active_floor_id()
	if active != _floor_id:
		restore()
		mode = mode # Preserve selected treatment across floor boundaries.
		_capture_floor(active)
	var time := Time.get_ticks_msec() / 1000.0
	for mesh in _canonical:
		if is_instance_valid(mesh):
			var canonical: Transform3D = _canonical[mesh]
			var altered := _distorted(canonical, mesh, time)
			mesh.global_transform = canonical.interpolate_with(
					altered, _chaos_strength if chaos_enabled else 1.0)
	if _announcement.modulate.a > 0.0:
		_announcement.modulate.a = maxf(
				0.0, _announcement.modulate.a - 0.008)


func _update_chaos(delta: float) -> void:
	_chaos_clock += delta
	var player_speed: float = building.player.velocity.length()
	var movement_pressure := clampf(player_speed / 4.6, 0.0, 1.0)
	_chaos_target = 0.62 + movement_pressure * 0.38
	_chaos_strength = move_toward(
			_chaos_strength, _chaos_target, delta * 0.72)
	if _chaos_clock < _chaos_duration:
		return
	_chaos_clock = 0.0
	_chaos_phase += 1
	# Every fifth phase offers a short, suspicious calm.
	if _chaos_phase % 5 == 0:
		_switch_chaos_map("none")
		_chaos_duration = _rng.randf_range(0.65, 1.35)
		_chaos_strength = 0.0
		_announce("REALITY APPEARS NORMAL")
		return
	_switch_chaos_map(_choose_chaos_mode())
	_chaos_duration = _rng.randf_range(1.8, 4.8) \
			- movement_pressure * 0.8
	_chaos_strength = 0.05
	_announce(CHAOS_MESSAGES[_rng.randi_range(
			0, CHAOS_MESSAGES.size() - 1)])


func _choose_chaos_mode(sample := -1.0) -> String:
	var roll: float = sample if sample >= 0.0 else _rng.randf()
	var cursor := 0.0
	for candidate in CHAOS_WEIGHTS:
		cursor += float(CHAOS_WEIGHTS[candidate])
		if roll <= cursor and candidate != mode:
			return candidate
	var alternatives := CHAOS_WEIGHTS.keys()
	alternatives.erase(mode)
	return alternatives[_rng.randi_range(0, alternatives.size() - 1)]


func _switch_chaos_map(next_mode: String) -> void:
	restore()
	mode = next_mode
	if mode != "none":
		_capture_active_floor()


func _capture_active_floor() -> void:
	_capture_floor(_active_floor_id())


func _capture_floor(floor_id: String) -> void:
	if not building.floor_nodes.has(floor_id):
		return
	_floor_id = floor_id
	var floor_node: Node = building.floor_nodes[floor_id]
	var meshes := floor_node.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	_pivot = Vector3.ZERO
	for mesh in meshes:
		_canonical[mesh] = mesh.global_transform
		_pivot += mesh.global_position
	_pivot /= float(meshes.size())


func _active_floor_id() -> String:
	var player_y: float = building.player.global_position.y
	var closest := "F01"
	var distance := INF
	for floor_id in building.floor_nodes:
		var level: float = building.layout["meta"]["levels"].get(
				floor_id, 0.0)
		var candidate := absf(player_y - level)
		if candidate < distance:
			distance = candidate
			closest = floor_id
	return closest


func _distorted(original: Transform3D, mesh: MeshInstance3D,
		time: float) -> Transform3D:
	var result := original
	var relative := original.origin - _pivot
	match mode:
		"upside_down":
			var flip := Basis(Vector3.FORWARD, PI)
			result.origin = _pivot + flip * relative
			result.basis = flip * original.basis
		"folded":
			var side := 1.0 if relative.x >= 0.0 else -1.0
			var angle := deg_to_rad(58.0) * side
			var fold := Basis(Vector3.FORWARD, angle)
			var hinge_relative := Vector3(relative.x, relative.y, relative.z)
			result.origin = _pivot + fold * hinge_relative
			result.basis = fold * original.basis
		"accordion":
			var band: float = floor((relative.z + 12.0) / 2.2)
			var direction := 1.0 if int(band) % 2 == 0 else -1.0
			result.origin.x += direction * 1.35
			result.origin.y += sin(band * 1.7) * 0.42
			result.basis = Basis(Vector3.UP,
					deg_to_rad(18.0) * direction) * original.basis
		"dollhouse":
			result.origin = _pivot + relative * 0.58 + Vector3.UP * 0.9
			result.basis = original.basis.scaled(Vector3.ONE * 0.58)
		"fractured":
			var seed: int = absi(hash(mesh.get_path()))
			var offset := Vector3(
					float(seed % 13 - 6) * 0.16,
					float(int(seed / 13.0) % 9 - 4) * 0.13,
					float(int(seed / 117.0) % 13 - 6) * 0.16)
			result.origin += offset
			var axis := Vector3(0.3 + float(seed % 5), 1.0,
					0.2 + float(seed % 7)).normalized()
			result.basis = Basis(axis,
					deg_to_rad(float(seed % 19 - 9))) * original.basis
		"breathing":
			var phase := float(abs(hash(mesh.name)) % 100) * 0.07
			var pulse := 1.0 + sin(time * 1.15 + phase) * 0.085
			result.origin = _pivot + Vector3(
					relative.x * pulse,
					relative.y + sin(time * 1.7 + phase) * 0.12,
					relative.z * (2.0 - pulse))
			result.basis = original.basis.scaled(
					Vector3(pulse, 1.0 / pulse, 2.0 - pulse))
	if chaos_enabled and mode not in ["none", "breathing"]:
		var chaos_phase := float(abs(hash(mesh.name)) % 31) * 0.11
		var twitch := sin(time * 2.4 + chaos_phase) * 0.035
		result.origin += relative.normalized() * twitch
		result.basis = result.basis.scaled(Vector3(
				1.0 + twitch, 1.0 - twitch * 0.6,
				1.0 + twitch * 0.3))
	return result


func _announce(message: String) -> void:
	if _announcement:
		_announcement.text = message
		_announcement.modulate.a = 0.9
