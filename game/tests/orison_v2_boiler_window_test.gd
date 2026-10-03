extends "res://tests/orison_v2_basement_route_test.gd"
## INERT installed fabric, actual air/barrier and ordinary input/walking proof.
var window: Node3D
var fixture: Dictionary
var inspection_checks := 0
var moving_samples := 0
var mapping_checks := 0
var render_observations: Array[Dictionary]=[]

func _init() -> void:route_label="BOILER WINDOW"

func _prepare_player_start() -> void:
	super._prepare_player_start()
	world.service_set_carrier.set_capture_hidden(true)
	window=world.adapter.root.get_node("B1_BOILER_AIR_E/OperatingWindow")
	fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_boiler_window.json"))

func verify(ok: bool,label: String) -> bool:
	inspection_checks+=1
	return _require(ok,label)

func _route() -> void:
	await _inspect_fabric()
	if not failures.is_empty():return
	await super._route()
	if not failures.is_empty():return
	for point: Vector3 in [Vector3(10.6,-3.2,-.4),Vector3(10.6,-3.2,2.4),Vector3(14.45,-3.2,2.4),Vector3(14.45,-3.2,3.2)]:
		if not await _walk(point):return
	if not verify(not window.opened,"manual window begins shut after basement circuit"):return
	await _window_view("closed_from_boiler_room")
	if not await _operate(true):return
	verify(RealityState.data.v2_household_controls.records.B1_BOILER_AIR_E=={"kind":"window","value":true},"existing household owner commits the chosen open setting")
	await _window_view("open_from_boiler_room")
	for point: Vector3 in [Vector3(14.45,-3.2,2.5),Vector3(14.45,-3.2,3.5),Vector3(14.45,-3.2,3.2)]:
		if not await _walk(point):return
	if not await _operate(false):return
	await _window_view("latched_from_boiler_room")
	verify(not player.noclip and player.collision_mask==1 and player.is_physics_processing(),"normal controller and collision remain active")
	for point: Vector3 in [Vector3(14.45,-3.2,2.4),Vector3(10.6,-3.2,2.4),Vector3(10.6,-3.2,-.4),Vector3(8.3,-3.2,-.4)]:
		if not await _walk(point):return
	await _diagnostic_views()
	var directory:=OS.get_environment("SHOT_DIR")
	var file:=FileAccess.open(directory.path_join("boiler-window-inspection.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","checks":inspection_checks,"mapping_checks":mapping_checks,"moving_samples":moving_samples,"render_observations":render_observations,"waypoints":trace.size(),"failures":failures,"note":"Fitted architecture and manual operation. No ventilation capacity or whole-shell weather acceptance."},"\t")+"\n");file.close()
	print("BOILER WINDOW INSPECTION: ",inspection_checks," checks; ",mapping_checks," mapping checks; ",moving_samples," moving samples")

