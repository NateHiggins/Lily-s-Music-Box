extends Node
## Two-face production evidence. TITLE_SCREEN_SILENT suppresses playback only;
## the exact imported streams, timing labels and automatic alternation remain.


func _ready() -> void:
	OS.set_environment("TITLE_SCREEN_SILENT", "1")
	var screen = load(
			"res://scenes/ui/title_screen.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(1.2).timeout
	await _capture("01_escapement_failure")
	screen._start_track(1, true)
	await get_tree().create_timer(0.4).timeout
	await _capture("02_original_session")
	print("[TITLE SHOT] two full-record faces saved")
	get_tree().quit(0)


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var out_dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
