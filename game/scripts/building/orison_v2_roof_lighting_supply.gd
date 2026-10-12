extends RefCounted
## Fixed native fabric; the original electrical and lighting owners remain.
const PATH := "res://data/orison_v2/roof_lighting_supply.json"
var errors: Array[String] = []
var installed: Array[MeshInstance3D] = []
var data: Dictionary
var root: Node3D

func mount(world: Node3D, native: RefCounted) -> bool:
	data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data.get("schema_version") != 1: return false
	# Imported sources may be absent from an exported PCK. ResourceLoader owns
	# the shipped scene; validate the source hash only while it is available.
	if FileAccess.file_exists(str(data.asset)) and FileAccess.get_sha256(str(data.asset)) != str(data.asset_sha256):
		errors.append("native supply asset hash differs"); return false
	var packed := load(str(data.asset)) as PackedScene
	if packed == null: errors.append("native supply missing"); return false
	var cap: MeshInstance3D
	var datum := _point(data.superseded_cap)
	for draw: MeshInstance3D in native.installed:
		if draw.get_meta("native_electrical_part", "") == "ConduitCap" and draw.position.distance_to(datum) < .0001:
			if cap != null: errors.append("duplicate roof cap"); return false
			cap = draw
	if cap == null: errors.append("original roof cap absent"); return false
	root = packed.instantiate() as Node3D
	root.name = "NativeRoofLightingSupply"
	var materials: Dictionary = {}
	for draw: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := draw.mesh.duplicate() as ArrayMesh
		for i in mesh.get_surface_count():
			var key := str(mesh.surface_get_material(i).resource_name)
			if not MatLib.SETS.has(key): errors.append("unknown supply finish " + key); continue
			if not materials.has(key):
				var mat := MatLib.get_mat(key).duplicate() as StandardMaterial3D
				mat.uv1_triplanar = false
				mat.normal_scale = .08
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				materials[key] = mat
			mesh.surface_set_material(i, materials[key])
		draw.mesh = mesh
		draw.set_meta("native_roof_lighting_supply", str(draw.name))
		var body := StaticBody3D.new()
		draw.add_child(body)
		var collider := CollisionShape3D.new()
		collider.shape = mesh.create_trimesh_shape()
		body.add_child(collider)
		installed.append(draw)
	if not errors.is_empty(): root.free(); installed.clear(); return false
	world.adapter.root.add_child(root)
	root.position = _point(data.origin)
	native.installed.erase(cap)
	cap.get_parent().remove_child(cap)
	cap.free()
	return true

func _point(p: Array) -> Vector3:
	return Vector3(p[0], p[1], p[2])
