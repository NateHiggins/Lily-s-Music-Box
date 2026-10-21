extends Node
const Fitter := preload("res://scripts/building/orison_v2_shop_seating.gd")
const Cache := preload("res://scripts/building/orison_v2_fitting_collision_cache.gd")
var failures: Array[String]=[]
var checks:=0

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("COLLISION CACHE CHECK: ",label," = ",ok)

func _ready() -> void: _run.call_deferred()

func _run() -> void:
	OS.set_environment("ORISON_PROFILE_NATIVE","1")
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	var source := "res://assets/building/floor_01_cells/shop_shoe_rebuilding.gltf"
	var original: Node3D=load(source).instantiate();original.name="shop_shoe_rebuilding"
	check(Fitter.mount_cobbler(original,layout),"original authored fitting passes its own predicates")
	var cache := Cache.new()
	check(cache.seed({"shop_shoe_rebuilding":original}),"validated native collisions enter bounded world cache")
	var original_meshes: Array[WeakRef]=[]
	for draw: MeshInstance3D in original.find_children("*","MeshInstance3D",true,false):
		if draw.has_meta("native_collision_key"): original_meshes.append(weakref(draw.mesh))
	original.free()
	var retained:=0
	for reference: WeakRef in original_meshes:
		if reference.get_ref()!=null: retained+=1
	check(retained==0,"collision cache retains zero retired native meshes")
	var restored: Node3D=load(source).instantiate();restored.name="shop_shoe_rebuilding"
	restored.set_meta("native_collision_paths",cache.paths)
	var shapes: Dictionary=cache.shapes.duplicate()
	restored.set_meta("native_collision_shapes",shapes)
	check(Fitter.mount_cobbler(restored,layout),"cached shapes reconstruct through original fitting predicates")
	var native_count:=0
	for draw: MeshInstance3D in restored.find_children("*","MeshInstance3D",true,false):
		if not draw.has_meta("native_collision_key"): continue
		native_count+=1
		var collisions:=draw.find_children("*","CollisionShape3D",true,false)
		check(collisions.size()==1 and collisions[0].shape.get_faces()==draw.mesh.get_faces(),"installed collision has every original native face")
	check(native_count==cache.paths.size() and native_count>0,"every cached native part is present")
	var tiny:=Cache.new();tiny.max_face_bytes=0
	check(not tiny.seed({"shop_shoe_rebuilding":restored}) and tiny.shapes.is_empty(),"memory cap refuses cache without changing installed collision")
	var key: String=cache.paths.keys()[0]
	var original_faces: PackedVector3Array=cache.shapes[key].get_faces()
	cache.shapes[key].set_faces(PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP]))
	check(int(cache.paths[key].shape_rid)==0,"in-place shape mutation invalidates cached identity")
	var mutated: Node3D=load(source).instantiate();mutated.name="shop_shoe_rebuilding"
	mutated.set_meta("native_collision_paths",cache.paths);mutated.set_meta("native_collision_shapes",shapes)
	check(not Fitter.mount_cobbler(mutated,layout),"same-RID geometry mutation refuses reconstruction")
	mutated.free()
	cache.shapes[key].set_faces(original_faces)
	var wrong:=ConcavePolygonShape3D.new();wrong.set_faces(PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP]))
	shapes[key]=wrong
	var rejected: Node3D=load(source).instantiate();rejected.name="shop_shoe_rebuilding"
	rejected.set_meta("native_collision_paths",cache.paths)
	rejected.set_meta("native_collision_shapes",shapes)
	check(not Fitter.mount_cobbler(rejected,layout),"wrong collision geometry refuses native reconstruction")
	rejected.free();restored.free();shapes.clear();wrong=null
	cache.dispose()
	check(cache.shapes.is_empty() and cache.paths.is_empty(),"world teardown releases collision cache")
	print("V2 FITTING COLLISION CACHE: ",checks," checks; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
