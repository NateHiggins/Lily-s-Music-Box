extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## Installed lobby route and true skylight sightline.
var court_views: Array[Dictionary]=[]

func _init() -> void: route_label="LIGHT COURT ENTRY"

func _prepare_player_start() -> void:
	var carrier := player.carried_device as ServiceSetCarrier
	if _require(carrier != null, "production handheld carrier is available for unobstructed review"):
		carrier.set_capture_hidden(true)
	player.global_position=world.adapter.root.to_global(Vector3(0,.02,-6))
	player.velocity=Vector3.ZERO

func _route() -> void:
	var root: Node3D=world.adapter.root
	var flight: Dictionary={}
	for row: Dictionary in world.layout.stairs:
		if row.id=="PRIMARY_F01_F02":flight=row
	if not _require(flight.origin==[1.4,-3.1] and is_equal_approx(flight.width,1.05) and is_equal_approx(flight.gap,1.),"actual world contains the source-fitted stair schedule"):return
	for point: Vector3 in [Vector3(1.925,0,-6.5),Vector3(1.925,0,-3.5),Vector3(2.95,0,-3.5),Vector3(2.95,0,-2.5),Vector3(2.95,0,-1.4)]:
		if not await _walk(point):return
		await _court_capture("lobby_to_court_%02d" % trace.size(),Vector3(2.95,23.16,-1.4))
	var eye: Vector3=root.to_local(player.camera.global_position)
	var query:=PhysicsRayQueryParameters3D.create(player.camera.global_position,root.to_global(Vector3(2.95,23.3,-1.4)),1,[player.get_rid()])
	var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
	var owner:=str(root.get_path_to(hit.collider)) if not hit.is_empty() else "none"
	_require(not hit.is_empty() and root.to_local(hit.position).y>22.4 and "LightCourtSkylight" in owner,"standing court sightline passes through the true roof opening to the fitted skylight")
	court_views.append({"standing_eye":str(eye),"first_owner":owner,"first_contact":str(root.to_local(hit.position)) if not hit.is_empty() else "none"})
	# Reach the passenger landing from the same lobby start, then return into court.
	for point: Vector3 in [Vector3(2.95,0,-2.5),Vector3(2.95,0,-3.5),Vector3(1.925,0,-3.5),Vector3(1.55,0,-3.4),Vector3(-.4,0,-3.4),Vector3(1.55,0,-3.4),Vector3(1.925,0,-3.5),Vector3(2.95,0,-3.5),Vector3(2.95,0,-2.5),Vector3(2.95,0,-1.4),Vector3(2.95,0,-2.5),Vector3(2.95,0,-3.5),Vector3(1.925,0,-3.5),Vector3(1.925,0,-6.5),Vector3(0,0,-6)]:
		if not await _walk(point):return
	await _court_capture("lobby_return",Vector3(2.95,1.41,-1.4))
	var file:=FileAccess.open(OS.get_environment("SHOT_DIR").path_join("court-fit.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","flight":flight,"views":court_views,"failures":failures,"note":"Installed geometric fit only; downstream roof drainage and final weather materials remain open. No completeness promotion."},"\t")+"\n")
	file.close()

func _court_capture(label: String,target: Vector3) -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	player.face_world_point(world.adapter.root.to_global(target))
	# face_world_point preserves yaw for a target directly overhead. Aim the
	# diagnostic camera explicitly there, with north as its screen-up axis.
	var local_at: Vector3 = world.adapter.root.to_local(player.global_position)
	if Vector2(target.x-local_at.x,target.z-local_at.z).length_squared() < .0001:
		player.camera.look_at(world.adapter.root.to_global(target),world.adapter.root.global_basis*Vector3.FORWARD)
	player.camera.basis=player.camera.basis.orthonormalized()
	player._hand.basis=player._hand.basis.orthonormalized()
	player.set_lamp_enabled(true)
	await get_tree().create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(label+".png"))
	court_views.append({"view":label,"actual_player":str(world.adapter.root.to_local(player.global_position)),"eye_height":player.STANDING_EYE,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
