extends Node
## V2 acceptance evidence: the layered sightline through a working shop —
## storefront glass, goods, counter, borrowed light, rear room, service
## doorway, darkness. Business hours, so the grilles are folded and the
## shop lamps are the light.
##     SHOT_DIR=<abs> godot --path game res://tests/VantryDepthShot.tscn

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
	# 12:30 — mid-day trade: every circuit returned, grilles folded.
	root.passage_finish.hours_director.apply_for_minute(750.0)
	await get_tree().create_timer(0.5).timeout
	cam = Camera3D.new()
	cam.fov = 66.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	if root.street_traffic != null:
		root.street_traffic.set_process(false)

	# Locksmith (west line, along 11.8..15.4): aisle -> glass -> bench ->
	# borrowed light -> the stock room's upper volume beyond.
	await _capture("01_locksmith_layers",
			[13.2, -52.2, 1.62], [2.0, -52.0, 3.00])
	# Inside HARDWARE PAINT, up over the drawer wall through its light.
	await _capture("02_hardware_depth",
			[10.0, -56.8, 1.55], [1.8, -56.8, 2.90])
	# The funeral parlour's chapel doorway on its own axis: drape, rail,
	# pews, catafalque.
	await _capture("03_chapel_doorway",
			[7.6, -60.3, 1.50], [2.4, -61.1, 1.20])
	# Oblique down the aisle: repeated borrowed lights over the fascias.
	await _capture("04_aisle_oblique",
			[15.6, -42.5, 1.60], [10.4, -57.5, 2.45])
	# THE TWO THINGS NOTHING HAS EVER LOOKED AT. Every station above aims
	# along the aisle or into a shopfront, which is how the lunette stayed
	# fully occluded by its own backing plate from V1 until 2026-08-16 and
	# how V4's crossing shaft could have shipped doing nothing. Three
	# separate defects this week hid behind an absent camera; two of them
	# were in this very structure.
	await _capture("05_crossing_lantern_up",
			[14.0, -51.6, 1.60], [14.0, -51.4, 9.60])
	# RESOLVED 2026-08-17, and the answer was in the camera, not the building.
	# This station used to sit at z 2.00 and return NIGHT SKY with a single
	# aisle pendant hanging in it, which was read as the nave vault failing to
	# roof this end of the hall. It was not. BuildingRoot's storey rule showed
	# a floor only within 1.75 m of its elevation, the whole Passage is
	# parented into F01, and 2.00 > 1.75 — so the camera culled the arcade out
	# from under itself. The pendant survived because props are root-owned and
	# were already exempted in the Passage; the vault was not. Every other
	# station here stands at 1.50..1.62 and never crossed the line, which is
	# why exactly one of six failed.
	#
	# The floor rule now carries the same Passage term the prop rule always
	# had, so this frame no longer depends on staying under 1.75. It is kept
	# at 1.60 anyway: that is where a 5'0" body's eye actually is, and a
	# station should photograph what a player can stand and see.
	# CeilingStreamingAudit.tscn holds the measurement and the paired frames.
	await _capture("06_south_gable_lunette",
			[14.0, -58.0, 1.60], [14.0, -64.5, 5.80])
	print("[VANTRY DEPTH SHOT] 6 frames saved")
	get_tree().quit(0)


func _capture(label: String, blender_eye: Array, blender_target: Array) -> void:
	cam.global_position = GameBoot.b2g(blender_eye)
	cam.look_at(GameBoot.b2g(blender_target))
	await get_tree().create_timer(1.25).timeout
	await RenderingServer.frame_post_draw
	var out_dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))


func _hide_capture_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for child in node.get_children():
		_hide_capture_ui(child)
