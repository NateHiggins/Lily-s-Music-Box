extends Node3D
## Fast production-owner/production-player gesture check before world reload.
var _terminal := false
var _capture_failed := false
func _ready() -> void:
	get_tree().create_timer(45).timeout.connect(func():
		if not _terminal:
			push_error("RADIATOR HAND BENCH: FAIL incomplete control pass")
			get_tree().quit(1))
	_run.call_deferred()

func _run() -> void:
	var capture_directory := OS.get_environment("SHOT_DIR")
	if not capture_directory.is_empty() and DirAccess.make_dir_recursive_absolute(capture_directory)!=OK:
		_terminal=true
		push_error("RADIATOR HAND BENCH: FAIL capture directory")
		get_tree().quit(1)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	var previous_contact: float=PhysicsServer3D.space_get_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION)
	var contact_policy := preload("res://scripts/building/orison_v2_contact_precision.gd").new()
	add_child(contact_policy)
	var nested_policy := preload("res://scripts/building/orison_v2_contact_precision.gd").new()
	add_child(nested_policy)
	nested_policy.free()
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.12,.14,.16)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.75,.82,.90)
	environment.environment.ambient_light_energy=.4
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-45,-25,0)
	light.light_energy=1.5
	light.shadow_enabled=true
	add_child(light)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size=Vector3(4,.1,4)
	floor_shape.shape=floor_box
	floor_shape.position.y=-.05
	floor_body.add_child(floor_shape)
	var floor_draw := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size=floor_box.size
	floor_draw.mesh=floor_mesh
	floor_draw.position=floor_shape.position
	floor_draw.material_override=MatLib.get_mat("concrete").duplicate()
	floor_body.add_child(floor_draw)
	add_child(floor_body)
	var inventory := MaintenanceInventory.new()
	add_child(inventory)
	inventory.setup()
	var prop := RadiatorProp.new()
	prop.use_native_v2 = true
	prop.section_count = 8
	prop.unit = "2B"
	prop.graph_node_id="F02_B_RADIATOR_01"
	prop.rotation.y = PI
	prop.installation_drop=.75
	prop.position.y=.75
	prop.bind_inventory(inventory)
	preload("res://scripts/building/orison_v2_heating.gd").new()._add_collision(prop)
	add_child(prop)
	var stock := preload("res://scripts/props/radiator_vent_stock.gd").new()
	stock.name="B1_VENT_SERVICE_STOCK"
	stock.position=Vector3(1.0,.85,.2)
	add_child(stock)
	var stock_source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/heating_service_stock.json"))
	stock.install_rack(stock_source.asset)
	stock.configure([prop],stock_source)
	var player := PlayerController.new()
	add_child(player)
	player.set_physics_process(false)
	player.call_locked=false
	player.mouse_released=false
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	prop.set_supply_position(0.0,0.0)
	var reviewer := preload("res://tests/radiator_cutover_review.gd").new()
	var failures: Array = []
	var feed_owner := prop.get_node_or_null("InstalledRadiatorCollision") as StaticBody3D
	if feed_owner==null:failures.append("installed collision owner remains available for existing floor-query exclusions")
	else:
		for collision: CollisionShape3D in feed_owner.get_children():
			if not collision.shape is ConcavePolygonShape3D:failures.append("fixed feed collision uses native open surfaces rather than a legacy solid box")
	for key in ["retainer","withdraw"]:
		var grip := prop.native_union_grip(key)
		if grip.is_empty(): failures.append("missing "+key);continue
		var part: Node3D=grip.part
		var contact := part.global_position+prop.global_basis*Vector3(0,0,-.04) if key=="retainer" else part.to_global(Vector3(0,.43,-.15))
		var offset := Vector3(-.45,.20,-.30) if key=="retainer" else Vector3(0,.15,-.65)
		player.camera.global_position=contact+prop.global_basis*offset
		player.camera.look_at(contact)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var found: Dictionary=player._grab.find_target()
		if found.get("owner")!=prop or found.get("part")!=part:
			failures.append("cursor "+key)
		reviewer._click(player)
		if not player._grab.active() or prop._native_held!=key: failures.append("acquire "+key);continue
		var goal := TAU if key=="retainer" else .027
		reviewer._drag_to(player,goal)
		var actual: float=grip.read.call()
		print("RADIATOR HAND ",key," target=",goal," actual=",actual)
		if absf(actual-goal)>.00001: failures.append("motion "+key)
		reviewer._click(player)
		if not prop._native_held.is_empty(): failures.append("release "+key)
	# Mutate the real mechanism before restoring it through the household
	# codec. Restoring an unchanged snapshot alone would also pass a no-op.
	var codec := preload("res://scripts/building/orison_v2_household_state.gd").new()
	add_child(codec)
	codec._subjects={"F02_B_RADIATOR_01":prop,"B1_VENT_SERVICE_STOCK":stock}
	codec._kinds={"F02_B_RADIATOR_01":"radiator","B1_VENT_SERVICE_STOCK":"mechanism"}
	codec._defaults=codec.snapshot()
	var saved: Dictionary=JSON.parse_string(JSON.stringify(codec.snapshot()))
	var body_pose := prop.native_rig.body.transform
	var wheel_pose := prop.native_rig.wheel.transform
	prop.native_service_progress=0.0
	prop.set_supply_position(.6,0.0)
	prop.set_pitch(-.35)
	prop.set_vent_grade(1)
	if prop.native_rig.body.transform.is_equal_approx(body_pose): failures.append("restore setup must change the real pose")
	if not codec.validate(saved,codec._kinds): failures.append("physical save codec validation")
	codec._restore(saved)
	var actual := codec.snapshot()
	var expected_settings: Dictionary=saved.records.F02_B_RADIATOR_01.value
	var actual_settings: Dictionary=actual.records.F02_B_RADIATOR_01.value
	# JSON decodes version/grade integers as floats. Compare their numeric
	# meaning, retaining strict key coverage and the independent pose checks.
	var same_settings: bool = actual.schema_version==saved.schema_version and actual.records.F02_B_RADIATOR_01.kind==saved.records.F02_B_RADIATOR_01.kind and _same_payload(actual_settings,expected_settings)
	if not same_settings or not prop.native_rig.body.transform.is_equal_approx(body_pose) or not prop.native_rig.wheel.transform.is_equal_approx(wheel_pose):
		print("RESTORE ACTUAL ",JSON.stringify(codec.snapshot())," EXPECTED ",JSON.stringify(saved),
			" BODY_MATCH ",prop.native_rig.body.transform.is_equal_approx(body_pose)," WHEEL_MATCH ",prop.native_rig.wheel.transform.is_equal_approx(wheel_pose))
		failures.append("physical save restores changed poses")
	var legacy := saved.duplicate(true)
	legacy.records.F02_B_RADIATOR_01.value=.42
	if not codec.validate(legacy,codec._kinds): failures.append("legacy valve scalar validation")
	codec._restore(legacy)
	if not is_equal_approx(prop.supply_position,.42): failures.append("legacy valve scalar restoration")
	await _packing_pass(prop,player,reviewer,codec,failures)
	await preload("res://tests/radiator_vent_hand_checks.gd").new().run(self,prop,player,reviewer,codec,failures)
	await _contact_orientations(prop,failures)
	await preload("res://tests/radiator_orifice_hand_checks.gd").new().run(self,prop,stock,player,reviewer,codec,failures)
	await preload("res://tests/radiator_pitch_hand_checks.gd").new().run(self,prop,player,reviewer,codec,failures)
	var inspector := preload("res://tests/radiator_native_review.gd").new()
	for draw: MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false):
		if not draw.has_meta("native_stock"): continue
		for index in draw.mesh.get_surface_count(): inspector._check_surface(draw.mesh,index,draw.get_active_material(index))
	for draw: MeshInstance3D in stock.find_children("*","MeshInstance3D",true,false):
		for index in draw.mesh.get_surface_count(): inspector._check_surface(draw.mesh,index,draw.get_active_material(index))
	failures.append_array(inspector.failures)
	var fixture: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/radiator_native_poses.json"))
	for count in [7,8,9,10]:
		var rig := RadiatorNativeAssembly.new()
		add_child(rig)
		rig.build(count)
		rig.hide()
		for row: Dictionary in fixture:
			if int(row.sections)!=count: continue
			rig.set_positions(float(row.pitch),1,0,2,0,0)
			var expected: Transform3D=inspector._blender_matrix(row.body_matrix)
			if inspector._matrix_distance(rig.body_pose,expected)>.000001: failures.append("cached bearing pose matches native reference")
			var unchanged := rig.body_pose
			rig.set_positions(float(row.pitch),.2,1,2,0,0)
			if not rig.body_pose.is_equal_approx(unchanged): failures.append("non-pitch motion preserves cached bearing solve")
		rig.free()
	var directory := OS.get_environment("SHOT_DIR")
	contact_policy.free()
	if not is_equal_approx(previous_contact,PhysicsServer3D.space_get_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION)):
		failures.append("V2 physics precision restores previous space setting")
	if _capture_failed: failures.append("review capture could not be saved")
	if not directory.is_empty():
		var file := FileAccess.open(directory.path_join("packing_review.json"),FileAccess.WRITE)
		if file==null:
			_terminal=true
			push_error("RADIATOR HAND BENCH: FAIL diagnostic write")
			get_tree().quit(1)
			return
		file.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Fast production actor/player controls, loose physics, in-memory pose restore, native surface import, bearing cache parity and shared steam budget. No composed-world or disk reconstruction contract.","surface_checks":inspector.checks,"kinematic_cases":20,"failures":failures},"\t"))
	inspector.free()
	codec.free()
	reviewer.free()
	print("RADIATOR HAND BENCH: ","PASS" if failures.is_empty() else "FAIL"," ",failures)
	_terminal=true
	get_tree().quit(0 if failures.is_empty() else 1)

