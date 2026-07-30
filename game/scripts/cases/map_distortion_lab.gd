class_name MapDistortionLab
extends Node3D
## Reversible visual reality laboratory. It deforms every rendered mesh on the
## player's current floor while leaving canonical collision in place, producing
## the sensation that the building and its physical memory disagree.

const MODES := [
	"none", "upside_down", "folded", "accordion", "dollhouse",
	"fractured", "breathing"
]

var building: Node3D
var mode := "none"
var _floor_id := ""
var _canonical: Dictionary = {}
var _pivot := Vector3.ZERO
var _announcement: Label


func setup(root: Node3D) -> void:
	building = root


func _ready() -> void:
	add_to_group("map_distortion_lab")
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


func _process(_delta: float) -> void:
	if mode == "none" or building == null or building.player == null:
		return
	var active := _active_floor_id()
	if active != _floor_id:
		restore()
		mode = mode # Preserve selected treatment across floor boundaries.
		_capture_floor(active)
	var time := Time.get_ticks_msec() / 1000.0
	for mesh in _canonical:
		if is_instance_valid(mesh):
			mesh.global_transform = _distorted(
					_canonical[mesh], mesh, time)
	if _announcement.modulate.a > 0.0:
		_announcement.modulate.a = maxf(
				0.0, _announcement.modulate.a - 0.008)


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
	return result


func _announce(message: String) -> void:
	if _announcement:
		_announcement.text = message
		_announcement.modulate.a = 0.9
