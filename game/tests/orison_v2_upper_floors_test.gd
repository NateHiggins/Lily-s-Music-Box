extends Node
## Prepared composition/floor/door ownership test; not a played route receipt.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Loader := preload("res://scripts/building/orison_v2_upper_floor_doors.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("UPPER FLOORS: " + label)

func _ready() -> void:
	RealityState.persistence_enabled = false
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Loader.PROGRAM_PATH))
	var probes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/v2_upper_floor_probes.json"))
	for cycle in 2:
		RealityState.reset_campaign_for_tests()
		var world := Runtime.instantiate() as OrisonV2RuntimeRoot
		add_child(world)
		check(not world.startup_failed, "full runtime with both upper floors starts")
		if world.startup_failed:
			world.shutdown_for_tests()
			world.free()
			break
		await get_tree().physics_frame
		var blockout := world.get("_blockout") as Node3D
		var refs: Array[WeakRef] = []
		var moving: Array[DoorProp] = []
		for identity: String in source.doors:
			var anchor := world.adapter.resolve(identity) as Node3D
			var door := anchor.get_node_or_null(identity+"_Leaf") as DoorProp
			check(door != null and anchor.get_node_or_null("Hinge") == null, "one physical leaf replaces placeholder: " + identity)
			if door == null: continue
			refs.append(weakref(door))
			var spec: Dictionary = source.doors[identity]
			check(door.unit == spec.unit and door.leaf_state == spec.leaf_state, "door retains unit and restriction")
			check(is_equal_approx(door.position.z,float(spec.mount_offset)), "hinge sits on reveal face")
			for part: String in ["FrameLeft", "FrameRight", "FrameHead"]:
				var frame := anchor.get_node(part) as MeshInstance3D
				check(is_equal_approx((frame.mesh as BoxMesh).size.z,.22), "deep jamb covers mounted hinge")
			door.npc_set_open(true)
			if spec.leaf_state == "locked":
				check(not door.open, "restricted threshold refuses an ordinary open request")
			else: moving.append(door)
		await get_tree().create_timer(.65).timeout
		for door: DoorProp in moving:
			check(door.open and is_equal_approx(absf(door._body.rotation.y),deg_to_rad(100)), "new leaf reaches full native swing")
		for floor: Dictionary in probes.floors:
			var y := 12.8 if floor.level == "F05" else 16.0
			for room: Dictionary in floor.rooms:
				var at := Vector3(room.point[0],y,room.point[1])
				var query := PhysicsRayQueryParameters3D.create(blockout.to_global(at+Vector3.UP),blockout.to_global(at-Vector3(0,.25,0)))
				var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty(), "occupied upper room has a real floor: " + str(room.id))
				if not hit.is_empty():
					check(absf(blockout.to_local(hit.position).y-y)<.025, "floor remains at authored storey height")
		var loader := Loader.new()
		check(loader.validate(source,world.layout), "full upper program validates")
		check(not loader.mount(world.adapter,world.layout), "second upper door owner refused")
		for mutation: String in ["missing_program", "wrong_resident", "duplicate_room", "unlock", "hinge", "missing_leaf"]:
			var bad := source.duplicate(true)
			match mutation:
				"missing_program": bad.programs.pop_back()
				"wrong_resident": bad.programs[0].resident = "mina_hale"
				"duplicate_room": bad.programs[0].rooms.append(bad.programs[0].rooms[0])
				"unlock": bad.doors.F05_DOOR_05.leaf_state = "closed"
				"hinge": bad.doors.F05_DOOR_02.mount_offset = 0
				"missing_leaf": bad.doors.erase("F05_DOOR_02")
			check(not loader.validate(bad,world.layout), "invalid upper program refused: " + mutation)
		world.shutdown_for_tests()
		world.free()
		for ref: WeakRef in refs: check(ref.get_ref()==null, "upper leaf retires with its world")
	print("UPPER FLOORS: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
