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

func _prepare_lighting_context() -> bool:
	# Reuse the existing untimed prefetch for a material-cache negative control.
	var before: Dictionary=world.passage_region.residency.snapshot()
	var drop:=OS.get_environment("V2_DROP_SHADER_AFTER_TIMED")=="1"
	var released:=false
	if drop:
		var reference: WeakRef=_drop_kept_shader_material()
		released=reference!=null and reference.get_ref()==null
		_require(released,"untimed material-cache release frees its dormant material")
	var ok: bool=await super._prepare_lighting_context()
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("untimed_shader_control.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"After timed traces freeze; same required lighting prefetch, not additional frame samples.","drop_requested":drop,"material_released":released,"before":before,"after":world.passage_region.residency.snapshot()},"\t"))
	return ok