func _inspect_fabric() -> void:
	var model: Node3D=window.model
	var parts:=0;var triangles:=0
	var mapping=load("res://tests/orison_v2_ceiling_top_closures_test.gd").new()
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		mapping._check_planar_mapping(draw.mesh,true)
		verify(draw.get_node("FittedCollision/Surface").shape.get_faces()==draw.mesh.get_faces(),"each installed draw retains matching physical triangles")
		var key: String=draw.get_meta("material_key")
		verify(key=="glass" or (MatLib.SETS.has(key) and draw.material_override==MatLib.get_mat(key)),"existing material authority "+key)
	mapping_checks=mapping.checks
	for failure: String in mapping.failures:failures.append("mapping: "+failure)
	mapping.free()
	verify(not window.has_method("interact") and window.get_node("HandleReach").has_method("interact"),"only the room-side physical handle publishes the manual verb")
	verify(parts==int(fixture.parts) and triangles==int(fixture.triangles),"all sixteen native material partitions are installed")
	verify(FileAccess.get_sha256("res://assets/props/boiler_window.glb")==fixture.asset_sha256,"installed glTF binds its exact source fixture")
	verify(window.sash.position.distance_to(_v(fixture.hinge_local))<.00001,"actual pivot retains the authored bottom hinge")
	verify(is_equal_approx(window.MAXIMUM_ANGLE,float(fixture.maximum_angle_degrees)) and is_equal_approx(window.STAY_LENGTH,float(fixture.stay_length)),"runtime stops and link lengths match the native plan")
	var root: Node3D=world.adapter.root
	verify(root.to_local(window.global_position).distance_to(_v(fixture.centre))<.00003,"fitted centre retains original reveal and sill/head")
	var excluded: Array[RID]=[player.get_rid()]
	for body: CollisionObject3D in window.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	# Original masonry ownership is tested independently beneath the folded liner.
	for at: Vector3 in [Vector3(.600,0,0),Vector3(-.600,0,0),Vector3(0,.500,0),Vector3(0,-.500,0)]:
		var outward:=Vector3(at.x,at.y,0).normalized()
		var hit:=_ray(at-outward*.01,at+outward*.025,excluded)
		verify(not hit.is_empty() and window.to_local(hit.position).distance_to(at)<.00005,"original reveal bears the fitted liner")
	for fixing: Array in fixture.flange_fixings:
		var at:=_v(fixing)
		var hit:=_ray(at-Vector3.BACK*.08,at+Vector3.BACK*.10,[player.get_rid()])
		verify(not hit.is_empty() and window.is_ancestor_of(hit.collider) and window.to_local(hit.position).distance_to(at)<.00005,"installed flange fixing has its exact visible head")
		hit=_ray(at-Vector3.BACK*.08,at+Vector3.BACK*.10,excluded)
		verify(not hit.is_empty() and absf(window.to_local(hit.position).z+.175)<.00005,"each flange fixing has original masonry behind its bed")
	for pane: Array in fixture.panes:
		var at:=Vector3((pane[0]+pane[3])*.5,-.44+(pane[1]+pane[4])*.5,0)
		var hit:=_ray(at+Vector3.BACK*.5,at-Vector3.BACK*.6,[player.get_rid()])
		verify(not hit.is_empty() and window.is_ancestor_of(hit.collider),"closed six-light pane has its actual physical barrier")
		if not hit.is_empty():verify(absf(window.to_local(hit.position).z+.116)<.00004,"first glass contact matches the imported four-millimetre pane")
	for angle in 36:
		window.angle_degrees=float(angle);window.latch_fraction=0.0 if angle==0 else 1.0;window._apply_pose()
		await get_tree().physics_frame
		for prefix: String in ["StayLeft","StayRight"]:
			var a: Node3D=model.get_node(prefix+"A");var b: Node3D=model.get_node(prefix+"B")
			verify((a.transform*Vector3(0,float(fixture.stay_length),0)).distance_to(b.position)<.00002,"actual first link reaches the shared elbow")
			var side: float=-1.0 if prefix=="StayLeft" else 1.0
			var end: Vector3=window.sash.transform*Vector3(side*.555,.55,0)
			verify((b.transform*Vector3(0,float(fixture.stay_length),0)).distance_to(end)<.00002,"actual second link reaches the sash pivot")
			moving_samples+=1
		for draw: MeshInstance3D in window.sash.find_children("*","MeshInstance3D",true,false):
			var pose:=window.global_transform.affine_inverse()*draw.global_transform
			for vertex: Vector3 in draw.mesh.get_faces():
				var p: Vector3=pose*vertex
				if p.z>-.10401:
					if absf(p.x)>=.59801 or absf(p.y)>=.49801:
						verify(false,"moving sash enters retained masonry at "+str(p));break
	# A real upper air route opens across the whole width into the grated well.
	for x: float in [-.45,-.2,0,.2,.45]:
		for y: float in [.32,.38,.42]:
			verify(_ray(Vector3(x,y,.8),Vector3(x,y,-.65),[player.get_rid()]).is_empty(),"open upper air route reaches the existing well")
	# A standing player's head within the sweep must prevent motion before it starts.
	var actor:=CharacterBody3D.new();actor.collision_layer=1;actor.collision_mask=1
	var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.75;capsule.radius=.25;shape.shape=capsule
	world.add_child(actor);actor.add_child(shape)
	actor.global_position=window.to_global(Vector3(0,-1.03,-.48))
	await get_tree().physics_frame
	verify(window.interact_handle(actor).is_empty() and not window.moving,"manual sweep rejects an occupied player volume")
	actor.free();window.restore_open_state(false)
	await get_tree().physics_frame
	verify(not window.opened and is_zero_approx(window.angle_degrees) and is_zero_approx(window.latch_fraction),"physical closed reconstruction seats the cam and sash")

