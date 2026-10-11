extends Node
## Isolated software-render review only; no world or gameplay acceptance.
func _ready() -> void:
	RealityState.persistence_enabled = false; RealityState.reset_campaign_for_tests()
	var finish := preload("res://scripts/building/v2_embedded_surface_stock.gd").new(); add_child(finish)
	var catalog := ArcadeCatalog.load_catalog()
	var directory := OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	for identity: String in ["mystery_serial","farm_and_market"]:
		var entry: Dictionary = {}
		for candidate: Dictionary in catalog.cabinets:
			if str(candidate.claimed_genre) == identity: entry = candidate; break
		var machine := ArcadeMachine.new();add_child(machine)
		if entry.is_empty() or not machine.boot(entry,ArcadeCatalog.DIR): get_tree().quit(1); return
		machine.set_live(true)
		for frame in 8:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		machine.get_texture().get_image().save_png(directory.path_join("embedded_"+identity+".png"))
		machine.scope_texture().get_image().save_png(directory.path_join("phosphor_"+identity+".png"))
		machine.unload();machine.free()
	finish.free()
	print("INERT EMBEDDED SURFACE PREVIEW: two unchanged source software worlds")
	get_tree().quit(0)
