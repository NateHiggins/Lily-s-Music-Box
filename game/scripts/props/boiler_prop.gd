class_name BoilerProp
extends FunctionalProp
## The Orison's original 1912 hand-fired coal plant. It was never replaced;
## every caretaker merely added another clamp, valve or instruction tag. The
## ordinary operation is already dramatic enough: coal, draft, water and ash
## must agree before twenty-three radiators receive one finite steam cycle.

signal boiler_state_changed(state: Dictionary)
signal maintenance_completed(result: Dictionary)

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

const W := 1.16
const D := 1.02
const BARREL_TOP := 1.62

const IRON := Color(0.20, 0.19, 0.18)
const IRON_EDGE := Color(0.29, 0.27, 0.25)
const JACKET := Color(0.66, 0.63, 0.54)
const STEEL := Color(0.34, 0.33, 0.31)
const BRASS := Color(0.58, 0.48, 0.27)
const SOOT := Color(0.09, 0.085, 0.08)
const PAPER := Color(0.82, 0.76, 0.62)
const FIREBRICK := Color(0.39, 0.19, 0.12)
const WATER := Color(0.28, 0.48, 0.52, 0.72)

var pressure := 0.48
var water_level := 0.62
var firebed := 0.78
var draft := 0.54
var coal_charge := 0.66
var ash_level := 0.24
var column_isolated := false
var column_proved := false

var _carcass: Node3D
var _fire_door: Node3D
var _ash_door: Node3D
var _draft_damper: Node3D
var _gauge_needle: Node3D
var _water_fill: MeshInstance3D
var _column_cocks: Array[Node3D] = []
var _blowdown_lever: Node3D
var _witness_marker: MeshInstance3D
var _service_panel: MaintenanceActivityPanel
var _firebed_mesh: MeshInstance3D
var _fire_material: StandardMaterial3D
var _fire_open := false
var _ash_open := false
var _fire_tween: Tween
var _ash_tween: Tween
var _thud: AudioStreamPlayer3D
var _settle: AudioStreamPlayer3D
var _draft_bed: AudioStreamPlayer3D
var _shake := 0.0


func _build_visual() -> void:
	add_to_group("boilers")
	_carcass = Node3D.new()
	_carcass.name = "StaticPlant"
	add_child(_carcass)
	_build_hearth_and_sections()
	_build_water_column()
	_build_pressure_gauge()
	_build_header_and_return()
	_build_smoke_hood()
	_build_service_plate()
	_build_doors()
	_build_collision()

	retexture(self, [
		[IRON, "cast_iron", Color(0.34, 0.33, 0.31), 0.72],
		# Section bosses and door hardware rely on silhouette and grime, not a
		# second near-identical iron tint that costs another surface everywhere.
		[IRON_EDGE, "cast_iron", Color(0.34, 0.33, 0.31), 0.72],
		[JACKET, "linen", Color(0.90, 0.84, 0.69), 0.72],
		[STEEL, "metal", Color(0.52, 0.50, 0.47), 0.62],
		[BRASS, "brass_dull", Color(0.80, 0.70, 0.43), 0.62],
		[SOOT, "soot", Color(0.72, 0.68, 0.64), 0.62],
		[PAPER, "paper", Color(0.86, 0.78, 0.62), 0.62],
		[FIREBRICK, "soot", Color(0.56, 0.30, 0.18), 0.48],
	])
	# The long parts list is not a licence for forty draw calls. The fixed
	# plant is one mesh per finish; each tended assembly is merged internally
	# but remains outside the carcass so its transform survives.
	merge_static(_carcass)
	merge_static(_fire_door)
	merge_static(_ash_door)
	merge_static(_draft_damper)
	merge_static(_gauge_needle)
	_fire_material = (_firebed_mesh.material_override as StandardMaterial3D).duplicate()
	_firebed_mesh.material_override = _fire_material

	_service_area("FireDoorReach", Vector3(0, 1.03, -0.72),
			Vector3(0.80, 0.62, 0.46))
	_service_area("AshDoorReach", Vector3(0, 0.43, -0.70),
			Vector3(0.72, 0.40, 0.42))
	_control_area("WaterGlassReach", "water_column",
			Vector3(0.54, 1.05, -0.55),
			Vector3(0.30, 0.62, 0.30))
	_service_area("DraftReach", Vector3(-0.49, 1.28, -0.57),
			Vector3(0.30, 0.42, 0.30))

	_thud = make_emitter("thud", -15.0)
	_thud.max_distance = 45.0
	_settle = make_emitter("tick", -25.0)
	_settle.max_distance = 24.0
	# The library has no dedicated coal-draft loop yet. This recorded low
	# mechanical bed is quiet enough to act as air moving through a masonry
	# flue, not an electric motor, until the sound pass records the real thing.
	_draft_bed = make_emitter("hum_loop", -34.0, true)
	_draft_bed.max_distance = 18.0
	_apply_state()


