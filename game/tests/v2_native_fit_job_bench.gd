extends Node
## INERT component equivalence/cancellation checks, not played-world qualification.
const Fitter := preload("res://scripts/building/orison_v2_shop_seating.gd")
const Cache := preload("res://scripts/building/orison_v2_fitting_collision_cache.gd")
const DATA := "res://data/orison_v2/cobbler_fittings.json"
const CELL := "res://assets/building/floor_01_cells/shop_shoe_rebuilding.gltf"
var checks: Array=[]
var cache: RefCounted
var layout: Dictionary
var packed: PackedScene

func check(ok: bool,label: String) -> void:
	checks.append({"ok":ok,"label":label});print("NATIVE JOB: ",label," = ",ok)

func fresh() -> Node3D:
	var cell:=packed.instantiate() as Node3D;cell.name="shop_shoe_rebuilding"
	cell.set_meta("native_collision_paths",cache.paths)
	cell.set_meta("native_collision_shapes",cache.shapes.duplicate())
	return cell

func begin(cell: Node3D,path:=DATA) -> RefCounted:
	return Fitter.begin_records(cell,layout,path,"CobblerFittings","F01_retail_cobbler_","cobbler_part")

func material_value(material: Material) -> Dictionary:
	if material is not BaseMaterial3D:return {"class":material.get_class() if material!=null else "null"}
	var result: Dictionary={}
	for key in ["albedo_color","roughness","metallic","uv1_triplanar","uv1_scale","uv1_offset","normal_enabled","normal_scale","transparency","cull_mode","texture_filter","alpha_scissor_threshold"]:result[key]=material.get(key)
	for key in ["albedo_texture","roughness_texture","normal_texture"]:
		var texture: Texture2D=material.get(key)
		result[key]=texture.resource_path if texture!=null else ""
	return result

func snapshot(cell: Node3D) -> Dictionary:
	var result: Dictionary={}
	for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):
		var names: Array[String]=[str(draw.name)];var parent:=draw.get_parent()
		while parent!=null and parent!=cell:names.push_front(str(parent.name));parent=parent.get_parent()
		var key:="/".join(names)
		var faces: Array=[]
		for collision: CollisionShape3D in draw.find_children("*","CollisionShape3D",true,false):
			faces.append({"pose":collision.transform,"disabled":collision.disabled,"hash":Cache.face_signature(collision.shape)})
		var mats: Array=[]
		for surface in draw.mesh.get_surface_count():mats.append(material_value(draw.get_active_material(surface)))
		result[key]={"pose":draw.transform,"visible":draw.visible,"shadow":draw.cast_shadow,"mesh":Cache.mesh_signature(draw.mesh),"materials":mats,"collisions":faces,"material_key":draw.get_meta("material_key",""),"native_key":draw.get_meta("native_collision_key","")}
	var model:=cell.get_node_or_null("CobblerFittings")
	if model!=null:result["removed_triangles"]=model.get_meta("removed_triangles").duplicate(true)
	return result

func drive(job: RefCounted) -> int:
	var calls:=0
	while not job.done and calls<1000:
		job.advance(500);calls+=1
		await get_tree().process_frame
	return calls

