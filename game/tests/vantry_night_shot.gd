extends Node
## What a closed arcade looks like at three in the morning.
##
##     SHOT_DIR=<abs> godot --path game res://tests/VantryNightShot.tscn
##     SHOT_DIR=<abs> VANTRY_SECURITY_OFF=1 godot --path game \
##             res://tests/VantryNightShot.tscn      # the control
##
## Every existing arcade station photographs trading hours: VantryDepthShot
## forces 12:30 so the grilles are folded and the shop lamps are the light.
## Nothing in the repo had ever pointed a camera at the state the shops are
## actually in for most of the game — shut, grilles drawn, after 02:00 — which
## is how "the interiors are dead behind their grilles" stayed an impression
## rather than a frame.
##
## Owner ruling 2026-08-17: "light the closed shops as realism determines. when
## instructions collide, favor realism." The collision was real — HANDOFF PS6
## records canonical 03:00 as "ten dark shop circuits" — and realism won it.
##
## Realism did not mean a uniform bulb per shop. It meant what each trade would
## leave burning, which is graded by what is inside worth watching: the
## pawnbroker and the druggist keep a real light, the laundry and the cobbler
## keep almost nothing, and the fascia goes out everywhere because a fascia is
## advertising. The table and its reasoning live in
## `passage_hours_director.gd`; these frames are whether it reads.
##
## The control reproduces the pre-ruling state exactly, by putting the security
## fixtures back out after the hours director has run.

const SECURITY_PREFIX := "SITE_SHOP_IN0_"

var root: Node3D
var cam: Camera3D


func _ready() -> void:
	# A true 03:00 sky, not the canonical-test pin: this frame is about how
	# dark the arcade is, so the sky has to be the real one.
	OS.set_environment("DAYNIGHT_FORCE", "03:00")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	_hide_capture_ui(get_tree().root)
	# 03:00 — after 02:00, so the grilles are drawn and every shop but
	# HARDWARE PAINT is shut.
	root.passage_finish.hours_director.apply_for_minute(180.0)
	await get_tree().create_timer(0.5).timeout
	var control := OS.get_environment("VANTRY_SECURITY_OFF") == "1"
	if control:
		_extinguish_security()
	cam = Camera3D.new()
	cam.fov = 66.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	if root.street_traffic != null:
		root.street_traffic.set_process(false)

	var tag := "_CONTROL" if control else ""
	# EAST line, x 17.95. The two that keep a real light.
	await _capture("01_pawnbroker_0.35" + tag,
			[14.5, -53.30, 1.60], [18.0, -53.30, 2.30])
	await _capture("02_druggist_0.30" + tag,
			[14.5, -46.55, 1.60], [18.0, -46.55, 2.30])
	# WEST line, x 10.05. The vigil light, and the dimmest shop in the arcade.
	await _capture("03_funeral_vigil_0.22" + tag,
			[13.5, -61.70, 1.60], [9.8, -61.70, 2.30])
	await _capture("04_cobbler_0.12" + tag,
			[13.5, -47.60, 1.60], [9.8, -47.60, 2.30])
	# The whole east line oblique: the point of grading them is the rhythm of
	# bright, dim and dark fronts down the aisle, which no single shop shows.
	await _capture("05_east_line_rhythm" + tag,
			[15.4, -40.5, 1.60], [16.6, -60.0, 2.20])
	# HARDWARE PAINT, the night-service trade, still fully lit and open. It is
	# the reference the security lights must not be confused with.
	await _capture("06_hardware_night_service" + tag,
			[13.5, -56.70, 1.60], [9.8, -56.70, 2.30])
	print("[VANTRY NIGHT SHOT] 6 frames saved%s" %
			("  (CONTROL: security lights out)" if control else ""))
	get_tree().quit(0)


## Put the security fixtures back out, reproducing the state before the owner's
## ruling. Runs AFTER the hours director so it overrides whatever it decided.
func _extinguish_security() -> void:
	var n := 0
	for child in root.get_children():
		var name := String(child.name)
		if not name.begins_with(SECURITY_PREFIX):
			continue
		var fixture := child as LightFixtureProp
		if fixture == null:
			continue
		fixture.set_state_gain(0.0)
		fixture.set_powered(false)
		n += 1
	print("[VANTRY NIGHT SHOT] CONTROL: %d security fixtures extinguished" % n)


func _capture(label: String, blender_eye: Array, blender_target: Array) -> void:
	cam.global_position = GameBoot.b2g(blender_eye)
	cam.look_at(GameBoot.b2g(blender_target))
	await get_tree().create_timer(1.25).timeout
	await RenderingServer.frame_post_draw
	var out_dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	print("   saved %s" % label)


func _hide_capture_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for child in node.get_children():
		_hide_capture_ui(child)
