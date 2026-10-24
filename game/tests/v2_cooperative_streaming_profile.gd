extends "res://tests/v2_played_streaming_profile.gd"
## Same played route; explicit scheduling control, not runtime qualification.
func _prepare_player_start() -> void:
	super._prepare_player_start()
	var enabled:=OS.get_environment("V2_COOPERATIVE_FITTING")!="0"
	world.passage_region.residency.cooperative_fitting=enabled
	if OS.get_environment("V2_KEEP_CANOPY_SHADER_WARM")=="0":world.passage_region.residency._canopy_shader_material=null
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("configuration.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","cooperative_fitting":enabled,"kept_shader_materials":world.passage_region.residency.snapshot().kept_shader_materials,"route":"V2PlayedStreamingProfile unchanged inherited route","scope":"Scheduling control only; startup fitting remains synchronous."},"\t"))

func _drop_kept_shader_material() -> WeakRef:
	var residency: Node=world.passage_region.residency
	if residency._canopy_shader_material==null:return null
	var reference: WeakRef=weakref(residency._canopy_shader_material)
	residency._canopy_shader_material=null
	return reference

func _drop_kept_portrait_atlas() -> WeakRef:
	var cache: RefCounted=world.passage_region.portrait_atlas_cache
	if cache._texture==null:return null
	var reference: WeakRef=weakref(cache._texture)
	cache.clear()
	return reference

func _portrait_atlas_observation() -> Dictionary:
	var texture: Texture2D=world.passage_region.portrait_atlas_cache._texture
	if texture==null:return {}
	var image:=texture.get_image()
	if image==null:return {}
	return {"width":image.get_width(),"height":image.get_height(),"format":image.get_format(),"mipmaps":image.has_mipmaps(),"image_bytes":image.get_data().size()}

func _prepare_lighting_context() -> bool:
	# Reuse the existing untimed prefetch for a material-cache negative control.
	var before: Dictionary=world.passage_region.residency.snapshot()
	var drop:=OS.get_environment("V2_DROP_SHADER_AFTER_TIMED")=="1"
	var released:=false
	var drop_atlas:=OS.get_environment("V2_DROP_PORTRAIT_ATLAS_AFTER_TIMED")=="1"
	var atlas_released:=false
	if drop:
		var reference: WeakRef=_drop_kept_shader_material()
		released=reference!=null and reference.get_ref()==null
		_require(released,"untimed material-cache release frees its dormant material")
	if drop_atlas:
		var reference: WeakRef=_drop_kept_portrait_atlas()
		atlas_released=reference!=null and reference.get_ref()==null
		_require(atlas_released,"untimed atlas-cache release frees its dormant texture")
	var ok: bool=await super._prepare_lighting_context()
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("untimed_shader_control.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"After timed traces freeze; same required lighting prefetch, not additional frame samples.","drop_requested":drop,"material_released":released,"before":before,"after":world.passage_region.residency.snapshot()},"\t"))
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("untimed_atlas_control.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"After timed traces freeze; existing lighting prefetch only.","drop_requested":drop_atlas,"texture_released":atlas_released,"before":before,"after":world.passage_region.residency.snapshot(),"atlas":_portrait_atlas_observation()},"\t"))
	return ok

func _verify_no_halos() -> void:
	await super._verify_no_halos()
	if OS.get_environment("V2_VERIFY_PORTRAITS")!="1":return
	# Untimed material/pixel/standing-camera diagnostics after actual input routes.
	player.set_physics_process(false)
	world.service_set_carrier.set_capture_hidden(true)
	var validator:=preload("res://tests/orison_v2_photo_portraits_test.gd").new()
	validator.batch_mode=true;validator.capture_enabled=true;add_child(validator)
	var result: Dictionary=await validator.validate_in_world(world)
	_require(result.failures.is_empty(),"resident portraits retain geometry, maps, complete mip pixels and supported detail views")
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("portrait_checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Untimed source/map/pixel and standing-view diagnostic; no continuous shop route or runtime_contract.","result":result},"\t"))
	validator.queue_free()
