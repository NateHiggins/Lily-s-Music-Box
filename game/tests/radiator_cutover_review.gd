extends Node3D
## Composed geometry/valve/inspection review during cutover. Other physical
## service controls, disk reconstruction and broad qualification remain pending.
var failures: Array[String] = []
var checks := 0
var _terminal := false

func _ready() -> void:
	get_tree().create_timer(170).timeout.connect(func():
		if not _terminal:
			push_error("Radiator cutover review did not finish")
			get_tree().quit(1))
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)

func _run() -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless":
		get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var previous_contact: float=PhysicsServer3D.space_get_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION)
	var world := preload("res://scenes/building/orison_v2_runtime.tscn").instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed and world.player!=null,"native radiator world starts through production composition")
	check(absf(PhysicsServer3D.space_get_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION)-.0005)<.000001,"production V2 applies small-part contact precision")
	if world.startup_failed or world.player==null:
		_finish(directory);return
	world.player.set_physics_process(false)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/heating.json"))
	var rosters := 0
	var supports := 0
	for record: Dictionary in source.installed:
		var prop := world.adapter.resolve(str(record.id)) as RadiatorProp
		check(prop!=null and prop.use_native_v2 and prop.native_rig!=null,"installed radiator uses native rig: "+str(record.id))
		if prop==null or prop.native_rig==null: continue
		rosters += 1
		check(prop.native_wall_mounts.size()==2,"both surveyed mounts are bound")
		var rig := prop.native_rig
		check(prop.native_pitch_wedges!=null and prop.native_pitch_wedges.rows.size()==2 and rig._shims.is_empty(),"installed radiator uses two fixed sliding wedges instead of preset shim draws")
		if prop.native_pitch_wedges!=null:
			var exclude: Array[RID]=[world.player.get_rid()]
			for collider: CollisionObject3D in prop.find_children("*","CollisionObject3D",true,false):exclude.append(collider.get_rid())
			for side: String in prop.native_pitch_wedges.rows:
				var draw: MeshInstance3D=prop.native_pitch_wedges.rows[side].draw
				var interior := ConvexPolygonShape3D.new()
				var centre := draw.mesh.get_aabb().get_center()
				var points := PackedVector3Array()
				for point: Vector3 in draw.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:points.append(centre+(point-centre)*.98)
				interior.points=points;interior.margin=.000001
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape=interior;query.transform=draw.global_transform;query.exclude=exclude
				var overlaps := get_world_3d().direct_space_state.intersect_shape(query,16)
				if not overlaps.is_empty():print("WEDGE ROOM OVERLAP ",record.id," ",side," ",overlaps)
				check(overlaps.is_empty(),"fixed wedge interior clears room/furniture at factory pose: "+str(record.id)+"/"+side)
		var sections := rig.body.get_node("SharedCastSections") as MultiMeshInstance3D
		check(sections.multimesh.instance_count==int(record.sections),"native casting count preserves heating roster")
		var finish := sections.material_override as StandardMaterial3D
		check(finish!=null and finish.get_meta("v2_surface_stock","")=="radiator_cast_iron",
			"installed casting uses its separate cast-skin recipe: "+str(record.id))
		if finish!=null:
			check(finish.normal_enabled and is_equal_approx(finish.normal_scale,1.0) and not finish.uv1_triplanar,
				"installed casting samples physical normal relief on native UVs")
		var shoes := RadiatorNativeParts.stock_points("mechanisms","CastShoeFoot")
		var half := float(prop.section_count-1)*.092*.5
		var shift := maxf(0.0,half-.322)
		var lowest := INF
		for x in [-half,half]:
			for point in shoes: lowest=minf(lowest,(rig.body.transform*(point+Vector3(x+shift,0,-.03))).y)
		check(absf(lowest)<.000001,"actual native shoe bears on installation floor")
		for draw: MeshInstance3D in rig.find_children("*","MeshInstance3D",true,false):
			if draw.get_meta("native_stock","")=="SlottedWallBracket": supports+=1
		var saved := prop.mechanism_snapshot()
		check(prop.valid_mechanism(JSON.parse_string(JSON.stringify(saved))),"physical radiator settings survive JSON encoding")
		prop.restore_mechanism(saved)
		check(prop.mechanism_snapshot()==saved,"restoration preserves physical positions")
	check(rosters==23 and supports==46,"23 native radiators have 46 wall brackets")
	check(world.adapter.root.find_child("RadiatorTiePlates",true,false)==null,"floating legacy wall ties are retired")
	var radiator := world.adapter.resolve("F02_B_RADIATOR_01") as RadiatorProp
	var orifice_stock: Node3D=world.adapter.resolve("B1_VENT_SERVICE_STOCK")
	check(orifice_stock!=null and orifice_stock.rows.size()==28,"finite vent stock contains 23 original inserts and five workshop spares")
	# Inspect imported buffers and actual loaded maps in this already-built
	# world; a second whole-project launch is unnecessary for the same rig.
	var native_inspector := preload("res://tests/radiator_native_review.gd").new()
	var native_sections := radiator.native_rig.body.get_node("SharedCastSections") as MultiMeshInstance3D
	for index in native_sections.multimesh.mesh.get_surface_count():
		native_inspector._check_surface(native_sections.multimesh.mesh,index,native_sections.material_override)
	for draw: MeshInstance3D in radiator.find_children("*","MeshInstance3D",true,false):
		if not draw.has_meta("native_stock"): continue
		for index in draw.mesh.get_surface_count(): native_inspector._check_surface(draw.mesh,index,draw.get_active_material(index))
	if orifice_stock!=null:
		for draw: MeshInstance3D in orifice_stock.find_children("*","MeshInstance3D",true,false):
			for index in draw.mesh.get_surface_count(): native_inspector._check_surface(draw.mesh,index,draw.get_active_material(index))
		var excludes: Array[RID]=[]
		for body: CollisionObject3D in orifice_stock.find_children("*","CollisionObject3D",true,false): excludes.append(body.get_rid())
		for x in [-.14,.14]:
			var probe := PhysicsRayQueryParameters3D.create(orifice_stock.to_global(Vector3(x,.045,-.075)),orifice_stock.to_global(Vector3(x,.045,-.13)))
			probe.exclude=excludes
			var hit := get_world_3d().direct_space_state.intersect_ray(probe)
			check(not hit.is_empty() and hit.position.distance_to(orifice_stock.to_global(Vector3(x,.045,-.1)))<.001 and hit.normal.dot(orifice_stock.global_basis*Vector3.BACK)>.95,"workshop rack standoff meets real room wall")
	checks += native_inspector.checks
	failures.append_array(native_inspector.failures)
	native_inspector.free()
	var player := world.player
	var rim := radiator._wheel.global_position+radiator.global_basis*Vector3(0,0,-.055)
	player.global_position = rim+radiator.global_basis*Vector3(0,-1.1,-.7)
	player.camera.global_position = rim+radiator.global_basis*Vector3(0,.17,-.65)
	player.camera.look_at(rim)
	player.call_locked = false
	player.mouse_released = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame
	await get_tree().physics_frame
	var target: Dictionary = player._grab.find_target()
	check(target.get("owner")==radiator,"physics cursor finds the actual supply wheel")
	if target.get("owner")==radiator:
		_click(player)
		check(player._grab.active(),"primary click acquires native wheel")
		var before := radiator.supply_position
		player._grab.move(Vector2(70,30))
		if is_equal_approx(before,radiator.supply_position): player._grab.move(Vector2(-70,-30))
		check(not is_equal_approx(before,radiator.supply_position),"mouse motion turns actual wheel and valve authority")
		_click(player)
		check(not radiator._supply_held,"next click releases native valve")
		target=player._grab.find_target()
		if target.get("owner")==radiator:
			_click(player)
			check(player.begin_inspection(),"space inspection reaches the mechanism without crossing walls")
			check(player.inspecting(),"inspection uses static camera and visible pointer")
			player.end_inspection()
		else: check(false,"native wheel remains available for inspection")
	# Set up a shut supply through the public mechanism authority, then drive
	# the new union controls through the real constrained hand and mouse motion.
	radiator.set_supply_position(0.0,0.0)
	for key in ["retainer","withdraw"]:
		var grip := radiator.native_union_grip(key)
		check(not grip.is_empty(),"prepared union exposes physical control: "+key)
		if grip.is_empty(): continue
		var part: Node3D = grip.part
		var contact := part.global_position+radiator.global_basis*Vector3(0,0,-.04) if key=="retainer" else part.to_global(Vector3(0,.43,-.15))
		var view_offset := Vector3(-.45,.20,-.30) if key=="retainer" else Vector3(0,.15,-.65)
		player.camera.global_position=contact+radiator.global_basis*view_offset
		player.camera.look_at(contact)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var found: Dictionary=player._grab.find_target()
		check(found.get("owner")==radiator and found.get("part")==part,"physics cursor finds native "+key)
		_click(player)
		check(player._grab.active() and radiator._native_held==key,"primary click acquires native "+key)
		var goal := TAU if key=="retainer" else .027
		_drag_to(player,goal)
		check(player._grab.active() and absf(float(grip.read.call())-goal)<.00001,"mouse motion drives native "+key)
		_click(player)
		check(radiator._native_held.is_empty(),"release clears native "+key)
	world.household_state.capture_now()
	var household := world.household_state.snapshot()
	check(household.records.F02_B_RADIATOR_01.value==radiator.mechanism_snapshot(),"household save includes 2B physical settings without duplicating case custody")
	await preload("res://tests/radiator_pitch_hand_checks.gd").new().run(self,radiator,world.player,self,world.household_state,failures)
	for identity in ["F02_B_RADIATOR_01","F01_LOBBY_RADIATOR_01","F01_D_RADIATOR_01"]:
		var prop := world.adapter.resolve(identity) as RadiatorProp
		player.camera.global_position = prop.to_global(Vector3(.25,.80-prop.installation_drop,-1.4))
		player.camera.look_at(prop.to_global(Vector3(0,.4-prop.installation_drop,0)))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join(identity+".png"))
	player.camera.global_position=radiator.to_global(Vector3(.18,.54-radiator.installation_drop,-.48))
	player.camera.look_at(radiator.to_global(Vector3(.04,.43-radiator.installation_drop,-.07)))
	var lamp_was_on: bool=player.lamp_is_enabled()
	for enabled: bool in [false,true]:
		player.set_lamp_enabled(enabled)
		# The production hand chases the camera; allow its real lamp to settle.
		await get_tree().create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("2B_cast_detail_lamp_"+("on" if enabled else "off")+".png"))
	player.set_lamp_enabled(lamp_was_on)
	var half := float(radiator.section_count-1)*.092*.5
	var cast_shift := maxf(0.0,half-.322)
	for detail: String in ["headers","shoe","union"]:
		var point := Vector3(cast_shift,.72,-.085) if detail=="headers" else Vector3(half+cast_shift,.045,-.03)
		var detail_target := radiator.native_rig.body.to_global(point)
		var offset := Vector3(.12,.11,-.39) if detail=="headers" else Vector3(.25,.18,-.42)
		if detail=="union":
			detail_target=radiator.native_rig.header_nut.global_position
			offset=Vector3(-.12,.10,-.26)
		player.camera.global_position=detail_target+radiator.global_basis*offset
		player.camera.look_at(detail_target)
		await get_tree().create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("2B_"+detail+"_detail.png"))
	player._grab.release()
	if orifice_stock!=null:
		player.camera.global_position=orifice_stock.to_global(Vector3(.13,.22,.55))
		player.camera.look_at(orifice_stock.to_global(Vector3(0,.035,0)))
		await get_tree().create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("B1_vent_stock_installed.png"))
	# Reuse the existing installed fuse gesture sequence in this world so the
	# changed contact tolerance also exercises another real loose-part repair.
	var fuse_driver := preload("res://tests/fuse_panel_hand_test.gd").new()
	fuse_driver.batch_mode=true
	add_child(fuse_driver)
	fuse_driver.player=player
	fuse_driver.panel=world.adapter.resolve("B1_FUSE_PANEL")
	fuse_driver.out=directory.path_join("fuse_precision")
	DirAccess.make_dir_recursive_absolute(fuse_driver.out)
	player.global_position=world.adapter.root.to_global(Vector3(7.6,-3.18,-4.9))
	# Detail captures move the camera independently of the standing body.
	# Restore its real eye before the next installed interaction fixture.
	player.camera.position=Vector3(0,PlayerController.STANDING_EYE,0)
	player.velocity=Vector3.ZERO
	await fuse_driver._repair_by_hand(false)
	for row: Dictionary in fuse_driver.checks: check(row.ok,"V2 precision / "+str(row.label))
	fuse_driver.free()
	world.free()
	check(is_equal_approx(previous_contact,PhysicsServer3D.space_get_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION)),"retiring V2 restores prior physics-space tolerance")
	_finish(directory)

