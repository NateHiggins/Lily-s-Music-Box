extends Node
## LC-6E Forward+ proof: one production Mina Dream root, its existing case
## clock, wall materials, exposure field, camera and service lamp.

const SEED_HEX := "f123456789abcdef"
const Lifecycle := preload("res://scripts/dream/dream_organelle_lifecycle.gd")

var root: DreamMazeRoot
var out_dir := ""
var failures := 0


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_user_data_dir().path_join("dream_incarnation_lifecycle_lc6e")
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _build()
	Engine.time_scale = 0.0
	await _stage_and_capture(Lifecycle.Stage.FOLDED, "00_folded_control_a")
	await _stage_and_capture(Lifecycle.Stage.FOLDED, "00_folded_control_b")
	await _stage_and_capture(Lifecycle.Stage.BUD, "01_bud_perfusion")
	await _stage_and_capture(Lifecycle.Stage.JUVENILE, "02_juvenile_calibration")
	await _stage_and_capture(Lifecycle.Stage.MATURE, "03_mature_control_a")
	await _stage_and_capture(Lifecycle.Stage.MATURE, "03_mature_control_b")
	await _stage_and_capture(Lifecycle.Stage.EXCHANGE, "04_exchange_gold_fold")
	await _stage_and_capture(Lifecycle.Stage.SENESCENT, "05_senescent_mineral")
	await _stage_and_capture(Lifecycle.Stage.SHED, "06_shed_wine_membrane")
	await _stage_and_capture(Lifecycle.Stage.STAIN, "07_stain_control_a")
	await _stage_and_capture(Lifecycle.Stage.STAIN, "07_stain_control_b")
	Engine.time_scale = 1.0
	print("[LC6E SHOT] production incarnation lifecycle -> %s" % out_dir)
	get_tree().quit(failures)


func _build() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	root.configure_dream({"case_id": "mina_caption_crisis",
			"profile_id": "mina_release_print", "window": {},
			"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
			"night_index": 2, "spawn_anchor": 1})
	add_child(root)
	await get_tree().process_frame
	root.set_physics_process(false)
	root.player.set_physics_process(false)
	root.player.set_process(false)
	root.pursuer.set_physics_process(false)
	root.pursuer.visible = false
	root.fauna.visible = false
	root.player.camera.make_current()
	var room: Dictionary = root.rooms.room_at_key(str(root.get("_here_key")))
	var rect: Array = room.rect
	var target := Vector3(float(rect[2]) - 0.11, 1.42,
			(float(rect[1]) + float(rect[3])) * 0.5)
	root.player.global_position = target + Vector3(-1.8, 0.0, 0.0) \
			- root.player.camera.position
	root.player.camera.look_at(target, Vector3.UP)
	root.exposure.pin_irradiance_for_proof(0.72)
	root.exposure.upload(root.get("_exposure_tex"))
	root.player.set_lamp_enabled(true)
	root.player.pin_lamp_gutter_for_proof(0.72)
	root.player.flashlight.visible = true
	root.player.call("_advance_lamp", 0.0)
	root.player.call("_carry_service_light", 1.0)
	root.call("_collect_molten_materials")


func _stage_and_capture(stage: int, label: String) -> void:
	var phases := [0.01, 0.08, 0.20, 0.44, 0.68, 0.81, 0.92, 0.98]
	root.run_elapsed_s = root.run_cap_s * float(phases[stage])
	root.call("_update_molten")
	var actual := DreamIncarnationProfile.lifecycle_stage_at(
			root.run_elapsed_s, root.run_cap_s)
	if actual != stage:
		failures += 1
		printerr("[LC6E SHOT] staged %s but classified %s" % [
				Lifecycle.stage_name(stage), Lifecycle.stage_name(actual)])
	for _i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_dir.path_join(label + ".png"))
	if error != OK:
		failures += 1
		printerr("[LC6E SHOT] failed %s" % label)
	else:
		print("[LC6E SHOT] %s %dx%d" % [label,
				image.get_width(), image.get_height()])
