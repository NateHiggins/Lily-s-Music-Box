extends Node
## In-situ contact proof for every authored artwork. One image is captured per
## piece, from its front at human eye level, plus a machine-readable manifest.
## ART_SHOT_DIR=<absolute directory> is optional.

const GROUPS := ["character_memories", "character_wall_art", "hallway_art"]

var building: Node3D
var camera: Camera3D
var output_dir := ""
var manifest: Array[Dictionary] = []


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	output_dir = OS.get_environment("ART_SHOT_DIR")
	if output_dir == "":
		output_dir = OS.get_user_data_dir().path_join("art_placement_audit")
	DirAccess.make_dir_recursive_absolute(output_dir)
	building = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(building)
	for child in building.get_children():
		if child is CanvasLayer:
			child.visible = false
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	building.show_all_floors = true
	Conductor.infection = 0.0
	if building.sanity:
		building.sanity.stand_down()
		building.sanity.enabled = false
	if building.fourth_wall:
		building.fourth_wall.force_finish()
	camera = Camera3D.new()
	camera.fov = 56.0
	add_child(camera)
	camera.make_current()
	# A restrained on-camera bounce makes the frame readable while preserving
	# the installed room lighting and its color cast.
	var bounce := OmniLight3D.new()
	bounce.light_color = Color(0.86, 0.91, 1.0)
	bounce.light_energy = 0.42
	bounce.omni_range = 3.0
	bounce.shadow_enabled = false
	camera.add_child(bounce)

	var pieces: Array[Node] = []
	for group_name in GROUPS:
		pieces.append_array(get_tree().get_nodes_in_group(group_name))
	pieces.sort_custom(func(a: Node, b: Node) -> bool: return a.name < b.name)
	for piece in pieces:
		await _capture_piece(piece)
	var file := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"count": manifest.size(), "pieces": manifest}, "  "))
	print("[ART AUDIT] saved %d in-scene views to %s" % [manifest.size(), output_dir])
	get_tree().quit(0)


func _capture_piece(piece: Node3D) -> void:
	var front := piece.global_basis.z.normalized()
	var target := piece.global_position
	var tabletop: bool = piece.get("tabletop") == true
	var distance := 1.10 if tabletop else 1.65
	var eye := target + front * distance
	# A tabletop portrait is viewed from slightly above; wall pieces retain
	# enough room context to judge relationship, centering, and collisions.
	if tabletop:
		eye.y += 0.30
		target.y -= 0.03
	if building.player:
		building.player.global_position = eye
	camera.global_position = eye
	camera.look_at(target, Vector3.UP)
	await get_tree().create_timer(0.18).timeout
	await RenderingServer.frame_post_draw
	var safe_name := str(piece.name).to_lower().validate_filename()
	var filename := "%02d_%s.png" % [manifest.size() + 1, safe_name]
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(filename))
	manifest.append({
		"name": str(piece.name),
		"art_id": str(piece.get("art_id")),
		"collection": str(piece.get("collection")),
		"tabletop": tabletop,
		"position": [piece.global_position.x, piece.global_position.y, piece.global_position.z],
		"image": filename,
	})
	print("[ART AUDIT] ", filename)