func _click(player: Node3D) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	player._unhandled_input(event)

func _drag_to(player: Node3D, goal: float) -> void:
	# The real supply stem takes 3.5 turns: 160 increments of .12 radians
	# cannot reach its full travel from shut. Keep actual mouse increments.
	for index in 512:
		if not player._grab.active(): return
		var grip: Dictionary=player._grab.target
		var before: float=grip.read.call()
		var remaining := goal-before
		if absf(remaining)<.000001: return
		var frame: Node3D=grip.frame
		var part: Node3D=grip.part
		var local_axis: Vector3=grip.axis.call() if grip.axis is Callable else grip.axis
		var axis: Vector3=frame.global_basis*local_axis
		var point: Vector3=part.to_global(player._grab.contact)
		var tangent: Vector3=axis.cross(point-part.global_position) if grip.kind=="hinge" else axis
		if grip.kind=="hinge" and tangent.length()<.025:
			tangent=axis.cross(player.camera.global_basis.x)*.06
			if tangent.length()<.01: tangent=axis.cross(player.camera.global_basis.y)*.06
		var step := clampf(remaining,-.12,.12) if grip.kind=="hinge" else clampf(remaining,-.02,.02)
		var pixels: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
		if pixels.length()<24.0 and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5:
			pixels=Vector2(0,tangent.dot(player.camera.global_basis.z)*180.0)
		var event := InputEventMouseMotion.new()
		event.relative=pixels*step
		player._unhandled_input(event)
		if is_equal_approx(float(grip.read.call()),before): return

func _finish(directory: String) -> void:
	_terminal = true
	var file := FileAccess.open(directory.path_join("cutover_review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,
		"scope":"Production geometry composition, valve grab/motion/release, inspection and in-memory save; remaining service controls, disk restore and broad runtime contracts unverified"},"\t"))
	print("RADIATOR CUTOVER REVIEW: %s; %d checks; %d failures" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
