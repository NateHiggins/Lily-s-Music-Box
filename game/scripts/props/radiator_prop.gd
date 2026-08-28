class_name RadiatorProp
extends FunctionalProp
## A second-hand American three-column steam radiator, assembled from cast
## sections rather than drawn as a row of pipes. The Orison is one-pipe steam:
## the angle valve is either open or shut, while a replaceable air-vent orifice
## decides how quickly this radiator wins steam from the building's fixed cycle.

signal supply_changed(open: bool, position: float)
signal vent_changed(grade: int)
signal pitch_changed(toward_supply: float)
signal maintenance_completed(result: Dictionary)

## The Dream finds this object interesting (design/DREAM_TENTACLE_DIRECTION
## §13, §17): the tentacle's first contact is the top rim, which it traces
## along the sections; cast iron answers strongly and may be converted.
func dream_target_profile() -> DreamTargetProfile:
	var p := DreamTargetProfile.new()
	p.contact_local = Vector3(0.0, BODY_BOTTOM + 0.56, 0.0)
	p.contact_normal_local = Vector3.UP
	p.trace_axis_local = Vector3.RIGHT
	p.trace_half_length = 0.28
	p.response_strength = 1.2
	p.transformation_eligible = true
	p.material_word = "iron"
	return p


const SECTION_PITCH := 0.085
const BODY_BOTTOM := 0.115
const BODY_TOP := 0.625
const BODY_DEPTH := 0.17
## The legacy marker's installed local -X is the building riser end. Keeping
## this explicit is cheaper than mirroring every 1912 riser in the baked floors.
const SUPPLY_X := -0.44
const RISER_X := -0.52

const IRON_DARK := Color(0.16, 0.16, 0.17)
const IRON_SILVER := Color(0.62, 0.63, 0.65)
const PIPE := Color(0.30, 0.28, 0.26)
const BRASS := Color(0.62, 0.55, 0.30)
const RUST := Color(0.31, 0.13, 0.065)
const SHIM := Color(0.24, 0.16, 0.09)

## Marker facts arrive before `_ready()`. Seven-to-nine sections vary the
## family without exceeding the old 810 mm body or moving the shared riser.
var unit := ""
var riser := "H-X"
var section_count := 0

var supply_position := 1.0
var vent_grade := 2
var pitch_toward_supply := 0.35

var _possessed_fit := false
var _body: Node3D
var _shell: Node3D
var _wheel: Node3D
var _vent: Node3D
var _shim: Node3D
var _knock: AudioStreamPlayer3D
var _tick: AudioStreamPlayer3D
var _whistle: AudioStreamPlayer3D
var _shake := 0.0
var _wheel_tween: Tween
var _balance
var _service_panel: MaintenanceActivityPanel


func _exit_tree() -> void:
	# A service completion can leave the handwheel's presentation tween active
	# while CampaignShell replaces the building. Kill and release that transient
	# owner here; the durable supply position is already held by the prop/save
	# authority and must not keep the retired scene (or its mesh resources) live.
	if _wheel_tween and _wheel_tween.is_valid():
		_wheel_tween.kill()
	_wheel_tween = null
	super()


func warehouse_variants() -> Array[Dictionary]:
	return [
		{"label": "radiator / 7-section dark",
			"properties": {"unit": "1D", "riser": "H-D", "section_count": 7}},
		{"label": "radiator / 9-section silver",
			"properties": {"unit": "LOBBY", "riser": "H-A", "section_count": 9}},
	]


func bind_heat_balance(model) -> void:
	_balance = model


func _build_visual() -> void:
	add_to_group("radiators")
	if section_count <= 0:
		section_count = 7 + posmod(hash(unit), 3)
	vent_grade = 2 + posmod(hash(unit), 2)

	_body = Node3D.new()
	_body.name = "WorkingAssembly"
	add_child(_body)
	_shell = Node3D.new()
	_shell.name = "CastSections"
	_body.add_child(_shell)

	var silvered := posmod(hash(unit), 3) == 0
	var iron := IRON_SILVER if silvered else IRON_DARK
	_build_sections(iron)
	_build_supply()
	_build_air_vent()
	_build_pitch_shim()

	retexture(_body, [
		[IRON_DARK, "cast_iron", Color(0.32, 0.31, 0.30), 0.68],
		[IRON_SILVER, "cast_iron", Color(0.74, 0.75, 0.76), 0.72],
		[PIPE, "metal", Color(0.52, 0.48, 0.44), 0.50],
		[BRASS, "brass_dull", Color(0.82, 0.72, 0.48), 0.72],
		[RUST, "cast_iron", Color(0.48, 0.20, 0.10), 0.42],
		[SHIM, "wood_dark", Color(0.42, 0.29, 0.18), 0.32],
	])
	# The cast body and fixed valve housing collapse to one draw per finish.
	# A rigged assembly still gets merged internally: keeping the handwheel
	# movable does not require keeping its ring, hub and six spokes as eight
	# draw calls. Only transforms which move independently remain separate.
	merge_static(_shell, [_vent])
	merge_static(_wheel)
	merge_static(_vent)
	merge_static(_body, [_shell, _wheel, _shim])
	_build_service_areas()
	_apply_pitch()
	_update_balance()

	_knock = make_emitter("knock", -12.0)
	_tick = make_emitter("tick", -23.0)
	_whistle = make_emitter("radiator_whistle", -29.0)


