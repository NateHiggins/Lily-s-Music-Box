class_name OtisProp
extends FunctionalProp
## The porter's board, on the lobby wall by the lift.
##
## A brass annunciator with a lamp per landing — the thing a porter
## would have watched all night when the building still had one. There
## has not been a porter in years, which is why the board is yours.

signal maintenance_completed(result: Dictionary)

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

var _panel: Node
var _service_panel: MaintenanceActivityPanel
var _clack: AudioStreamPlayer3D
var _lamps: Array = []
var _flag_arms: Array[MeshInstance3D] = []
var _contact_bridge: MeshInstance3D
var _reset_spindle: MeshInstance3D
var _t := 0.0

var stuck_flag := true
var contact_alignment := 0.32
var bank_reset := 0.0


func _build_visual() -> void:
	# Mahogany case, brass face, eight little windows in a column.
	make_box(Vector3(0.26, 0.62, 0.06), Vector3(0, 0, 0),
			Color(0.26, 0.15, 0.09))
	var face := make_box(Vector3(0.21, 0.55, 0.012),
			Vector3(0, 0, 0.036), Color(0.55, 0.44, 0.20))
	var fm := face.material_override as StandardMaterial3D
	fm.metallic = 0.65
	fm.roughness = 0.38
	var legend := Label3D.new()
	legend.name = "ColumnLegend"
	legend.text = "CAR     CALL"
	legend.font_size = 64
	legend.pixel_size = 0.00022
	legend.modulate = Color(0.92, 0.82, 0.56)
	legend.outline_size = 5
	legend.outline_modulate = Color(0.10, 0.055, 0.025, 0.9)
	legend.position = Vector3(-0.008, 0.288, 0.042)
	add_child(legend)
	for i in 8:
		var lamp := make_box(Vector3(0.055, 0.035, 0.008),
				Vector3(-0.055, 0.235 - i * 0.063, 0.044),
				Color(0.30, 0.26, 0.16))
		_lamps.append(lamp.material_override as StandardMaterial3D)
		make_box(Vector3(0.075, 0.030, 0.006),
				Vector3(0.040, 0.235 - i * 0.063, 0.042),
				Color(0.78, 0.74, 0.66))
		# A hinged flag sits proud of each ivory legend. These are call
		# armatures, not the travelling-car lamps at left.
		var arm := make_box(Vector3(0.058, 0.021, 0.010),
				Vector3(0.040, 0.235 - i * 0.063, 0.054),
				Color(0.48, 0.08, 0.055))
		_flag_arms.append(arm)
	# Exposed silver faces and the common reset spindle make all three service
	# beats visible on the board instead of only on the paper strip.
	_contact_bridge = make_box(Vector3(0.086, 0.014, 0.012),
			Vector3(0.0, -0.282, 0.056), Color(0.72, 0.70, 0.62))
	_reset_spindle = make_cyl(0.020, 0.020, 0.075,
			Vector3(0.092, -0.282, 0.058), Color(0.58, 0.44, 0.20),
			0.34, 0.72)
	_reset_spindle.rotation_degrees.x = 90.0
	_build_control_area("DispatchReach", "dispatch",
			Vector3(-0.060, 0.0, 0.075), Vector3(0.12, 0.64, 0.12))
	_build_control_area("CallHardwareReach", "service",
			Vector3(0.065, 0.0, 0.075), Vector3(0.12, 0.64, 0.12))
	_apply_service_pose()
	_clack = make_emitter("tick", -12.0)


func interact_prompt() -> String:
	return "[E]  Work the lift"


func interact(player: Node) -> void:
	_open_lift_panel(player)


func control_prompt(control_id: String) -> String:
	return ("[E]  Service annunciator contacts" if control_id == "service"
			else "[E]  Work the lift")


func interact_control(control_id: String, player: Node) -> bool:
	if control_id == "service":
		return _begin_annunciator_service(player)
	_open_lift_panel(player)
	return true


