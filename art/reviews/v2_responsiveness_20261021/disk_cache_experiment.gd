extends RefCounted
## World-owned disk cache of already validated immutable native collision faces.
## No scene, mesh or shape resource survives retirement through this owner.
var paths: Dictionary = {}
var directory := ""
var seed_ms := 0.0
var bundle_path := ""
var cache_bytes := 0
var warmed_rids: Dictionary = {}
var warm_valid := false

func warm_shapes(shapes: Dictionary) -> void:
	var accepted := {}
	warm_valid=false
	for key: String in shapes:
		var shape:=shapes[key] as ConcavePolygonShape3D
		if shape==null or not paths.has(key) or face_signature(shape)!=str(paths[key].face_hash): return
		# Warm the physics backend's lazy shape construction without scene nodes.
		var body:=PhysicsServer3D.body_create()
		PhysicsServer3D.body_add_shape(body,shape.get_rid())
		PhysicsServer3D.free_rid(body)
		accepted[key]=shape.get_rid().get_id()
	warmed_rids=accepted
	warm_valid=accepted.size()==paths.size()

func publish_warm_validation() -> void:
	for key: String in warmed_rids: paths[key]["shape_rid"]=warmed_rids[key]

static func mesh_signature(mesh: Mesh) -> String:
	if mesh is not ArrayMesh or mesh.get_blend_shape_count()!=0: return ""
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
	for surface: Dictionary in mesh.get("_surfaces"):
		for key: String in ["format","primitive","vertex_count","index_count","aabb"]:
			digest.update(var_to_bytes(surface.get(key)))
		for key: String in ["vertex_data","attribute_data","skin_data","index_data","blend_shape_data"]:
			digest.update(var_to_bytes(surface.get(key)))
	return digest.finish().hex_encode()

static func face_signature(shape: ConcavePolygonShape3D) -> String:
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
	digest.update(shape.get_faces().to_byte_array())
	return digest.finish().hex_encode()

func seed(cells: Dictionary) -> bool:
	var started := Time.get_ticks_usec()
	directory="user://v2_fitting_collision/"+str(get_instance_id())
	if DirAccess.make_dir_recursive_absolute(directory)!=OK: return false
	var shapes := {}
	for cell: Node3D in cells.values():
		for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):
			var key := str(draw.get_meta("native_collision_key",""))
			if key.is_empty() or paths.has(key): continue
			var collisions := draw.find_children("*","CollisionShape3D",true,false)
			if collisions.size()!=1 or collisions[0].shape is not ConcavePolygonShape3D: return false
			var signature:=mesh_signature(draw.mesh)
			if signature.is_empty(): return false
			paths[key]={"mesh_hash":signature,"face_hash":face_signature(collisions[0].shape)}
			shapes[key]=collisions[0].shape
	var bundle:=Resource.new()
	bundle.set_meta("shapes",shapes)
	bundle_path=directory.path_join("native_collision.res")
	if ResourceSaver.save(bundle,bundle_path)!=OK: return false
	var file:=FileAccess.open(bundle_path,FileAccess.READ)
	if file==null: return false
	cache_bytes=file.get_length()

	seed_ms=float(Time.get_ticks_usec()-started)/1000.0
	return not paths.is_empty()

func dispose() -> void:
	# Only exact files created by this instance, followed by its empty directory.
	if not bundle_path.is_empty(): DirAccess.remove_absolute(bundle_path)
	bundle_path=""
	paths.clear()
	warmed_rids.clear()
	if not directory.is_empty(): DirAccess.remove_absolute(directory)
	directory=""
