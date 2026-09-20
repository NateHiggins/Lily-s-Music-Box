extends Node
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Loader := preload("res://scripts/building/orison_v2_bookshelves.gd")
const State := preload("res://scripts/building/orison_v2_household_state.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("BOOKSHELVES: " + label)
class ManifestAdapter extends RefCounted:
	var nodes := {}
	func resolve(identity: String) -> Node: return nodes.get(identity)

func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
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
			"canonical":bad.shelves[-1].canonical_book=""
			"bounds":bad.shelves[0].bounds[0][0]=NAN
		check(not loader.validate(bad,adapter),"invalid bookshelf manifest rejected: "+change)
	for node: Node in adapter.nodes.values():node.free()
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	check(not world.startup_failed,"production world starts")
	if not world.startup_failed: await exercise(world, source)
	world.shutdown_for_tests();world.free()
	await get_tree().process_frame
	check(find_children("*","BookshelfPanel",true,false).is_empty(),"no panel survives retired world")
	print("BOOKSHELVES: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
func exercise(world: OrisonV2RuntimeRoot, source: Dictionary) -> void:
	var player := world.player
	player.set_physics_process(false);player.set_process_unhandled_input(false)
	player.camera.make_current()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .38;capsule.height = 1.524
	for record: Dictionary in source.shelves:
		var shelf := world.adapter.resolve(record.id) as BookshelfProp
		var stance := world.adapter.resolve(record.id+"_STANCE") as Node3D
		check(shelf != null and stance != null,"native shelf and approach: " + str(record.id))
		if shelf == null or stance == null: continue
		player.global_position = stance.global_position
		player.camera.global_position = player.global_position+Vector3.UP*player.STANDING_EYE
		player.camera.look_at(shelf.to_global(Vector3(0,1.03,0)))
		await get_tree().physics_frame
		var space := player.get_world_3d().direct_space_state
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape=capsule;q.transform=Transform3D(Basis.IDENTITY,player.global_position+Vector3.UP*.8);q.exclude=[player.get_rid()]
		check(space.intersect_shape(q).is_empty(),"standing capsule clear: "+str(record.id))
		var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position,shelf.to_global(Vector3(0,1.03,0)))
		ray.collide_with_areas=true;ray.exclude=[player.get_rid()]
		var hit := space.intersect_ray(ray)
		check(not hit.is_empty() and shelf.is_ancestor_of(hit.get("collider")),"unobstructed player interaction ray")
		var body_ray := PhysicsRayQueryParameters3D.create(shelf.to_global(Vector3(0,.6,1)),shelf.to_global(Vector3(0,.6,-.2)))
		body_ray.exclude=[player.get_rid()]
		var body_hit := space.intersect_ray(body_ray)
		check(not body_hit.is_empty() and shelf.is_ancestor_of(body_hit.get("collider")),"installed case blocks walking")
		check(shelf.owner_name == record.owner and shelf.case_style == record.style,"authored owner and case retained")
		var actual: AABB=shelf.call("_visual_bounds")
		var lo := Vector3(record.bounds[0][0],record.bounds[0][1],record.bounds[0][2])
		var hi := Vector3(record.bounds[1][0],record.bounds[1][1],record.bounds[1][2])
		check(AABB(lo,hi-lo).grow(.001).encloses(actual),"native visual fits reserved clearance")
		check(shelf.sorter.order.size()>3,"resident library populated")
		if record.unit == "6C":check(shelf.sorter.order.has("prospectus"),"Mae keeps canonical prospectus")
		var before := shelf.sorter.order.duplicate()
		player.use_primary_interaction()
		var panel: Node = shelf.get("_panel")
		check(is_instance_valid(panel) and player.call_locked,"player E opens actual sorting panel")
		if not is_instance_valid(panel):continue
		var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
		panel.set("_hover",0);panel.call("_on_input",click)
		check(shelf.sorter.held==0 and shelf.sorter.order==before,"taking book does not discard saved identity")
		panel.set("_hover",before.size()-1);panel.call("_on_input",click)
		check(shelf.sorter.order[-1]==before[0] and shelf.sorter.order!=before,"native UI moves book through resident sequence")
		check(RealityState.data[State.KEY].records[record.id].value==shelf.sorter.order,"UI change commits through household save owner")
		await get_tree().process_frame
		check(shelf.get_node("Books").get_child_count()==2,"two batched book meshes after sort")
		if record.style=="sectional":
			await get_tree().create_timer(.6).timeout
			check(is_equal_approx(shelf.get("_door_open"),1.0),"sectional glass lifts through native mechanism")
		panel.call("close")
		await get_tree().process_frame
		check(not player.call_locked and shelf.sorter.held==-1,"normal close releases player and held slot")
	# Reload while holding a book: no old panel can edit the replaced facts.
	var last := world.adapter.resolve("F06_6C_BOOKSHELF_01") as BookshelfProp
	last.interact(player)
	var open_panel: Node=last.get("_panel")
	var panel_ref: WeakRef = weakref(open_panel)
	last.sorter.touch(0)
	var saved: Dictionary=world.household_state.snapshot()
	saved.records[str(last.name)].value.reverse()
	RealityState.data[State.KEY]=saved
	RealityState.state_changed.emit()
	await get_tree().process_frame
	check(panel_ref.get_ref()==null and not player.call_locked and last.sorter.held==-1,"mid-session load retires panel and restores held book")
	last.interact(player)
	check(player.call_locked,"new panel can open after load")
