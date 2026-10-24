extends "res://tests/v2_nook_world_profile.gd"
## INERT matched actual-world pickup/inspection/first-cover-opening diagnostic.
class PrintHand extends "res://tests/v2_readable_library_bench.gd":
	func _ready() -> void:pass

func _init() -> void:route_label="V2 BOOK PRINT WORLD PROFILE"

func _inspect_stock_review(selected: Node3D) -> void:
	if not _require(selected!=null and is_zero_approx(selected.opening),"first gathering remains closed before opening input"):return
	if not _require(player.inspecting(),"Space supports selected book for opening"):return
	var prepared_before_open:=bool(selected.get("_print_ready"))
	var hand:=PrintHand.new();hand.player=player;add_child(hand)
	var point: Vector3=selected.left.to_global(Vector3(float(selected.construction.width)*.7,float(selected.construction.height)*.7,float(selected.construction.thickness)*.5))
	profile_phase="print_acquire_excluded"
	if not _require(await hand.cursor_at(point),"free cursor reaches native gathering"):hand.free();return
	hand.click()
	if not _require(player._grab.active() and player._grab.target.part==selected.left,"primary grips actual gathering"):hand.free();return
	profile_phase="print_first_open"
	if not _require(await hand.hinge(PI),"mouse opens physical gathering"):hand.free();return
	hand.click()
	for frame in 120:await get_tree().process_frame
	profile_phase="print_open_still"
	for frame in 120:await get_tree().process_frame
	profile_phase="print_capture_excluded"
	var zoom:=InputEventMouseButton.new();zoom.pressed=true;zoom.button_index=MOUSE_BUTTON_WHEEL_UP;zoom.factor=12.;player._unhandled_input(zoom)
	await hand.capture("world_reading_spread")
	var vertices:=0;var triangles:=0
	for printed: Dictionary in selected._print_surfaces:
		for surface in RenderingServer.mesh_get_surface_count(printed.mesh):
			var arrays:=RenderingServer.mesh_surface_get_arrays(printed.mesh,surface)
			vertices+=arrays[Mesh.ARRAY_VERTEX].size();triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("print.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","stock_id":selected.stock_id,"title_id":selected.title_id,"opening":selected.opening,"vertices":vertices,"triangles":triangles,"prepared_before_open":prepared_before_open,"preparation_ms":selected.get_meta("print_preparation_ms",null),"preparation_max_slice_ms":selected.get_meta("print_preparation_max_slice_ms",null),"preparation_latency_ms":selected.get_meta("print_preparation_latency_ms",null),"failures":failures},"\t"))
	hand.free()