func _build_hearth_and_sections() -> void:
	_box(_carcass, Vector3(W + 0.28, 0.10, D + 0.40),
			Vector3(0, 0.05, -0.10), Color(0.42, 0.40, 0.37))
	_box(_carcass, Vector3(W, 0.22, D), Vector3(0, 0.21, 0), IRON)
	# Five joined sections make the silhouette read as bolted heating plant,
	# not a domestic tank. Narrow seams remain as honest assembly shadows.
	for i in 5:
		var x := -0.46 + float(i) * 0.23
		_box(_carcass, Vector3(0.205, 1.28, D),
				Vector3(x, 0.94, 0), IRON)
		for y in [0.41, 1.48]:
			var boss := _cyl(_carcass, 0.045, 0.045, 0.225,
					Vector3(x, y, -D * 0.50 - 0.015), IRON_EDGE)
			boss.rotation_degrees.z = 90.0
	# Patched canvas/asbestos lagging covers the hot block, held by straps.
	_box(_carcass, Vector3(W + 0.065, 1.12, D + 0.065),
			Vector3(0, 1.00, 0), JACKET)
	for y in [0.56, 0.94, 1.32]:
		_box(_carcass, Vector3(W + 0.09, 0.035, D + 0.09),
				Vector3(0, y, 0), STEEL)
	# A torn inspection patch exposes the dark fibrous edge underneath.
	_box(_carcass, Vector3(0.22, 0.22, 0.012),
			Vector3(-0.45, 0.78, -D * 0.5 - 0.040), SOOT)
	# Soot belongs above the firing opening and fades before the gauge side.
	_box(_carcass, Vector3(0.50, 0.22, 0.008),
			Vector3(0.06, 1.37, -D * 0.5 - 0.047), SOOT)
	# Firebrick throat and grate bars exist behind the opening; an open door
	# reveals a place coal can actually be put rather than another black card.
	_box(_carcass, Vector3(0.58, 0.42, 0.06),
			Vector3(0, 1.03, -D * 0.5 - 0.008), FIREBRICK)
	for i in 7:
		var gx := -0.24 + float(i) * 0.08
		var bar := _cyl(_carcass, 0.012, 0.012, 0.34,
				Vector3(gx, 0.86, -D * 0.5 - 0.055), IRON_EDGE)
		bar.rotation_degrees.x = 90.0
	# Kept outside the static carcass because its emission follows the firebed.
	_firebed_mesh = _box(self, Vector3(0.46, 0.07, 0.24),
			Vector3(0, 0.91, -0.34), SOOT)


func _build_doors() -> void:
	_fire_door = Node3D.new()
	_fire_door.name = "FiringDoor"
	_fire_door.position = Vector3(-0.33, 1.04, -D * 0.5 - 0.075)
	add_child(_fire_door)
	_box(_fire_door, Vector3(0.66, 0.43, 0.055),
			Vector3(0.33, 0, 0), IRON)
	for y in [-0.15, 0.15]:
		_cyl(_fire_door, 0.027, 0.027, 0.12,
				Vector3(0, y, 0), IRON_EDGE)
	# Furnace-door furniture is black iron, not decorative brass. Keeping the
	# latch in the door's iron finish also leaves this moving assembly one draw.
	var fire_latch := _cyl(_fire_door, 0.015, 0.015, 0.22,
			Vector3(0.57, 0, -0.040), IRON)
	fire_latch.rotation_degrees.z = 90.0
	# Peep slide: the ordinary orange line becomes frightening only when it
	# appears to blink. It remains a real combustion inspection opening first.
	make_ring(0.047, 0.009, Vector3(0.23, 0.07, -0.040),
			IRON_EDGE, 0.58, 0.30, _fire_door).rotation_degrees.x = 90.0

	_ash_door = Node3D.new()
	_ash_door.name = "AshpitDoor"
	_ash_door.position = Vector3(-0.29, 0.43, -D * 0.5 - 0.070)
	add_child(_ash_door)
	_box(_ash_door, Vector3(0.58, 0.26, 0.05),
			Vector3(0.29, 0, 0), IRON)
	for y in [-0.085, 0.085]:
		_cyl(_ash_door, 0.023, 0.023, 0.10,
				Vector3(0, y, 0), IRON_EDGE)
	var ash_latch := _cyl(_ash_door, 0.013, 0.013, 0.18,
			Vector3(0.50, 0, -0.035), IRON)
	ash_latch.rotation_degrees.z = 90.0
	# Ash on the apron follows the lower opening rather than washing the whole
	# machine in generic dirt.
	_box(_carcass, Vector3(0.62, 0.010, 0.27),
			Vector3(0.06, 0.106, -D * 0.5 - 0.22), SOOT)


