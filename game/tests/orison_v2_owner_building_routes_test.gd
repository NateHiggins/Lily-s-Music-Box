extends "res://tests/orison_v2_owner_service_finish_test.gd"
## Original input/physics route helpers, embedded without constructing worlds.
class LiftWalker extends "res://tests/orison_v2_elevator_route_test.gd":
	func _ready() -> void: pass
class InnerWalker extends "res://tests/orison_v2_inner_door_test.gd":
	func _ready() -> void: pass
class FrontWalker extends "res://tests/orison_v2_front_entry_route_test.gd":
	func _ready() -> void: pass
	func _route() -> void:
		var door:=world.adapter.resolve("F01_DOOR_06").get_node("F01_DOOR_06_Leaf") as DoorProp
		if not _require(not door.open and door.leaf_state=="closed","original entrance starts closed"):return
		var contact:=false
		player.face_world_point(door._body.to_global(Vector3(door.width*.5,1.1,door._hinge_offset)))
		Input.action_press("move_forward")
		for frame in 45:
			await get_tree().physics_frame
			for i in player.get_slide_collision_count():
				if player.get_slide_collision(i).get_collider()==door._body:contact=true
		Input.action_release("move_forward")
		if not _require(contact,"closed native entrance stops live player"):return
		if not await _walk(Vector3(0,0,-10.3)):return
		if not await _operate_entry(door,true,"inside_open"):return
		if not await _walk(Vector3(0,0,-13.15)):return
		if not await _operate_entry(door,false,"outside_close"):return
		if not await _operate_entry(door,true,"outside_open"):return
		if not await _walk(Vector3(0,0,-10.3)):return
		if not await _operate_entry(door,false,"inside_close"):return
		_require(player.is_on_floor() and not player.noclip,"entrance round trip ends with gravity and collision")
class RoofWalker extends "res://tests/orison_v2_roof_route_test.gd":
	func _ready() -> void: pass
	func _prepare_player_start() -> void:
		player.global_position=world.adapter.root.to_global(Vector3(-1.35,19.25,0));player.velocity=Vector3.ZERO
	func _route() -> void:
		if not await _open_door("ROOF_PUBLIC_DOOR"):return
		if not await _walk(Vector3(-3.6,19.2,0)):return
		if not await _close_door("ROOF_PUBLIC_DOOR"):return
		for point in [Vector3(-12,19.2,0),Vector3(-12,19.2,-9),Vector3(0,19.2,-9),Vector3(14,19.2,-9),Vector3(14,19.2,10.8),Vector3(7.5,19.2,10.8),Vector3(7.5,19.2,3),Vector3(8,19.2,3)]:
			if not await _walk(point):return
		await _roof_capture("roof_service_approach",Vector3(10.3,20.1,3))
		if not await _open_door("ROOF_SERVICE_DOOR"):return
		if not await _walk(Vector3(10.3,19.2,3)):return
		if not await _walk(Vector3(8.1,19.2,3)):return
		if not await _close_door("ROOF_SERVICE_DOOR"):return
		_require(player.is_on_floor() and not player.noclip,"roof approaches retain live gravity and collision")

func _init() -> void:
	contract_key="owner_building_routes"
	contract_scope="Existing closed entrance collision and keyboard E round trip, inner vestibule full swing/both approaches/key operations, roof public/service-door approaches, seven-stop passenger lift route with live platform carry, empty-shaft barrier and physical F06 recall. One shared production world; original helpers and inputs; route traces and owner teardown. No save reconstruction."

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	contract_started=Time.get_ticks_msec()
	var traces: Dictionary={}
	var choices: Dictionary={"front":FrontWalker,"inner":InnerWalker,"roof":RoofWalker,"lift":LiftWalker}
	var selected: Array=choices.keys()
	var only:=OS.get_environment("ORISON_BUILDING_ROUTES")
	if not only.is_empty():selected=Array(only.split(","))
	var directory:=OS.get_environment("SHOT_DIR")
	for key: String in selected:
		check(choices.has(key),"registered route: "+key)
		if not choices.has(key):continue
		var walker: Node=choices[key].new();walker.world=world;walker.player=world.player;add_child(walker)
		retained.append(weakref(world.elevator if key=="lift" else world.player))
		var destination:=directory.path_join(key);DirAccess.make_dir_recursive_absolute(destination)
		OS.set_environment("SHOT_DIR",destination if capture_enabled else "")
		world.player.set_physics_process(true);world.player.set_process_unhandled_input(true)
		world.player.camera.make_current();world.player.set_lamp_enabled(true)
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		walker._prepare_player_start()
		await get_tree().physics_frame;await get_tree().physics_frame
		await walker._route()
		Input.action_release("move_forward")
		check(walker.failures.is_empty(),"original input/physics route completed: "+key)
		for failure: String in walker.failures:failures.append(key+": "+failure)
		traces[key]=walker.trace.duplicate(true)
		world.player.set_physics_process(false);walker.free()
		if not failures.is_empty():break
	OS.set_environment("SHOT_DIR",directory)
	validation_completed=true
	return {"checks":checks,"failures":failures,"routes":traces}
