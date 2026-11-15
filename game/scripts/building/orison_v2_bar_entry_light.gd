extends LightFixtureProp
## Authored accent; inherited hours, electrical envelope and LightRig budget own output.
const Entry := preload("res://scripts/building/orison_v2_bar_entry.gd")
const ENTRY_DATA := "res://data/orison_v2/harukiya_entry.json"
const Surface := preload("res://scripts/building/surface_pass.gd")
var native_failed := false
var fixture_record: Dictionary = {}
var _tubes: Array[MeshInstance3D] = []
var _tube_surfaces: Array[ShaderMaterial] = []
var _native_surface: RefCounted

func _ready() -> void:
	if str(fixture_record.get("id", "")) != str(name) \
			or not _finite_components(fixture_record.get("tint"), 3, 4) \
			or not _finite_components(fixture_record.get("emitter_local_source"), 3, 3):
		_fail_native("invalid identity, tint or emitter coordinates")
		return
	for key: String in ["range_m", "energy_scale"]:
		var value: Variant = fixture_record.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) <= 0.0:
			_fail_native("invalid fixture " + key)
			return
	range_clamp = float(fixture_record.range_m)
	energy_scale = float(fixture_record.energy_scale)
	_target_scale = 0.0
	# Await the existing venue director's first verdict. Its disabled diagnostic
	# convention remains unchanged; the rig still supplies the first budget.
	if OS.get_environment("DAYNIGHT") != "0" or OS.get_environment("SCHEDULE") == "1":
		powered = false
	super._ready()

static func _finite_components(value: Variant, minimum: int, maximum: int) -> bool:
	if value is not Array or value.size() < minimum or value.size() > maximum: return false
	for component: Variant in value:
		if not (component is float or component is int) or not is_finite(float(component)): return false
	return true

func _author_personality(base_tone: Color) -> void:
	super._author_personality(base_tone)
	var color: Array = fixture_record.get("tint", [1.0, 1.0, 1.0])
	_individual_tone = Color(color[0], color[1], color[2])
	_individual_gain = 1.0
	_flicker_profile = 2
	_flicker_depth = .012

func _build_body(parent: Node3D) -> Vector3:
	var spec := Entry.read_spec(ENTRY_DATA)
	if spec.get("fixture_parts") is not Array or str(fixture_record.get("id", "")) != str(name):
		_fail_native("fixture specification or identity missing")
		return Vector3.ZERO
	var packed := load(str(spec.get("fixture_asset", ""))) as PackedScene
	if packed == null:
		_fail_native("fixture native asset missing")
		return Vector3.ZERO
	var model := packed.instantiate() as Node3D
	if model == null:
		_fail_native("fixture native root invalid")
		return Vector3.ZERO
	var expected := {}; var seen := {}; var prepared: Array[Dictionary] = []
	for part: Dictionary in spec.fixture_parts:
		if expected.has(str(part.name)):
			model.free(); _fail_native("duplicate fixture part"); return Vector3.ZERO
		expected[str(part.name)] = part
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var identity := str(draw.name)
		if not expected.has(identity) or seen.has(identity) or draw.mesh == null:
			model.free(); _fail_native("fixture part inventory mismatch"); return Vector3.ZERO
		seen[identity] = true
		var part: Dictionary = expected[identity]
		if draw.mesh.get_surface_count() != 1 or draw.mesh.get_faces().size() != int(part.triangles)*3:
			model.free(); _fail_native("fixture mesh differs from native record"); return Vector3.ZERO
		if str(part.fixture_id) != str(name): continue
		var finish: Dictionary = spec.materials.get(str(part.matkey), {})
		var key := str(finish.get("catalog_key", ""))
		if not MatLib.SETS.has(key) or finish.get("tint") is not Array or finish.tint.size() != 4:
			model.free(); _fail_native("fixture material invalid"); return Vector3.ZERO
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE / float(MatLib.SETS[key][3])
		material.albedo_color = Color(finish.tint[0], finish.tint[1], finish.tint[2], finish.tint[3])
		material.normal_scale = float(finish.get("normal", material.normal_scale))
		material.roughness = float(finish.get("roughness", material.roughness))
		prepared.append({"draw":draw, "pose":model.transform * StaticMeshBatcher._relative_xform(draw, model),
			"material":material, "record":part, "key":key})
	if seen.size() != expected.size() or prepared.is_empty():
		model.free(); _fail_native("fixture inventory incomplete"); return Vector3.ZERO
	var emitters := 0
	for part: Dictionary in prepared:
		if bool(part.record.is_emitter): emitters += 1
	if emitters != 1:
		model.free(); _fail_native("fixture needs exactly one tube partition"); return Vector3.ZERO
	for part: Dictionary in prepared:
		var draw: MeshInstance3D = part.draw
		draw.owner = null
		draw.get_parent().remove_child(draw)
		parent.add_child(draw)
		draw.transform = part.pose
		draw.mesh = draw.mesh.duplicate() as ArrayMesh
		draw.mesh.surface_set_material(0, part.material)
		draw.set_meta("material_key", part.key)
		draw.set_meta("harukiya_entry_fixture_part", str(part.record.name))
		if bool(part.record.is_emitter):
			draw.name = "bulb_entry_tube"
			_tubes.append(draw)
		else:
			draw.name = "F01_retail_bar_entry_fixture_" + str(part.record.name)
			draw.create_trimesh_collision()
	model.free()
	return GameBoot.b2g(fixture_record.emitter_local_source)

func _build_visual() -> void:
	super._build_visual()
	if native_failed: return
	_bulb_mat.emission_energy_multiplier = 0.0
	_native_surface = Surface.new()
	_native_surface.apply({"entry_fixture": _swing_node})
	for tube: MeshInstance3D in _tubes:
		var original := tube.mesh.surface_get_material(0) as StandardMaterial3D
		var material := Surface.surface_for(original, {"uv_mode":0, "pigment_variation":1.0})
		# No shared cache: each fixture publishes its own live inherited envelope.
		tube.material_override = null
		tube.set_surface_override_material(0, material)
		_tube_surfaces.append(material)
	_publish_emission()

func _process(delta: float) -> void:
	if native_failed: return
	super._process(delta)
	_swing_node.rotation = Vector3.ZERO
	bounce.light_energy = 0.0
	bounce.visible = false
	_publish_emission()

func _publish_emission() -> void:
	if _bulb_mat == null: return
	var allowed := powered and _state_gain > .001 and _target_scale > .001
	for material: ShaderMaterial in _tube_surfaces:
		material.set_shader_parameter("emission_color", _bulb_mat.emission)
		material.set_shader_parameter("emission_energy", _bulb_mat.emission_energy_multiplier if allowed else 0.0)

func _fail_native(reason: String) -> void:
	native_failed = true
	push_error("Harukiya entry light: " + reason)
