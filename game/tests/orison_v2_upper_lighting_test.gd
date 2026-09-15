extends Node
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Loader := preload("res://scripts/building/orison_v2_room_lighting.gd")
const State := preload("res://scripts/building/orison_v2_household_state.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("UPPER LIGHTING: " + label)

func _ready() -> void:
	RealityState.persistence_enabled = false
	var probes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/v2_upper_lighting_probes.json"))
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Loader.PATH))
	check(probes.rooms.size() == 42, "all 42 occupied upper rooms have lighting probes")
	for cycle in 2:
		RealityState.reset_campaign_for_tests()
		var clock := CampaignClock.new()
		clock.configure_date(1928,11,10,20*60)
		var world := Runtime.instantiate() as OrisonV2RuntimeRoot
		add_child(world)
		check(not world.startup_failed, "full production world starts")
		if world.startup_failed:
			world.shutdown_for_tests()
			world.free()
			break
		world.player.set_physics_process(false)
		world.player.set_process_unhandled_input(false)
		world.player.camera.make_current()
		var refs: Array[WeakRef] = []
		var fixtures: Dictionary = {}
		for record: Dictionary in source.fixtures:
			if record.kind == "lamp": continue
			fixtures[record.id] = world.adapter.resolve(record.id)
		# Source routes use ordinary doors open; restricted thresholds stay locked.
		var doors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/upper_floor_programs.json"))
		for identity: String in doors.doors:
			var door: DoorProp = world.adapter.resolve(identity).get_node(identity+"_Leaf")
			door.npc_set_open(true)
		await get_tree().create_timer(.7).timeout
		var capsule := CapsuleShape3D.new()
		capsule.radius = .38
		capsule.height = 1.524
		for probe: Dictionary in probes.rooms:
			var fixture := world.adapter.resolve(probe.fixture) as LightFixtureProp
			var plate := world.adapter.resolve(probe.switch) as StaticBody3D
			check(fixture != null and plate != null, "one native fixture and switch: " + str(probe.room))
			if fixture == null or plate == null: continue
			refs.append(weakref(fixture)); refs.append(weakref(plate))
			check(fixture.prop_type == probe.kind and is_equal_approx(fixture.energy_scale,probe.properties.energy_scale), "authored family/gain: " + str(probe.room))
			check(fixture.is_in_group("light_fixtures") and fixture.light != null, "native rig owns emitter")
			check(plate.get_meta("room_id","") == probe.room and plate.system == world.get_node("V2RoomSwitches"), "one semantic circuit owner")
			check(fixture.find_children("*","MeshInstance3D",true,false).size() > 2, "fixture has its native housing")
			var y := 12.8 if probe.level == "F05" else 16.0
			var local := Vector3(probe.stance[0],y,probe.stance[1])
			var stance: Vector3 = world.adapter.root.to_global(local)
			var ray := PhysicsRayQueryParameters3D.create(stance+Vector3.UP*1.41,plate.global_position,1,[world.player.get_rid()])
			var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(hit.get("collider") == plate, "eye-height ray reaches switch: " + str(probe.room))
			var shape := PhysicsShapeQueryParameters3D.new()
			shape.shape = capsule
			shape.transform = Transform3D(Basis.IDENTITY,stance+Vector3.UP*(capsule.height*.5+.025))
			shape.collision_mask = 1
			shape.exclude = [world.player.get_rid()]
			check(world.get_world_3d().direct_space_state.intersect_shape(shape).is_empty(), "standing capsule fits switch approach: " + str(probe.room))
			var before := {}
			for identity: String in fixtures:before[identity] = fixtures[identity].powered
			plate.call("interact",world.player)
			for identity: String in fixtures:
				check(fixtures[identity].powered == (not before[identity] if identity == probe.fixture else before[identity]), "toggle isolated: " + str(probe.room) + " / " + identity)
			check(RealityState.data[State.KEY].records[probe.fixture].value == fixture.powered, "upper switch captured by existing save owner")
			plate.call("interact",world.player)
			check(fixture.powered == before[probe.fixture], "return throw restores room")
		# Exercise both storey gates with actual player feet and camera.
		var rig := world.get_node("WakingAtmosphere/LightRig") as LightRig
		for level: String in ["F05","F06"]:
			var y := 12.8 if level == "F05" else 16.0
			world.player.global_position = world.adapter.root.to_global(Vector3(-12,y,-3.5))
			world.player.camera.global_position = world.player.global_position+Vector3.UP*world.player.STANDING_EYE
			await get_tree().create_timer(1.8).timeout
			check(rig.active_floor == level, "rig follows actual upper storey")
			for probe: Dictionary in probes.rooms:
				var fixture: LightFixtureProp = fixtures[probe.fixture]
				check(rig._fixture_floor(fixture) == probe.level, "fixture classified on authored floor")
				check(fixture.light.visible == (probe.level == level), "off-storey emitter leaves render list")
				check(fixture.light.light_energy > 0 if probe.level == level else fixture.light.light_energy < .001 and is_zero_approx(fixture._target_scale), "storey gate settles through native fade: " + str(probe.room))
		var loader := Loader.new()
		check(loader.validate(source,world.adapter), "complete circuit source accepted")
		for mutation: String in ["missing_control","duplicate_control","wrong_room","invalid_gain"]:
			var bad := source.duplicate(true)
			match mutation:
				"missing_control":bad.switches.pop_back()
				"duplicate_control":bad.switches[-1].room = bad.switches[-2].room
				"wrong_room":bad.switches[-1].room = "F05_D_RESTRICTED"
				"invalid_gain":bad.fixtures[-1].properties.energy_scale = NAN
			check(not loader.validate(bad,world.adapter), "malformed circuit rejected: " + mutation)
		world.shutdown_for_tests()
		world.free()
		for ref: WeakRef in refs:check(ref.get_ref() == null, "upper circuit retires with its world")
	print("UPPER LIGHTING: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
