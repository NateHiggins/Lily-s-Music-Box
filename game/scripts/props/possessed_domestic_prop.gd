class_name PossessedDomesticProp
extends FunctionalProp
## One low-cost household object with a resident-specific, reversible tell.

var prop_id := ""
var kind := "mirror"
var tell := ""
var case_ids: Array = []
var relay_all := false
var accent := Color(0.52, 0.60, 0.57)

var _rig: Node3D
var _moving: Node3D
var _indicator: MeshInstance3D
var _display: Label3D
var _sound: AudioStreamPlayer3D
var _home := Transform3D.IDENTITY
var _busy := false
var _tween: Tween


func configure(spec: Dictionary) -> void:
	prop_id = str(spec.id)
	kind = str(spec.kind)
	tell = str(spec.tell)
	case_ids = spec.get("cases", []).duplicate()
	relay_all = bool(spec.get("relay_all", false))
	prop_type = "wall_clock" # conservative conductor timing profile
	accent = Color.from_hsv(fposmod(float(abs(prop_id.hash()) % 997) / 997.0,
			1.0), 0.32, 0.62)


func _ready() -> void:
	name = "DomesticAnomaly_%s" % prop_id
	add_to_group("possessed_domestic_props")
	add_to_group("reality_affected_props")
	super._ready()
	_home = transform


func _build_visual() -> void:
	_rig = Node3D.new()
	_rig.name = "PossessionRig"
	add_child(_rig)
	match kind:
		"mirror": _build_mirror()
		"smoke_detector": _build_smoke_detector()
		"intercom": _build_intercom()
		"coat_hook": _build_coat_hook()
		"smart_speaker": _build_speaker()
		"houseplant": _build_plant()
		"power_outlet": _build_outlet()
		"telephone": _build_telephone()
		"thermostat": _build_thermostat()
		"door_chain": _build_chain()
		"luggage_scale": _build_scale()
		"spirit_level": _build_level()
		"table_radio": _build_radio()
		"picture_frame": _build_frame()
		"security_camera": _build_camera()
		"typewriter": _build_typewriter()
		"key_bowl": _build_key_bowl()
	_build_collision()
	_sound = make_emitter("tick", -34.0)
	_sound.max_distance = 4.5


func _build_mirror() -> void:
	make_box(Vector3(0.42, 0.62, 0.035), Vector3.ZERO, Color(0.18, 0.13, 0.09))
	_moving = make_box(Vector3(0.36, 0.56, 0.012), Vector3(0, 0, 0.025),
			Color(0.38, 0.44, 0.46))


func _build_smoke_detector() -> void:
	_moving = make_cyl(0.12, 0.14, 0.045, Vector3.ZERO,
			Color(0.77, 0.75, 0.68), 0.82)
	_indicator = _dot(Vector3(0.07, 0.028, 0), Color(0.8, 0.04, 0.02))


func _build_intercom() -> void:
	make_box(Vector3(0.22, 0.34, 0.055), Vector3.ZERO, Color(0.68, 0.63, 0.50))
	_moving = make_box(Vector3(0.055, 0.27, 0.045), Vector3(-0.07, 0, 0.055),
			Color(0.20, 0.18, 0.15))
	for y in [-0.07, -0.025, 0.025, 0.07]: _dot(Vector3(0.055, y, 0.065), accent)


func _build_coat_hook() -> void:
	make_box(Vector3(0.38, 0.075, 0.035), Vector3.ZERO, Color(0.24, 0.16, 0.10))
	_rig = Node3D.new(); add_child(_rig)
	for x in [-0.13, 0.0, 0.13]:
		var hook := make_cyl(0.012, 0.012, 0.13, Vector3(x, -0.06, 0.05),
				Color(0.36, 0.30, 0.22), 0.35, 0.65)
		hook.rotation_degrees.x = 70
	_moving = _dot(Vector3(0.20, 0, 0.04), accent)
	_moving.visible = false


func _build_speaker() -> void:
	_moving = make_cyl(0.075, 0.085, 0.22, Vector3.ZERO, Color(0.08, 0.09, 0.10))
	_indicator = _dot(Vector3(0, 0.118, 0), accent)


func _build_plant() -> void:
	make_cyl(0.13, 0.09, 0.20, Vector3(0, 0.10, 0), Color(0.31, 0.18, 0.10))
	_moving = Node3D.new(); _moving.position.y = 0.18; add_child(_moving)
	for i in 7:
		var a := TAU * i / 7.0
		var leaf := make_box(Vector3(0.055, 0.25, 0.018),
				Vector3(sin(a) * 0.09, 0.15, cos(a) * 0.09), Color(0.16, 0.34, 0.17))
		remove_child(leaf); _moving.add_child(leaf); leaf.rotation.z = a * 0.22


