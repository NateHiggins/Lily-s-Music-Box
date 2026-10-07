extends "res://tests/orison_v2_city_sweep.gd"
## Original nook and all five task-lamp installations in the composed world.
const NativeLamp := preload("res://scripts/props/native_task_lamp.gd")
var batch_mode := true
var capture_enabled := true
var originals := {}
var mounted_ids: Array[int] = []

func _ready() -> void: pass

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_reading_nook.json"))
	var installations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/task_lamp_installations.json"))
	check(FileAccess.get_sha256("res://assets/props/reading_nook.glb") == fixture.asset_sha256, "nook export matches construction fixture")
	var count := 0
	var triangles := 0
	for row: Dictionary in fixture.runtime.assemblies:
		var body := world.adapter.resolve(str(row.id)) as StaticBody3D
		check(body != null and body.get_meta("v2_nook_source", "") == row.id, "one physical owner for original nook record: " + str(row.id))
		if body == null: continue
		mounted_ids.append(body.get_instance_id())
		check(body.position.is_equal_approx(Vector3(row.position[0], row.position[1], row.position[2])), "retained rigid composition: " + str(row.id))
		for part: Dictionary in row.parts:
			var draw := body.find_child(str(part.name), true, false) as MeshInstance3D
			check(draw != null and draw.owner == null, "actor owns unbound native part: " + str(part.name))
			if draw == null: continue
			var expected: Dictionary = fixture.parts.filter(func(p): return p.name == part.name)[0]
			var faces := draw.mesh.get_faces()
			check(faces.size()/3 == int(expected.triangles), "exact native triangle partition")
			count += 1; triangles += faces.size()/3
			_check_cap_mapping(draw.mesh, true)
			var material := draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(material != null and not material.uv1_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE/float(part.tile)), "actual source material uses metre UVs")
			if part.has("catalog_key"):
				var library := MatLib.get_mat(str(part.catalog_key))
				check(material != library and material.albedo_texture == library.albedo_texture and material.normal_texture == library.normal_texture, "catalogue maps remain local to nook")
			else:
				var spec: Dictionary = fixture.runtime.local_materials[str(part.key)]
				check(material.normal_texture.resource_path.ends_with(str(spec.files[2])) and material.roughness_texture.resource_path.ends_with(str(spec.files[1])), "original source maps reach noncatalogue finish")
		var shapes := body.find_children("*", "CollisionShape3D", false, false)
		check(shapes.size() == row.parts.size(), "each nook part has its exact visible collision")
		for shape: CollisionShape3D in shapes: check(shape.shape is ConcavePolygonShape3D, "no broad invisible nook obstruction")
	check(count == fixture.parts.size() and triangles == int(fixture.triangles), "all native nook partitions accounted for")
	check(fixture.book_stock.size() == 60, "all 57 shelf volumes and three table books retained")
	for probe: Dictionary in fixture.contacts:
		var point: Array = probe.point
		var at: Vector3 = world.adapter.root.to_global(Vector3(point[0], point[1]+fixture.runtime.floor_y, point[2]))
		var direction := Vector3(probe.direction[0], probe.direction[1], probe.direction[2])
		var child := world.adapter.resolve(str(probe.assembly)) as StaticBody3D
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+direction*.004, at-direction*.004, 1, [child.get_rid()]))
		var owner: Node = world.adapter.resolve(str(probe.owner)) if probe.owner != "floor" else null
		check(not hit.is_empty() and hit.position.distance_to(at)<.00003 and hit.normal.dot(direction)>.9 and (owner==null or hit.collider==owner), "actual reciprocal nook bearing: " + str(probe.label))
	var radii := {"emeralite":.095,"office_green":.078,"bench_friction":.110,"landlord_enamel":.082,"architect_counterweight":.112}
	var stations := {"B1_NOOK_LAMP":Vector3(-.50,-3.18,.65),"F02_A_LAMP_01":Vector3(-12.30,3.22,6.75),"F03_B_LAMP_01":Vector3(13.65,6.42,-1.35),"F04_B_LAMP_01":Vector3(-9.90,9.62,.70),"F05_A_LAMP_01":Vector3(-11.,12.82,-4.60)}
	for row: Dictionary in installations.lamps:
		var lamp := world.adapter.resolve(str(row.id)) as LampProp
		var support := world.adapter.resolve(str(row.support)) as StaticBody3D
		check(lamp != null and lamp.get_script() == NativeLamp, "original lamp restored as native actor: " + str(row.id))
		if lamp == null or support == null: continue
		mounted_ids.append(lamp.get_instance_id())
		check(lamp.variant == row.variant and lamp.graph_node_id == row.id and lamp.get_meta("source_unit") == row.unit, "original variant, household and electrical identity")
		var local := support.to_local(lamp.global_position)
		check(local.is_equal_approx(Vector3(row.position[0],row.position[1],row.position[2])), "lamp rests at its fitted support-local datum")
		check(row.existing or lamp.get_parent() == support, "new lamp lifetime follows actual support")
		var graph: Dictionary = AcousticGraphData.nodes[str(row.id)]
		check(GameBoot.b2g(graph.pos).is_equal_approx(lamp.global_position), "electrical graph follows actual installed lamp")
		check(world.adapter._acoustic_originals.has(row.id), "source graph saved for restoration")
		originals[str(row.id)] = world.adapter._acoustic_originals[str(row.id)].duplicate(true)
		for ring: float in [.0,.33,.67,1.]:
			for index in (1 if ring == 0. else 64):
				var angle := TAU*index/64.
				var at := lamp.global_position+Vector3(cos(angle)*radii[row.variant]*ring,0,sin(angle)*radii[row.variant]*ring)
				var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.004,1))
				check(not hit.is_empty() and hit.collider==support and hit.position.distance_to(at)<.00003 and hit.normal.y>.99, "full lamp footprint has actual visible bearing: "+str(row.id))
		var feet: Vector3 = world.adapter.root.to_global(stations[str(row.id)])
		check(_city_clear_station(world,feet), "standing clearance at installed lamp: "+str(row.id))
		world.player.global_position=feet; world.player.velocity=Vector3.ZERO
		world.player.face_world_point(lamp.global_position+Vector3.UP*.30)
		await get_tree().physics_frame
		var enabled := lamp.is_locally_enabled()
		world.player.use_primary_interaction()
		check(lamp.is_locally_enabled()!=enabled, "ordinary player ray reaches lamp key: "+str(row.id))
		lamp.set_local_enabled(enabled,false)
		if capture_enabled and not row.existing:
			await _city_capture(world,feet,lamp.global_position+Vector3.UP*.3,str(row.id)+"_context","fitted task lamp",str(row.id))
	var terminal := world.adapter.resolve("F04_B_MONITOR_01") as SignalTerminalProp
	var desk := world.adapter.resolve("4B_terminal_desk") as Node3D
	check(desk.to_local(terminal.global_position).is_equal_approx(Vector3(.075,.75,0)), "terminal fits within existing desk beside restored lamp")
	originals["F04_B_MONITOR_01"] = world.adapter._acoustic_originals["F04_B_MONITOR_01"].duplicate(true)
	check(GameBoot.b2g(AcousticGraphData.nodes["F04_B_MONITOR_01"].pos).is_equal_approx(terminal.global_position), "terminal graph follows fitted body")
	var operator := world.adapter.resolve("F04_B_MONITOR_STANCE") as Node3D
	check(_city_clear_station(world,operator.global_position+Vector3.UP*.02), "original terminal working stance remains clear")
	# The adjacent lamp must not steal the terminal's existing ordinary player ray.
	world.player.global_position=operator.global_position
	world.player.camera.global_position=operator.global_position+Vector3.UP*PlayerController.STANDING_EYE
	var scope := terminal.find_child("SignalScope",true,false) as MeshInstance3D
	world.player.face_world_point(scope.global_position)
	world.call_interface.fast=true; world.call_interface.fast_factor=.05
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame
	Input.action_press("interact")
	await get_tree().process_frame; await get_tree().process_frame
	Input.action_release("interact")
	await get_tree().process_frame; await get_tree().process_frame
	var entered := world.player.call_locked and world.player.seated_interaction is DeskZone
	check(entered and world.call_interface._panel.visible and terminal._stage=="call", "actual interact action still enters the sole Vantry call owner")
	if entered:
		world.player.face_world_point(world.player.global_position+Vector3.LEFT)
		Input.action_press("interact")
		await get_tree().process_frame; await get_tree().process_frame
		Input.action_release("interact")
		await get_tree().process_frame; await get_tree().process_frame
		check(not world.player.call_locked and world.player.seated_interaction==null and not world.call_interface._panel.visible, "seated interact releases the same call owner after looking away")
	for identity: String in ["2A_desk","5A_plantable"]:
		var owner := world.adapter.resolve(identity) as StaticBody3D
		for collision: CollisionShape3D in owner.find_children("*","CollisionShape3D",false,false):
			check(collision.shape is ConcavePolygonShape3D,"lamp-bearing furniture collision follows actual source triangles")
	# Sample the unchanged open strip between nook and lift, plus the original
	# laundry and stair approaches. These are physical clearance checks, not a route contract.
	for local: Vector3 in [Vector3(-1.65,-3.18,.55),Vector3(-.5,-3.18,.55),Vector3(.65,-3.18,.55),Vector3(-1.80,-3.18,-1.5),Vector3(1.9,-3.18,2.4)]:
		check(_city_clear_station(world,world.adapter.root.to_global(local)), "nook leaves sampled basement approach clear: "+str(local))
	return {"checks":checks,"parts":count,"triangles":triangles,"production_lamps":installations.lamps.size(),"failures":failures.duplicate()}

func validate_after_teardown() -> Dictionary:
	for identity: String in originals:
		check(AcousticGraphData.nodes[identity] == originals[identity], "teardown restores original electrical graph: "+identity)
	for id: int in mounted_ids: check(not is_instance_id_valid(id), "teardown frees the actual mounted nook/lamp owner")
	return {"checks":checks,"failures":failures.duplicate()}