func _contact_orientations(prop: Node3D,failures: Array) -> void:
	if absf(PhysicsServer3D.space_get_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION)-.0005)>.000001:
		failures.append("nested V2 physics lease retains sub-millimetre contact")
	var part: RigidBody3D=prop.native_packing
	var original: Dictionary=prop.mechanism_snapshot()
	for angles: Vector3 in [Vector3(.4,.7,1.1),Vector3(1.8,.1,.3),Vector3(.1,2.5,2.0)]:
		var fixture := original.duplicate(true)
		fixture.packing_spread=1.0
		fixture.packing_out=1.0
		var q := Basis.from_euler(angles).get_rotation_quaternion()
		var at: Vector3=prop.to_local(Vector3(-1.0,.22,-.6))
		fixture.packing={"station":1,"position":[at.x,at.y,at.z],"rotation":[q.x,q.y,q.z,q.w]}
		prop.restore_mechanism(fixture)
		await get_tree().create_timer(2.0).timeout
		var minimum := INF
		for collider: Node in part.get_children():
			if not collider is CollisionShape3D: continue
			for point: Vector3 in collider.shape.points: minimum=minf(minimum,collider.to_global(point).y)
		print("PACKING ORIENTATION SUPPORT ",angles," MIN ",minimum)
		if minimum<-.001 or minimum>.004: failures.append("packing skin contact across released orientations")
	prop.restore_mechanism(original)

