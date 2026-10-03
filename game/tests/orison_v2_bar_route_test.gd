extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## A real street-to-basement round trip through the retained Harukiya.

func _init() -> void:
	route_label = "V2 BAR ROUTE"

func _route() -> void:
	var bar := world.bar_region
	if not _require(bar != null and not bar.startup_failed and bar.doors.size() == 3,
			"registered bar cell and all three original door owners compose"): return
	var acoustic_before: Dictionary = AcousticGraphData.nodes["F01_BAR_LT_STAIR"].duplicate(true)
	var stair_light := bar.actors.get_node("F01_BAR_LT_STAIR") as LightFixtureProp
	if not _require(AcousticGraphData.node_pos("F01_BAR_LT_STAIR").distance_to(stair_light.global_position)<.001,
			"existing acoustic source follows the registered physical fixture"): return
	for point in [Vector3(1.925,0,-6.5),Vector3(0,0,-8.5),Vector3(0,0,-10.2),Vector3(0,0,-12.2)]:
		if not await _walk(point): return
	# Cross east of the retained subway kiosk, then approach behind its rails.
	var outward := [Vector3(0,0,3),Vector3(7,0,3),Vector3(7,0,4.2),
		Vector3(7,-.1,8),Vector3(7,-.1,13.6),Vector3(7,0,15),
		Vector3(5.65,0,17.3),Vector3(4.8,0,18)]
	for point: Vector3 in outward:
		if not await _walk_world(point): return
	await _capture("bar_street_entry",bar.to_global(GameBoot.b2g([5.1,-30.5,1])))
	# The authored clear lane lies west of the umbrella stand and crates.
	if not await _walk_source(bar,Vector3(4.8,.02,29.99)): return
	var descent := [Vector3(4.8,-.7,31.07),Vector3(4.8,-1.4,32.15),
		Vector3(4.8,-2.1,33.23),Vector3(4.8,-2.8,34.55)]
	for point: Vector3 in descent:
		if not await _walk_source(bar,point): return
	var red: DoorProp = bar.doors["F01_BAR_RED_DOOR"]
	if not await _use(red,red.to_global(Vector3(red.width*.5,1.15,0)),"bar_red_door"): return
	await get_tree().create_timer(.6).timeout
	if not _require(red.open,"existing red door opens through ordinary input"): return
	for point in [Vector3(3.7,-2.8,34.5),Vector3(2.5,-2.8,34.5),Vector3(1.45,-2.8,34.5)]:
		if not await _walk_source(bar,point): return
	await _capture("bar_room",bar.to_global(Vector3(-5,-1.3,32)))
	var pool_zone = bar.actors.get_node("BAR_POOL_TABLE")
	if not _require(pool_zone.position.distance_to(Vector3(-7.4,-1.95,31.25))<.001,
			"pool inspection volume follows the retained table in the west bay"):return
	if not _require(bar.actors.has_node("F01_BAR_SONGBOOK")
			and bar.actors.has_node("F01_BAR_DARTS") and bar.actors.has_node("F01_BAR_POOL")
			and bar.actors.find_children("*","ArcadeCabinetProp",true,false).size()==2,
			"retained games and recording apparatus have their original owners"): return
	var service = [Vector3(1.45,-2.8,33.1),Vector3(-1,-2.8,33.1),Vector3(-3,-2.8,33.1),Vector3(-5.6,-2.8,33.1),Vector3(-8.0,-2.8,33.1),Vector3(-10.5,-2.8,33.1),Vector3(-10.5,-2.8,35.4)]
	for point in service:
		if not await _walk_source(bar,point): return
	var wc: DoorProp = bar.doors["F01_BAR_WC_DOOR"]
	if not await _use(wc,wc.to_global(Vector3(wc.width*.5,1.15,0)),"wc_door"):return
	await get_tree().create_timer(.6).timeout
	if not _require(wc.open and absf(rad_to_deg(wc._body.rotation.y)-145.0)<.1,
			"ordinary restroom input clears the retained jamb with a 145-degree opening"):return
	if not await _walk_source(bar,Vector3(-10.48,-2.8,36.65)):return
	await _capture("wc_inside",bar.to_global(Vector3(-10.1,-1.9,37.5)))
	var sink = bar.actors.get_node("F01_BAR_WC_SINK_01")
	if not await _use(sink,sink.to_global(Vector3(0,.82,0)),"wc_sink"):return
	if not _require(sink.get_flow_state().hot and not sink.get_flow_state().cold,
			"retained sink first opens its hot valve through ordinary input"):return
	if not await _use(sink,sink.to_global(Vector3(0,.82,0)),"wc_sink_mixed"):return
	if not _require(sink.get_flow_state().hot and sink.get_flow_state().cold,
			"retained sink admits both valves on repeated input"):return
	if not await _use(sink,sink.to_global(Vector3(0,.82,0)),"wc_sink_off"):return
	if not _require(not sink.get_flow_state().hot and not sink.get_flow_state().cold,
			"retained sink closes both valves through ordinary input"):return
	if not await _walk_source(bar,Vector3(-10.48,-2.8,35.4)):return
	if not await _use(wc,wc._body.to_global(Vector3(.25,1.15,.026)),"wc_door_close"):return
	await get_tree().create_timer(.6).timeout
	if not _require(not wc.open and absf(wc._body.rotation.y)<.001,"restroom leaf returns to its original closed pose"):return
	service.reverse()
	for point in service.slice(1):
		if not await _walk_source(bar,point):return
	if not await _walk_source(bar,Vector3(1.45,-2.8,34.5)):return
	# The bar stays resident independently while the arcade reloads on exit.
	var bar_geometry := bar.get_node("RetainedBarGeometry")
	for point in [Vector3(2.5,-2.8,34.5),Vector3(3.7,-2.8,34.5),Vector3(4.8,-2.8,34.55)]:
		if not await _walk_source(bar,point): return
	descent.reverse()
	for point: Vector3 in descent.slice(1):
		if not await _walk_source(bar,point): return
	if not await _walk_source(bar,Vector3(4.8,.02,29.99)): return
	outward.reverse()
	for point: Vector3 in outward:
		if not await _walk_world(point): return
	for point in [Vector3(0,0,-10.2),Vector3(0,0,-8.5),Vector3(1.925,0,-6.5)]:
		if not await _walk(point): return
	_require(is_instance_valid(bar_geometry) and AcousticGraphData.nodes["F01_BAR_LT_STAIR"]==acoustic_before,
			"return preserves bar geometry and one acoustic source authority")

func _walk_source(bar: Node3D, point: Vector3) -> bool:
	return await _walk_world(bar.to_global(point))

func _capture(identity: String,target: Vector3) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty():return
	DirAccess.make_dir_recursive_absolute(output)
	player.camera.look_at(target)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(identity+".png"))