func _build_water_column() -> void:
	# Glass tube, separate top and bottom cocks, and a blow-down tail. The
	# water level is a real moving object because judging it is the activity.
	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(0.70, 0.88, 0.90, 0.34)
	glass_mat.roughness = 0.08
	glass_mat.metallic = 0.0
	var tube := _cyl(_carcass, 0.019, 0.019, 0.48,
			Vector3(0.50, 1.08, -D * 0.5 - 0.075), Color.WHITE)
	tube.material_override = glass_mat
	for y in [0.82, 1.34]:
		_cyl(_carcass, 0.035, 0.035, 0.075,
				Vector3(0.50, y, -D * 0.5 - 0.075), BRASS)
		var cock_root := Node3D.new()
		cock_root.position = Vector3(0.50, y, -D * 0.5 - 0.075)
		add_child(cock_root)
		var cock := _cyl(cock_root, 0.010, 0.010, 0.12,
				Vector3(0.06, 0.0, 0.0), BRASS)
		cock.rotation_degrees.z = 90.0
		_column_cocks.append(cock_root)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.albedo_color = WATER
	fill_mat.roughness = 0.14
	_water_fill = _box(self, Vector3(0.024, 0.28, 0.024),
			Vector3(0.50, 1.00, -D * 0.5 - 0.075), WATER)
	_water_fill.name = "GaugeWaterLevel"
	_water_fill.material_override = fill_mat
	var blowdown := _cyl(_carcass, 0.016, 0.016, 0.24,
			Vector3(0.50, 0.67, -D * 0.5 - 0.075), STEEL)
	blowdown.rotation_degrees.x = 12.0
	_blowdown_lever = Node3D.new()
	_blowdown_lever.position = Vector3(0.50, 0.72, -D * 0.5 - 0.112)
	add_child(_blowdown_lever)
	_box(_blowdown_lever, Vector3(0.17, 0.014, 0.014),
			Vector3(0.075, 0.0, 0.0), BRASS)
	_witness_marker = _box(self, Vector3(0.095, 0.012, 0.010),
			Vector3(0.43, _column_level_y(water_level),
			-D * 0.5 - 0.116), PAPER)
	_witness_marker.name = "WaterWitnessMarker"
	# Mineral track begins at the packing gland and ends at the hearth.
	_box(_carcass, Vector3(0.075, 0.34, 0.006),
			Vector3(0.50, 0.54, -D * 0.5 - 0.105), PAPER)


func _build_pressure_gauge() -> void:
	var face := _cyl(_carcass, 0.092, 0.092, 0.038,
			Vector3(0.31, 1.48, -D * 0.5 - 0.055), PAPER)
	face.rotation_degrees.x = 90.0
	make_ring(0.098, 0.010, Vector3(0.31, 1.48, -D * 0.5 - 0.078),
			BRASS, 0.55, 0.30, _carcass).rotation_degrees.x = 90.0
	_gauge_needle = Node3D.new()
	_gauge_needle.name = "PressureNeedle"
	_gauge_needle.position = Vector3(0.31, 1.48, -D * 0.5 - 0.102)
	add_child(_gauge_needle)
	var needle := _box(_gauge_needle, Vector3(0.008, 0.068, 0.006),
			Vector3(0, 0.030, 0), IRON)
	needle.position.y = 0.030
	# The pointer and its hub turn as one blackened-steel movement. A brass hub
	# too small to read at service distance cost a whole additional mesh batch.
	_cyl(_gauge_needle, 0.012, 0.012, 0.008, Vector3.ZERO, IRON)