func _same_payload(a: Variant,b: Variant) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]: return absf(float(a)-float(b))<.0000001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not _same_payload(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for index in a.size():
			if not _same_payload(a[index],b[index]): return false
		return true
	return a==b

func _aim(player: Node3D,prop: Node3D,point: Vector3) -> void:
	player.camera.global_position=point+prop.global_basis*Vector3(-.03,.10,-.32)
	player.camera.look_at(point)
	await get_tree().physics_frame
	await get_tree().physics_frame

func _packing_pass(prop: Node3D,player: Node3D,reviewer: Node3D,codec: Node,failures: Array) -> void:
	prop.set_supply_position(0.0,0.0)
	var body_point: Vector3=prop.native_rig.body.to_global(Vector3(0,.43,-.15))
	await _aim(player,prop,body_point)
	reviewer._click(player)
	if not player._grab.active(): failures.append("packing setup body grip");return
	reviewer._drag_to(player,.04)
	reviewer._click(player)
	if prop.native_service_progress<.999: failures.append("packing setup union clearance");return
	var part: RigidBody3D=prop.native_packing
	var acquired := {"count":0}
	prop.inventory.part_acquired.connect(func(_id: String,_shop: String): acquired.count+=1)
	var contact := part.to_global(Vector3(.012,0,-.030))
	await _aim(player,prop,contact)
	var target: Dictionary=player._grab.find_target()
	print("PACKING CURSOR ",target.get("part")," EXPECTED ",part," AT ",part.position)
	reviewer._click(player)
	if not player._grab.active() or prop._native_held!="packing": failures.append("real packing acquisition");return
	reviewer._drag_to(player,.144)
	if prop.native_packing_spread<.999 or prop.native_packing_out<.999: failures.append("real packing peel/lift");return
	await _capture_part(player,prop,part,"packing_lifted")
	var height := part.global_position.y
	reviewer._click(player)
	if part.station!=1 or part.freeze: failures.append("packing becomes a real loose body")
	if not prop.inventory.has_item(prop.PACKING_ITEM): failures.append("one historical part acquisition")
	await get_tree().create_timer(1.5).timeout
	print("PACKING FALL ",height," -> ",part.global_position.y," SPEED ",part.linear_velocity)
	var lowest := INF
	for collider: CollisionShape3D in part.get_children().filter(func(n): return n is CollisionShape3D):
		for vertex: Vector3 in collider.shape.points: lowest=minf(lowest,collider.to_global(vertex).y)
	print("PACKING ACTUAL LOWER SURFACE ",lowest)
	print("PACKING SUPPORT CORRECTION ",part.support_correction)
	if lowest<-.001 or lowest>.004: failures.append("actual packing skin rests on floor without penetration or hovering")
	if part.global_position.y>=height-.05 or part.global_position.y<-.02: failures.append("loose packing falls onto actual floor")
	await _capture_part(player,prop,part,"packing_on_floor")
	var loose_save: Dictionary=JSON.parse_string(JSON.stringify(codec.snapshot()))
	if not codec.validate(loose_save,codec._kinds): failures.append("loose packing save validation")
	var floor_pose := part.transform
	part.position+=Vector3(.6,.3,.1)
	codec._restore(loose_save)
	if part.position.distance_to(floor_pose.origin)>.000001 or absf(part.basis.get_rotation_quaternion().dot(floor_pose.basis.get_rotation_quaternion()))<.99999:
		failures.append("loose packing pose restoration")
	var bad: Dictionary=prop.mechanism_snapshot().duplicate(true)
	bad.packing.rotation=[0,0,0,0]
	if prop.valid_mechanism(bad): failures.append("reject invalid packing quaternion")
	# An empty cup can be shut; it must leak rather than magically acquire cloth.
	prop.native_service_progress=0.0
	prop.set_supply_position(1.0,0.0)
	if prop.native_union_leak()<.999 or not prop._vapor.visible: failures.append("closed empty joint leaks with live supply")
	if not prop.valid_mechanism(prop.mechanism_snapshot()): failures.append("loose cloth persists beside closed cup")
	prop.native_service_progress=1.0
	prop.set_supply_position(0.0,0.0)
	await _aim(player,prop,_packing_contact(part,prop))
	# Physics may settle a restored loose body during those two frames. Aim at
	# its current surface, as the live cursor does, rather than a stale point.
	var loose_contact := _packing_contact(part,prop)
	player.camera.global_position=loose_contact+prop.global_basis*Vector3(-.03,.10,-.32)
	player.camera.look_at(loose_contact)
	reviewer._click(player)
	if not player._grab.active() or prop._native_held!="packing": failures.append("loose packing re-grab");return
	# The physical wedges change where released cloth can settle. Frame the
	# actual part and receiver, then lift clear before approaching the cup.
	player.camera.global_position=(part.global_position+prop.to_global(part.home().origin))*.5+prop.global_basis*Vector3(-.35,.28,-.65)
	player.camera.look_at(_packing_contact(part,prop))
	await _carry_to(player,part.position+Vector3(0,.12,-.12))
	await _carry_to(player,part.home().origin+Vector3.FORWARD*.12)
	await _carry_to(player,part.home().origin)
	reviewer._click(player)
	print("PACKING RESEAT station ",part.station," delta ",part.position.distance_to(part.home().origin)," BLOCK ",part.last_block)
	if part.station!=0: failures.append("hand-delivered packing reseats");return
	await _aim(player,prop,part.to_global(Vector3(.012,0,-.052)))
	reviewer._click(player)
	if not player._grab.active() or prop._native_held!="packing": failures.append("reseated packing grip");return
	reviewer._drag_to(player,0.0)
	reviewer._click(player)
	if prop.native_packing_spread>.001 or prop.native_packing_out>.001: failures.append("actual push closes packing around ball")
	await _capture_part(player,prop,part,"packing_reseated")
	if prop.inventory.item_state(prop.PACKING_ITEM).shop_id!="radiator_2b_union": failures.append("part identity retained")
	var legacy: Dictionary=prop.mechanism_snapshot()
	legacy.erase("packing")
	legacy.erase("vent_cap")
	legacy.erase("pitch_wedges")
	if not prop.valid_mechanism(legacy): failures.append("six-field native save migration")
	prop.restore_mechanism(legacy)
	# A used item remains the same physical liner; the historical one-time
	# inventory record must not mint a fresh part when it is removed again.
	prop.inventory.consume(prop.PACKING_ITEM)
	await _aim(player,prop,part.to_global(Vector3(.012,0,-.030)))
	reviewer._click(player)
	if not player._grab.active() or prop._native_held!="packing": failures.append("used packing remains manipulable");return
	reviewer._drag_to(player,.084)
	reviewer._click(player)
	if part.station!=1 or part.freeze: failures.append("partial lift release never floats on an invisible track")
	if acquired.count!=1 or prop.inventory.serialize().items.size()!=1 or not prop.inventory.is_consumed(prop.PACKING_ITEM):
		failures.append("repeated removal preserves one acquired/used inventory record")
	var legacy_removed: Dictionary=prop.mechanism_snapshot()
	legacy_removed.erase("packing")
	legacy_removed.erase("vent_cap")
	legacy_removed.erase("pitch_wedges")
	prop.restore_mechanism(legacy_removed)
	if part.station!=1 or acquired.count!=1: failures.append("legacy removed-packing migration does not grant again")
	await _inclined_support(prop,player,reviewer,part,failures)
	# Finite steam is spent by the leak, not delivered as useful emitter heat.
	var balance := HeatBalance.new()
	balance.configure({"floors":[{"markers":[{"kind":"radiator","id":"A","unit":"A"},{"kind":"radiator","id":"B","unit":"B"}]}]})
	balance.update_radiator("A",1,2,.35)
	balance.update_radiator("B",1,2,.35)
	var healthy: float=balance.result_for("B").heat
	balance.update_radiator("A",1,2,.35,1.0)
	var lost: float=balance.result_for("A").steam_lost+balance.result_for("B").steam_lost
	if absf(balance.total_delivered_heat()+lost-1.24)>.000001 or balance.result_for("A").heat!=0 or balance.result_for("B").heat>=healthy:
		failures.append("leak conserves finite budget and reduces other heat")
	print("PACKING PASS COMPLETE")

func _inclined_support(prop: Node3D,player: Node3D,reviewer: Node3D,part: RigidBody3D,failures: Array) -> void:
	var shelf := StaticBody3D.new()
	shelf.name="RealInclinedSupport"
	shelf.position=Vector3(1.2,.35,.4)
	shelf.rotation.z=deg_to_rad(10.0)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(.5,.04,.5)
	collision.shape=box
	shelf.add_child(collision)
	add_child(shelf)
	var shelf_draw := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=box.size
	shelf_draw.mesh=mesh
	shelf_draw.material_override=MatLib.get_mat("timber").duplicate()
	shelf.add_child(shelf_draw)
	await get_tree().create_timer(.6).timeout
	var contact := _packing_contact(part,prop)
	var landing := Vector3(1.2,.62,.4)
	player.camera.global_position=(contact+landing)*.5+Vector3(0,.5,1.0)
	player.camera.look_at(contact)
	reviewer._click(player)
	if not player._grab.active() or prop._native_held!="packing": failures.append("packing acquisition for actual inclined support");return
	await _carry_to(player,prop.to_local(landing))
	reviewer._click(player)
	await get_tree().create_timer(4.0).timeout
	var normal := shelf.global_basis*Vector3.UP
	var origin := shelf.to_global(Vector3(0,.02,0))
	var lowest := INF
	for collider: Node in part.get_children():
		if not collider is CollisionShape3D: continue
		for vertex: Vector3 in collider.shape.points: lowest=minf(lowest,(collider.to_global(vertex)-origin).dot(normal))
	print("PACKING INCLINED SUPPORT ",lowest," BODY ",part.global_position," ANGULAR ",part.angular_velocity," CORRECTION ",part.support_correction)
	if lowest<-.001 or lowest>.004: failures.append("packing contacts real raised inclined support")
	await _capture_part(player,prop,part,"packing_on_inclined_support")

func _capture_part(player: Node3D,prop: Node3D,part: Node3D,label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): return
	var point := part.to_global(Vector3(.012,0,-.02))
	var previous_fov: float=player.camera.fov
	player.camera.fov=48.0
	player.camera.global_position=point+prop.global_basis*Vector3(.12,.18,-.24)
	player.camera.look_at(point)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))!=OK: _capture_failed=true
	player.camera.fov=previous_fov

