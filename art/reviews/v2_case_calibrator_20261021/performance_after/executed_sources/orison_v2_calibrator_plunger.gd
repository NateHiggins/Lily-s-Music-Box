extends Node3D
## One physical control, no case state. Only an accepted full stroke invokes
## the existing callback; acquisition, partial motion and release do not.
const DATA_PATH := "res://data/orison_v2/case_calibrator.json"
const STROKE := .004
var subject: CaseInteractable
var plunger: Node3D
var target_area: Area3D
var stroke := 0.0
var held := false
var fired := false
var _returning := false
var _cap_shape: ConvexPolygonShape3D

func configure(item: CaseInteractable) -> bool:
	if item == null or is_instance_valid(item.physical_control): return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if data is not Dictionary or data.get("schema_version") != 1 or data.get("stroke_m") != STROKE \
			or data.get("parts") is not Array or data.parts.size() != 5: return false
	if item.response_kind != "calibrator" or data.get("housing_bounds_m") != [.48,.42,.26]: return false
	var body_shape: CollisionShape3D
	for child: Node in item.get_children():
		if child is CollisionShape3D:
			if body_shape != null: return false
			body_shape = child
	if body_shape == null or body_shape.shape is not BoxShape3D \
			or not body_shape.shape.size.is_equal_approx(Vector3(.48,.42,.26)): return false
	var packed := load(str(data.asset)) as PackedScene
	if packed == null: return false
	var model := packed.instantiate() as Node3D
	var found: Dictionary = {}
	for record: Dictionary in data.parts:
		var draw := model.find_child(str(record.name),true,false) as MeshInstance3D
		if draw == null or draw.mesh == null or found.has(draw) \
				or record.get("component") not in ["Fixed","Plunger"]:
			model.free(); return false
		if draw.mesh.get_surface_count() != 1 or draw.mesh.surface_get_array_index_len(0) != int(record.get("triangles",0))*3 \
				or record.get("key") not in ["bakelite","brass_dull","metal"] \
				or typeof(record.get("tile")) not in [TYPE_FLOAT,TYPE_INT] \
				or not is_finite(float(record.tile)) or float(record.tile) <= 0.0:
			model.free(); return false
		found[draw] = record
	if found.size() != 5: model.free(); return false
	subject = item
	name = "CalibratorMechanism"
	item.add_child(self)
	plunger = AnimatableBody3D.new()
	plunger.sync_to_physics = false
	plunger.name = "CalibrationPlunger"; add_child(plunger)
	for draw: MeshInstance3D in found:
		var record: Dictionary = found[draw]
		var material := MatLib.get_mat(str(record.key)).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE / float(record.tile)
		draw.mesh = draw.mesh.duplicate() as Mesh
		draw.mesh.surface_set_material(0,material)
		draw.owner = null
		draw.reparent(plunger if record.component == "Plunger" else self,false)
		draw.set_meta("material_key",str(record.key))
		draw.set_meta("calibrator_part",str(record.name))
		if record.component == "Plunger" and record.key == "bakelite":
			_cap_shape = draw.mesh.create_convex_shape()
			var contact := CollisionShape3D.new(); contact.name = "NativeCapContact"
			contact.shape = _cap_shape
			plunger.add_child(contact); contact.transform = draw.transform
	model.free()
	var plate := Label3D.new()
	plate.name = "CalibratorPlateInk"
	plate.text = "CAPTION CALIBRATOR"
	plate.font = TelegramStyle.BOLD_FONT
	plate.font_size = 32; plate.pixel_size = .00065
	plate.modulate = TelegramStyle.CARBON
	plate.outline_size = 0; plate.shaded = true; plate.double_sided = false
	plate.position = Vector3(0,.21,.13304)
	add_child(plate)
	item._visual.mesh = null
	item._visual.material_override = null
	item._response_sound.pitch_scale = .94
	item.physical_control = self
	target_area = preload("res://scripts/props/manipulation_area.gd").install(plunger,grip)
	item.set_enabled(item.enabled)
	set_physics_process(false)
	return true

func manipulation_target(_hit: Dictionary) -> Dictionary:
	# A ray may hit the native physical cap before its matching target area.
	return grip()

func set_available(available: bool) -> void:
	if is_instance_valid(target_area): target_area.collision_layer = 1 if available else 0
	if not available and held: finish()

func grip() -> Dictionary:
	if not is_instance_valid(subject) or not subject.enabled or RealityState.save_write_blocked \
			or _returning: return {}
	return {"owner":subject,"part":plunger,"frame":self,"kind":"slide",
		"axis":Vector3.DOWN,"minimum":0.0,"maximum":STROKE,"motion_scale":.025,
		"read":func(): return stroke,"write":move,
		"begin":begin,"owns":func(): return held,"end":finish}

func begin() -> bool:
	if held or not subject.enabled or RealityState.save_write_blocked \
			or _returning: return false
	held = true; fired = false
	return true

func move(value: float) -> void:
	if not held or not subject.enabled or not is_finite(value): return
	_apply_stroke(clampf(value,0.0,STROKE))
	if stroke < STROKE - .000001 or fired: return
	fired = true
	if subject.action.is_valid():
		# Presentation follows the same authoritative result and existing radio
		# power/protected-dialogue checks as semantic interaction.
		var result: Variant = subject.action.call()
		var player := get_tree().get_first_node_in_group("player_controller") as PlayerController
		if player != null: player._present_interaction_telegram(subject,result)
		if is_instance_valid(subject._response_sound): subject._response_sound.play()

func _apply_stroke(value: float) -> void:
	# Godot's general approximate equality is ten micrometres near zero.
	# A smaller residual must still return to the rest datum and rearm.
	if value == stroke: return
	var motion := global_basis * Vector3.DOWN * (value-stroke)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _cap_shape
	query.transform = plunger.get_node("NativeCapContact").global_transform
	query.motion = motion
	query.margin = .00001
	query.collision_mask = 1
	query.exclude = [subject.get_rid(),(plunger as CollisionObject3D).get_rid()]
	var space := get_world_3d().direct_space_state
	var fractions := space.cast_motion(query)
	var safe := clampf(float(fractions[0]),0.0,1.0) if fractions.size() == 2 else 0.0
	query.transform.origin += motion * safe
	query.motion = Vector3.ZERO
	query.margin = 0.0
	if not space.intersect_shape(query,1).is_empty(): return
	stroke = lerpf(stroke,value,safe)
	plunger.position.y = -stroke

func finish() -> void:
	if not held: return
	held = false
	_returning = stroke > 0.0
	set_physics_process(_returning)

func _physics_process(delta: float) -> void:
	if not _returning or held:
		set_physics_process(false)
		return
	_apply_stroke(maxf(0.0,stroke-delta*STROKE/.12))
	if stroke <= .000001:
		stroke = 0.0; plunger.position.y = 0.0
		_returning = false; set_physics_process(false)
