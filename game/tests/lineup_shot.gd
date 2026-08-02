extends Node
## Renders the debug cast lineup: every resident teleported into lobby
## ranks exactly as building_debug's "line up in lobby" button does, one
## frame, SHOT_DIR/cast_lineup.png. The inspection parade, photographed.

var root: Node3D


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	for c in root.get_children():
		if c is CanvasLayer:
			c.visible = false
	_run()


func _run() -> void:
	await get_tree().create_timer(1.2).timeout
	if root.resident_routines:
		root.resident_routines.inspection_hold = true
	var residents := get_tree().get_nodes_in_group("resident_placeholders")
	residents.sort_custom(func(a, b):
		return str(a.get("resident_id")) < str(b.get("resident_id")))
	for i in residents.size():
		var resident: Node3D = residents[i]
		resident.global_position = GameBoot.b2g([
				-4.4 + (i % 9) * 1.1, -8.7 + (i / 9) * 1.3, 0.0])
		resident.rotation.y = PI
	var cam := Camera3D.new()
	cam.fov = 68
	add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(0.0, 1.9, 4.6)
	cam.look_at(Vector3(0.0, 1.0, 8.2))
	if root.player:
		root.player.global_position = Vector3(0.0, 1.7, 5.4)
	var light := OmniLight3D.new()
	light.light_energy = 5.0
	light.omni_range = 16.0
	light.shadow_enabled = false
	light.position = Vector3(0.0, 2.6, 6.0)
	add_child(light)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = OS.get_user_data_dir()
	get_viewport().get_texture().get_image().save_png(dir + "/cast_lineup.png")
	print("saved ", dir, "/cast_lineup.png")
	get_tree().quit(0)
