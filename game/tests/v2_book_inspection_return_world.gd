extends "res://tests/v2_nook_world_profile.gd"
## INERT played-world diagnostic of Space return and next-click release.
func _inspect_stock_review(book: Node3D) -> void:
	# The parent just read back/compressed a PNG. Drain that interval while
	# still capture-excluded before delivering the measured Space event.
	for frame in 3:await get_tree().process_frame
	profile_phase="nook_return_hand"
	var space:=InputEventKey.new();space.keycode=KEY_SPACE;space.physical_keycode=KEY_SPACE;space.pressed=true
	player._unhandled_input(space)
	space=InputEventKey.new();space.keycode=KEY_SPACE;space.physical_keycode=KEY_SPACE;space.pressed=false;player._unhandled_input(space)
	if not _require(not player.inspecting() and player._grab.holding_pickup() and player._grab.target.part==book,"Space returns world binding to original hand"):return
	_require(book._held and book.freeze,"returned world binding retains owner hand permission")
	_require(player.get_collision_exceptions().has(book) and book.get_collision_exceptions().has(player),"returned world binding excludes only carrier")
	for frame in 110:await get_tree().process_frame
	var error: float=(book.global_transform*book.pickup_centre()).distance_to(player.camera.global_transform*Vector3(.17,-.16,-.48))
	_require(error<.01,"returned world binding reaches swept hand pose")
	_require(book.shelf.valid_library(book.shelf.library_snapshot()),"returned world binding retains valid durable snapshot")
	profile_phase="nook_return_capture_excluded"
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("returned_world_book.png"))
	for frame in 3:await get_tree().process_frame
	profile_phase="nook_return_release"
	_click_library()
	_require(not player._grab.active() and not book._held and not book.freeze,"next primary releases returned world binding")
	_require(not player.get_collision_exceptions().has(book) and not book.get_collision_exceptions().has(player),"world primary release restores carrier collision")
	for frame in 40:await get_tree().process_frame
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("return.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","stock_id":book.stock_id,"held_error_m":error,"failures":failures},"\t"))
