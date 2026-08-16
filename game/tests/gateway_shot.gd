extends Node
## THROWAWAY (2026-08-16): current-state evidence for the arcade-gate frame /
## continuous street facade proposal. Aimed street-level and elevated views of
## the Vantry gate and the play-area perimeter. Real window, no --headless.

var root: Node3D
var cam: Camera3D
var _dir := ""

# [name, pos (world), look (world)] — street plane is world z=28.316,
# stage bounds x -20.10..+20.60, portal x 11..17 centre 14.
const VIEWS := [
	["01_gate_head_on", Vector3(14.0, 1.6, 21.5), Vector3(14.0, 3.0, 28.3)],
	["02_gate_oblique_west", Vector3(5.5, 1.6, 26.2), Vector3(16.5, 3.0, 28.8)],
	["03_south_frontage_wide", Vector3(0.0, 2.6, 13.0), Vector3(14.0, 2.5, 28.3)],
	["04_from_gate_to_orison", Vector3(14.0, 1.6, 27.2), Vector3(-2.0, 5.0, 5.0)],
	["05_east_end_join", Vector3(11.0, 1.6, 23.5), Vector3(20.6, 2.5, 27.5)],
	["06_west_end_join", Vector3(-9.0, 1.6, 23.5), Vector3(-20.1, 2.8, 27.0)],
	["07_high_oblique", Vector3(-7.0, 9.0, 16.0), Vector3(14.0, 2.0, 28.3)],
	["08_pavement_east_sweep", Vector3(19.0, 1.6, 26.8), Vector3(-15.0, 2.5, 26.0)],
]


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_dir = OS.get_environment("SHOT_DIR")
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	_hide_overlays(root)
	if root.sanity:
		root.sanity.stand_down()
		root.sanity.enabled = false
	if root.fourth_wall:
		root.fourth_wall.force_finish()
	cam = Camera3D.new()
	cam.fov = 68
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	for v in VIEWS:
		await _grab(v[1], v[2], str(v[0]))
	get_tree().quit(0)


func _hide_overlays(node: Node) -> void:
	for c in node.get_children():
		if c is CanvasLayer:
			c.visible = false
		elif c is Label3D and node.is_in_group("resident_placeholders"):
			c.visible = false
		_hide_overlays(c)


func _grab(pos: Vector3, look: Vector3, shot_name: String) -> void:
	if root.player:
		root.player.global_position = pos
	cam.global_position = pos
	cam.look_at(look)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_dir, shot_name]
	img.save_png(path)
	print("saved ", path)
