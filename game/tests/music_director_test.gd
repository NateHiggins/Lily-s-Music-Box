extends Node
## Headless regression for catalog integrity, playback, and resident rewards.


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var scene := load("res://scenes/building/orison_root.tscn") as PackedScene
	var building := scene.instantiate()
	add_child(building)
	await get_tree().process_frame
	await get_tree().process_frame
	var director := get_tree().get_first_node_in_group("music_director") \
			as OrisonMusicDirector
	assert(director != null)
	assert(director.catalog.get("tracks", {}).size() == 36)
	assert(director.catalog.get("residents", {}).size() == 18)
	assert(director.play_track("am_maintenance", "TEST"))
	assert(director.current_track_id == "am_maintenance")
	var unlocked := director.unlock_resident_music("mina_vale")
	assert(unlocked == 3)
	assert("mina_s_midday_quest" in RealityState.data.music_library)
	assert(director.play_for_resident("mina_vale"))
	assert(director.try_music_conversation("mina_vale"))
	director.stop_radio()
	building.queue_free()
	print("[MUSIC TEST] 36 tracks, 18 residents, playback and rewards verified")
	get_tree().quit(0)
