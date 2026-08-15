class_name BakedFurnitureInteraction
extends StaticBody3D
## A lightweight mechanism owner placed over one individually-authored object
## that remains visually baked into its floor glTF.
##
## The generated furniture record owns identity and transform.  This node owns
## only the part that can move, its collision, sound and current condition; it
## never claims the merged floor mesh as mutable state.

const BRASS := Color(0.58, 0.46, 0.25)

var furniture_kind := ""
var record_id := ""
var _refilling := false
var _lever: Node3D
var _water: AudioStreamPlayer3D
var _flush_tween: Tween
var _busy_tween: Tween
var _powered := false
var _radio_knob: Node3D
var _radio_bed: AudioStreamPlayer3D
var _control_click: AudioStreamPlayer3D
var _control_tween: Tween


func setup(spec: Dictionary) -> void:
	furniture_kind = str(spec.get("asm", ""))
	record_id = str(spec.get("id", furniture_kind))
	name = "Service_%s" % record_id
	add_to_group("baked_furniture_interactions")
	set_meta("furniture_record_id", record_id)
	set_meta("furniture_kind", furniture_kind)


func _ready() -> void:
	match furniture_kind:
		"toilet": _build_toilet_control()
		"radio": _build_radio_control()
		_: push_error("No baked furniture interaction for %s" % furniture_kind)


func _build_toilet_control() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.54, 0.84, 0.76)
	collision.shape = shape
	collision.position = Vector3(0, 0.42, -0.02)
	add_child(collision)

	# The porcelain is in the floor buffer.  This small side lever is the only
	# overlay geometry and sits clear of the close-coupled tank's right cheek.
	_lever = Node3D.new()
	_lever.name = "CisternHandle"
	_lever.position = Vector3(0.18, 0.64, 0.12)
	add_child(_lever)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.11, 0.022, 0.026)
	mesh_node.mesh = mesh
	mesh_node.position.x = -0.035
	var material := StandardMaterial3D.new()
	material.albedo_color = BRASS
	material.metallic = 0.72
	material.roughness = 0.34
	mesh_node.material_override = material
	_lever.add_child(mesh_node)

	_water = AudioStreamPlayer3D.new()
	_water.name = "CisternWater"
	_water.stream = PropAudio.get_stream("sink_water")
	_water.volume_db = -14.0
	_water.unit_size = 1.4
	_water.max_distance = 8.0
	add_child(_water)


func _build_radio_control() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.48, 0.34, 0.34)
	collision.shape = shape
	collision.position = Vector3(0, 0.14, -0.02)
	add_child(collision)

	# One knob sits a few millimetres proud of the baked right-hand control.
	# The cabinet, dial strip and grille remain in the floor buffer.
	_radio_knob = Node3D.new()
	_radio_knob.name = "PowerTuningKnob"
	_radio_knob.position = Vector3(0.14, 0.062, -0.139)
	add_child(_radio_knob)
	var mesh_node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.017
	mesh.bottom_radius = 0.017
	mesh.height = 0.026
	mesh.radial_segments = 10
	mesh_node.mesh = mesh
	mesh_node.rotation_degrees.x = 90.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.065, 0.052)
	material.roughness = 0.43
	mesh_node.material_override = material
	_radio_knob.add_child(mesh_node)

	_control_click = AudioStreamPlayer3D.new()
	_control_click.name = "RadioSwitchClick"
	_control_click.stream = PropAudio.get_stream("tick")
	_control_click.volume_db = -20.0
	_control_click.unit_size = 1.2
	_control_click.max_distance = 6.0
	add_child(_control_click)
	_radio_bed = AudioStreamPlayer3D.new()
	_radio_bed.name = "ValveProgramme"
	_radio_bed.stream = PropAudio.get_stream("murmur_loop")
	_radio_bed.volume_db = -28.0
	_radio_bed.unit_size = 1.4
	_radio_bed.max_distance = 7.0
	add_child(_radio_bed)


func interact_prompt() -> String:
	if furniture_kind == "toilet":
		return "[E] Test refilling cistern handle" if _refilling \
				else "[E] Flush water closet"
	if furniture_kind == "radio":
		return "[E] Switch valve radio off" if _powered \
				else "[E] Switch valve radio on"
	return ""


func interact(_player: Node = null) -> Dictionary:
	if furniture_kind == "radio":
		return _interact_radio()
	if furniture_kind != "toilet": return {}
	if _refilling:
		# The handle still gives under an impatient second hand, but the stored
		# water and refill clock are not restarted.
		if _busy_tween and _busy_tween.is_valid():
			_busy_tween.kill()
		_lever.position.x = 0.18
		_busy_tween = create_tween()
		_busy_tween.tween_property(_lever, "position:x", 0.168, 0.05)
		_busy_tween.tween_property(_lever, "position:x", 0.18, 0.10)
		return service_wire_card()

	_refilling = true
	_water.pitch_scale = randf_range(0.96, 1.03)
	_water.play()
	if _flush_tween and _flush_tween.is_valid():
		_flush_tween.kill()
	_flush_tween = create_tween()
	_flush_tween.tween_property(_lever, "rotation:z", deg_to_rad(-34.0), 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flush_tween.tween_property(_lever, "rotation:z", 0.0, 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flush_tween.tween_interval(2.1)
	_flush_tween.tween_callback(_finish_refill)
	return service_wire_card()


func _interact_radio() -> Dictionary:
	_powered = not _powered
	_control_click.pitch_scale = 1.05 if _powered else 0.94
	_control_click.play()
	if _powered:
		_radio_bed.play()
	else:
		_radio_bed.stop()
	if _control_tween and _control_tween.is_valid():
		_control_tween.kill()
	_control_tween = create_tween()
	_control_tween.tween_property(_radio_knob, "rotation:z",
			deg_to_rad(42.0 if _powered else 0.0), 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return service_wire_card()


func service_wire_card() -> Dictionary:
	if furniture_kind == "radio":
		return PropServiceWire.card("radio", {
			"power_state": "ON" if _powered else "OFF",
			"tuning_state": "MID-BAND",
			"programme_state": "DISTANT SPEECH" if _powered else "SILENT",
		})
	if furniture_kind != "toilet": return {}
	return PropServiceWire.card("toilet", {
		"cistern_state": "REFILLING" if _refilling else "FULL",
		"flush_state": "RUNNING" if _refilling else "READY",
	})


func _finish_refill() -> void:
	_refilling = false