func _packing_contact(part: RigidBody3D,prop: Node3D) -> Vector3:
	var toward_eye: Vector3=prop.global_basis*Vector3(-.03,.10,-.32).normalized()
	var best := -INF
	var chosen := part.global_position
	for collider: CollisionShape3D in part._targets:
		var world: Vector3=collider.global_position
		var score := (world-part.global_position).dot(toward_eye)
		if score>best:
			best=score
			chosen=world
	return chosen

func _carry_to(player: Node3D,goal: Vector3) -> void:
	for index in 160:
		if not player._grab.active(): return
		var grip: Dictionary=player._grab.target
		var part: Node3D=grip.part
		var contact: Vector3=part.to_global(player._grab.contact)
		var destination: Vector3=grip.frame.to_global(goal)+part.global_basis*player._grab.contact
		if part.position.distance_to(goal)<.0005: return
		var axis: Vector3=(contact-player.camera.global_position).normalized()
		var depth := (destination-contact).dot(axis)
		if absf(depth)>.0001:
			var wheel := InputEventMouseButton.new()
			wheel.pressed=true
			wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN if depth>0 else MOUSE_BUTTON_WHEEL_UP
			wheel.factor=minf(3.0,absf(depth)/.025)
			player._unhandled_input(wheel)
		contact=part.to_global(player._grab.contact)
		var motion := InputEventMouseMotion.new()
		motion.relative=player.camera.unproject_position(destination)-player.camera.unproject_position(contact)
		player._unhandled_input(motion)