func _build_header_and_return() -> void:
	# The prop owns the fittings up to the old fitter's unions; the generator
	# owns the long ceiling runs. That seam keeps this serviceable without a
	# duplicate pipe hiding in the floor mesh.
	_cyl(_carcass, 0.105, 0.105, 0.28,
			Vector3(0.05, 1.72, 0.02), IRON_EDGE)
	var takeoff := _cyl(_carcass, 0.078, 0.078, 0.40,
			Vector3(0.05, 1.84, 0.02), STEEL)
	takeoff.position.y = 1.82
	# Equalizer and low return form a visible Hartford-style loop at the left.
	_cyl(_carcass, 0.038, 0.038, 0.72,
			Vector3(-0.49, 0.54, 0.28), STEEL)
	var return_leg := _cyl(_carcass, 0.038, 0.038, 0.48,
			Vector3(-0.26, 0.18, 0.28), STEEL)
	return_leg.rotation_degrees.z = 90.0
	_cyl(_carcass, 0.055, 0.055, 0.09,
			Vector3(-0.49, 0.77, 0.28), BRASS)
	# Safety valve is vertical, with a discharge elbow aimed away from the
	# person reading the water glass.
	_cyl(_carcass, 0.042, 0.052, 0.13,
			Vector3(-0.30, 1.68, -0.10), BRASS)
	var relief := _cyl(_carcass, 0.022, 0.022, 0.34,
			Vector3(-0.30, 1.88, -0.10), STEEL)
	relief.rotation_degrees.z = -18.0


func _build_smoke_hood() -> void:
	_box(_carcass, Vector3(0.68, 0.30, 0.32),
			Vector3(0, 1.65, D * 0.5 + 0.09), IRON)
	var collar := _cyl(_carcass, 0.17, 0.17, 0.34,
			Vector3(0, 1.84, D * 0.5 + 0.30), STEEL)
	collar.rotation_degrees.x = 90.0
	# Barometric damper is the tended draft control, a weighted disc in the
	# breeching rather than a science-fiction slider on the boiler jacket.
	_draft_damper = Node3D.new()
	_draft_damper.name = "BarometricDamper"
	_draft_damper.position = Vector3(-0.20, 1.84, D * 0.5 + 0.30)
	add_child(_draft_damper)
	var disc := _cyl(_draft_damper, 0.13, 0.13, 0.025, Vector3.ZERO, STEEL)
	disc.rotation_degrees.x = 90.0
	var weight_arm := _cyl(_draft_damper, 0.009, 0.009, 0.22,
			Vector3(-0.11, -0.03, 0), STEEL)
	weight_arm.rotation_degrees.z = 90.0
	_cyl(_draft_damper, 0.025, 0.025, 0.035,
			Vector3(-0.22, -0.03, 0), STEEL)


func _build_service_plate() -> void:
	# The maker's name has been polished illegible. Two raised rules preserve
	# the fact of a nameplate without asking an image generator to typeset it.
	_box(_carcass, Vector3(0.30, 0.13, 0.012),
			Vector3(-0.20, 1.47, -D * 0.5 - 0.054), BRASS)
	for y in [1.44, 1.49]:
		_box(_carcass, Vector3(0.20, 0.008, 0.008),
				Vector3(-0.20, y, -D * 0.5 - 0.063), IRON_EDGE)
	# One inspection tag, tied where a hand actually checks the glass.
	_box(_carcass, Vector3(0.12, 0.16, 0.006),
			Vector3(0.40, 1.24, -D * 0.5 - 0.112), PAPER)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "BoilerCollision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(W + 0.16, BARREL_TOP, D + 0.24)
	shape.shape = box
	shape.position = Vector3(0, BARREL_TOP * 0.5, 0)
	body.add_child(shape)
	add_child(body)


func _start_normal_function() -> void:
	state = PState.OPERATING


func interact_prompt() -> String:
	return "[E]  %s firing door" % ("Close" if _fire_open else "Open")


func interact(_player: Node) -> void:
	set_fire_door_open(not _fire_open)


func interact_area(area: Area3D) -> void:
	match area.name:
		"AshDoorReach": set_ash_door_open(not _ash_open)
		"DraftReach": set_draft(wrapf(draft + 0.2, 0.15, 1.01))
		"WaterGlassReach": _begin_water_column_service(
				get_tree().get_first_node_in_group("player_controller"))
		_: set_fire_door_open(not _fire_open)


func control_prompt(control_id: String) -> String:
	return ("[E]  Prove the boiler water column" if control_id == "water_column"
			else interact_prompt())


func interact_control(control_id: String, player: Node) -> bool:
	if control_id == "water_column":
		return _begin_water_column_service(player)
	return false