func _build_sections(iron: Color) -> void:
	var half_width := float(section_count - 1) * SECTION_PITCH * 0.5
	for i in section_count:
		var sx := -half_width + float(i) * SECTION_PITCH
		# Each factory section is one casting: three water columns joined by
		# rounded transverse headers. The 9 mm inter-section shadow is the
		# nipple joint, not a fourth decorative bar.
		for z in [-0.057, 0.0, 0.057]:
			_cyl(_shell, 0.019, 0.023, BODY_TOP - BODY_BOTTOM - 0.10,
					Vector3(sx, (BODY_TOP + BODY_BOTTOM) * 0.5, z), iron)
			_ellipsoid(_shell, Vector3(sx, BODY_BOTTOM + 0.04, z),
					Vector3(0.034, 0.045, 0.036), iron)
			_ellipsoid(_shell, Vector3(sx, BODY_TOP - 0.04, z),
					Vector3(0.034, 0.045, 0.036), iron)
		for y in [BODY_BOTTOM + 0.035, BODY_TOP - 0.035]:
			var header := _cyl(_shell, 0.031, 0.031, BODY_DEPTH,
					Vector3(sx, y, 0), iron)
			header.rotation_degrees.x = 90.0
	# Feet are continuations of the end castings, with broad toes that keep
	# the load out of a century-old floorboard rather than modern box legs.
	for x in [-half_width, half_width]:
		_cyl(_shell, 0.026, 0.036, 0.09, Vector3(x, 0.07, 0), iron)
		_box(_shell, Vector3(0.105, 0.025, 0.16),
				Vector3(x, 0.0125, -0.012), iron)


func _build_supply() -> void:
	# Building geometry owns the slab-to-slab riser at x=.52. The prop owns
	# only the tee branch, union and angle valve that can actually be serviced.
	var branch := _cyl(_body, 0.023, 0.023, absf(RISER_X + 0.34),
			Vector3((RISER_X - 0.34) * 0.5, 0.145, 0), PIPE)
	branch.rotation_degrees.z = 90.0
	_cyl(_body, 0.038, 0.038, 0.055, Vector3(-0.365, 0.145, 0), PIPE)
	_cyl(_body, 0.032, 0.042, 0.085, Vector3(SUPPLY_X, 0.185, 0), PIPE)
	# Water sits at the lowest union and leaves the first honest stain there.
	var stain := _cyl(_body, 0.040, 0.043, 0.012,
			Vector3(-0.365, 0.113, 0), RUST)
	stain.scale = Vector3(1.0, 1.0, 0.48)

	_wheel = Node3D.new()
	_wheel.name = "SupplyHandwheel"
	_wheel.position = Vector3(SUPPLY_X, 0.295, 0)
	_body.add_child(_wheel)
	# The rising stem belongs to the wheel assembly. Leaving it in the static
	# valve body made the wheel climb away from its own stem when opened.
	_cyl(_wheel, 0.018, 0.018, 0.09, Vector3(0, -0.050, 0), BRASS)
	make_ring(0.052, 0.007, Vector3.ZERO, BRASS, 0.52, 0.30, _wheel)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var end := Vector3(cos(angle) * 0.046, 0, sin(angle) * 0.046)
		_tube_between(_wheel, Vector3.ZERO, end, 0.0045, BRASS)
	_cyl(_wheel, 0.012, 0.012, 0.014, Vector3.ZERO, BRASS)


func _build_air_vent() -> void:
	var half_width := float(section_count - 1) * SECTION_PITCH * 0.5
	_vent = Node3D.new()
	_vent.name = "ReplaceableAirVent"
	_vent.position = Vector3(half_width + 0.045, 0.485, -0.072)
	_shell.add_child(_vent)
	var neck := _cyl(_vent, 0.010, 0.010, 0.045,
			Vector3(0.020, 0, 0), BRASS)
	neck.rotation_degrees.z = 90.0
	var body := _cyl(_vent, 0.015, 0.021, 0.060,
			Vector3(-0.012, 0.015, 0), BRASS)
	body.rotation_degrees.z = -12.0
	_ellipsoid(_vent, Vector3(-0.018, 0.050, 0),
			Vector3(0.018, 0.026, 0.018), BRASS)
	# A wet vent stains downward and toward the wall; no generic rust wash.
	_box(_vent, Vector3(0.018, 0.075, 0.004),
			Vector3(-0.010, -0.050, 0.016), RUST)


