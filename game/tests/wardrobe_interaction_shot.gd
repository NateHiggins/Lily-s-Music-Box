extends Node
## Paired production evidence for the generator/runtime wardrobe leaf split.
##     SHOT_DIR=<abs> godot --path game res://tests/WardrobeInteractionShot.tscn

var root: Node3D
var cam: Camera3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	_hide_capture_ui(get_tree().root)
	var wardrobe: BakedFurnitureInteraction
	for owner in get_tree().get_nodes_in_group("baked_furniture_interactions"):
		if owner is BakedFurnitureInteraction \
				and owner.record_id == "4A_w0_wardrobe":
			wardrobe = owner
			break
	if wardrobe == null:
		push_error("Wardrobe shot cannot find 4A_w0_wardrobe")
		get_tree().quit(1)
		return
	cam = Camera3D.new()
	cam.fov = 61.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	cam.global_position = wardrobe.to_global(Vector3(0.0, 1.30, -2.05))
	cam.look_at(wardrobe.to_global(Vector3(0.0, 1.02, -0.18)))
	root._apply_visibility(cam.global_position)
	await _capture("01_wardrobe_closed")
	wardrobe.interact(root.player)
	await get_tree().create_timer(0.62).timeout
	await _capture("02_wardrobe_open")
	print("[WARDROBE SHOT] paired frames saved; open=%s left=%.1f right=%.1f" % [
			wardrobe._wardrobe_open,
			rad_to_deg(wardrobe._wardrobe_left_leaf.rotation.y),
			rad_to_deg(wardrobe._wardrobe_right_leaf.rotation.y)])
	get_tree().quit(0)


func _capture(label: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var out_dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var error := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	if error != OK:
		push_error("Wardrobe shot failed: %s" % label)


func _hide_capture_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for child in node.get_children():
		_hide_capture_ui(child)