func _begin_water_column_service(player: Node) -> bool:
	if _service_panel and is_instance_valid(_service_panel):
		return false
	var script: GDScript = load("res://scripts/ui/maintenance_activity_panel.gd")
	_service_panel = script.new()
	get_tree().current_scene.add_child(_service_panel)
	if not _service_panel.open(player, self, "boiler_water_column_test"):
		_service_panel.queue_free()
		_service_panel = null
		return false
	return true


func maintenance_panel_closed() -> void:
	_service_panel = null


func maintenance_snapshot() -> Dictionary:
	return {"water_level": water_level, "column_isolated": column_isolated,
			"column_proved": column_proved}


func preview_maintenance_step(step: Dictionary, value: float) -> void:
	var worked := clampf(value, 0.0, 1.0)
	match str(step.get("id", "")):
		"isolate_column", "return_service":
			_set_column_cocks(worked)
		"read_level":
			_set_water_visual(worked)
			_set_witness_visual(worked)


func preview_maintenance_hold(step: Dictionary, progress: float,
		_value: float) -> void:
	if str(step.get("id", "")) != "prove_drain":
		return
	var worked := clampf(progress, 0.0, 1.0)
	_set_water_visual(lerpf(water_level, 0.02, worked))
	if _blowdown_lever:
		_blowdown_lever.rotation.z = deg_to_rad(lerpf(0.0, -34.0, worked))


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	column_isolated = bool(snapshot.get("column_isolated", column_isolated))
	column_proved = bool(snapshot.get("column_proved", column_proved))
	water_level = clampf(float(snapshot.get("water_level", water_level)), 0.0, 1.0)
	_set_water_visual(water_level)
	_apply_column_service_pose()


func apply_maintenance_result(result: Dictionary) -> void:
	var patch: Dictionary = result.get("mechanism_patch", {})
	water_level = clampf(float(patch.get("water_level", water_level)), 0.0, 1.0)
	column_proved = bool(patch.get("column_proved", column_proved))
	column_isolated = false
	_apply_state()
	_apply_column_service_pose()
	maintenance_completed.emit(result.duplicate(true))


func _apply_column_service_pose() -> void:
	_set_column_cocks(0.0 if column_isolated else 1.0)
	_set_witness_visual(water_level)
	if _blowdown_lever:
		_blowdown_lever.rotation.z = 0.0


func _set_column_cocks(value: float) -> void:
	for cock in _column_cocks:
		cock.rotation.z = deg_to_rad(lerpf(-82.0, 0.0,
				clampf(value, 0.0, 1.0)))


func _set_water_visual(value: float) -> void:
	if _water_fill == null:
		return
	var h := lerpf(0.018, 0.44, clampf(value, 0.0, 1.0))
	_water_fill.scale.y = h / 0.28
	_water_fill.position.y = 0.82 + h * 0.5


func _set_witness_visual(value: float) -> void:
	if _witness_marker:
		_witness_marker.position.y = _column_level_y(value)


func _column_level_y(value: float) -> float:
	return 0.82 + lerpf(0.018, 0.44, clampf(value, 0.0, 1.0))


func set_fire_door_open(open: bool, seconds := 0.55) -> void:
	_fire_open = open
	if _fire_tween and _fire_tween.is_valid():
		_fire_tween.kill()
	if seconds <= 0.0:
		_fire_door.rotation.y = deg_to_rad(-95.0 if open else 0.0)
	else:
		_fire_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(
				Tween.EASE_IN_OUT)
		_fire_tween.tween_property(_fire_door, "rotation:y",
				deg_to_rad(-95.0 if open else 0.0), seconds)
	boiler_state_changed.emit(get_boiler_state())


func set_ash_door_open(open: bool, seconds := 0.45) -> void:
	_ash_open = open
	if _ash_tween and _ash_tween.is_valid():
		_ash_tween.kill()
	if seconds <= 0.0:
		_ash_door.rotation.y = deg_to_rad(-82.0 if open else 0.0)
	else:
		_ash_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(
				Tween.EASE_IN_OUT)
		_ash_tween.tween_property(_ash_door, "rotation:y",
				deg_to_rad(-82.0 if open else 0.0), seconds)
	boiler_state_changed.emit(get_boiler_state())


func set_draft(value: float) -> void:
	draft = clampf(value, 0.0, 1.0)
	if _draft_damper:
		_draft_damper.rotation.z = deg_to_rad(lerpf(-28.0, 32.0, draft))
	_apply_state()


