extends Node3D
## Presentation only. The command and borrowed sky clock supply every date.
const State := preload("res://scripts/game/prologue_state.gd")
const ASSET := "res://assets/props/companion_time_register.glb"
const OPEN_START := 1.0
const OPEN_END := 68.0 / 24.0
const CLOSE_START := 164.0 / 24.0
const CLOSE_END := 208.0 / 24.0
const FINISHES := {
	"fire_hardware_steel": [.128, .22, .8],
	"brass_dull": [.5, .2, .85],
	"porcelain_fixture": [.4, .1, .7],
	"bakelite_black": [.3, .16, .85],
	"glass_drawn_expressive": [.128, .025, .25],
}
var native: Node3D
var hinge: Node3D
var animator: AnimationPlayer
var clip: StringName
var labels: Dictionary = {}
var phase := "idle"
var opening := 0.0
var _owner: WeakRef
var _carrier: Node
var _target: Dictionary = {}
var capacitor: ShaderMaterial
var emission_counts := PackedInt32Array([0, 0, 0, 0])

func configure(mechanism: Node3D, carrier: Node = null) -> bool:
	_carrier = carrier
	var packed := load(ASSET) as PackedScene
	if packed == null: return false
	native = packed.instantiate(); add_child(native)
	var mount := native.find_child("TemporalAccessoryMount", true, false)
	if mount == null or not is_equal_approx(float(mount.get_meta("extras", {}).get("baked_reference_scale", 0)), .42): return false
	scale = Vector3.ONE / .42
	var materials := {}
	for key: String in FINISHES:
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		if key == "glass_drawn_expressive": material = preload("res://scripts/building/orison_v2_expressive_glass.gd").make(key)
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE / float(FINISHES[key][0])
		material.normal_scale = FINISHES[key][1]
		material.roughness = FINISHES[key][2]
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if key == "bakelite_black": material.albedo_color = Color(.035, .045, .04)
		materials[key] = material
	var count := 0
	for draw: MeshInstance3D in native.find_children("*", "MeshInstance3D", true, false):
		var key := str(draw.get_meta("extras", {}).get("material_key", ""))
		if not materials.has(key): return false
		draw.layers = 1 << (ServiceSetProp.DEVICE_LAYER - 1)
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		for surface in draw.mesh.get_surface_count(): draw.set_surface_override_material(surface, materials[key])
		if key == "porcelain_fixture" and not _bind_capacitor(draw, materials[key]): return false
		count += 1
	if count != 7: return false
	hinge = native.find_child("RegisterHinge", true, false)
	var players := native.find_children("*", "AnimationPlayer", true, false)
	if hinge == null or players.size() != 1: return false
	animator = players[0]
	for name: StringName in animator.get_animation_list():
		if str(name).ends_with("RegisterHingeAction"): clip = name
	if clip.is_empty(): return false
	animator.play(clip); animator.pause()
	for row: String in ["Departure", "Passing", "Destination"]:
		var anchor := native.find_child("Readout_" + row, true, false) as Node3D
		if anchor == null: return false
		var label := Label3D.new()
		label.name = "Temporal" + row
		label.font = TelegramStyle.BODY_FONT; label.font_size = 48
		label.pixel_size = .000090 if row == "Passing" else .000070
		# Native face normal is Blender +Y, exported Godot -Z. Text reads along
		# the panel's +Z chart direction; the authoring basis converts only once.
		label.rotation_degrees = Vector3(0, 180, 180)
		label.modulate = Color(.55, 1.0, .67)
		label.outline_size = 0; label.no_depth_test = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.layers = 1 << (ServiceSetProp.DEVICE_LAYER - 1)
		anchor.add_child(label); labels[row] = label
	_set_opening(0)
	set_process(false)
	return mechanism != null

## Conservative native 121-pose sweep, converted once into the parent rig.
func envelope_in_rig() -> AABB:
	var low := Vector3(-.039000001, -.117074401, -.026143272) / .42
	var high := Vector3(.039000001, .032219999, .078751669) / .42
	return AABB(low, high - low)

func begin(owner: Node, destination: Dictionary) -> bool:
	if not is_instance_valid(owner) or not owner.is_inside_tree() or not State.valid_target(destination): return false
	if get_tree().paused or (_carrier != null and not _carrier.device.radio_powered): return false
	if _owner != null and is_instance_valid(_owner.get_ref()) and _owner.get_ref() != owner: return false
	_owner = weakref(owner); _target = State.annual_destination(destination)
	capacitor.set_shader_parameter("capacitor_charge", 1.0)
	labels.Departure.text = "DEPARTURE  UNKNOWN"
	labels.Passing.text = "PASSING  --"
	labels.Destination.text = "DEST " + _date(float(_target.utc_unix_seconds), int(_target.local_bias_minutes))
	phase = "opening"; set_process(true)
	return true

func sample_clock(owner: Node, utc_seconds: float) -> void:
	if _owner == null or _owner.get_ref() != owner or not is_finite(utc_seconds): return
	# The sky's existing UTC projection is EST in the authored year. Never
	# resample OS time or turn this presentation into a campaign clock writer.
	var text := "PASS " + _date(utc_seconds, -300)
	if labels.Passing.text != text: labels.Passing.text = text

