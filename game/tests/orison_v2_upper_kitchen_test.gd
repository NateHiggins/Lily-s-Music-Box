extends Node
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Prep := preload("res://scripts/building/orison_v2_prep_cabinet.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("UPPER KITCHENS: " + label)

func _ready() -> void:
	RealityState.persistence_enabled = false
	var probes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/v2_upper_kitchen_probes.json"))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json"))
	var programs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/upper_floor_programs.json"))
	check(probes.kitchens.size() == 6, "all six occupied upper kitchens")
	for cycle in 2:
		RealityState.reset_campaign_for_tests()
		var world := Runtime.instantiate() as OrisonV2RuntimeRoot
		add_child(world)
		check(not world.startup_failed, "production world starts")
		if world.startup_failed:
			world.shutdown_for_tests(); world.free(); break
		world.player.set_physics_process(false)
		world.player.set_process_unhandled_input(false)
		for identity: String in programs.doors:
			var door: DoorProp = world.adapter.resolve(identity).get_node(identity+"_Leaf")
			door.npc_set_open(true)
		var refs: Array[WeakRef] = []
		await get_tree().create_timer(.7).timeout
		var capsule := CapsuleShape3D.new()
		capsule.radius = .38
		capsule.height = 1.524
		var count := 0
		for a: Dictionary in layout.anchors:
			if a.level not in ["F05","F06"] or not str(a.id).ends_with("_STANCE"):continue
			var marker := world.adapter.resolve(a.id) as Node3D
			check(marker != null, "approach resolves: " + str(a.id))
			if marker == null:continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform = Transform3D(Basis.IDENTITY,marker.global_position+Vector3.UP*(capsule.height*.5+.025))
			query.collision_mask = 1
			query.exclude = [world.player.get_rid()]
			check(world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "standing clearance: " + str(a.id))
			count += 1
		check(count == 140, "all new and existing upper approaches remain clear")
		for probe: Dictionary in probes.kitchens:
			var cabinet := world.adapter.resolve(probe.prep) as StaticBody3D
			var cup := world.adapter.resolve(probe.cupboard) as StaticBody3D
			check(cabinet != null and cup != null, "both cabinet families mounted: " + str(probe.unit))
			if cabinet == null or cup == null:continue
			refs.append(weakref(cabinet));refs.append(weakref(cup))
			check(cabinet.get("unit") == probe.unit and not cabinet.get("opened"), "closed household-owned preparation cabinet")
			check(not cup.has_method("interact"), "wall cupboard retains fixed source behavior")
			for body: StaticBody3D in [cabinet,cup]:
				for mesh: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
					check(mesh.mesh != null and mesh.material_override != null, "authored material is bound: " + str(probe.unit))
			var panel := cabinet.get_node("SlidingPanel") as AnimatableBody3D
			refs.append(weakref(panel))
			var stance := world.adapter.resolve(str(probe.prep)+"_STANCE") as Node3D
			var ray := PhysicsRayQueryParameters3D.create(stance.global_position+Vector3.UP*1.41,cabinet.to_global(Vector3(-.19,.55,-.253)),1,[world.player.get_rid()])
			check(world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == panel, "cabinet panel reachable: " + str(probe.unit))
			var sink_id := "F0"+str(probe.unit)[0]+"_"+str(probe.unit)+"_KITCHEN_SINK_01"
			var sink: Node3D = world.adapter.resolve(sink_id)
			var sink_stance: Node3D = world.adapter.resolve(sink_id+"_STANCE")
			for control_name: String in ["HotValveControl","ColdValveControl"]:
				var control := sink.get_node(control_name) as Area3D
				var reach := PhysicsRayQueryParameters3D.create(sink_stance.global_position+Vector3.UP*1.41,control.global_position,1,[world.player.get_rid()])
				reach.collide_with_areas = true
				check(world.get_world_3d().direct_space_state.intersect_ray(reach).get("collider") == control, "sink valve reachable: " + str(probe.unit)+" / "+control_name)
			var before: Dictionary = world.household_state.snapshot()
			panel.call("interact",world.player)
			before.records[probe.prep].value = true
			check(RealityState.data[world.household_state.KEY] == before, "opening changes only the selected household fact")
		await get_tree().create_timer(.4).timeout
		await get_tree().physics_frame
		for probe: Dictionary in probes.kitchens:
			var cabinet := world.adapter.resolve(probe.prep) as StaticBody3D
			var panel := cabinet.get_node("SlidingPanel") as AnimatableBody3D
			check(is_equal_approx(panel.position.x,Prep.TRAVEL), "full bypass travel: " + str(probe.unit))
			var physical: Transform3D = PhysicsServer3D.body_get_state(panel.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)
			check(physical.is_equal_approx(panel.global_transform), "animated collider matches visual")
			var ray := PhysicsRayQueryParameters3D.create(cabinet.to_global(Vector3(-.19,.55,-.6)),cabinet.to_global(Vector3(-.19,.55,.16)),1)
			check(world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "open cabinet exposes shelf space")
			panel.call("interact",world.player)
		await get_tree().create_timer(.4).timeout
		await get_tree().physics_frame
		for probe: Dictionary in probes.kitchens:
			var cabinet := world.adapter.resolve(probe.prep) as StaticBody3D
			check(not cabinet.get("opened") and is_zero_approx((cabinet.get_node("SlidingPanel") as Node3D).position.x), "closing restores front")
			cabinet.call("interact",world.player)
			cabinet.call("interact",world.player)
			cabinet.call("interact",world.player)
		world.shutdown_for_tests();world.free()
		for ref: WeakRef in refs:check(ref.get_ref() == null, "cabinet retires during active motion")
	print("UPPER KITCHENS: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