func set_water_level(value: float) -> void:
	water_level = clampf(value, 0.0, 1.0)
	_apply_state()


func set_pressure(value: float) -> void:
	pressure = clampf(value, 0.0, 1.0)
	_apply_state()


func add_coal(amount := 0.22) -> void:
	coal_charge = clampf(coal_charge + amount, 0.0, 1.0)
	firebed = clampf(firebed + amount * 0.72, 0.0, 1.0)
	ash_level = clampf(ash_level + amount * 0.08, 0.0, 1.0)
	_apply_state()


func rake_grate() -> void:
	ash_level = maxf(0.0, ash_level - 0.24)
	firebed = clampf(firebed + 0.08, 0.0, 1.0)
	_settle.play()
	_apply_state()


func blow_down_glass() -> void:
	# Clearing sediment briefly drops the visible column. The tending system
	# restores it from the boiler state rather than pretending water vanished.
	if _water_fill:
		var held := water_level
		set_water_level(0.08)
		await get_tree().create_timer(0.55, false).timeout
		if is_inside_tree():
			set_water_level(held)


func tick_plant(sim_seconds: float) -> void:
	# One shift can neglect the boiler; one conversation cannot. Rates are
	# deliberately slow and deterministic so render/test timing cannot become
	# a hidden source of heat-balance failures.
	var burn := sim_seconds / 1800.0 * lerpf(0.45, 1.25, draft)
	coal_charge = maxf(0.0, coal_charge - burn)
	firebed = maxf(0.0, firebed - burn * 0.72)
	ash_level = clampf(ash_level + burn * 0.38, 0.0, 1.0)
	pressure = move_toward(pressure, boiler_output(), sim_seconds / 480.0)
	water_level = clampf(water_level - sim_seconds / 7200.0, 0.0, 1.0)
	_apply_state()


func boiler_output() -> float:
	var water_factor := clampf((water_level - 0.12) / 0.46, 0.0, 1.0)
	var ash_factor := lerpf(1.0, 0.48, ash_level)
	return clampf(firebed * lerpf(0.58, 1.12, draft) * water_factor * ash_factor,
			0.0, 1.0)


func get_boiler_state() -> Dictionary:
	return {"pressure": pressure, "water_level": water_level,
			"firebed": firebed, "draft": draft, "coal_charge": coal_charge,
			"ash_level": ash_level, "output": boiler_output(),
			"fire_door_open": _fire_open, "ash_door_open": _ash_open}


func set_service_pose() -> void:
	set_fire_door_open(true, 0.0)
	set_ash_door_open(true, 0.0)
	set_draft(0.82)
	set_water_level(0.56)
	set_pressure(0.68)


func _apply_state() -> void:
	_set_water_visual(water_level)
	if _gauge_needle:
		_gauge_needle.rotation.z = deg_to_rad(lerpf(-118.0, 118.0, pressure))
	if _fire_material:
		_fire_material.emission_enabled = firebed > 0.08
		_fire_material.emission = Color(0.50, 0.070, 0.010) * firebed
		_fire_material.emission_energy_multiplier = 0.24 + firebed * 0.24
	if _draft_bed:
		_draft_bed.volume_db = lerpf(-40.0, -31.0, boiler_output())
	boiler_state_changed.emit(get_boiler_state())


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_thud.volume_db = -17.0 + linear_to_db(clampf(accent, 0.25, 1.0))
	_thud.pitch_scale = rng.randf_range(0.78, 0.93)
	_thud.play()
	_shake = maxf(_shake, accent * 0.004)


func _process(delta: float) -> void:
	if _shake > 0.0002:
		_carcass.position = Vector3(rng.randf_range(-_shake, _shake), 0,
				rng.randf_range(-_shake, _shake))
		_shake = maxf(0.0, _shake - delta * 0.025)
	elif _carcass and _carcass.position != Vector3.ZERO:
		_carcass.position = Vector3.ZERO


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


func _control_area(area_name: String, control_id: String,
		at: Vector3, size: Vector3) -> void:
	var area := ControlArea.new()
	area.name = area_name
	area.configure(control_id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	area.add_child(shape)
	add_child(area)


func _box(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = _pmat(color, 0.58, 0.18)
	parent.add_child(node)
	return node


func _cyl(parent: Node3D, rt: float, rb: float, height: float,
		at: Vector3, color: Color) -> MeshInstance3D:
	return make_cyl(rt, rb, height, at, color, 0.56, 0.25, parent)
