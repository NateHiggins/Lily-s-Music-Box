extends Node
const Runtime = preload("res://scenes/building/orison_v2_runtime.tscn")
var directory: String
var world: OrisonV2RuntimeRoot
var draws := {}
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.configure_date(1928,11,10,20*60)
	world = Runtime.instantiate()
	add_child(world)
	if world.startup_failed:
		get_tree().quit(2)
		return
	var player := world.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	await get_tree().create_timer(.5).timeout
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.service_set_carrier._pass_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_hide_canvases(world)
	var air: Node3D = world.get_node("LampAtmosphere")
	if air.receivers.receivers.size() != 1:
		push_error("Expected the one source-authored 3B glass receiver")
		get_tree().quit(2)
		return
	var receiver: MeshInstance3D = air.receivers.receivers.values()[0][0].get_ref()
	var center := receiver.to_global(receiver.get_aabb().get_center())
	player.camera.global_position = center + Vector3(.18,.10,.24)
	player.camera.near = .015
	player.camera.look_at(center)
	player.camera.make_current()
	player.set_lamp_enabled(true)
	air.driver.state = preload("res://scripts/lamp/lamp_optical_state.gd").new()
	air.driver.state.configure(0x28A11CE,true)
	air.driver.state.advance(2.0)
	air.driver.apply_output()
	player.flashlight.global_position = player.camera.global_position + Vector3(-.06,-.03,0)
	player.flashlight.look_at(center)
	for record: Array in air.receivers.lights.values():
		var light: Light3D = record[0].get_ref()
		if is_instance_valid(light) and light != player.flashlight: light.light_energy = 0
	air._update_volume(0)
	# Isolate the real object's material; air and motes would confound A/B.
	air.volume.visible = false
	air.particles.visible = false
	world.get_node("WakingAtmosphere").environment.volumetric_fog_enabled = false
	for candidate in [false,true,false]:
		receiver.visible = candidate
		await _capture("glass_%d_%s"%[_index,"haze" if candidate else "native"])
		_index += 1
	FileAccess.open(directory.path_join("placement.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"receiver":str(receiver.get_path()),"world_center":str(center),
		"native_surface_unchanged":receiver.mesh == receiver.get_parent().mesh,
		"field_material_count":air.field._materials.size(),"draw_calls":draws},"\t"))
	world.shutdown_for_tests()
	world.queue_free()
	await get_tree().create_timer(.3).timeout
	print("V2 GLASS REVIEW: actual bedside consumer captured native/haze/native")
	get_tree().quit()
var _index := 0
func _capture(label: String) -> void:
	for frame in 45: await RenderingServer.frame_post_draw
	draws[label] = get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
func _hide_canvases(node: Node) -> void:
	if node is CanvasLayer: node.visible = false
	for child in node.get_children(): _hide_canvases(child)