func _build_outlet() -> void:
	make_box(Vector3(0.13, 0.20, 0.025), Vector3.ZERO, Color(0.75, 0.72, 0.63))
	for y in [-0.05, 0.05]:
		for x in [-0.022, 0.022]: make_box(Vector3(0.012, 0.034, 0.008), Vector3(x, y, 0.02), Color(0.05, 0.045, 0.04))
	_indicator = _dot(Vector3(0, 0, 0.025), accent)
	_indicator.visible = false


func _build_telephone() -> void:
	make_box(Vector3(0.30, 0.09, 0.20), Vector3(0, 0.045, 0), Color(0.20, 0.22, 0.19))
	_moving = make_box(Vector3(0.34, 0.055, 0.07), Vector3(0, 0.13, 0), Color(0.10, 0.11, 0.10))
	for i in 6: _dot(Vector3(-0.10 + i * 0.04, 0.095, 0.105), accent.darkened(0.2))


func _build_thermostat() -> void:
	make_box(Vector3(0.20, 0.16, 0.045), Vector3.ZERO, Color(0.67, 0.65, 0.57))
	_display = _label("72", Vector3(0, 0.015, 0.035), accent)
	_indicator = _dot(Vector3(0.065, -0.045, 0.035), accent)


func _build_chain() -> void:
	make_box(Vector3(0.08, 0.15, 0.025), Vector3(-0.17, 0, 0), Color(0.32, 0.28, 0.22))
	make_box(Vector3(0.08, 0.15, 0.025), Vector3(0.17, 0, 0), Color(0.32, 0.28, 0.22))
	_moving = Node3D.new(); add_child(_moving)
	for i in 9:
		var link := make_ring(0.020, 0.005, Vector3(-0.12 + i * 0.03, sin(i * 0.8) * 0.025, 0.025), Color(0.40, 0.36, 0.28), 0.28, 0.75)
		remove_child(link); _moving.add_child(link); link.rotation_degrees.x = 90


func _build_scale() -> void:
	make_box(Vector3(0.36, 0.05, 0.28), Vector3(0, 0.025, 0), Color(0.18, 0.20, 0.19))
	_display = _label("0.0", Vector3(0, 0.06, 0.03), accent)


func _build_level() -> void:
	_moving = make_box(Vector3(0.54, 0.075, 0.045), Vector3.ZERO, Color(0.75, 0.55, 0.13))
	make_box(Vector3(0.16, 0.034, 0.052), Vector3(0, 0, 0.015), Color(0.25, 0.42, 0.28))
	_indicator = _dot(Vector3(0, 0, 0.05), Color(0.04, 0.08, 0.04))


func _build_radio() -> void:
	make_box(Vector3(0.34, 0.20, 0.16), Vector3(0, 0.10, 0), Color(0.20, 0.10, 0.055))
	_moving = make_cyl(0.045, 0.045, 0.025, Vector3(0.10, 0.10, 0.095), accent)
	_moving.rotation_degrees.x = 90
	_display = _label("AM 570", Vector3(-0.055, 0.12, 0.09), Color(0.75, 0.48, 0.18))


func _build_frame() -> void:
	make_box(Vector3(0.38, 0.48, 0.035), Vector3.ZERO, Color(0.22, 0.12, 0.07))
	_moving = make_box(Vector3(0.31, 0.40, 0.012), Vector3(0, 0, 0.026), accent.darkened(0.28))
	_indicator = _dot(Vector3(0, 0.05, 0.04), Color(0.75, 0.65, 0.52))


func _build_camera() -> void:
	make_box(Vector3(0.11, 0.11, 0.18), Vector3.ZERO, Color(0.16, 0.17, 0.17))
	_moving = Node3D.new(); add_child(_moving)
	var lens := make_cyl(0.047, 0.057, 0.09, Vector3(0, 0, 0.11), Color(0.07, 0.08, 0.09), 0.25, 0.55)
	remove_child(lens); _moving.add_child(lens); lens.rotation_degrees.x = 90
	_indicator = _dot(Vector3(0.04, 0.04, 0.095), Color(0.75, 0.03, 0.02))


