extends "res://tests/v2_readable_library_bench.gd"
## Installed controls and real disk rebuild. Scoped diagnostic, no ledger admission.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Loader := preload("res://scripts/building/orison_v2_bookshelves.gd")
const State := preload("res://scripts/building/orison_v2_household_state.gd")
var _round_complete:=false
class ManifestAdapter extends RefCounted:
	var nodes := {}
	func resolve(identity: String) -> Node: return nodes.get(identity)


func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	var original_path: String=RealityState.save_path
	var test_path: String="user://v2_readable_library_%d.json"%Time.get_ticks_usec()
	RealityState.save_path=test_path
	await installed_round()
	check(_round_complete,"complete installed programme reaches final teardown")
	RealityState.save_path=original_path
	for suffix: String in ["",".bak",".tmp",".txn"]:
		var path:=ProjectSettings.globalize_path(test_path+suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("V2 INSTALLED READABLE LIBRARY: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func installed_round() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Loader.PATH))
	var adapter := ManifestAdapter.new()
	for row: Dictionary in source.shelves:
		adapter.nodes[row.id] = Marker3D.new()
		adapter.nodes[row.id+"_STANCE"] = Marker3D.new()
	var loader := Loader.new()
	check(loader.validate(source,adapter),"complete authored manifest accepted")
	for change: String in ["missing","duplicate","owner","style","canonical","bounds"]:
		var bad := source.duplicate(true)
		match change:
			"missing":bad.shelves.pop_back()
			"duplicate":bad.shelves[-1]=bad.shelves[0].duplicate(true)
			"owner":bad.shelves[0].owner="Mae Kessler"
			"style":bad.shelves[0].style="plain"
			"canonical":
				for row: Dictionary in bad.shelves:
					if row.unit=="6C": row.canonical_book=""
			"bounds":bad.shelves[0].bounds[0][0]=NAN
		check(not loader.validate(bad,adapter),"invalid bookshelf manifest rejected: "+change)
	for node: Node in adapter.nodes.values():node.free()
	var allowance:=PhysicsServer3D.space_get_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION)
	var world:=Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	if not check(not world.startup_failed,"production world starts: "+world.startup_failure_reason):
		world.shutdown_for_tests();world.free();return
	player=world.player
	player.set_physics_process(false);player.set_process_unhandled_input(false)
	player.camera.make_current();player.set_lamp_enabled(true)
	var capsule:=CapsuleShape3D.new();capsule.radius=PlayerController.BODY_RADIUS;capsule.height=PlayerController.STANDING_HEIGHT
	for record: Dictionary in source.shelves:
		player.cancel_manipulation()
		var shelf: Node3D=world.adapter.resolve(record.id)
		var stance: Node3D=world.adapter.resolve(record.id+"_STANCE")
		if not check(shelf!=null and stance!=null,"native shelf and original approach: "+str(record.id)): continue
		check(shelf.owner_name==record.owner and shelf.case_style==record.style,"resident and style retained: "+str(record.id))
		check(shelf._books.size()==shelf.sorter.order.size() and shelf._ends.size()==2,"individual books and two bookends: "+str(record.id))
		var lo:=Vector3(record.bounds[0][0],record.bounds[0][1],record.bounds[0][2])
		var hi:=Vector3(record.bounds[1][0],record.bounds[1][1],record.bounds[1][2])
		check(AABB(lo,hi-lo).grow(.001).encloses(shelf.native_stock._bounds(shelf._case_record.parts)),"native case within authored reserve: "+str(record.id))
		player.set_mouse_released(false);player.global_position=stance.global_position
		player.camera.position=Vector3(0,PlayerController.STANDING_EYE,0)
		player.camera.look_at(shelf.to_global(Vector3(-float(shelf._case_record.width)*.5+.009,1.08,.13)))
		for frame in 4: await get_tree().physics_frame
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule
		query.transform=Transform3D(Basis.IDENTITY,player.global_position+Vector3.UP*PlayerController.STANDING_HEIGHT*.5)
		query.exclude=[player.get_rid()];query.margin=0.;query.collision_mask=player.collision_mask
		var raw_contacts:=get_world_3d().direct_space_state.intersect_shape(query)
		for hit: Dictionary in raw_contacts: print("RAW STANCE CONTACT: ",record.id," foot=",stance.global_position," with=",hit.collider.get_path()," rest=",get_world_3d().direct_space_state.get_rest_info(query))
		# A walking CharacterBody stands at its real safe margin above a floor.
		# The marker names the floor datum; placing a capsule exactly on it can
		# produce micron-scale floor overlap at upper-storey float precision.
		player.global_position.y+=player.safe_margin
		query.transform.origin.y+=player.safe_margin
		var contacts:=get_world_3d().direct_space_state.intersect_shape(query)
		for hit: Dictionary in contacts: print("BLOCKED STANCE: ",record.id," with=",hit.collider.get_path())
		check(contacts.is_empty(),"actual standing capsule clears original stance: "+str(record.id))
		click()
		if not check(player._grab.active() and player._grab.target.owner==shelf,"primary grabs installed case: "+str(record.id)): continue
		await space()
		if not check(player.inspecting() and player.inspect_owner==shelf,"Space inspects installed case: "+str(record.id)): player.cancel_manipulation();continue
		var camera_pose:=player.camera.global_transform
		if not shelf._sashes.is_empty(): await open_installed_sash(shelf)
		var book: Node3D=shelf._books[shelf.sorter.order[2]]
		await cursor_at(book.to_global(Vector3(-.0025,float(book.construction.height)*.5,0)));click()
		if check(player._grab.active() and player._grab.target.part==book,"cursor grabs installed individual binding: "+str(record.id)):
			check(await carry(book.position+Vector3(0,.04,.30)),"mouse extracts installed book: "+str(record.id))
			click();check(not player._grab.active() and not book.freeze,"release restores physical book: "+str(record.id))
		if player._grab.active(): player._grab.release()
		check(player.camera.global_transform.is_equal_approx(camera_pose),"installed case inspection camera stays fixed: "+str(record.id))
		await capture("installed_"+str(record.unit))
		await space()
		var end: Node3D=shelf._ends.left
		# Focus a loose stock from ordinary view, including one displaced by
		# another book. Whole-case inspection must not hide a fallen bookend.
		for frame in 120:
			if end.sleeping or (end.linear_velocity.length()<.005 and end.angular_velocity.length()<.005): break
			await get_tree().physics_frame
		if check(await grab_visible_stock(end),"primary grabs an exposed part of installed bookend in its actual position: "+str(record.id)):
			var visible_approach:=player.camera.global_transform
			await space()
			check(player.camera.global_transform.is_equal_approx(visible_approach),"end inspection retains the acquired visible approach: "+str(record.id))
			if check(player.inspecting() and end.freeze,"Space focuses and supports installed bookend: "+str(record.id)):
				var end_camera:=player.camera.global_transform
				if check(await grab_visible_stock(end),"cursor grabs exposed native surface of focused bookend: "+str(record.id)):
					var start: Vector3=end.position
					var foot:=AABB()
					var first_vertex:=true
					for solid: CollisionShape3D in end._solids:
						if "__Foot_" not in str(solid.name): continue
						for vertex: Vector3 in solid.shape.points:
							var point: Vector3=end.transform*solid.transform*vertex
							if first_vertex: foot=AABB(point,Vector3.ZERO);first_vertex=false
							else: foot=foot.expand(point)
					check(not first_vertex,"native foot supplies load bounds: "+str(record.id))
					var rear:=foot.position.z
					var front:=rear
					for loaded: Node3D in shelf._books.values():
						var bounds:=AABB();var first:=true
						for solid: CollisionShape3D in loaded._solids:
							for vertex: Vector3 in solid.shape.points:
								var point: Vector3=loaded.transform*solid.transform*vertex
								if first: bounds=AABB(point,Vector3.ZERO);first=false
								else: bounds=bounds.expand(point)
						if bounds.position.x<foot.end.x and bounds.end.x>foot.position.x \
								and bounds.position.z<foot.end.z and bounds.end.z>foot.position.z \
								and bounds.position.y<foot.end.y+.005 and bounds.end.y>foot.end.y-.005:
							front=maxf(front,bounds.end.z)
					# Clear the actual load, not just one foot length. Slight upward
					# intent permits the real support to guide the outgoing draw.
					var distance:=maxf(.11,front-rear+.01)
					print("INSTALLED END DRAW: ",record.id," start=",start," rear=",rear," load_front=",front)
					check(await carry(start+Vector3(0,.002,distance)),"mouse draws the complete bookend foot out from under its load: "+str(record.id))
					check(await carry(end.position+Vector3(0,.01,0)),"mouse lifts the freed installed bookend: "+str(record.id));click()
				if player._grab.active(): player._grab.release()
				check(player.camera.global_transform.is_equal_approx(end_camera),"installed loose-stock inspection camera stays fixed: "+str(record.id))
		if player._grab.active(): player._grab.release()
		world.household_state.capture_now()
		var saved: Variant=RealityState.data.get(State.KEY,{}).get("records",{}).get(record.id,{}).get("value")
		check(saved is Dictionary and shelf.valid_library(saved) and equivalent(saved,shelf.library_snapshot()),"same household owner captures physical state: "+str(record.id))
		await capture("installed_"+str(record.unit)+"_bookend")
		await space()
	check(find_children("*","BookshelfPanel",true,false).is_empty(),"no legacy sorting minigame")
	var wanted: Dictionary=world.household_state.snapshot()
	check(RealityState.save_game(),"actual disk save succeeds")
	var owner_ref: WeakRef=weakref(world.household_state)
	world.shutdown_for_tests();world.free()
	check(owner_ref.get_ref()==null,"first household save owner retired")
	check(is_equal_approx(PhysicsServer3D.space_get_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION),allowance),"V2 teardown restores prior contact setting")
	RealityState.reset_campaign_for_tests();RealityState.load_game()
	check(RealityState.data.get(State.KEY)==JSON.parse_string(JSON.stringify(wanted,"",true,true)),"same durable household payload reloads from disk")
	if OS.get_environment("LIBRARY_INSTALLED_CONTROLS_ONLY")=="1":
		print("INSTALLED CONTROL-ONLY: second-world reconstruction intentionally not rerun")
		_round_complete=true;return
	world=Runtime.instantiate() as OrisonV2RuntimeRoot;add_child(world)
	if check(not world.startup_failed,"disk state reconstructs on fresh physical owners: "+world.startup_failure_reason):
		var restored: Dictionary=world.household_state.snapshot()
		for record: Dictionary in source.shelves:
			check(equivalent(restored.records[record.id],wanted.records[record.id]),"pose/opening/end/sash state rebuilds: "+str(record.id))
		# Legacy order-only saves remain valid and adopt native construction.
		var legacy: Dictionary=JSON.parse_string(JSON.stringify(wanted))
		for record: Dictionary in source.shelves: legacy.records[record.id].value=legacy.records[record.id].value.order
		RealityState.data[State.KEY]=legacy;RealityState.state_changed.emit()
		for record: Dictionary in source.shelves:
			var shelf: Node3D=world.adapter.resolve(record.id)
			check(shelf.sorter.order==legacy.records[record.id].value and shelf._books.size()==legacy.records[record.id].value.size(),"legacy order migrates without lost identities: "+str(record.id))
	world.shutdown_for_tests();world.free()
	check(is_equal_approx(PhysicsServer3D.space_get_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION),allowance),"rebuilt world restores contact setting on teardown")

	_round_complete=true

func open_installed_sash(shelf: Node3D) -> void:
	var sash: Node3D=shelf._sashes[1]
	var rail: MeshInstance3D=sash.leaf.get_node("sectional_sash1__Rail0")
	await cursor_at(rail.global_transform*rail.get_aabb().get_center());click()
	if not check(player._grab.active() and player._grab.target.part==sash.leaf,"installed lower rail supplies lift grip"): return
	check(await hinge(PI*.5),"mouse raises installed glazing");click()
	var upper: MeshInstance3D=sash.leaf.get_node("sectional_sash1__Rail1")
	await cursor_at(upper.global_transform*upper.get_aabb().get_center());click()
	if check(player._grab.active() and player._grab.target.kind=="slider","installed raised rail supplies track grip"):
		check(await hinge(float(sash.record.inset_limit)),"mouse stores installed glazing");click()
	if player._grab.active(): player._grab.release()
