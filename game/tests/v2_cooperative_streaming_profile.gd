extends "res://tests/v2_played_streaming_profile.gd"
## Same played route; explicit scheduling control, not runtime qualification.
func _prepare_player_start() -> void:
	super._prepare_player_start()
	var enabled:=OS.get_environment("V2_COOPERATIVE_FITTING")!="0"
	world.passage_region.residency.cooperative_fitting=enabled
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("configuration.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","cooperative_fitting":enabled,"route":"V2PlayedStreamingProfile unchanged inherited route","scope":"Scheduling control only; startup fitting remains synchronous."},"\t"))
