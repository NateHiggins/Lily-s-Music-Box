extends "res://tests/orison_v2_vertical_route_test.gd"
const Hand := preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand
var checks: Array[Dictionary]=[]

func _init() -> void: route_label="V2 PASSAGE SHOP DOOR REPAIR"

func check(ok: bool, label: String) -> bool:
	checks.append({"ok":ok,"label":label})
	print("SHOP DOOR CHECK: ",label," = ",ok)
	if not ok: failures.append(label)
	return ok

func _prepare_player_start() -> void:
	var door: DoorProp=world.passage_region.doors.values()[0]
	player.global_position=door.to_global(Vector3(.45,.04,1.15));player.velocity=Vector3.ZERO

func _route() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var hand:=Hand.new();add_child(hand);hand.player=player
	var sweep_rows: Array=[]
	var expected: Dictionary={}
	var expected_locks: Dictionary={}
	# Reproduce the continuous route's old outside stance. The player's own
	# capsule remains a real obstruction; do not weaken the original sweep.
	var hardware: DoorProp=world.passage_region.doors.SITE_SHOP_DOOR_HARDWARE_PAINT
	var center:=hardware.to_global(Vector3(hardware.width*.5,0,0))
	player.global_position=Vector3(12.4966,.012,center.z-.006)
	await get_tree().physics_frame;await get_tree().physics_frame
	var player_contacts:=0
	var trial:=hardware._body.transform;trial.basis=Basis(Vector3.UP,1.035)
	for shape: CollisionShape3D in hardware._body.find_children("*","CollisionShape3D",false,false):
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=hardware.global_transform*trial*shape.transform;query.collision_mask=hardware._body.collision_mask;query.exclude=[hardware._body.get_rid()];query.margin=.001
		for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,16):
			print("ORIGINAL SHOP STANCE BLOCKER: ",hit.collider.get_path())
			if hit.collider==player:player_contacts+=1
	check(player_contacts>0,"original approach capsule physically blocks the hardware leaf near59degrees")
	player.global_position=hardware.to_global(Vector3(.45,.04,1.15))
	await get_tree().physics_frame

	check(world.passage_region.doors.size()==11,"all eleven original shop identities remain")
	var inventory:=preload("res://tests/orison_v2_surface_inventory.gd").new()
	var native: Node=preload("res://assets/props/passage_shop_leaves.glb").instantiate()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/passage_shop_leaves.json"))
	check(FileAccess.get_sha256("res://assets/props/passage_shop_leaves.glb")==fixture.asset_sha256,"installed native export matches owning Blender build")
	var originals:=native.find_children("*","MeshInstance3D",true,false)
	check(originals.size()==13,"all thirteen authored native stocks imported")
	for draw: MeshInstance3D in originals:
		var mesh: Dictionary=inventory._mesh(draw.mesh)
		for surface: Dictionary in mesh.surfaces:
			check(not surface.missing_uv and surface.nonfinite_uv==0 and surface.degenerate_uv_triangles==0,str(draw.name)+" loaded native UVs are finite and nondegenerate")
	native.free()
	var representative: DoorProp=world.passage_region.doors.values()[0]
	for draw: MeshInstance3D in representative._body.find_children("*","MeshInstance3D",true,false):
		for surface in draw.mesh.get_surface_count():
			var finish:=draw.get_active_material(surface)
			var info: Dictionary=inventory._material(finish)
			check(not info.get("triplanar",false) and int(info.get("uv_mode",0))==0,"installed leaf finish samples native UVs")
			check(info.maps.size()>=3 and (info.get("normal_enabled",false) or info.get("has_normal_tex",false)),"installed leaf finish has custom albedo roughness and normal")
	for texture: Dictionary in inventory.texture_rows.values():
		check(texture.mips and texture.mip_levels>0,"installed leaf map has loaded mip levels")
	inventory.free()
	for identity: String in world.passage_region.doors:
		var door: DoorProp=world.passage_region.doors[identity]
		player.global_position=door.to_global(Vector3(.45,.04,1.15));player.velocity=Vector3.ZERO
		await get_tree().physics_frame
		check(world.household_state.snapshot().records.has(identity),identity+" belongs to existing household save authority")
		var shell:=door._body.get_child(0) as CollisionShape3D
		check(absf(shell.position.y-(shell.shape as BoxShape3D).size.y*.5-.016)<.000001,identity+" lower shell datum is 16 mm")
		check(door._body.find_children("*","CollisionShape3D",false,false).size()==7,identity+" retained shell and six pull supports are physical")
		# Independent whole-world compound sweep. Keep every obstruction owner.
		var blocked: Array=[]
		for degree in range(91):
			var pose:=door._body.transform;pose.basis=Basis(Vector3.UP,deg_to_rad(degree))
			for shape: CollisionShape3D in door._body.find_children("*","CollisionShape3D",false,false):
				var query:=PhysicsShapeQueryParameters3D.new()
				query.shape=shape.shape;query.transform=door.global_transform*pose*shape.transform
				query.collision_mask=door._body.collision_mask;query.exclude=[door._body.get_rid()];query.margin=.001
				for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,16):
					blocked.append({"degrees":degree,"part":str(shape.name),"owner":str(hit.collider.get_path())})
		sweep_rows.append({"id":identity,"blocked":blocked})
		check(blocked.is_empty(),identity+" complete shell and pull sweep clears 0 through 90 degrees")
		if not blocked.is_empty(): print("SHOP SWEEP BLOCKERS ",JSON.stringify(sweep_rows.back()))
		var was_locked:=door.leaf_state=="locked"
		if was_locked:
			player.face_world_point(door._body.to_global(Vector3(.065,1.35,door._hinge_offset+.0275)))
			await get_tree().physics_frame
			hand.click()
			for attempt in 3:
				var motion:=InputEventMouseMotion.new();motion.relative=Vector2(35,12)
				player._unhandled_input(motion)
				await get_tree().physics_frame
			check(is_zero_approx(door._body.rotation.y),identity+" locked leaf refuses real pointer motion")
			if player._grab.active():hand.click()
			# Existing key authority is the setup for unlocked manipulation, not a
			# claimed direct-manipulation key test or an invented lock bypass.
			check(not door.interact_key(player).is_empty(),identity+" existing key authority admits its key")
			while door._key_turning: await get_tree().physics_frame
		if door.open:
			check(await hand.operate(door._body.to_global(Vector3(.065,1.35,door._hinge_offset+.0275)),0,door),identity+" original open leaf closes by grab motion release")
		check(await hand.operate(door._body.to_global(Vector3(.065,1.35,door._hinge_offset+.0275)),.55,door),identity+" intermediate angle follows real pointer input")
		check(await hand.operate(door._body.to_global(Vector3(.065,1.35,door._hinge_offset+.0275)),PI*.5,door),identity+" real hand reaches fitted open stop")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join(identity+"_open.png"))
		check(await hand.operate(door._body.to_global(Vector3(.065,1.35,door._hinge_offset+.0275)),0,door),identity+" real hand returns to closed stop")
		if was_locked:
			check(not door.interact_key(player).is_empty(),identity+" original lock authority relocks the closed leaf")
			while door._key_turning: await get_tree().physics_frame
		else:
			check(await hand.operate(door._body.to_global(Vector3(.065,1.35,door._hinge_offset+.0275)),.4+expected.size()*.035,door),identity+" partial pose prepared through pointer input for disk save")
		if identity.ends_with("NEWS_CIGARS") and not was_locked:
			# The awake-building key policy can override the authored closed lock.
			# Exercise a locked save through the real key owner instead of assuming it.
			check(await hand.operate(door._body.to_global(Vector3(.065,1.35,door._hinge_offset+.0275)),0,door),identity+" closes through hand before key setup")
			check(not door.interact_key(player).is_empty(),identity+" existing key authority locks the closed leaf")
			while door._key_turning: await get_tree().physics_frame
			player.face_world_point(door._body.to_global(Vector3(.065,1.35,door._hinge_offset+.0275)))
			await get_tree().physics_frame
			hand.click()
			for attempt in 3:
				var motion:=InputEventMouseMotion.new();motion.relative=Vector2(35,12)
				player._unhandled_input(motion);await get_tree().physics_frame
			check(is_zero_approx(door._body.rotation.y),identity+" key-owned lock refuses actual pointer motion")
			if player._grab.active():hand.click()
		expected[identity]=door.mechanism_snapshot()
		expected_locks[identity]=door.leaf_state=="locked"
		check(door.valid_mechanism({"angle":deg_to_rad(100.0)}) and not door.valid_mechanism({"angle":deg_to_rad(101.0)}),identity+" legacy 100 degree record accepted, excessive travel refused")
	check(hand.follows_cursor,"projected leaf motion follows pointer direction")
	hand.free()
	var old_path:=RealityState.save_path
	var path:="user://tests/shop_door_"+Crypto.new().generate_random_bytes(8).hex_encode()+".json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	RealityState.save_path=path
	check(RealityState.save_game(),"existing RealityState writes actual disk save")
	var disk: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(disk is Dictionary and disk.has("v2_household_controls"),"disk contains existing household domain")
	world.shutdown_for_tests();world.free();world=null;player=null
	await get_tree().process_frame
	RealityState.data.clear();RealityState.load_game()
	world=Runtime.instantiate();add_child(world)
	await get_tree().create_timer(.5).timeout
	check(not world.startup_failed,"actual disk load and fresh world reconstruction succeed")
	player=world.player
	_prepare_player_start()
	for identity: String in expected:
		var door: DoorProp=world.passage_region.doors[identity]
		check(absf(float(door.mechanism_snapshot().angle)-float(expected[identity].angle))<.000001,identity+" partial angle survives disk and destruction")
		check((door.leaf_state=="locked")==bool(expected_locks[identity]),identity+" lock authority survives reconstruction")
	# Legacy migration exercises the production validator/restorer, independently
	# of physical hand travel. It cannot qualify a route or collision sweep.
	var migrated: DoorProp=world.passage_region.doors.values()[0]
	migrated.restore_mechanism({"angle":deg_to_rad(100.0)})
	check(absf(migrated._body.rotation.y-PI*.5)<.000001,"historical 100 degree pose migrates to fitted 90 degree stop")
	RealityState.save_path=old_path
	FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Eleven original shop doors: compound sweep, actual pointer input and disk/world reconstruction; stance placement and key setup are fixtures, not route or key acceptance.","checks":checks,"sweeps":sweep_rows,"expected":expected,"save_path":ProjectSettings.globalize_path(path)},"\t"))