func release(owner: Node, immediate := false) -> void:
	if _owner == null or _owner.get_ref() != owner: return
	_owner = null; _target.clear()
	capacitor.set_shader_parameter("capacitor_charge", 0.0)
	phase = "closing"
	if immediate: _settle()
	else: set_process(true)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if get_tree().paused: return
	if _owner != null and (not is_instance_valid(_owner.get_ref()) or (_carrier != null and not _carrier.device.radio_powered)):
		_owner = null; _target.clear(); phase = "closing"
		capacitor.set_shader_parameter("capacitor_charge", 0.0)
	if phase == "opening":
		_set_opening(minf(1, opening + delta / (OPEN_END - OPEN_START)))
		if opening >= 1: phase = "open"
	elif phase == "closing":
		_set_opening(maxf(0, opening - delta / (CLOSE_END - CLOSE_START)))
		if opening <= 0: _settle()

func _set_opening(value: float) -> void:
	opening = clampf(value, 0, 1)
	var sample := lerpf(CLOSE_END, CLOSE_START, opening) if phase == "closing" else lerpf(OPEN_START, OPEN_END, opening)
	animator.seek(sample, true)
	# Imported animation optimization slightly rounds held key rotations. The
	# measured absolute mechanical stops remain exact; do not accumulate them.
	if opening == 0: hinge.basis = Basis(Vector3.RIGHT, deg_to_rad(-90))
	elif opening == 1: hinge.basis = Basis(Vector3.RIGHT, deg_to_rad(-210))
	for label: Label3D in labels.values(): label.visible = opening > .98

func _settle() -> void:
	_set_opening(0); phase = "idle"; set_process(false)

static func _date(seconds: float, bias: int) -> String:
	var date := Time.get_datetime_dict_from_unix_time(int(seconds) + bias * 60)
	return "%02d/%02d/%04d %02d.%02d" % [date.month, date.day, date.year, date.hour, date.minute]

func _bind_capacitor(draw: MeshInstance3D, source: StandardMaterial3D) -> bool:
	# Godot ignores arbitrary glTF vertex semantics. Read the immutable native
	# tags once, matching positions rather than assuming importer vertex order.
	# Never edit the generated GLB, shared mesh, UVs, normals or tangents.
	var bytes := FileAccess.get_file_as_bytes(ASSET)
	if bytes.size() < 28 or bytes.decode_u32(0) != 0x46546c67: return false
	var json_length := bytes.decode_u32(12)
	var data: Dictionary = JSON.parse_string(bytes.slice(20, 20 + json_length).get_string_from_utf8())
	var binary := bytes.slice(28 + json_length)
	var attributes: Dictionary = {}
	for node: Dictionary in data.nodes:
		if str(node.get("name", "")) == str(draw.name):
			attributes = data.meshes[int(node.mesh)].primitives[0].attributes
	if not attributes.has("_EMISSION_REGION"): return false
	var points := _accessor(data, binary, int(attributes.POSITION), 3)
	var regions := _accessor(data, binary, int(attributes._EMISSION_REGION), 1)
	if points.size() != regions.size() * 3: return false
	var tags := {}
	for index in regions.size():
		var region := int(regions[index])
		if region < 0 or region > 3: return false
		var point := Vector3(points[index * 3], points[index * 3 + 1], points[index * 3 + 2])
		var key := Vector3i((point * 10000000).round())
		if tags.has(key) and int(tags[key]) != region: return false
		tags[key] = region
	var arrays := draw.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray(); colors.resize(vertices.size())
	for index in vertices.size():
		var key := Vector3i((vertices[index] * 10000000).round())
		if not tags.has(key): return false
		var region := int(tags[key])
		emission_counts[region] += 1
		colors[index] = Color(float(region) / 3.0, 0, 0, 1)
	for region in 4:
		if emission_counts[region] == 0: return false
	arrays[Mesh.ARRAY_COLOR] = colors
	var local_mesh := ArrayMesh.new()
	local_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	draw.mesh = local_mesh
	capacitor = ShaderMaterial.new(); capacitor.shader = preload("res://shaders/companion_capacitor.gdshader")
	capacitor.resource_name = "porcelain_fixture"
	capacitor.set_shader_parameter("albedo_tex", source.albedo_texture)
	capacitor.set_shader_parameter("rough_tex", source.roughness_texture)
	capacitor.set_shader_parameter("normal_tex", source.normal_texture)
	capacitor.set_shader_parameter("mesh_uv_scale", Vector2(source.uv1_scale.x, source.uv1_scale.y))
	capacitor.set_shader_parameter("normal_scale", source.normal_scale)
	capacitor.set_shader_parameter("roughness_mul", source.roughness)
	capacitor.set_shader_parameter("metallic", source.metallic)
	draw.set_surface_override_material(0, capacitor)
	return true

static func _accessor(data: Dictionary, binary: PackedByteArray, index: int, components: int) -> PackedFloat32Array:
	var spec: Dictionary = data.accessors[index]
	if int(spec.componentType) != 5126 or spec.has("sparse"): return PackedFloat32Array()
	var view: Dictionary = data.bufferViews[int(spec.bufferView)]
	var stride := int(view.get("byteStride", components * 4))
	var offset := int(view.get("byteOffset", 0)) + int(spec.get("byteOffset", 0))
	var count := int(spec.count)
	if offset + (count - 1) * stride + components * 4 > binary.size(): return PackedFloat32Array()
	var values := PackedFloat32Array(); values.resize(count * components)
	for vertex in count:
		for axis in components: values[vertex * components + axis] = binary.decode_float(offset + vertex * stride + axis * 4)
	return values
