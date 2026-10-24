extends Node
## INERT file-binding, texture mutation and lifetime controls.
const Portraits := preload("res://scripts/building/orison_v2_photo_portraits.gd")
var checks: Array=[]
var folder: String
var source_path: String
var payload: String

class Loader extends RefCounted:
	var calls:=0
	var bad_dimensions:=false
	var mutate_payload:=""
	func fetch(path: String) -> Texture2D:
		calls+=1
		var image:=Image.create(8 if bad_dimensions else 1024,8 if bad_dimensions else 1536,true,Image.FORMAT_RGBA8)
		image.fill(Color.RED if FileAccess.get_file_as_string(path)=="alpha" else Color.BLUE)
		if not mutate_payload.is_empty():FileAccess.open(mutate_payload,FileAccess.WRITE).store_string("payload3")
		return ImageTexture.create_from_image(image)

func check(ok: bool,label: String) -> void:
	checks.append({"ok":ok,"label":label});print("ATLAS CACHE: ",label," = ",ok)

func write(path: String,value: String) -> void:
	FileAccess.open(path,FileAccess.WRITE).store_string(value)

func sidecar() -> void:
	var config:=ConfigFile.new()
	config.set_value("remap","path",payload)
	config.set_value("deps","source_file",source_path)
	config.set_value("deps","dest_files",PackedStringArray([payload]))
	config.set_value("params","compress/high_quality",false)
	config.save(source_path+".import")

func abandoned(loader: RefCounted,sha: String) -> Array:
	var cache:=Portraits.AtlasCache.new(loader.fetch)
	var texture:=cache.load_checked(source_path,sha)
	return [weakref(cache),weakref(texture)]

func real_atlas_lifetime() -> Array:
	var path:="res://assets/props/photo_portraits/portrait_atlas.png"
	var cache:=Portraits.AtlasCache.new()
	var texture:=cache.load_checked(path,FileAccess.get_sha256(path))
	return [weakref(cache),weakref(texture)]

func describe(reference: WeakRef) -> Dictionary:
	var resource: RefCounted=reference.get_ref()
	return {"alive":resource!=null,"class":resource.get_class() if resource!=null else "", "references":resource.get_reference_count() if resource!=null else 0}

func _ready() -> void:run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	folder="user://portrait_cache_%d_%d"%[OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(folder)
	source_path=folder.path_join("atlas.source");payload=folder.path_join("atlas.ctex")
	write(source_path,"alpha");write(payload,"payload1");sidecar()
	var sha:=FileAccess.get_sha256(source_path)
	var loader:=Loader.new();var cache:=Portraits.AtlasCache.new(loader.fetch)
	var first:=cache.load_checked(source_path,sha)
	check(first!=null and first.get_image().has_mipmaps() and cache.snapshot().textures_kept==1 and loader.calls==1,"first complete source/import/payload generation loads one mipmapped atlas")
	var second:=cache.load_checked(source_path,sha)
	check(second==first and cache.hits==1 and loader.calls==1,"unchanged generation reuses the exact texture without loading")
	write(source_path+".import",FileAccess.get_file_as_string(source_path+".import").replace("\n","\r\n"))
	check(cache.load_checked(source_path,sha)==first and loader.calls==1,"CRLF-only import rewrite preserves normalized text binding")
	write(payload,"payload2")
	second=cache.load_checked(source_path,sha)
	check(second!=null and second!=first and loader.calls==2,"same-length imported payload mutation forces a fresh load")
	(first as ImageTexture).update(Image.create(1024,1536,true,Image.FORMAT_RGBA8))
	check(not cache.snapshot().dirty and cache.load_checked(source_path,sha)==second and loader.calls==2,"retired texture change listener is disconnected")
	var config:=ConfigFile.new();config.load(source_path+".import");config.set_value("params","compress/high_quality",true);config.save(source_path+".import")
	second=cache.load_checked(source_path,sha)
	check(second!=null and loader.calls==3,"import settings mutation invalidates a byte-identical source")
	write(source_path,"bravo")
	check(cache.load_checked(source_path,sha)==null and loader.calls==3 and cache.snapshot().textures_kept==0,"wrong current source hash refuses reuse and load")
	sha=FileAccess.get_sha256(source_path);second=cache.load_checked(source_path,sha)
	check(second!=null and second.get_image().get_pixel(0,0)==Color.BLUE and loader.calls==4,"newly authorized source generation loads current pixels")
	(second as ImageTexture).update(Image.create(1024,1536,true,Image.FORMAT_RGBA8))
	check(cache.snapshot().dirty,"in-place texture mutation marks the cache dirty")
	var third:=cache.load_checked(source_path,sha)
	check(third!=null and third!=second and loader.calls==5,"dirty texture cannot substitute for validated imported bytes")
	DirAccess.remove_absolute(payload)
	var missing_before:=loader.calls
	check(cache.load_checked(source_path,sha)!=null and cache.load_checked(source_path,sha)!=null and loader.calls==missing_before+2 and cache.snapshot().textures_kept==0,"unverifiable import payload falls back to fresh loads without caching")
	write(payload,"payload2");sidecar();loader.bad_dimensions=true
	check(cache.load_checked(source_path,sha)==null and cache.snapshot().textures_kept==0,"wrong texture dimensions are not installed or retained")
	loader.bad_dimensions=false;loader.mutate_payload=payload
	check(cache.load_checked(source_path,sha)==null and cache.last_error=="changed_during_load" and cache.snapshot().textures_kept==0,"import generation changing during load is refused")
	loader.mutate_payload="";write(payload,"payload2")
	var references:=abandoned(loader,sha)
	check(references[0].get_ref()==null and references[1].get_ref()==null,"abandoned cache and its texture release outside getter scope")
	cache.clear()
	check(cache.snapshot().textures_kept==0,"explicit world shutdown releases the cached atlas")
	first=null;second=null;third=null;cache=null;loader=null
	var real_references:=real_atlas_lifetime()
	var immediate:=describe(real_references[1])
	for frame in 2:await get_tree().process_frame
	var settled:=describe(real_references[1])
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("real_lifetime.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","immediate":immediate,"after_two_frames":settled,"cache":describe(real_references[0])},"	"))
	check(not settled.alive and real_references[0].get_ref()==null,"actual imported atlas/cache release after scope and two frames")
	for file: String in DirAccess.get_files_at(folder):DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	var ok: bool=checks.all(func(row):return row.ok)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Synthetic loader tests exact file binding and resource lifetime. Actual imported pixels/maps and player input remain separate.","checks":checks},"\t"))
	print("PORTRAIT ATLAS CACHE: ","PASS" if ok else "FAIL"," checks=",checks.size());get_tree().quit(0 if ok else 1)