func _operate(value: bool) -> bool:
	var target: Vector3=window.latch.to_global(Vector3(0,.025,-.04))
	if not await _use(window,target,"window_open" if value else "window_close"):return false
	for frame in 120:
		await get_tree().physics_frame
		if not window.moving:break
	return verify(window.opened==value and not window.moving and absf(window.angle_degrees-(35.0 if value else 0.0))<.00001,"ordinary E completes the fitted sash and latch travel")

func _window_view(label: String) -> void:
	player.face_world_point(window.to_global(Vector3(0,0,0)))
	await _capture(label)

func _diagnostic_views() -> void:
	player.set_physics_process(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var root: Node3D=world.adapter.root
	var opening: Node3D=window.get_parent()
	var old_pane: MeshInstance3D=opening.get_node("Glazing")
	var library:=preload("res://scripts/building/orison_v2_window_joinery.gd")
	var previous:=MeshInstance3D.new();previous.name="ReadOnlyPreviousWindow"
	previous.mesh=library._mesh();previous.material_override=opening.get_node("JambA").get_active_material(0)
	var record: Dictionary
	for entry: Dictionary in root.layout.windows:
		if str(entry.id)=="B1_BOILER_AIR_E":record=entry;break
	previous.transform=opening.transform.affine_inverse()*library._placement(root,record)
	opening.add_child(previous);previous.hide()
	old_pane.position.x=(float(fixture.reveal_span[0])+float(fixture.reveal_span[1]))*.5-float(record.center[0])
	for opened: bool in [false,true]:
		window.restore_open_state(opened)
		await get_tree().physics_frame
		for view: Array in [["walking_stance",Vector3(14.45,-3.2+player.STANDING_EYE,3.2),Vector3(15.755,-1.3,3.2)],
			["room_detail",Vector3(14.6,-1.05,3.45),Vector3(15.65,-1.3,3.2)],
			["well_detail",Vector3(16.6,-1.1,3.45),Vector3(15.75,-1.3,3.2)]]:
			player.global_position=root.to_global(view[1])-Vector3.UP*player.STANDING_EYE
			player.face_world_point(root.to_global(view[2]));player.set_lamp_enabled(true)
			await get_tree().create_timer(.25).timeout
			var label:=str(view[0])+"_"+("open" if opened else "closed")
			await _capture(label)
			var after:=_render_counters()
			window.model.hide();previous.show();old_pane.show()
			await get_tree().create_timer(.25).timeout;await _capture(label+"_before")
			var before:=_render_counters()
			render_observations.append({"view":label,"before":before,"after":after,"note":"Same-camera visual substitution of unchanged previous frame/card. Main-viewport visible counters; standing stance or labelled diagnostic view, not FPS acceptance."})
			window.model.show();previous.hide();old_pane.hide()
	previous.free();window.restore_open_state(false)

func _ray(start: Vector3,end: Vector3,excluded: Array[RID]) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(window.to_global(start),window.to_global(end),1,excluded)
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func _v(a: Array) -> Vector3:return Vector3(float(a[0]),float(a[1]),float(a[2]))

func _capture(label: String) -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

func _render_counters() -> Dictionary:
	var viewport:=get_viewport().get_viewport_rid()
	return {"draw_calls":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)}
