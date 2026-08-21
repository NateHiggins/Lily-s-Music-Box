extends Node
## FA-V1 Slice A: production-root lighting/channel migration proof.
##
## SHOT_DIR=<absolute> godot --path game --resolution 1280x720 \
##     res://tests/DreamFaunaStyleShot.tscn

const SEED_HEX := "f123456789abcdef"
const FAMILIES := [
	["buttons", "GildersButtons"],
	["tessellates", "Tessellates"],
	["anemones", "WineAnemones"],
	["ribbonettes", "Ribbonettes"],
	["loupe", "TheLoupe"],
]
const FAMILY_DISTANCE := {
	"GildersButtons": 0.9,
	"Tessellates": 2.1,
	"WineAnemones": 1.5,
	"Ribbonettes": 1.8,
	"TheLoupe": 2.4,
}

var root: DreamMazeRoot
var out_dir := ""
var failures := 0

func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty(): out_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _build()
	_feed_ecology()
	var first := _first_live_family()
	if first == null:
		printerr("[FAUNA STYLE SHOT] no live fauna")
		get_tree().quit(1); return
	_stage(first, false, 0.0)
	root.fauna.visible = false
	await _capture("00_control_a")
	await _capture("00_control_a_repeat")
	root.fauna.visible = true
	for family in FAMILIES:
		await _capture_family(str(family[0]), str(family[1]))
	print("[FAUNA STYLE SHOT] 22 frames, findings=%d census=%s" %
			[failures, root.fauna.census()])
	get_tree().quit(failures)

func _build() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	root.configure_dream({"case_id":"mina_caption_crisis",
			"profile_id":"mina_release_print", "window":{},
			"seed_hex":SEED_HEX, "maze_revision":1, "outcome":"",
			"night_index":3, "spawn_anchor":1})
	add_child(root)
	await get_tree().process_frame
	root.set_physics_process(false)
	root.player.set_physics_process(false)
	root.pursuer.set_physics_process(false)
	root.pursuer.visible = false
	root.fauna.set_physics_process(false)
	root.player.camera.make_current()

func _feed_ecology() -> void:
	root.player.set_lamp_enabled(true)
	root.player.pin_lamp_gutter_for_proof(1.0)
	root.player.set("_lamp_phase", 0.0)
	root.player.set("_lamp_phase_total", 0.0)
	root.player.call("_advance_lamp", 0.0)
	for _i in 24: root.call("_update_exposure", 0.25)
	for _i in 16: root.fauna.advance_fixed()
	root.fauna.refresh()
	root.call("_collect_molten_materials")
	root.call("_update_molten")

func _first_live_family() -> MultiMeshInstance3D:
	for family in FAMILIES:
		var batch := root.fauna.get_node(str(family[1])) as MultiMeshInstance3D
		if batch != null and batch.multimesh.instance_count > 0: return batch
	return null

func _capture_family(slug: String, node_name: String) -> void:
	var batch := root.fauna.get_node(node_name) as MultiMeshInstance3D
	if batch == null or batch.multimesh.instance_count == 0:
		failures += 1
		printerr("[FAUNA STYLE SHOT] absent family "+node_name)
		return
	_show_only(batch)
	_stage(batch, false, 0.0)
	batch.visible = false
	await _capture("01_%s_hidden_dark" % slug)
	batch.visible = true
	await _capture("02_%s_dark" % slug)
	_stage(batch, true, 1.65)
	await _capture("03_%s_beam_edge" % slug)
	_stage(batch, true, 0.0)
	await _capture("04_%s_full_beam" % slug)

func _show_only(wanted: MultiMeshInstance3D) -> void:
	root.fauna.visible = true
	for child in root.fauna.get_children(): child.visible = child == wanted

func _stage(batch: MultiMeshInstance3D, lamp_on: bool,
		edge_offset: float) -> void:
	var instance_transform := batch.multimesh.get_instance_transform(0)
	var target := batch.global_transform * instance_transform.origin
	var world_basis := batch.global_transform.basis * instance_transform.basis
	# The Loupe eye and the other families' authored presentation face +Z.
	var front := (world_basis * Vector3(0.0, 0.0, 1.0)).normalized()
	var right := (world_basis * Vector3.RIGHT).normalized()
	var distance := float(FAMILY_DISTANCE.get(str(batch.name), 2.1))
	# Place the eye, not the player's feet, at the proof distance. The production
	# camera is parented at standing-eye height, so omitting this compensation
	# turns a close silhouette inspection into a distant overhead view.
	root.player.global_position = target + front * distance \
			- root.player.camera.position
	root.player.camera.look_at(target + Vector3(0.0, 0.18, 0.0) + right * edge_offset,
			Vector3.UP)
	root.player.set_lamp_enabled(lamp_on)
	root.player.pin_lamp_gutter_for_proof(1.0)
	root.player.set("_lamp_phase", 0.0)
	root.player.set("_lamp_phase_total", 0.0)
	root.player.call("_advance_lamp", 0.0)
	# The production service set intentionally trails the eye. Settle that real
	# hand owner onto the new proof pose before the root samples its lamp cone;
	# otherwise a camera cut mislabeled the previous aim as this frame's beam.
	root.player.call("_carry_service_light", 1.0)
	root.call("_update_molten")

func _capture(file_name: String) -> void:
	for _frame in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(file_name+".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		failures += 1
		printerr("[FAUNA STYLE SHOT] failed %s (%d)" % [path,error])
	else:
		print("[FAUNA STYLE SHOT] saved "+path)
