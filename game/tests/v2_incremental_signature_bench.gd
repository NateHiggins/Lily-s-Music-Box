extends Node
## INERT digest compatibility controls, not runtime qualification.
const Cache := preload("res://scripts/building/orison_v2_fitting_collision_cache.gd")
var checks: Array=[]

func check(ok: bool,label: String) -> void:
	checks.append({"ok":ok,"label":label})
	print("SIGNATURE CHECK: ",label," = ",ok)

func drain(job: RefCounted,budget: int=1) -> int:
	var steps:=0
	while not job.done and steps<10000:
		job.advance(budget);steps+=1
	return steps

func canonical_digest(surfaces: Array) -> String:
	# Independent concatenation oracle for zero-byte controls. The frozen old
	# implementation logs FAILED on update(empty), despite leaving its digest intact.
	var encoded:=PackedByteArray()
	for surface: Dictionary in surfaces:
		for key: String in ["format","primitive","vertex_count","index_count","aabb"]:encoded.append_array(var_to_bytes(surface.get(key)))
		for key: String in ["vertex_data","attribute_data","skin_data","index_data","blend_shape_data"]:
			var bytes: Variant=surface.get(key)
			if bytes is PackedByteArray:
				encoded.append_array(var_to_bytes([key,bytes.size()]));encoded.append_array(bytes)
			else:encoded.append_array(var_to_bytes([key,bytes]))
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
	if not encoded.is_empty():digest.update(encoded)
	return digest.finish().hex_encode()

func _ready() -> void:run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	var path:=OS.get_environment("V2_ORIGINAL_COLLISION_CACHE")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=OS.get_environment("V2_ORIGINAL_COLLISION_CACHE_SHA"):
		check(false,"frozen synchronous cache source hash");finish();return
	var original: Script=load(path)
	if original==null:check(false,"frozen cache compiles");finish();return
	for length in [0,1,262143,262144,262145,1048577]:
		for field: String in Cache.SignatureJob.BUFFERS:
			var bytes:=PackedByteArray();bytes.resize(length);bytes.fill(87)
			if length>0:bytes[0]=11;bytes[length-1]=219
			var surfaces: Array=[{"format":123,"primitive":4,"vertex_count":31,"index_count":93,"aabb":AABB(Vector3.ZERO,Vector3.ONE),field:bytes}]
			var expected: String=original.call("surfaces_signature",surfaces) if length>0 else canonical_digest(surfaces)
			if length==0:check(Cache.surfaces_signature(surfaces)==expected,"synchronous empty buffer is an error-free no-op "+field)
			var job:=Cache.SignatureJob.new(surfaces)
			var steps:=drain(job)
			check(job.done and job.result==expected and job.largest_buffer_update<=Cache.SignatureJob.CHUNK_BYTES,"complete original digest "+field+" size "+str(length))
			if length>Cache.SignatureJob.CHUNK_BYTES:check(steps>1 and job.buffer_updates>1,"large buffer yields without omitting suffix "+field+" size "+str(length))
	var mixed: Array=[{}, {"format":16,"primitive":4,"vertex_count":7,"index_count":12,"vertex_data":null,"attribute_data":17,"skin_data":[1,"two"],"index_data":PackedByteArray([1,2,3]),"blend_shape_data":"fallback"}]
	var empty:=Cache.SignatureJob.new([]);drain(empty,0)
	check(empty.done and empty.result==original.call("surfaces_signature",[]),"empty input digest stays identical")
	var job:=Cache.SignatureJob.new(mixed);drain(job,0)
	check(job.done and job.result==original.call("surfaces_signature",mixed),"multiple surfaces and original non-packed fallback encoding")
	var bytes:=PackedByteArray();bytes.resize(1048577);bytes.fill(41)
	var mutable: Array=[{"format":1,"vertex_data":bytes,"index_data":PackedByteArray([9,8,7])}]
	var expected: String=original.call("surfaces_signature",mutable)
	job=Cache.SignatureJob.new(mutable);job.advance(1)
	mutable[0].format=55;mutable[0].vertex_data[262144]=88;mutable[0].index_data[0]=0;mutable.append({"format":2})
	drain(job)
	check(job.result==expected and job.result!=original.call("surfaces_signature",mutable),"constructor freezes caller dictionary/header/buffer/array mutation")
	check(Cache.surfaces_signature(job.copy_surfaces())==expected,"mesh-copy snapshot is exactly the complete hashed snapshot")
	var completed:=job.result;job.advance(0)
	check(job.done and job.result==completed,"completed job is stable on repeated advance")
	for key: String in Cache.SignatureJob.HEADERS+Cache.SignatureJob.BUFFERS:
		var first: Array=[{"format":1,"primitive":4,"vertex_count":4,"index_count":6,"aabb":AABB(Vector3.ZERO,Vector3.ONE),"vertex_data":PackedByteArray([1,2,3]),"attribute_data":PackedByteArray([4,5]),"skin_data":PackedByteArray([6]),"index_data":PackedByteArray([7,8]),"blend_shape_data":PackedByteArray([9])}]
		var second: Array=first.duplicate(true)
		second[0][key]=PackedByteArray([97,98]) if key in Cache.SignatureJob.BUFFERS else 999
		job=Cache.SignatureJob.new(second);drain(job)
		check(job.result==original.call("surfaces_signature",second) and job.result!=original.call("surfaces_signature",first),"complete identity includes "+key)
	finish()

func finish() -> void:
	var ok: bool=checks.all(func(row):return row.ok)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks},"\t"))
	print("INCREMENTAL SIGNATURE: ","PASS" if ok else "FAIL"," checks=",checks.size())
	get_tree().quit(0 if ok else 1)
