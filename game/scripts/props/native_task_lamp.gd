extends LampProp
## V2 manufactured bodies; LampProp retains the mechanism and every light owner.
const DATA := "res://data/orison_v2/task_lamps.json"
var native_parts: Dictionary = {}
var _native_record: Dictionary = {}
var _opal: StandardMaterial3D

func _build_emeralite() -> void: _mount_native()
func _build_office_green() -> void: _mount_native()
func _build_bench_friction() -> void: _mount_native()
func _build_landlord() -> void: _mount_native()
func _build_architect() -> void: _mount_native()

func _mount_native() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	assert(data.schema_version == 1)
	_native_record = data.variants.filter(func(row): return row.id == variant)[0]
	var packed := load(str(data.asset)) as PackedScene
	var model := packed.instantiate() as Node3D
	var records: Dictionary = {}
	for row: Dictionary in _native_record.parts: records[str(row.name)] = row
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not records.has(str(draw.name)): continue
		var row: Dictionary = records[str(draw.name)]
		var pose := draw.transform
		draw.owner = null
		draw.get_parent().remove_child(draw)
		add_child(draw)
		draw.transform = pose
		# Each actor owns its surfaces; on/off state must never affect another lamp.
		draw.mesh = draw.mesh.duplicate() as Mesh
		var material := MatLib.get_mat(str(row.catalog_key)).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE / float(row.tile)
		if row.has("tint"):
			var tint: Array = row.tint
			material.albedo_color = Color(tint[0], tint[1], tint[2], tint[3])
		draw.mesh.surface_set_material(0, material)
		draw.set_meta("task_lamps_part", str(row.name))
		draw.set_meta("material_key", str(row.key))
		if row.key == "bulb_opal":
			# Its own filament is inside the glass; an opaque shadow would seal it.
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_opal = material
			_opal.emission_enabled = true
			_opal.emission = _spec.tone
			# The controlled filament uses its actor-owned emission material.
			draw.material_override = _opal
		native_parts[str(row.name)] = draw
	model.free()
	_head = Vector3(_native_record.emitter[0], _native_record.emitter[1], _native_record.emitter[2])

func _build_key_switch() -> void:
	_switch_key = Node3D.new()
	_switch_key.name = "LocalKeySwitch"
	var pivot: Array = _native_record.switch_pivot
	_switch_key.position = Vector3(pivot[0], pivot[1], pivot[2])
	add_child(_switch_key)
	for row: Dictionary in _native_record.parts:
		if row.key != "switch_bakelite": continue
		var draw: MeshInstance3D = native_parts[str(row.name)]
		var pose := _switch_key.transform.affine_inverse() * draw.transform
		remove_child(draw)
		_switch_key.add_child(draw)
		draw.transform = pose

func merge_static(_under: Node3D, _keep: Array = []) -> int:
	# Blender already exports one partition per finish, with a separate moving key.
	return 0

func _process(delta: float) -> void:
	super._process(delta)
	if _opal != null and light != null:
		_opal.emission_energy_multiplier = light.light_energy if light.visible else 0.0
