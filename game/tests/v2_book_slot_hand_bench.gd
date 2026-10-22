extends "res://tests/v2_readable_library_bench.gd"
## Diagnostic of stored slots and the real pickup/inspection input path.
func _run() -> void:
	RealityState.persistence_enabled=false
	check(contact_precision.bind(get_world_3d()),"native contact precision")
	var stock:=preload("res://scripts/building/v2_readable_library_stock.gd").new()
	if not check(stock.prepare(),"native library prepares"): get_tree().quit(1);return
	var shelf:=Shelf.new();shelf.native_stock=stock;shelf.owner_name="Iris Bell";shelf.unit="5C";shelf.case_style="plain";add_child(shelf)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-25,0);sun.light_energy=1.;add_child(sun)
	var floor_body:=StaticBody3D.new();floor_body.position.y=-.1;add_child(floor_body)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(8,.2,8);shape.shape=box;floor_body.add_child(shape)
	player=PlayerController.new();player.position=Vector3(0,.02,1.2);add_child(player);player.camera.make_current();player.set_lamp_enabled(true)
	check(player._light_mask==null,"shared player constructs no photographic flare overlay")
	player.set_beam_mask_enabled(true);player.set_lamp_enabled(false);player.set_lamp_enabled(true)
	check(player._light_mask==null and player.flashlight.light_projector==null,"lamp toggles and old enable API cannot restore retired overlay")
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.06,.07,.085)
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var world:=WorldEnvironment.new();world.environment=environment;add_child(world)
	var air:=preload("res://scripts/building/orison_v2_lamp_atmosphere.gd").new();add_child(air)
	check(air.setup(player,environment),"production volumetric light initializes")
	var original: Dictionary=shelf.library_snapshot()
	for frame in 20: await get_tree().physics_frame
	for book: Node3D in shelf._books.values():
		check(book.freeze and book.shelf_slot>=0,"stored book excluded from simulation: "+book.stock_id)
		check(not book.is_physics_processing(),"stored book has no polling: "+book.stock_id)
	check(shelf.valid_library(original),"slot payload validates")
	var encoded: Dictionary=JSON.parse_string(JSON.stringify(original,"",true,true))
	check(shelf.valid_library(encoded),"slot JSON payload validates")
	shelf.restore_order(encoded)
	check(equivalent(shelf.library_snapshot(),original),"slot JSON round trip")
	var legacy:=original.duplicate(true);legacy.schema_version=2;legacy.erase("slots")
	for entry: Dictionary in legacy.books.values(): entry.erase("slot")
	check(shelf.valid_library(legacy),"legacy schema 2 accepted")
	shelf.restore_order(legacy)
	for book: Node3D in shelf._books.values(): check(book.freeze and book.shelf_slot>=0,"legacy resting book adopts slot: "+book.stock_id)
	player.set_mouse_released(false)
	var book: Node3D=shelf._books.values()[2]
	check(await grab_visible_stock(book),"real primary click picks up binding")
	if player._grab.active():
		for frame in 110: await get_tree().physics_frame
		check(player._grab.active() and player._grab.holding_pickup(),"pickup remains in hand")
		var wanted: Vector3=player.camera.global_transform*Vector3(.17,-.16,-.48)
		check((book.global_transform*book.pickup_centre()).distance_to(wanted)<.003,"binding reaches FPS held pose")
		check(book.shelf_slot==-1,"pickup vacates placement spot")
		var yaw:=player.rotation.y
		var motion:=InputEventMouseMotion.new();motion.relative=Vector2(12,0);player._unhandled_input(motion)
		for frame in 8: await get_tree().physics_frame
		check(not is_equal_approx(yaw,player.rotation.y),"mouse looks while carrying pickup")
		var hand_wall:=StaticBody3D.new();var hand_shape:=CollisionShape3D.new();var hand_box:=BoxShape3D.new()
		hand_box.size=Vector3(.5,.12,.015);hand_shape.shape=hand_box;hand_wall.add_child(hand_shape);add_child(hand_wall)
		hand_wall.global_basis=player.camera.global_basis
		hand_wall.global_position=book.global_transform*book.pickup_centre()+player.camera.global_basis.z*.05
		for frame in 2: await get_tree().physics_frame
		var wheel:=InputEventMouseButton.new();wheel.pressed=true;wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.factor=3.;player._unhandled_input(wheel)
		for frame in 16: await get_tree().physics_frame
		check(player._grab.active() and player._grab.feedback({}).state=="blocked","held stock obstruction drives authoritative reticle feedback")
		print("HELD WALL: active=",player._grab.active()," feedback=",player._grab.feedback({})," blocked=",book._hold_blocked," last=",book._last_motion)
		hand_wall.free()
		for frame in 25: await get_tree().physics_frame
		await capture("held_book")
		check(air.volume!=null and air.volume.visible and environment.volumetric_fog_enabled,"rendered carried light uses participating air")
		await space()
		check(player.inspecting() and not player._grab.active(),"Space enters free cursor inspection")
		for frame in 100: await get_tree().physics_frame
		check(book.freeze and not book.is_physics_processing(),"floating inspection settles without simulation or polling")
		var pose: Transform3D=book.global_transform
		for frame in 8: await get_tree().physics_frame
		check(book.global_transform.is_equal_approx(pose),"floating inspected book remains static")
		await capture("floating_book")
		var point: Vector3=book.left.to_global(Vector3(float(book.construction.width)*.7,float(book.construction.height)*.7,float(book.construction.thickness)*.5))
		await cursor_at(point)
		var selected: Dictionary=player._grab.find_target()
		print("FLOATING COVER TARGET: ",selected)
		check(selected.get("part")==book.left,"free cursor identifies actual cover")
		click()
		if player._grab.active():
			check(await hinge(PI),"actual mouse opens floating cover to full spread")
			await capture("floating_spread")
			click()
		await space()
	# Reconstruct before testing placement, with no hidden manipulation of the
	# active hand. The slot is a save authority, not a fresh rigid-body pile.
	shelf.restore_order(encoded)
	for frame in 3: await get_tree().physics_frame
	book=shelf._books.values()[2]
	var slot: int=book.shelf_slot
	check(book._claim("body"),"placement fixture claims book")
	book._carry(book.position+Vector3(0,0,.015))
	book._release()
	if book.shelf_slot!=slot:
		print("SLOT RETURN: pose=",book.transform," goal=",shelf.book_slots[slot]," opening=",book.opening," contact=",book._last_motion)
		for solid: CollisionShape3D in book._solids:
			for fraction: float in [0.,.5,1.]:
				var pose: Transform3D=book.transform.interpolate_with(shelf.book_slots[slot],fraction)
				var query: PhysicsShapeQueryParameters3D=book._shape_query(solid,book.get_parent().global_transform*pose)
				for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query,8): print("SLOT CONTACT: ",fraction," / ",solid.name," / ",hit.collider.get_path())
	check(book.shelf_slot==slot and book.freeze,"release into clear nearby slot parks book")
	var bad:=shelf.library_snapshot()
	bad.books[book.stock_id].slot=shelf._books.values()[0].shelf_slot
	check(not shelf.valid_library(bad),"duplicate occupancy rejected")
	var wall:=StaticBody3D.new();var obstruction:=CollisionShape3D.new();var obstruction_box:=BoxShape3D.new()
	obstruction_box.size=Vector3(.012,.025,.012);obstruction.shape=obstruction_box;wall.add_child(obstruction)
	add_child(wall);wall.global_position=book.global_transform*book.pickup_centre()
	check(book._claim("body"),"blocked placement fixture claims binding")
	book._carry(book.position+Vector3(0,0,.02))
	for frame in 2: await get_tree().physics_frame
	book._release()
	check(book.shelf_slot==-1,"occupied placement is refused without disabling its blocker")
	wall.free();shelf.restore_order(encoded)
	for frame in 3: await get_tree().physics_frame
	var permutation: Array=shelf.sorter.order.duplicate();permutation.reverse();shelf.restore_order(permutation)
	var rearranged: Dictionary=JSON.parse_string(JSON.stringify(shelf.library_snapshot(),"",true,true))
	var rebuilt:=Shelf.new();rebuilt.native_stock=stock;rebuilt.owner_name="Iris Bell";rebuilt.unit="5C";rebuilt.case_style="plain";rebuilt.position.x=3.;add_child(rebuilt)
	check(rebuilt.valid_library(rearranged),"rearranged placement slots validate on a fresh owner")
	rebuilt.restore_order(rearranged)
	check(equivalent(rebuilt.library_snapshot(),rearranged),"fresh native owner rebuilds rearranged slot poses and occupancy")
	shelf.restore_order(encoded)
	for frame in 3: await get_tree().physics_frame
	book=shelf._books.values()[2]
	check(await grab_visible_stock(book),"binding can be picked up again after restoration")
	for frame in 100: await get_tree().physics_frame
	click()
	check(not player._grab.active() and not book.freeze and book.shelf_slot==-1,"second primary click releases held book outside a placement slot")
	print("BOOK SLOT HAND DIAGNOSTIC: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	get_tree().quit(failures.size())
