extends RefCounted
## Fixed fabric. Shared meshes and floor-scoped instances retain authored poses.
const DATA_PATH := "res://data/orison_v2/front_lighting_supply.json"
var errors: Array[String] = []
var installed: Array[MeshInstance3D] = []
var instance_groups: Array[MultiMeshInstance3D] = []
var replaced_covers: Array[String] = []
var _shapes: Dictionary = {}

func mount(world: Node3D, electrical: RefCounted) -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if data.get("schema_version") != 1: return false
	if FileAccess.file_exists(str(data.asset)) and FileAccess.get_sha256(str(data.asset))!=str(data.asset_sha256):
		errors.append("front supply asset differs from reviewed export"); return false
	var packed := load(str(data.asset)) as PackedScene
	if packed == null: errors.append("front supply asset missing"); return false
	var model := packed.instantiate() as Node3D
	var root := Node3D.new(); root.name = "NativeFrontLightingSupply"
	world.adapter.root.add_child(root)
	var materials: Dictionary = {}
	var meshes: Dictionary = {}
	var poses: Dictionary = {}
	var memberships: Dictionary = {}
	var finishes: Dictionary = {}
	for row: Dictionary in data.materials:
		finishes[str(row.mesh)] = str(row.catalog_key)
	for row: Dictionary in data.hangers:
		if memberships.has(str(row.node)): model.free(); return false
		memberships[str(row.node)] = row
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var pose := node.transform
		var parent := node.get_parent() as Node3D
		while parent != null and parent != model:
			pose = parent.transform * pose
			parent = parent.get_parent() as Node3D
		pose = model.transform * pose
		var identity := str(node.name)
		var resource_id := node.mesh.get_instance_id()
		if not meshes.has(resource_id):
			var mesh := node.mesh.duplicate() as ArrayMesh
			for surface in mesh.get_surface_count():
				var key := str(finishes.get(mesh.resource_name,""))
				if not MatLib.SETS.has(key): errors.append("unknown front supply finish " + key); continue
				if not materials.has(key):
					var mat := MatLib.get_mat(key).duplicate() as StandardMaterial3D
					mat.uv1_triplanar = false
					mat.uv1_scale = Vector3.ONE / float(data.material_tile)
					mat.normal_scale = .12
					mat.roughness = .7
					mat.albedo_color = Color(.65,.67,.68)
					mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					materials[key] = mat
				mesh.surface_set_material(surface,materials[key])
			meshes[resource_id] = mesh
		var fitted: ArrayMesh = meshes[resource_id]
		if memberships.has(identity):
			var row: Dictionary = memberships[identity]
			var group := str(row.level) + "_" + str(row.prototype)
			if not poses.has(group): poses[group] = {"mesh":fitted,"poses":[]}
			if poses[group].mesh != fitted: errors.append("support prototype lost sharing"); continue
			poses[group].poses.append(pose)
			memberships.erase(identity)
		else:
			var draw := MeshInstance3D.new(); draw.name = identity; draw.mesh = fitted
			root.add_child(draw); draw.transform = pose
			draw.set_meta("native_front_lighting_supply",identity); installed.append(draw)
			_collision(root,fitted,pose)
	model.free()
	if not memberships.is_empty(): errors.append("missing support placements")
	for group: String in poses:
		var record: Dictionary = poses[group]
		var multi := MultiMesh.new(); multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = record.mesh; multi.instance_count = record.poses.size()
		for i in multi.instance_count:
			multi.set_instance_transform(i,record.poses[i])
			_collision(root,record.mesh,record.poses[i])
		var draw := MultiMeshInstance3D.new(); draw.name = group; draw.multimesh = multi
		draw.set_meta("native_front_lighting_support",group); root.add_child(draw); instance_groups.append(draw)
	# Only the six old front-facing covers are superseded. Use the retained
	# casting's actual cavity instead of a box collider across the new entry.
	for identity: String in data.superseded_covers:
		if not electrical.stations.has(identity): errors.append("junction missing " + identity); continue
		var owner: Node3D = electrical.stations[identity].get_ref()
		var cover := owner.get_node_or_null("JunctionCover") as MeshInstance3D
		var casting := owner.get_node_or_null("JunctionCasting") as MeshInstance3D
		if cover == null or casting == null: errors.append("junction stock missing " + identity); continue
		for collider: CollisionShape3D in owner.find_children("*","CollisionShape3D",true,false):
			collider.shape = _shape_for(casting.mesh)
		electrical.installed.erase(cover); owner.remove_child(cover); cover.free()
		replaced_covers.append(identity)
	return errors.is_empty()

func _collision(parent: Node3D, mesh: Mesh, pose: Transform3D) -> void:
	var body := StaticBody3D.new(); parent.add_child(body); body.transform = pose
	var collision := CollisionShape3D.new(); collision.shape = _shape_for(mesh); body.add_child(collision)

func _shape_for(mesh: Mesh) -> Shape3D:
	var identity := mesh.get_instance_id()
	if not _shapes.has(identity): _shapes[identity] = mesh.create_trimesh_shape()
	return _shapes[identity]

func finish() -> void:
	installed.clear(); instance_groups.clear(); replaced_covers.clear(); _shapes.clear()