func _ready() -> void:run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	RealityState.persistence_enabled=false
	layout=JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	packed=load(CELL)
	var original_path:=OS.get_environment("V2_ORIGINAL_FITTER")
	var expected_sha:=OS.get_environment("V2_ORIGINAL_FITTER_SHA")
	if not FileAccess.file_exists(original_path) or FileAccess.get_sha256(original_path)!=expected_sha:
		check(false,"frozen original fitter source hash matches declared baseline");finish();return
	var original: Script=load(original_path)
	if original==null:check(false,"frozen original fitter compiles");finish();return
	var baseline:=packed.instantiate() as Node3D;baseline.name="shop_shoe_rebuilding"
	check(bool(original.call("mount_cobbler",baseline,layout)),"frozen pre-refactor fitter accepts actual authored cell")
	var reference:=snapshot(baseline)
	cache=Cache.new();check(cache.seed({"shop_shoe_rebuilding":baseline}),"original native collision shapes seed the unchanged cache")
	var cell:=fresh();var before:=snapshot(cell);var job:=begin(cell)
	job.advance(1)
	check(not job.done and job.prepared and not cell.has_node("CobblerFittings") and snapshot(cell)==before,"prepare keeps public cell byte/pose/material/collision state unchanged")
	var unpublished:=true;var calls:=0
	while not job.done and calls<1000:
		job.advance(500);calls+=1
		if not job.done:unpublished=unpublished and not cell.has_node("CobblerFittings") and snapshot(cell)==before
		await get_tree().process_frame
	check(job.done and job.ok and calls>2 and unpublished,"part chunks yield without partial publication")
	check(snapshot(cell)==reference,"cooperative result equals frozen original buffers, transforms, PBR fields, collision faces and source counts")
	if not job.ok:
		print("NATIVE_JOB_FAILURE ",JSON.stringify({"done":job.done,"cursor":job.cursor,"source_changed":job.source_changed,"signature_pending":job.signature_job!=null,"signature_done":job.signature_job.done if job.signature_job!=null else false}))
		job=null;cell.free();baseline.free();cache.dispose();finish();return
	var model_id:=cell.get_node("CobblerFittings").get_instance_id()
	cell.set_meta("prepared_native_fit",job)
	check(Fitter.mount_cobbler(cell,layout) and cell.get_node("CobblerFittings").get_instance_id()==model_id and not cell.has_meta("prepared_native_fit"),"original wrapper consumes one exact prepared result without rebuilding")
	check(not Fitter.mount_cobbler(cell,layout),"duplicate mount remains refused after token consumption")
	job=null;cell.free()
	cell=fresh();job=begin(cell);before=snapshot(cell);job.advance(1)
	var private_model: WeakRef=weakref(job.model)
	job.cancel()
	check(job.done and not job.ok and private_model.get_ref()==null and snapshot(cell)==before,"cancellation releases private model and preserves original cell")
	job=null;cell.free()
	cell=fresh();job=begin(cell);before=snapshot(cell);job.advance(1);private_model=weakref(job.model);job=null
	check(private_model.get_ref()==null and snapshot(cell)==before,"abandoned unfinished job releases private model without an explicit cancel")
	cell.free()
	cell=fresh();job=begin(cell);before=snapshot(cell);job.advance(1)
	var source_mesh: Mesh=job.source_guards[0].mesh;var source_material:=source_mesh.surface_get_material(0)
	source_mesh.surface_set_material(0,source_material.duplicate())
	var changed_result:=await drive(job)
	check(job.done and not job.ok and not cell.has_node("CobblerFittings"),"source resource mutation during yielded construction refuses publication")
	source_mesh.surface_set_material(0,source_material);job=null;cell.free()
	cell=fresh();job=begin(cell);job.advance(1)
	var source_draw: MeshInstance3D=job.source_guards[0].draw;source_draw.position.x+=.01
	await drive(job)
	check(job.done and not job.ok and not cell.has_node("CobblerFittings"),"source pose mutation during yielded construction refuses publication")
	job=null;cell.free()
	cell=fresh();job=begin(cell);job.advance(1)
	while not job.done and job.verified_shapes.is_empty():job.advance(1)
	if job.verified_shapes.is_empty():check(false,"cached native part is reached before cancellation controls")
	else:
		var shape: ConcavePolygonShape3D=job.verified_shapes[0].shape;var saved_faces:=shape.get_faces()
		shape.set_faces(PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP]))
		await drive(job)
		check(job.done and not job.ok and not cell.has_node("CobblerFittings"),"same-RID cached shape mutation between chunks is rechecked before publication")
		shape.set_faces(saved_faces)
	job=null;cell.free()
	cell=fresh();job=begin(cell);await drive(job);cell.set_meta("prepared_native_fit",job)
	check(not Fitter.mount_records(cell,layout,DATA,"WrongModel","F01_retail_cobbler_","cobbler_part") and not cell.has_meta("prepared_native_fit"),"prepared token refuses mismatched arguments and is consumed once")
	job=null;cell.free()
	cell=fresh();cell.set_meta("prepared_native_fit",RefCounted.new())
	check(not Fitter.mount_cobbler(cell,layout) and not cell.has_node("CobblerFittings"),"foreign prepared object cannot bypass source validation")
	cell.free()
	for action: String in ["cancel","abandon"]:
		cell=fresh();before=snapshot(cell)
		var references: Array=hash_lifetime_case(cell,action)
		check(references.size()==2 and references[0].get_ref()==null and references[1].get_ref()==null and snapshot(cell)==before,action+" during hash releases context/model outside temporary getter scope")
		cell.free()
	cell=fresh();before=snapshot(cell);job=begin_hash(cell)
	if job.signature_job==null:check(false,"signature phase reached for native source replacement")
	else:
		var native_draw:=job.draws[job.cursor] as MeshInstance3D
		native_draw.mesh=native_draw.mesh.duplicate() as Mesh
		await drive(job)
		check(job.done and not job.ok and snapshot(cell)==before,"native mesh identity change during hashing refuses publication")
	job=null;cell.free()
	baseline.free();cache.dispose();cache=null;packed=null
	await check_streamed_families(original)
	finish()