func _open_lift_panel(player: Node) -> void:
	if _panel and is_instance_valid(_panel):
		return
	if _clack:
		_clack.play()
	var scr: GDScript = load("res://scripts/ui/otis_panel.gd")
	_panel = scr.new()
	_panel.open(player, self)
	get_tree().current_scene.add_child(_panel)


func panel_closed() -> void:
	_panel = null


func _begin_annunciator_service(player: Node) -> bool:
	if _service_panel and is_instance_valid(_service_panel):
		return false
	var script: GDScript = load("res://scripts/ui/maintenance_activity_panel.gd")
	_service_panel = script.new()
	get_tree().current_scene.add_child(_service_panel)
	if not _service_panel.open(player, self, "annunciator_flag_service"):
		_service_panel.queue_free()
		_service_panel = null
		return false
	return true


func maintenance_panel_closed() -> void:
	_service_panel = null


func maintenance_snapshot() -> Dictionary:
	return {"stuck_flag": stuck_flag, "contact_alignment": contact_alignment,
			"bank_reset": bank_reset}


func preview_maintenance_step(step: Dictionary, value: float) -> void:
	var worked := clampf(value, 0.0, 1.0)
	match str(step.get("id", "")):
		"hold_armature":
			if not _flag_arms.is_empty():
				_flag_arms[0].rotation.x = deg_to_rad(lerpf(34.0, -8.0, worked))
		"square_contact":
			if _contact_bridge:
				_contact_bridge.rotation.z = deg_to_rad(lerpf(-18.0, 0.0, worked))
		"reset_bank":
			if _reset_spindle:
				_reset_spindle.rotation.y = worked * TAU
			for i in _flag_arms.size():
				_flag_arms[i].rotation.x = deg_to_rad(
						lerpf(26.0 if i == 0 else 7.0, -8.0, 1.0 - worked))


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	stuck_flag = bool(snapshot.get("stuck_flag", stuck_flag))
	contact_alignment = float(snapshot.get(
			"contact_alignment", contact_alignment))
	bank_reset = float(snapshot.get("bank_reset", bank_reset))
	_apply_service_pose()


func apply_maintenance_result(result: Dictionary) -> void:
	var patch: Dictionary = result.get("mechanism_patch", {})
	stuck_flag = bool(patch.get("stuck_flag", stuck_flag))
	contact_alignment = clampf(float(patch.get(
			"contact_alignment", contact_alignment)), 0.0, 1.0)
	bank_reset = 1.0
	_apply_service_pose()
	maintenance_completed.emit(result.duplicate(true))


func _apply_service_pose() -> void:
	for i in _flag_arms.size():
		_flag_arms[i].rotation.x = deg_to_rad(
				26.0 if stuck_flag and i == 0 else -8.0 * bank_reset)
	if _contact_bridge:
		_contact_bridge.rotation.z = deg_to_rad(
				lerpf(-18.0, 0.0, contact_alignment))
	if _reset_spindle:
		_reset_spindle.rotation.y = bank_reset * TAU


func _build_control_area(area_name: String, control_id: String,
		at: Vector3, size: Vector3) -> void:
	var area := ControlArea.new()
	area.name = area_name
	area.configure(control_id)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = at
	area.add_child(shape_node)
	add_child(area)


func _process(delta: float) -> void:
	# One lamp wanders up and down the column: the car, still running
	# whether or not anybody is watching the board.
	_t += delta
	if _lamps.is_empty():
		return
	var n := _lamps.size()
	var k := int(fmod(_t * 0.55, float(n * 2 - 2)))
	if k >= n:
		k = (n * 2 - 2) - k
	for i in n:
		var m: StandardMaterial3D = _lamps[i]
		var on: bool = i == k
		m.albedo_color = Color(0.95, 0.72, 0.34) if on \
				else Color(0.30, 0.26, 0.16)
		m.emission_enabled = on
		if on:
			m.emission = Color(0.95, 0.72, 0.34)
			m.emission_energy_multiplier = 1.6