func _build_typewriter() -> void:
	make_box(Vector3(0.40, 0.13, 0.30), Vector3(0, 0.065, 0), Color(0.10, 0.105, 0.10))
	_moving = make_box(Vector3(0.43, 0.025, 0.035), Vector3(0, 0.19, -0.06), Color(0.30, 0.27, 0.22))
	for x in range(9): _dot(Vector3(-0.14 + x * 0.035, 0.14, 0.07), Color(0.32, 0.31, 0.28))


func _build_key_bowl() -> void:
	make_cyl(0.14, 0.08, 0.07, Vector3(0, 0.035, 0), Color(0.34, 0.25, 0.15))
	_moving = Node3D.new(); add_child(_moving)
	for i in 3: make_box(Vector3(0.035, 0.008, 0.13), Vector3(-0.04 + i * 0.04, 0.09, 0), Color(0.48, 0.43, 0.31))
	_indicator = _dot(Vector3(0.09, 0.09, 0), accent); _indicator.visible = false


func _dot(at: Vector3, color: Color) -> MeshInstance3D:
	return make_cyl(0.012, 0.012, 0.008, at, color, 0.25, 0.2)


func _label(text: String, at: Vector3, color: Color) -> Label3D:
	var label := Label3D.new(); label.text = text; label.position = at
	label.font_size = 36; label.pixel_size = 0.002; label.modulate = color
	label.outline_size = 4; label.outline_modulate = Color(0, 0, 0, 0.85)
	add_child(label); return label


func _build_collision() -> void:
	var body := StaticBody3D.new(); var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(0.52, 0.58, 0.20)
	shape.shape = box; body.add_child(shape); add_child(body)


func _start_normal_function() -> void: state = PState.OPERATING


func stage_haunt(case_id: String, tier: int, player: Node3D) -> bool:
	if (not relay_all and not case_ids.has(case_id)) or _busy: return false
	if _watched(player) and tier < 4:
		_sound.pitch_scale = 0.72; _sound.play(); return true
	_busy = true; state = PState.INFECTED
	if _tween: _tween.kill()
	_tween = create_tween()
	_apply_tell(case_id, tier)
	_tween.tween_interval(8.0 + tier * 2.0)
	_tween.tween_callback(_restore)
	return true


func _apply_tell(case_id: String, tier: int) -> void:
	match tell:
		"late_reflection": _moving.position.x = 0.035 * tier
		"held_breath": _indicator.visible = true; _moving.scale = Vector3(1.0, 0.82, 1.0)
		"unlisted_call": _moving.rotation.z = -0.16 * tier
		"one_more_hook": _moving.visible = true
		"stolen_voice": _indicator.scale = Vector3(1.0 + tier * 0.5, 1, 1.0 + tier * 0.5)
		"turns_to_listen": _moving.rotation.y = PI * 0.35
		"wrong_voltage": _indicator.visible = true
		"open_line": _moving.position.y += 0.025 * tier
		"approval_required": _display.text = "DENIED"
		"shared_threshold": _moving.rotation.z = (-0.20 if case_id == "cam_tilted_room" else 0.20) * tier
		"departure_weight": _display.text = "∞"
		"false_level": _moving.rotation.z = 0.08 * tier
		"previous_room": _display.text = "YESTERDAY"
		"changed_pose": _moving.rotation.y = PI; _indicator.position.x += 0.045
		"tracks_after": _moving.rotation.y = 0.34 * tier
		"finishes_sentence": _moving.position.x = 0.12
		"extra_key": _indicator.visible = true
	if _indicator: _indicator.visible = true


func _restore() -> void:
	_busy = false; state = PState.OPERATING; transform = _home
	_rig.transform = Transform3D.IDENTITY
	if _moving: _moving.transform = Transform3D.IDENTITY; _moving.visible = true
	if _indicator: _indicator.visible = false; _indicator.transform = Transform3D.IDENTITY
	if _display:
		match kind:
			"thermostat": _display.text = "72"
			"luggage_scale": _display.text = "0.0"
			"table_radio": _display.text = "AM 570"


func _watched(player: Node3D) -> bool:
	if player == null: return false
	var candidate = player.get("camera")
	if not (candidate is Camera3D): return false
	var camera: Camera3D = candidate
	if not camera.is_position_in_frustum(global_position): return false
	var q := PhysicsRayQueryParameters3D.create(camera.global_position, global_position)
	if player is CollisionObject3D: q.exclude = [player.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.position.distance_to(global_position) < 0.6


func _perform_synced_event(_index: int, strength: float, _pitch: float) -> void:
	if _indicator: _indicator.visible = strength > 0.7