func begin_hash(cell: Node3D) -> RefCounted:
	var job:=begin(cell);job.advance(1)
	for step in 64:
		if job.done or job.signature_job!=null:break
		job.advance(1)
	return job

func hash_lifetime_case(cell: Node3D,action: String) -> Array:
	# Getter temporaries can keep a RefCounted alive in the probing VM frame.
	# Return only WeakRefs and check after this entire frame has unwound.
	var job:=begin_hash(cell)
	if job.signature_job==null:return []
	var references: Array=[weakref(job.signature_job),weakref(job.model)]
	if action=="cancel":job.cancel()
	job=null
	return references

func check_streamed_families(original: Script) -> void:
	for spec: Array in [
		["laundry","shop_model_laundry","res://assets/building/floor_01_cells/shop_model_laundry.gltf"],
		["cobbler","shop_shoe_rebuilding","res://assets/building/floor_01_cells/shop_shoe_rebuilding.gltf"],
		["locksmith","shop_keys_cut","res://assets/building/floor_01_cells/shop_keys_cut.gltf"],
		["arcade_canopy","passage","res://assets/building/orison_v2/passage/passage.gltf"],
		["arcade_throat","passage","res://assets/building/orison_v2/passage/passage.gltf"],
		["hardware_drawers","shop_hardware_paint","res://assets/building/floor_01_cells/shop_hardware_paint.gltf"],
		["hardware_stock","shop_hardware_paint","res://assets/building/floor_01_cells/shop_hardware_paint.gltf"],
		["druggist_drawers","shop_otis_son","res://assets/building/floor_01_cells/shop_otis_son.gltf"]]:
		var scene: PackedScene=load(str(spec[2]))
		var baseline:=scene.instantiate() as Node3D;baseline.name=str(spec[1])
		var accepted: bool=original.call("mount_"+str(spec[0]),baseline,layout)
		check(accepted,str(spec[0])+" frozen original accepts actual source cell")
		if not accepted:baseline.free();continue
		var reference:=snapshot(baseline)
		var local_cache:=Cache.new()
		check(local_cache.seed({str(spec[1]):baseline}),str(spec[0])+" original exact collision cache seeds")
		var cell:=scene.instantiate() as Node3D;cell.name=str(spec[1])
		cell.set_meta("native_collision_paths",local_cache.paths)
		cell.set_meta("native_collision_shapes",local_cache.shapes.duplicate())
		var job:=Fitter.begin_streamed_fitting(str(spec[0]),cell,layout)
		var calls: int=await drive(job)
		check(job.ok and calls>2 and snapshot(cell)==reference,str(spec[0])+" yielded mesh/material/pose/collision output equals frozen original")
		cell.set_meta("prepared_native_fit",job)
		check(bool(Fitter.new().call("mount_"+str(spec[0]),cell,layout)) and not cell.has_meta("prepared_native_fit"),str(spec[0])+" exact original entry consumes prepared result")
		job=null;cell.free();baseline.free();local_cache.dispose()

func finish() -> void:
	var ok: bool=checks.all(func(row):return row.ok)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("job_checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual imported component and frozen original fitter equivalence/cancellation checks; not player input or runtime_contract.","checks":checks},"\t"))
	print("NATIVE JOB: ","PASS" if ok else "FAIL"," checks=",checks.size());get_tree().quit(0 if ok else 1)
