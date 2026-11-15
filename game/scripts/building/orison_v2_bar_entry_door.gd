extends DoorProp
## Replace only the red leaf's appearance; retain DoorProp's entire mechanism.
const Entry := preload("res://scripts/building/orison_v2_bar_entry.gd")
const Surface := preload("res://scripts/building/surface_pass.gd")
var native_failed := false
var native_leaf: Node3D
var _native_surface: RefCounted

func _build_service() -> void:
	var spec := Entry.read_spec()
	var record: Dictionary = spec.get("door", {})
	if str(record.get("identity", "")) != str(name) \
			or not is_equal_approx(width, float(record.get("width", 0.0))) \
			or not is_equal_approx(height, float(record.get("height", 0.0))):
		_fail_native("source door identity or dimensions changed")
		return
	native_leaf = Entry.prepare_model(spec, true)
	if native_leaf == null:
		_fail_native("native leaf inventory or registered materials invalid")
		return
	native_leaf.name = "NativeEntryLeaf"
	# Native draws use mesh materials, not batchable material_override. Their
	# root remains intact; compensate the existing body hinge exactly once.
	# DoorProp.apply_hinge_setback handles its direct hardware meshes separately.
	native_leaf.position.z += _hinge_offset
	_body.add_child(native_leaf)
	_build_knob_set(MatLib.get_mat("brass_dull", Color(.64, .58, .43)))

func _ready() -> void:
	super._ready()
	if native_failed: return
	_native_surface = Surface.new()
	_native_surface.apply({"entry_leaf": native_leaf})
	for draw: MeshInstance3D in native_leaf.find_children("*", "MeshInstance3D", true, false):
		for surface in draw.mesh.get_surface_count():
			var material := draw.get_surface_override_material(surface) as ShaderMaterial
			if material != null:
				material.set_shader_parameter("pigment_variation", float(draw.get_meta("harukiya_entry_pigment", 1.0)))

func _fail_native(reason: String) -> void:
	native_failed = true
	push_error("Harukiya entry door: " + reason)
