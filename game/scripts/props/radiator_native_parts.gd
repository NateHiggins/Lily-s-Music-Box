class_name RadiatorNativeParts
extends RefCounted
## Shared imported stocks. Each draw preserves its authored object frame and
## binds catalogue PBR maps once; images are never embedded per radiator.

const MODELS := {
	"mechanisms": "res://assets/props/radiator_mechanisms.glb",
	"vent": "res://assets/props/radiator_air_vent.glb",
	"supports": "res://assets/props/radiator_wall_support.glb",
	"shims": "res://assets/props/radiator_pitch_shims.glb",
	"wedges": "res://assets/props/radiator_sliding_wedge.glb",
}
static var _stocks := {}
static var _materials := {}
static var _collision_shapes := {}

static func collision_for(mesh: Mesh) -> ConcavePolygonShape3D:
	var key := mesh.get_rid()
	if not _collision_shapes.has(key):_collision_shapes[key]=mesh.create_trimesh_shape()
	return _collision_shapes[key]

static func _load_family(family: String) -> Dictionary:
	if _stocks.has(family): return _stocks[family]
	var model := (load(MODELS[family]) as PackedScene).instantiate() as Node3D
	var stocks := {}
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var materials: Array[Material] = []
		for index in draw.mesh.get_surface_count():
			var imported := draw.get_active_material(index)
			assert(imported != null or family=="wedges", "Native radiator stock has no catalogue slot")
			# The shared fixed-stock exporter preserves its catalogue partition
			# name and deliberately omits per-model material/image payloads.
			var key := str(draw.name).trim_prefix("SlidingPitchWedge_") if family=="wedges" else imported.resource_name.trim_prefix("CATALOG_")
			assert(MatLib.SETS.has(key), "Unknown native radiator material: " + key)
			var tint := Color(.62,.52,.4) if family in ["shims","wedges"] else Color.WHITE
			var identity := key + "|" + tint.to_html()
			if not _materials.has(identity):
				var stock := MatLib.get_mat(key,tint).duplicate() as StandardMaterial3D
				stock.resource_name = "Radiator_" + key
				# This casting map encodes measured metre-space relief. Worked
				# fittings retain their separate, quieter catalogue finish.
				if key in ["radiator_cast_iron","graphited_packing","radiator_service_brass"]: stock.normal_scale = 1.0
				stock.uv1_triplanar = false
				stock.uv2_triplanar = false
				stock.set_meta("v2_surface_stock",key)
				_materials[identity] = stock
			materials.append(_materials[identity])
		var pose := draw.transform
		var ancestor := draw.get_parent() as Node3D
		while ancestor != model:
			pose = ancestor.transform * pose
			ancestor = ancestor.get_parent() as Node3D
		# Keep Godot's actual node identity, including its period sanitization.
		var identity := str(draw.name)
		assert(not identity.is_empty() and not stocks.has(identity))
		stocks[identity] = {"mesh":draw.mesh,"pose":pose,"materials":materials}
	model.free()
	_stocks[family] = stocks
	return stocks

static func names(family: String) -> Array:
	return _load_family(family).keys()

static func part(family: String, identity: String, parent: Node3D,
		pose := Transform3D.IDENTITY) -> MeshInstance3D:
	var stocks := _load_family(family)
	assert(stocks.has(identity), "Missing native radiator stock " + identity)
	var source: Dictionary = stocks[identity]
	var draw := MeshInstance3D.new()
	draw.name = identity
	draw.mesh = source.mesh
	draw.transform = pose * source.pose
	draw.set_meta("native_pose",source.pose)
	draw.set_meta("native_stock",identity)
	for index in source.materials.size():
		draw.set_surface_override_material(index,source.materials[index])
	parent.add_child(draw)
	return draw

static func stock_points(family: String, identity: String) -> PackedVector3Array:
	var source: Dictionary = _load_family(family)[identity]
	var result := PackedVector3Array()
	for index in source.mesh.get_surface_count():
		var vertices: PackedVector3Array = source.mesh.surface_get_arrays(index)[Mesh.ARRAY_VERTEX]
		for point in vertices: result.append(source.pose * point)
	return result

static func spread_packing(draw: MeshInstance3D, value: float) -> void:
	# Two adjacent shading anchors follow the original native position path.
	# Interpolating only the endpoints breaks tangent/normal orthogonality.
	var sample := clampf(value,0.0,1.0) * 20.0
	var lower := int(floor(sample))
	var upper := mini(lower + 1,20)
	for index in draw.get_blend_shape_count(): draw.set_blend_shape_value(index,0.0)
	if lower > 0:
		var index := draw.find_blend_shape_by_name("Spread_%02d" % lower)
		assert(index >= 0)
		draw.set_blend_shape_value(index,1.0 - (sample - lower))
	if upper > lower:
		var index := draw.find_blend_shape_by_name("Spread_%02d" % upper)
		assert(index >= 0)
		draw.set_blend_shape_value(index,sample - lower)