func _build_pitch_shim() -> void:
	var half_width := float(section_count - 1) * SECTION_PITCH * 0.5
	_shim = Node3D.new()
	_shim.name = "FarEndPitchShim"
	_shim.position = Vector3(-half_width, 0.006, 0.035)
	_body.add_child(_shim)
	_box(_shim, Vector3(0.12, 0.012, 0.13), Vector3.ZERO, SHIM)


func _build_service_areas() -> void:
	_service_area("HandwheelReach", Vector3(SUPPLY_X, 0.30, 0),
			Vector3(0.17, 0.20, 0.28))
	var half_width := float(section_count - 1) * SECTION_PITCH * 0.5
	_service_area("VentReach", Vector3(half_width + 0.04, 0.49, -0.04),
			Vector3(0.16, 0.20, 0.24))


func _service_area(area_name: String, at: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.name = area_name
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	area.add_child(shape)
	add_child(area)


func _start_normal_function() -> void:
	state = PState.OPERATING


func interact_prompt() -> String:
	return "[E]  Service radiator fittings"


func interact(player: Node) -> void:
	_begin_vent_service(player)


func interact_area(area: Area3D) -> void:
	var player := get_tree().get_first_node_in_group("player_controller")
	_begin_vent_service(player)


func _begin_vent_service(player: Node) -> bool:
	if _service_panel and is_instance_valid(_service_panel):
		return false
	var script: GDScript = load("res://scripts/ui/maintenance_activity_panel.gd")
	_service_panel = script.new()
	get_tree().current_scene.add_child(_service_panel)
	if not _service_panel.open(player, self, "radiator_vent_service"):
		_service_panel = null
		return false
	return true


func maintenance_snapshot() -> Dictionary:
	return {"supply_position": supply_position, "vent_grade": vent_grade}


## Preview animates the actual fittings but does not publish heat state. The
## committed result below is the only route to the physical setters.
func preview_maintenance_step(step: Dictionary, value: float) -> void:
	match str(step.get("id", "")):
		"shut_supply", "open_supply":
			if _wheel:
				_wheel.rotation.y = clampf(value, 0.0, 1.0) * TAU * 3.5
				_wheel.position.y = 0.295 + clampf(value, 0.0, 1.0) * 0.016
		"free_vent":
			if _vent:
				_vent.position.y = sin(value * PI) * 0.006
		"seat_orifice":
			if _vent:
				_vent.rotation.x = deg_to_rad(clampf(value, 0.0, 1.0) * 44.0)


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	if _vent:
		_vent.position.y = 0.0
	set_supply_position(float(snapshot.get("supply_position", supply_position)), 0.2)
	set_vent_grade(int(snapshot.get("vent_grade", vent_grade)))


func apply_maintenance_result(result: Dictionary) -> void:
	var patch: Dictionary = result.get("mechanism_patch", {})
	if _vent:
		_vent.position.y = 0.0
	set_vent_grade(int(patch.get("vent_grade", vent_grade)))
	set_supply_position(float(patch.get("supply_position", supply_position)))
	maintenance_completed.emit(result.duplicate(true))


func maintenance_panel_closed() -> void:
	_service_panel = null


func set_supply_open(open: bool, seconds := 0.65) -> void:
	set_supply_position(1.0 if open else 0.0, seconds)


## The maintenance rig can stop the wheel part-way so the player can learn
## why that is not a valid setting. Endpoints are the only healthy states.
func set_supply_position(value: float, seconds := 0.65) -> void:
	supply_position = clampf(value, 0.0, 1.0)
	if _wheel == null:
		_update_balance()
		return
	if _wheel_tween and _wheel_tween.is_valid():
		_wheel_tween.kill()
	var turns := supply_position * TAU * 3.5
	var target_y := 0.295 + supply_position * 0.016
	if seconds <= 0.0:
		_wheel.rotation.y = turns
		_wheel.position.y = target_y
	else:
		_wheel_tween = create_tween()
		_wheel_tween.set_trans(Tween.TRANS_CUBIC)
		_wheel_tween.set_ease(Tween.EASE_IN_OUT)
		_wheel_tween.tween_property(_wheel, "rotation:y", turns, seconds)
		_wheel_tween.parallel().tween_property(_wheel, "position:y", target_y,
				seconds)
	_update_balance()
	supply_changed.emit(supply_position >= 0.98, supply_position)


func set_vent_grade(grade: int) -> void:
	vent_grade = clampi(grade, 0, 4)
	if _vent:
		# The small clocking difference lets inspection renders prove that the
		# insert was changed without turning a fixed orifice into a thermostat.
		_vent.rotation.x = deg_to_rad(float(vent_grade) * 11.0)
	_update_balance()
	vent_changed.emit(vent_grade)


## Positive values pitch the far end upward so condensate returns toward the
## supply. Negative values are the service fault; zero is visually level.
func set_pitch(value: float) -> void:
	pitch_toward_supply = clampf(value, -1.0, 1.0)
	_apply_pitch()
	_update_balance()
	pitch_changed.emit(pitch_toward_supply)


func _apply_pitch() -> void:
	if _shell == null:
		return
	_shell.rotation.z = deg_to_rad(-pitch_toward_supply * 1.15)
	if _shim:
		_shim.visible = pitch_toward_supply > 0.05


func get_heat_state() -> Dictionary:
	var local := {
		"supply_position": supply_position,
		"supply_open": supply_position >= 0.98,
		"supply_partial": supply_position > 0.02 and supply_position < 0.98,
		"vent_grade": vent_grade,
		"pitch": pitch_toward_supply,
		"riser": riser,
	}
	if _balance and graph_node_id != "":
		local.merge(_balance.result_for(graph_node_id), true)
	return local


func _update_balance() -> void:
	if _balance and graph_node_id != "":
		_balance.update_radiator(graph_node_id, supply_position, vent_grade,
				pitch_toward_supply)


## Called by AmbientSoundscape. Central scheduling makes a riser answer as a
## pipe system instead of letting every radiator improvise alone.
func play_ambient_cycle(kind: String, intensity := 0.5) -> void:
	if state != PState.OPERATING:
		return
	var heat := get_heat_state()
	match kind:
		"whistle":
			if not bool(heat.get("supply_open", false)):
				return
			_whistle.volume_db = lerpf(-34.0, -23.0, intensity)
			_whistle.pitch_scale = lerpf(0.90, 1.10,
					float(vent_grade) / 4.0)
			_whistle.play()
		"knock":
			var faulted := bool(heat.get("hammer", false))
			_knock.volume_db = lerpf(-22.0, -11.0, intensity) + \
					(4.0 if faulted else 0.0)
			_knock.pitch_scale = rng.randf_range(0.88, 1.08)
			_knock.play()
			_shake = maxf(_shake, intensity * (0.005 if faulted else 0.002))
		_:
			_tick.volume_db = lerpf(-29.0, -18.0, intensity)
			_tick.pitch_scale = rng.randf_range(0.82, 1.18)
			_tick.play()


func _perform_synced_event(_index: int, accent: float, pitch: float) -> void:
	_knock.volume_db = -11.0 + linear_to_db(clampf(accent, 0.2, 1.0))
	_knock.pitch_scale = clampf(pow(2.0, pitch * 0.15 / 12.0), 0.9, 1.1)
	_knock.play()
	_shake = maxf(_shake, accent * 0.006)


func _process(delta: float) -> void:
	if _shake > 0.0002:
		_body.position = Vector3(rng.randf_range(-_shake, _shake), 0,
				rng.randf_range(-_shake, _shake))
		_shake = maxf(_shake - delta * 0.04, 0.0)
	elif _body.position != Vector3.ZERO:
		_body.position = Vector3.ZERO


## Possession does not invent a new power. It drives a real water-hammer
## symptom in the motif already carried by this radiator's authored riser.
func possess_fit(beats := 4) -> void:
	if _possessed_fit:
		return
	_possessed_fit = true
	for i in range(beats):
		play_ambient_cycle("knock", 0.85 + 0.1 * float(i % 2))
		await get_tree().create_timer(0.24 if i % 2 else 0.38, false).timeout
		if not is_inside_tree():
			return
	_possessed_fit = false


func _box(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = _pmat(color, 0.55, 0.0)
	parent.add_child(node)
	return node


func _cyl(parent: Node3D, rt: float, rb: float, height: float,
		at: Vector3, color: Color) -> MeshInstance3D:
	return make_cyl(rt, rb, height, at, color, 0.52, 0.28, parent)


func _ellipsoid(parent: Node3D, at: Vector3, scale_: Vector3,
		color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.position = at
	node.scale = scale_
	node.material_override = _pmat(color, 0.52, 0.28)
	parent.add_child(node)
	return node


func _tube_between(parent: Node3D, a: Vector3, b: Vector3, radius: float,
		color: Color) -> MeshInstance3D:
	var delta := b - a
	var tube := _cyl(parent, radius, radius, delta.length(),
			(a + b) * 0.5, color)
	var direction := delta.normalized()
	var dot := Vector3.UP.dot(direction)
	if dot < -0.9999:
		tube.rotation_degrees.x = 180.0
	elif dot < 0.9999:
		tube.quaternion = Quaternion(Vector3.UP, direction)
	return tube
