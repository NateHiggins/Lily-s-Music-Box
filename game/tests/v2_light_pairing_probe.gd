extends Node3D
## INERT renderer diagnostic. Console phase markers locate engine errors;
## successful script completion alone does not mean clean renderer teardown.
var cases: Array[Dictionary] = []
var directory := ""
@export var selected := ""

func _ready() -> void:
	_run.call_deferred()

func settle() -> void:
	for index in 6: await RenderingServer.frame_post_draw

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty(): get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	var camera := Camera3D.new(); add_child(camera); camera.make_current()
	Engine.max_fps = 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pairing-case="): selected = argument.trim_prefix("--pairing-case=")
	for kind in ["unchanged", "mesh_layer", "multimesh_layer", "light_mask", "hidden_layer", "preconfigured_layer"]:
		if not selected.is_empty() and selected != kind: continue
		print("PAIRING BEGIN ", kind)
		var owner := Node3D.new(); add_child(owner)
		var draw: GeometryInstance3D
		if kind == "multimesh_layer":
			var batch := MultiMeshInstance3D.new()
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			batch.multimesh.mesh = BoxMesh.new()
			batch.multimesh.instance_count = 1
			batch.multimesh.set_instance_transform(0, Transform3D.IDENTITY)
			draw = batch
		else:
			var mesh := MeshInstance3D.new(); mesh.mesh = BoxMesh.new(); draw = mesh
		draw.position.z = -2
		if kind == "preconfigured_layer": draw.layers = 2
		owner.add_child(draw)
		var lamp := SpotLight3D.new()
		lamp.spot_range = 8; lamp.light_cull_mask = 1 if kind != "light_mask" else 3
		lamp.shadow_enabled = true
		owner.add_child(lamp)
		await settle()
		if kind == "hidden_layer": draw.hide(); await settle()
		if kind in ["mesh_layer", "multimesh_layer", "hidden_layer"]: draw.layers = 2
		elif kind == "light_mask": lamp.light_cull_mask = 2
		if kind == "hidden_layer": draw.show()
		await settle()
		cases.append({"name":kind,"geometry_layer":draw.layers,"light_mask":lamp.light_cull_mask})
		owner.queue_free()
		await settle()
		print("PAIRING END ", kind)
	if selected.is_empty() or selected == "native_world_carrier": await native_carrier()
	FileAccess.open(directory.path_join("observations.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","cases":cases,"note":"Inspect original stderr between console phase markers; no clean renderer or runtime-contract verdict from these observations alone."},"\t"))
	get_tree().quit()

func native_carrier() -> void:
	# Exercise the actual world adapter with its original Player-owned lamp,
	# native layer2 stock, current hand and full asynchronous flight placement.
	print("PAIRING BEGIN native_world_carrier")
	RealityState.persistence_enabled = false; RealityState.reset_campaign_for_tests()
	var player := PlayerController.new(); add_child(player)
	player.set_physics_process(false); player.camera.make_current()
	var carrier := preload("res://scripts/device/companion_world_carrier.gd").new()
	await carrier.setup(player, player.camera, null)
	player.carried_device = carrier
	await settle()
	cases.append({"name":"native_world_carrier","ready":carrier.world_ready})
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("native_carrier.png"))
	carrier.queue_free(); player.queue_free()
	await settle()
	print("PAIRING END native_world_carrier")
