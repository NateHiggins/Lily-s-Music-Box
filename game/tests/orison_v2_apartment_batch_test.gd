extends Node
## Prepared category-level composition/lifetime check. No played route claim.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const UNITS := ["2A", "2B", "3B", "4B"]
const ALL_DOMESTIC_UNITS := ["2A", "2B", "3A", "3B", "4A", "4B"]
var failures: Array[String] = []
var checks := 0

class SurfaceSourceAdapter extends RefCounted:
	var supports: Dictionary = {}
	func resolve(identity: String) -> Node:
		return supports.get(identity)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("APARTMENT BATCH: " + label)

func _ready() -> void:
	RealityState.persistence_enabled = false
	_check_wall_extensions()
	var furniture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/domestic_furniture.json"))
	var fittings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/domestic_fittings.json"))
	var heating_acoustics := {}
	var accessory_acoustics := {}
	var accessory_source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/household_accessories.json"))
	for record: Dictionary in accessory_source.accessories:
		if AcousticGraphData.nodes.has(record.id):
			accessory_acoustics[record.id] = AcousticGraphData.nodes[record.id].duplicate(true)
	for unit: String in preload("res://scripts/building/orison_v2_heating.gd").UNITS:
		var identity := "F0"+unit[0]+"_"+unit[1]+"_RADIATOR_01"
		heating_acoustics[identity] = AcousticGraphData.nodes[identity].duplicate(true)
	for cycle in 2:
		RealityState.reset_campaign_for_tests()
		var world := Runtime.instantiate() as OrisonV2RuntimeRoot
		add_child(world)
		check(not world.startup_failed, "full batch starts, cycle " + str(cycle))
		if world.startup_failed:
			world.shutdown_for_tests()
			world.free()
			break
		await get_tree().physics_frame
		var refs: Array[WeakRef] = []
		await _check_household_accessories(world, refs)
		_check_heating(world, refs)
		_check_room_circuits(world, refs)
		_check_apartment_doors(world, refs)
		_check_surface_props(world, refs)
		_check_bath_details(world, refs)
		_check_storage_tables_boards(world, furniture)
		_check_household_radios(world, refs)
		await _check_projectors(world, refs)
		await _check_prep_cabinets(world, refs)
		_check_specialist_devices(world, refs)
		for identity in ["F02_B_FABRIC_TABLE_MASS", "F02_B_KITCHEN_RUN_MASS",
				"F02_B_BED_MASS", "F02_B_STORAGE_MASS", "F02_B_BATH_MASS"]:
			var mass := world.find_child(identity, true, false) as Node3D
			check(mass != null and not mass.visible, "replaced planning mass hidden: " + identity)
			if mass == null: continue
			for shape: CollisionShape3D in mass.find_children("*", "CollisionShape3D", true, false):
				check(shape.disabled, "replaced planning collision retired: " + identity)
		for unit: String in ALL_DOMESTIC_UNITS:
			var dining_table := unit + "_din_t" if unit != "4B" else "4B_meal_table"
			check(world.adapter.resolve(dining_table) is StaticBody3D, "meal table mounted for " + unit)
			for index in range(1, 3):
				var chair_id := unit + "_din_dc" + str(index) if unit != "4B" else "4B_meal_chair_0" + str(index)
				check(world.adapter.resolve(chair_id) is StaticBody3D, "dining chair mounted: " + chair_id)
			var wc := world.adapter.resolve(unit + "_wc") as BakedFurnitureInteraction
			check(wc != null, "toilet mounted for " + unit)
			if wc != null:
				refs.append(weakref(wc))
				wc.interact(world.player)
				check("refilling" in wc.interact_prompt(), "shared flush operates for " + unit)
			var counts := {"sink":0, "shower":0, "stove":0, "fridge":0}
			for record: Dictionary in fittings.fittings:
				if record.unit != unit: continue
				counts[record.kind] += 1
				var prop := world.adapter.resolve(record.id) as FunctionalProp
				check(prop != null and prop.get("unit") == unit, "household fitting mounted: " + str(record.id))
				if prop == null: continue
				refs.append(weakref(prop))
				if prop is TapProp:
					check(world.boiler_tend != null and world.boiler_tend.taps.count(prop) == 1,
							"water fitting has one real supply: " + str(record.id))
					for control_name in ["HotValveControl", "ColdValveControl"]:
						var control := prop.get_node_or_null(control_name) as Area3D
						check(control != null and control.get("tap") == prop,
								"independent water control: " + str(record.id) + "/" + control_name)
						if control != null: refs.append(weakref(control))
			check(counts == {"sink":2,"shower":1,"stove":1,"fridge":1},
					"complete sanitary/appliance category roster for " + unit)
		for record: Dictionary in furniture.furniture:
			var prop := world.adapter.resolve(record.id) as StaticBody3D
			check(prop != null, "furniture mounted: " + str(record.id))
			if prop == null: continue
			refs.append(weakref(prop))
			if record.kind == "plant":
				check(str(record.id) == "3A_story_specimen", "authored Malcolm specimen mounted")
				var bound_materials: Array[String] = []
				for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
					var material := mesh.material_override as StandardMaterial3D
					check(material != null and material.albedo_texture != null, "plant surfaces have textures")
					for key: String in ["plant", "timber", "soil", "terracotta"]:
						if material == MatLib.get_mat(key): bound_materials.append(key)
				bound_materials.sort()
				check(bound_materials == ["plant", "soil", "terracotta", "timber"], "plant uses all four semantic materials")
			if record.kind == "wardrobe":
				check(prop.get("_case_wood") == record.mechanism.case_wood,
						"wardrobe retains its household wood: " + str(record.id))
				prop.call("interact", world.player)
				check("Close" in str(prop.call("interact_prompt")),
						"production wardrobe opens: " + str(record.id))
		# Free while cistern/wardrobe tweens are active, exercising their existing
		# teardown owners instead of waiting until all temporary state is idle.
		for unit: String in ALL_DOMESTIC_UNITS:
			var radiator := world.adapter.resolve("F0"+unit[0]+"_"+unit[1]+"_RADIATOR_01") as RadiatorProp
			if radiator != null: radiator.set_supply_open(false)
		var servicing := world.adapter.resolve("F03_A_RADIATOR_01") as RadiatorProp
		var panel: MaintenanceActivityPanel
		if servicing != null:
			servicing.perform_physical_action("service_vent")
			panel = servicing.get("_service_panel") as MaintenanceActivityPanel
			check(panel != null and world.player.call_locked, "household vent activity owns player input")
		for record: Dictionary in accessory_source.accessories:
			var accessory := world.adapter.resolve(str(record.id)) as FunctionalProp
			if accessory is ToasterProp:
				accessory.start_cycle()
				accessory.set_crumb_tray_open(false, 0)
				accessory.set_crumb_tray_open(true)
			elif accessory is MedicineCabinetProp:
				accessory.set_door_open(true)
		world.shutdown_for_tests()
		check(world.mirror_renderer.active_mirror() == null and not world.mirror_renderer.is_processing(),
				"reflection stops before support-owned cabinets retire")
		if is_instance_valid(panel):
			check(panel.is_queued_for_deletion() and not world.player.call_locked, "radiator teardown closes service panel and releases input")
		world.free()
		for identity: String in heating_acoustics:
			check(AcousticGraphData.nodes[identity] == heating_acoustics[identity], "radiator acoustic position restored after teardown")
		for identity: String in accessory_acoustics:
			check(AcousticGraphData.nodes[identity] == accessory_acoustics[identity], "accessory acoustic position restored after teardown")
		for ref in refs: check(ref.get_ref() == null, "batch subject retires with its world")
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("apartment_batch.json"),FileAccess.WRITE).store_string(
				JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("APARTMENT BATCH: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _check_household_accessories(world: OrisonV2RuntimeRoot, refs: Array[WeakRef]) -> void:
	var loader := preload("res://scripts/building/orison_v2_household_accessories.gd").new()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(loader.PATH))
	var probe := SurfaceSourceAdapter.new()
	for record: Dictionary in source.accessories:
		probe.supports[record.support] = StaticBody3D.new() if record.kind == "toaster" else TapProp.new()
	check(loader.validate(source, probe), "complete accessory source validates before mounting")
	var broken := source.duplicate(true)
	broken.accessories.pop_back()
	check(not loader.validate(broken, probe), "missing cabinet rejected before mounting")
	broken = source.duplicate(true)
	broken.accessories[0].position[1] = .95
	check(not loader.validate(broken, probe), "floating toaster rejected before mounting")
	broken = source.duplicate(true)
	broken.accessories[1].position[2] = NAN
	check(not loader.validate(broken, probe), "nonfinite cabinet placement rejected")
	broken = source.duplicate(true)
	broken.accessories[1].hinge_side = "left"
	check(not loader.validate(broken, probe), "wrong cabinet hinge rejected")
	broken = source.duplicate(true)
	broken.accessories[2] = broken.accessories[0].duplicate(true)
	check(not loader.validate(broken, probe), "duplicate accessory rejected")
	for support: Node in probe.supports.values(): support.free()
	var renderer := world.mirror_renderer
	refs.append(weakref(renderer))
	await get_tree().process_frame
	var views := renderer.find_children("*", "SubViewport", true, false)
	check(views.size() == 1, "twelve mirrors share exactly one reflection viewport")
	if views.size() == 1: refs.append(weakref(views[0]))
	var saved_camera := world.player.camera.global_transform
	var saved_infection: float = Conductor.infection
	Conductor.infection = 0
	var toasters: Array[ToasterProp] = []
	for record: Dictionary in source.accessories:
		var prop := world.adapter.resolve(str(record.id)) as FunctionalProp
		check(prop != null and prop.get("unit") == record.unit, "native household accessory: " + str(record.id))
		if prop == null: continue
		refs.append(weakref(prop))
		var support := world.adapter.resolve(str(record.support)) as Node3D
		check(prop.get_parent() == support, "accessory belongs to its actual support")
		var stance := support.to_global(Vector3(record.stance[0], record.stance[1], record.stance[2]))
		var target := prop.to_global(Vector3(0, .11, 0) if record.kind == "toaster" else Vector3(0, 1.505, -.08))
		var ray := PhysicsRayQueryParameters3D.create(stance + Vector3.UP * 1.41, target, 1, [world.player.get_rid()])
		ray.collide_with_areas = true
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and prop.is_ancestor_of(hit.collider), "real player ray reaches accessory: " + str(record.id))
		if prop is ToasterProp:
			var toaster := prop as ToasterProp
			check(toaster.tray_axis == (Vector3.LEFT if record.unit == "4B" else Vector3.FORWARD), "authored tray direction retained")
			toaster.set_crumb_tray_open(true, 0)
			check(toaster.is_crumb_tray_open() and (toaster.get("_crumb_tray") as Node3D).position.is_equal_approx(
					Vector3(0,.027,0)+toaster.tray_axis*.16), "full crumb tray travel")
			toaster.set_crumb_tray_open(false, 0)
			toaster.start_cycle()
			toaster.interact(world.player)
			toasters.append(toaster)
		else:
			var cabinet := prop as MedicineCabinetProp
			check(cabinet.inventory_names().size() == MedicineCabinetProp.KEPT[record.unit].size(), "resident-specific cabinet contents retained")
			check(cabinet.get_node_or_null("CabinetDoor/CabinetLeafBody") is AnimatableBody3D, "moving cabinet leaf is solid")
			cabinet.set_door_open(true, 0)
			check(cabinet.is_door_open(), "cabinet opens through native mechanism")
			cabinet.set_door_open(false, 0)
			world.player.camera.global_position = stance + Vector3.UP * 1.41
			world.player.camera.look_at(cabinet.mirror_center())
			renderer._process(0)
			check(renderer.active_mirror() == cabinet, "shared reflection selects viewed household cabinet")
	world.player.camera.global_transform = saved_camera
	await get_tree().create_timer(6.0, false).timeout
	for toaster in toasters:
		check(toaster.cycles_completed == 1 and toaster.state == FunctionalProp.PState.IDLE, "normal toaster cycle returns raised and cold")
		toaster.start_cycle()
		toaster.set_crumb_tray_open(true)
	Conductor.infection = saved_infection

func _check_room_circuits(world: OrisonV2RuntimeRoot, refs: Array[WeakRef]) -> void:
	var lighting: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/room_lighting.json"))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2_blockout.json"))
	var rooms: Dictionary = {}
	for space: Dictionary in layout.spaces:
		var identity := str(space.id)
		for prefix in ["F02_A_", "F02_B_", "F03_A_", "F03_B_", "F04_A_", "F04_B_"]:
			if identity.begins_with(prefix): rooms[identity] = true
	check(rooms.size() == 38, "all detailed apartment spaces covered")
	var fixtures: Dictionary = {}
	var owners: Dictionary = {}
	for record: Dictionary in lighting.fixtures:
		if record.kind == "lamp": continue
		var fixture := world.adapter.resolve(record.id) as LightFixtureProp
		check(fixture != null, "room fixture mounted: " + str(record.id))
		if fixture == null: continue
		fixtures[record.id] = fixture
		owners[record.id] = str(record.room)
		refs.append(weakref(fixture))
	var covered: Dictionary = {}
	for record: Dictionary in lighting.switches:
		if not rooms.has(record.room): continue
		check(not covered.has(record.room), "one apartment circuit control: " + str(record.room))
		covered[record.room] = true
		var plate := world.adapter.resolve(record.id) as StaticBody3D
		check(plate != null and plate.has_method("interact"), "physical switch mounted: " + str(record.id))
		if plate == null or not plate.has_method("interact"): continue
		refs.append(weakref(plate))
		check(plate.get_meta("room_id", "") == record.room, "plate has correct circuit owner")
		var before: Dictionary = {}
		var served := 0
		for identity: String in fixtures:
			before[identity] = fixtures[identity].powered
			if owners[identity] == record.room: served += 1
		check(served == 1, "one ceiling/wall fixture serves " + str(record.room))
		plate.call("interact", world.player)
		for identity: String in fixtures:
			var expected: bool = not bool(before[identity]) if owners[identity] == record.room else bool(before[identity])
			check(fixtures[identity].powered == expected,
					"switch changes only its circuit: " + str(record.id) + " / " + identity)
		plate.call("interact", world.player)
		for identity: String in fixtures:
			check(fixtures[identity].powered == before[identity], "return throw restores circuit: " + identity)
	check(covered.size() == rooms.size(), "every apartment room has a mounted circuit")

func _check_apartment_doors(world: OrisonV2RuntimeRoot, refs: Array[WeakRef]) -> void:
	var covered := 0
	for record: Dictionary in world.layout.doors:
		var unit := ""
		for room: String in record.connects:
			for candidate: String in ALL_DOMESTIC_UNITS:
				if room.begins_with("F0" + candidate[0] + "_" + candidate[1] + "_"):
					unit = candidate
		if unit.is_empty(): continue
		covered += 1
		var opening := world.adapter.resolve(record.id) as Node3D
		check(opening != null, "apartment opening retained: " + str(record.id))
		if opening == null: continue
		var door := opening.get_node_or_null(str(record.id) + "_Leaf") as DoorProp
		check(door != null and door.unit == unit, "one production door with household owner: " + str(record.id))
		check(opening.get_node_or_null("Hinge") == null, "placeholder leaf retired: " + str(record.id))
		if door == null: continue
		refs.append(weakref(door))
		var body := door.get_node_or_null("HingedLeaf") as AnimatableBody3D
		check(body != null, "physical movable door body: " + str(record.id))
		check(is_equal_approx(door.width, float(record.width)) and is_equal_approx(door.height, float(record.height)),
				"door fits its authored opening: " + str(record.id))
		check(door.scale == Vector3.ONE, "door handedness uses positive scale")
		var right: bool = record.hinge == "right"
		check(is_equal_approx(door.position.x, float(record.width) * (.5 if right else -.5)), "correct hinge jamb")
		# Existing shared API must answer resident requests; teardown occurs
		# with the resulting tweens active, alongside toilet/wardrobe motion.
		door.npc_set_open(true)
		check(door.open, "production resident opening API: " + str(record.id))
	check(covered == 24, "all doors across all six detailed apartments covered")

func _check_surface_props(world: OrisonV2RuntimeRoot, refs: Array[WeakRef]) -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/domestic_surface_props.json"))
	var counts := {"2A":0, "2B":0, "3A":0, "3B":0, "4A":0, "4B":0, "5A":0, "5B":0, "5C":0, "6A":0, "6B":0, "6C":0}
	var dry_adapter := SurfaceSourceAdapter.new()
	for record: Dictionary in source.props:
		var support := world.adapter.resolve(record.support) as Node3D
		var prop := world.adapter.resolve(record.id) as Node3D
		dry_adapter.supports[record.support] = support
		counts[record.unit] += 1
		check(prop != null and support != null, "surface prop and support exist: " + str(record.id))
		if prop == null or support == null: continue
		refs.append(weakref(prop))
		check(prop.get_parent() == support, "surface owner controls lifetime: " + str(record.id))
		var position := Vector3(record.position[0], record.position[1], record.position[2])
		var expected := Transform3D(Basis(Vector3.UP, float(record.yaw)), position)
		check(prop.transform.is_equal_approx(expected), "support-relative prop placement: " + str(record.id))
		check(not prop.has_method("interact") and prop.find_children("*", "CollisionObject3D", true, false).is_empty(),
				"fixed dressing adds no interaction or collision owner: " + str(record.id))
		check(prop.find_children("*", "MeshInstance3D", true, false).size() >= record.surfaces.size(),
				"material surfaces mounted: " + str(record.id))
	check(counts == {"2A":5, "2B":4, "3A":4, "3B":8, "4A":3, "4B":2, "5A":7, "5B":4, "5C":4, "6A":6, "6B":5, "6C":3}, "surface category roster across all apartments")
	var loader := preload("res://scripts/building/orison_v2_surface_props.gd").new()
	check(loader.validate(source, dry_adapter), "complete source accepts available supports")
	var missing := source.duplicate(true)
	missing.props[0].support = "ABSENT_SUPPORT"
	check(not loader.validate(missing, dry_adapter), "missing support refused before mounting")
	check(not loader.validate(source, world.adapter), "second installation refuses occupied identities")
	var malformed := source.duplicate(true)
	malformed.props[0].yaw = NAN
	check(not loader.validate(malformed, dry_adapter), "nonfinite placement refused")

func _check_wall_extensions() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2_blockout.json"))
	var builder := preload("res://scripts/building/orison_v2_blockout.gd").new()
	builder.layout = source.duplicate(true)
	builder._validate_wall_extensions()
	check(builder.failures.is_empty(), "production wall extensions have unique bounded owners")
	var count := 0
	for space: Dictionary in source.spaces:
		for extension: Dictionary in space.get("wall_extensions", []):
			count += 1
			var holder := Node3D.new()
			var edge: Vector3 = builder._wall_edge(space.rect, str(extension.side))
			var axis := "z" if extension.side in ["east", "west"] else "x"
			builder._wall_with_openings(holder, str(space.id), "Probe", axis, edge.x,
					float(extension.start), float(extension.end), 0.0, 3.0, .14, "private")
			check(holder.get_child_count() > 0, "partial wall produces geometry: " + str(space.id))
			for mesh: MeshInstance3D in holder.get_children():
				var size: Vector3 = (mesh.mesh as BoxMesh).size
				var low := mesh.position - size * .5
				var high := mesh.position + size * .5
				var along := 0 if axis == "x" else 2
				check(size.x > 0 and size.y > 0 and size.z > 0,
						"partial wall has positive geometry")
				check(low[along] >= float(extension.start) - .0001 \
						and high[along] <= float(extension.end) + .0001,
						"aperture clipping cannot extend partial wall past its endpoints")
				var shapes := mesh.find_children("*", "CollisionShape3D", true, false)
				check(shapes.size() == 1, "partial wall has exactly one collision shape")
				check(shapes.size() == 1 and (shapes[0].shape as BoxShape3D).size.is_equal_approx(size),
						"partial wall visual and collision dimensions agree")
				for window: Dictionary in source.windows:
					if window.space != space.id or window.axis != axis: continue
					var fixed := float(window.center[1] if axis == "x" else window.center[0])
					if not is_equal_approx(fixed, edge.x): continue
					var center := float(window.center[0] if axis == "x" else window.center[1])
					var overlaps_width := minf(high[along], center + float(window.width) * .5) \
							> maxf(low[along], center - float(window.width) * .5) + .0001
					var overlaps_height := minf(high.y, float(window.sill) + float(window.height)) \
							> maxf(low.y, float(window.sill)) + .0001
					check(not (overlaps_width and overlaps_height), "window aperture remains free of wall geometry")
			holder.free()
	check(count == 41, "23 lower and 18 upper wall intervals have build coverage")
	# Reject corrupt interval data before building any geometry.
	for bad: Variant in [{"side":"east","start":-100.0,"end":0.0},
			{"side":"east","start":NAN,"end":0.0}, {"side":"up","start":0.0,"end":1.0},
			{"side":"west","start":-1.0,"end":1.0}]:
		builder.layout = source.duplicate(true)
		for space: Dictionary in builder.layout.spaces:
			if space.id == "F02_A_MAIN": space.wall_extensions = [bad]
		builder.failures.clear()
		builder._validate_wall_extensions()
		check(not builder.failures.is_empty(), "invalid or duplicate extension refused")
	builder.layout = source.duplicate(true)
	for space: Dictionary in builder.layout.spaces:
		if space.id == "F02_A_MAIN": space.wall_extensions.append(space.wall_extensions[0].duplicate())
	builder.failures.clear()
	builder._validate_wall_extensions()
	check(not builder.failures.is_empty(), "overlapping extensions refused")
	# Apertures before AND after a short edge previously produced boxes outside
	# its interval. Keep a synthetic regression independent of authored windows.
	builder.layout = {"doors":[
		{"connects":["probe"],"center":[-10.0,0.0],"width":1.0,"height":2.0},
		{"connects":["probe"],"center":[10.0,0.0],"width":1.0,"height":2.0}]}
	var holder := Node3D.new()
	builder._wall_with_openings(holder, "probe", "Probe", "x", 0.0, -1.0, 1.0, 0.0, 3.0, .14, "private")
	check(holder.get_child_count() == 1, "unrelated apertures do not split partial edge")
	if holder.get_child_count() == 1:
		var mesh := holder.get_child(0) as MeshInstance3D
		check((mesh.mesh as BoxMesh).size.is_equal_approx(Vector3(2.0,3.0,.14)),
				"unrelated apertures preserve exact segment size")
	holder.free()
	builder.free()

func _check_storage_tables_boards(world: OrisonV2RuntimeRoot, source: Dictionary) -> void:
	# Includes Mae's upper-floor glass coffee table as well as the lower homes.
	var expected := {"cupboard":12, "coffee":3, "pinboard":2, "toolboard":1, "crate":1}
	var seen := {"cupboard":0, "coffee":0, "pinboard":0, "toolboard":0, "crate":0}
	var cupboards: Array[String] = []
	var timber_surfaces := 0
	var plywood_surfaces := 0
	var glass_surfaces := 0
	for record: Dictionary in source.furniture:
		if not expected.has(record.kind): continue
		seen[record.kind] += 1
		var body := world.adapter.resolve(record.id) as StaticBody3D
		check(body != null, "category furniture mounted: " + str(record.id))
		if body == null: continue
		check(not body.has_method("interact"), "fixed storage does not claim inventory mechanics")
		var shapes := body.find_children("*", "CollisionShape3D", true, false)
		check(shapes.size() == 1, "bounded fixed furniture collision: " + str(record.id))
		if record.kind == "cupboard":
			cupboards.append(str(record.id).left(2))
			var local: Vector3 = world.adapter.root.to_local(body.global_position)
			var floor := 3.2 * (int(str(record.id).left(1)) - 1)
			check(is_equal_approx(local.y - floor, 1.65), "wall cupboard mounted above standing capsule")
			if shapes.size() == 1:
				var shape := shapes[0] as CollisionShape3D
				check(is_equal_approx((shape.shape as BoxShape3D).size.y, .7),
						"upper cupboard has no phantom lower cabinet collider")
			check(record.source_component.component == "upper_cabinet", "cupboard retains partial source attribution")
		var meshes: Array[Node] = body.find_children("*", "MeshInstance3D", true, false)
		# Glass haze is a nested receiver; enumerate only direct material surfaces.
		var direct: Array[MeshInstance3D] = []
		for node in meshes:
			if node.get_parent() == body: direct.append(node as MeshInstance3D)
		check(direct.size() == record.surfaces.size(), "all category material surfaces mounted")
		for i in mini(direct.size(), record.surfaces.size()):
			var key := str(record.surfaces[i].material)
			var material := direct[i].material_override
			if key == "glassish":
				glass_surfaces += 1
				check(material is ShaderMaterial and (material as ShaderMaterial).shader.resource_path \
						== "res://shaders/lamp_glass_surface.gdshader", "coffee table uses existing optical glass shader")
			elif key in ["timber", "plywood"]:
				if key == "timber": timber_surfaces += 1
				else: plywood_surfaces += 1
				check(material is StandardMaterial3D, "wood has catalogue material: " + key)
				if material is StandardMaterial3D:
					check(material.albedo_texture != null and material.normal_texture != null \
							and material.roughness_texture != null, "complete wood texture triplet: " + key)
					if material.albedo_texture != null:
						check(material.albedo_texture.resource_path.get_file() == "T_ai_materials_" + key + "_albedo.png",
								"wood uses its own canonical texture: " + key)
	check(seen == expected, "complete storage/table/board category roster")
	cupboards.sort()
	check(cupboards == ["2A", "2B", "3A", "3B", "4A", "4B", "5A", "5B", "5C", "6A", "6B", "6C"], "one kitchen wall cupboard per detailed apartment")
	check(timber_surfaces == 4 and plywood_surfaces == 1 and glass_surfaces == 3,
			"new wood and glass surface bindings covered")

func _check_household_radios(world: OrisonV2RuntimeRoot, refs: Array[WeakRef]) -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/domestic_radios.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/domestic_radios.json"))
	var dry_adapter := SurfaceSourceAdapter.new()
	var radios: Array[DomesticRadioProp] = []
	var emitters: Array[AudioStreamPlayer3D] = []
	for record: Dictionary in source.receivers:
		var radio := world.adapter.resolve(record.id) as DomesticRadioProp
		var support := world.adapter.resolve(record.support) as StaticBody3D
		dry_adapter.supports[record.support] = support
		check(radio != null and support != null, "household receiver and table mount: " + str(record.unit))
		if radio == null or support == null: continue
		radios.append(radio)
		refs.append(weakref(radio))
		check(radio.get_parent() == support, "radio lifetime belongs to furniture support")
		check(radio.unit == record.unit and not radio.powered, "household identity preserved and starts silent")
		var lo := Vector3(record.bounds[0][0],record.bounds[0][1],record.bounds[0][2])
		var hi := Vector3(record.bounds[1][0],record.bounds[1][1],record.bounds[1][2])
		check(AABB(lo,hi-lo).grow(.002).encloses(radio.call("_visual_bounds")), "receiver stays in reserved native clearance")
		check(radio.find_children("*", "StaticBody3D", true, false).is_empty(), "receiver adds no movement blocker")
		var area := radio.get_node_or_null("PrimaryInteraction") as Area3D
		check(area != null, "receiver has physical interaction target")
		var stance := world.adapter.resolve(str(record.id) + "_STANCE") as Node3D
		check(stance != null, "receiver has supported operator stance")
		if area != null and stance != null:
			refs.append(weakref(area))
			var origin := stance.global_position + Vector3.UP * 1.41
			var target := radio.to_global(Vector3(0,.15,0))
			check(origin.distance_to(target) < 2.1, "wireless target is within player reach")
			var query := PhysicsRayQueryParameters3D.create(origin, target, 1, [world.player.get_rid()])
			query.collide_with_areas = true
			var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
			check(hit.get("collider") == area, "furniture does not swallow receiver target ray: " + str(record.unit))
		var emitter := radio.get("_programme") as AudioStreamPlayer3D
		check(emitter != null, "receiver has shared programme emitter")
		if emitter != null:
			emitters.append(emitter)
			refs.append(weakref(emitter))
			check(not emitter.playing and emitter.stream != null, "programme is loaded but silent on entry")
			check(emitter.bus == "Broadcast" and emitter.max_distance <= 5.5, "programme has bounded diegetic audio")
		if record.unit in ["3A", "5C"]:
			check(radio.family == "crystal_set" and "headphones" in radio.interact_prompt(),
					"authored resident retains passive headphone listening")
			check(emitter != null and is_equal_approx(emitter.max_distance, 1.6)
					and is_equal_approx(float(radio.public_state().reach), 1.6), "headphone reach matches emitter")
		if record.unit == "4A": check(radio.family == "atwater_kent_44", "Peter retains authored AC set")
		for mesh: MeshInstance3D in radio.find_children("*", "MeshInstance3D", true, false):
			var material := mesh.material_override as StandardMaterial3D
			check(material != null and material.albedo_texture != null, "all receiver parts have texture-backed materials")
	check(radios.size() == 12 and emitters.size() == 12, "all twelve developed households have complete receivers")
	var loader := preload("res://scripts/building/orison_v2_radios.gd").new()
	check(loader.validate(source, catalog, dry_adapter), "complete household source accepts supports")
	check(not loader.validate(source, catalog, world.adapter), "duplicate radio installation is refused")
	var bad := source.duplicate(true)
	bad.receivers[0].support = "MISSING_RADIO_TABLE"
	check(not loader.validate(bad, catalog, dry_adapter), "absent radio table refused")
	bad = source.duplicate(true)
	bad.receivers[0].position[0] = NAN
	check(not loader.validate(bad, catalog, dry_adapter), "nonfinite radio pose refused")
	bad = source.duplicate(true)
	bad.receivers.pop_back()
	check(not loader.validate(bad, catalog, dry_adapter), "missing household refused")
	var bad_catalog := catalog.duplicate(true)
	for profile: Dictionary in bad_catalog.profiles:
		if profile.unit == "2A": profile.family = "unknown_receiver"
	check(not loader.validate(source, bad_catalog, dry_adapter), "unsupported receiver geometry refused")
	bad_catalog = catalog.duplicate(true)
	for profile: Dictionary in bad_catalog.profiles:
		if profile.unit == "3A": profile.speaker = "cone"
	check(not loader.validate(source, bad_catalog, dry_adapter), "crystal placement refuses a speaker substitution")
	var reality_before := JSON.stringify(RealityState.data)
	for i in radios.size():
		radios[i].interact(world.player)
		check(TelegramHud.card_from_interaction(radios[i], {}).get("condition") == "PLAYING", "wireless card reports active listening")
		for j in radios.size(): check(radios[j].powered == (i == j), "one household switch cannot power another")
		if i < emitters.size(): check(emitters[i].playing, "powered radio starts its programme")
		radios[i].interact(world.player)
		if i < emitters.size(): check(not emitters[i].playing, "radio switch returns programme to silence")
		check(TelegramHud.card_from_interaction(radios[i], {}).get("condition") == "SILENT", "wireless card reports stopped listening")
	check(JSON.stringify(RealityState.data) == reality_before, "local radio use leaves persistent campaign state untouched")
	# Reconstruct/free with all programme decoders active. WeakRefs in the
	# caller must retire together with the table and receiver owners.
	for radio in radios: radio.interact(world.player)

func _check_prep_cabinets(world: OrisonV2RuntimeRoot, refs: Array[WeakRef]) -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/domestic_furniture.json"))
	var loader := preload("res://scripts/building/orison_v2_domestic_furniture.gd").new()
	check(loader.validate(source, world.adapter), "complete furniture manifest validates")
	for mutation: String in ["unit", "bounds", "collision", "radio_owner", "radio_bounds"]:
		var bad := source.duplicate(true)
		for record: Dictionary in bad.furniture:
			if record.id == "2A_prep_cabinet":
				if mutation == "unit": record.mechanism.unit = "3B"
				elif mutation == "bounds": record.bounds[1][0] += .1
				elif mutation == "collision": record.erase("collision_boxes")
			if record.id == "3B_radio":
				if mutation == "radio_owner": record.mechanism.id = "2A_deck"
				elif mutation == "radio_bounds": record.bounds[1][1] += .1
		check(not loader.validate(bad, world.adapter), "mechanism contract rejects " + mutation)
	var cabinets: Array[StaticBody3D] = []
	var panels: Array[AnimatableBody3D] = []
	for unit: String in ALL_DOMESTIC_UNITS:
		var cabinet := world.adapter.resolve(unit + "_prep_cabinet") as StaticBody3D
		check(cabinet != null and cabinet.has_method("interact"), "operable preparation cabinet for " + unit)
		if cabinet == null or not cabinet.has_method("interact"): continue
		cabinets.append(cabinet)
		refs.append(weakref(cabinet))
		check(cabinet.get("unit") == unit and not bool(cabinet.get("opened")), "cabinet reconstructs closed for its household")
		var panel := cabinet.get_node_or_null("SlidingPanel") as AnimatableBody3D
		check(panel != null and panel.has_method("interact"), "moving panel forwards cabinet interaction")
		if panel == null: continue
		panels.append(panel)
		refs.append(weakref(panel))
		check(_cabinet_aperture_hit(cabinet).get("collider") == panel, "closed panel blocks lower shelf access")
		var stance := world.adapter.resolve(unit + "_prep_cabinet_STANCE") as Node3D
		if stance != null:
			var query := PhysicsRayQueryParameters3D.create(stance.global_position + Vector3.UP * 1.41,
					cabinet.to_global(Vector3(-.19,.55,-.253)), 1, [world.player.get_rid()])
			var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
			check(hit.get("collider") == panel, "cabinet panel can be reached from cooking aisle")
		else: check(false, "preparation cabinet stance resolves")
	check(cabinets.size() == 6 and panels.size() == 6, "complete six-kitchen preparation category")
	for i in cabinets.size():
		var state_before: Dictionary = world.household_state.snapshot()
		cabinets[i].call("interact", world.player)
		state_before.records[cabinets[i].get("unit") + "_prep_cabinet"].value = true
		check(RealityState.data[world.household_state.KEY] == state_before,
			"cabinet opening persists only its own household control")
		for j in cabinets.size():
			check(bool(cabinets[j].get("opened")) == (j <= i), "cabinet switch has local household state")
	await get_tree().create_timer(.36).timeout
	await get_tree().physics_frame
	for cabinet in cabinets:
		var panel := cabinet.get_node("SlidingPanel") as AnimatableBody3D
		check(is_equal_approx(panel.position.x, .382), "panel reaches full bypass travel")
		check(_cabinet_aperture_hit(cabinet).is_empty(), "open cabinet exposes actual free shelf space")
		var query := PhysicsRayQueryParameters3D.create(cabinet.to_global(Vector3(-.19,.55,-.6)),
				cabinet.to_global(Vector3(-.19,.55,.24)), 1)
		check(world.get_world_3d().direct_space_state.intersect_ray(query).get("collider") == cabinet,
				"open shelf retains its physical back panel")
		var state_before: Dictionary = world.household_state.snapshot()
		panel.call("interact", world.player)
		state_before.records[cabinet.get("unit") + "_prep_cabinet"].value = false
		check(RealityState.data[world.household_state.KEY] == state_before,
			"cabinet closing persists only its own household control")
	await get_tree().create_timer(.36).timeout
	await get_tree().physics_frame
	for cabinet in cabinets:
		check(_cabinet_aperture_hit(cabinet).get("collider") == cabinet.get_node("SlidingPanel"),
				"closing restores the physical front")
	# Rapid reversal and immediate world teardown exercise cancellation of an
	# active physics tween, rather than only freeing a stationary cabinet.
	for cabinet in cabinets:
		cabinet.call("interact", world.player)
		cabinet.call("interact", world.player)
		cabinet.call("interact", world.player)

func _cabinet_aperture_hit(cabinet: Node3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(cabinet.to_global(Vector3(-.19,.55,-.6)),
			cabinet.to_global(Vector3(-.19,.55,.16)), 1)
	return cabinet.get_world_3d().direct_space_state.intersect_ray(query)

func _check_specialist_devices(world: OrisonV2RuntimeRoot, refs: Array[WeakRef]) -> void:
	var deck := world.adapter.resolve("2A_deck") as StaticBody3D
	var coffee := world.adapter.resolve("2A_cof") as Node3D
	check(deck != null and coffee != null, "Mina's reel deck and glass table mount")
	if deck != null and coffee != null:
		check(coffee.to_local(deck.global_position).is_equal_approx(Vector3(0,.3838806654,0)),
				"reel deck rests on extracted glass top")
		check(not deck.has_method("interact"), "fixed source reel deck does not claim playback")
	var radio := world.adapter.resolve("3B_radio") as BakedFurnitureInteraction
	check(radio != null, "Omar's specialist valve receiver mounts with native controls")
	if radio == null: return
	refs.append(weakref(radio))
	check(not bool(radio.get("_powered")), "specialist receiver reconstructs switched off")
	var shapes := radio.find_children("*", "CollisionShape3D", true, false)
	check(shapes.size() == 1, "specialist receiver has one native collision owner")
	var stance := world.adapter.resolve("3B_tools0_STANCE") as Node3D
	check(stance != null, "equipment-shelf operator stance resolves")
	if stance != null:
		var origin := stance.global_position + Vector3.UP * 1.41
		var target := radio.to_global(Vector3(0,.14,0))
		check(origin.distance_to(target) < 2.1, "specialist receiver is within player reach")
		var query := PhysicsRayQueryParameters3D.create(origin, target, 1, [world.player.get_rid()])
		check(world.get_world_3d().direct_space_state.intersect_ray(query).get("collider") == radio,
				"equipment shelf does not swallow specialist radio targeting")
	var emitter := radio.get("_radio_bed") as AudioStreamPlayer3D
	var click := radio.get("_control_click") as AudioStreamPlayer3D
	check(emitter != null and click != null, "native radio programme and switch emitters exist")
	if emitter == null or click == null: return
	refs.append(weakref(emitter))
	refs.append(weakref(click))
	check(emitter.stream != null and not emitter.playing and emitter.bus == "Broadcast" \
			and emitter.max_distance <= 7.0, "native programme starts silent with bounded range")
	var household_states: Dictionary = {}
	for unit: String in UNITS:
		var household := world.adapter.resolve("DomesticRadio_" + unit) as DomesticRadioProp
		if household != null: household_states[unit] = household.powered
	var state_before := JSON.stringify(RealityState.data)
	radio.interact(world.player)
	check(bool(radio.get("_powered")) and emitter.playing, "specialist power starts its programme")
	radio.interact(world.player)
	check(not bool(radio.get("_powered")) and not emitter.playing, "specialist power silences its programme")
	for unit: String in household_states:
		var household := world.adapter.resolve("DomesticRadio_" + unit) as DomesticRadioProp
		check(household.powered == household_states[unit], "specialist switch leaves household receivers unchanged")
	check(JSON.stringify(RealityState.data) == state_before, "specialist radio is local ephemeral state")
	# Exercise decoder and knob-tween teardown while both are active.
	radio.interact(world.player)

func _check_projectors(world: OrisonV2RuntimeRoot, refs: Array[WeakRef]) -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/domestic_projectors.json"))
	var subjects: Array[ProjectorProp] = []
	var dry_adapter := SurfaceSourceAdapter.new()
	for record: Dictionary in source.projectors:
		var prop := world.adapter.resolve(record.id) as ProjectorProp
		var stand := world.adapter.resolve(record.support) as StaticBody3D
		check(prop != null and stand != null, "projector and stand mounted for " + str(record.unit))
		if prop == null or stand == null: continue
		dry_adapter.supports[record.support] = stand
		subjects.append(prop)
		refs.append(weakref(prop))
		check(prop.get_parent() == stand, "projector lifetime belongs to stand")
		check(prop.unit == record.unit and prop.reel == record.reel and not prop.powered,
				"projector enters with its household reel loaded and lamp off")
		var shapes := prop.find_children("*", "CollisionShape3D", true, false)
		check(shapes.size() == 1, "projector has one fitted control body")
		if shapes.size() == 1:
			check(((shapes[0] as CollisionShape3D).shape as BoxShape3D).size.is_equal_approx(Vector3(.29,.51,.40)),
					"projector does not retain television-sized interaction skin")
		for key in ["_feed", "_accum"]:
			var viewport := prop.get(key) as SubViewport
			refs.append(weakref(viewport))
			check(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "idle projection buffer is disabled")
		refs.append(weakref(prop.get("_video")))
		refs.append(weakref(prop.get("_screen")))
		refs.append(weakref(prop.get("_beam")))
		var stance := world.adapter.resolve(str(record.id) + "_STANCE") as Node3D
		check(stance != null, "projector operator stance resolves")
		if stance != null:
			var origin := stance.global_position + Vector3.UP * 1.41
			var target := prop.to_global(Vector3(0,.205,0))
			check(origin.distance_to(target) < 2.1, "projector is within operator reach")
			var ray := PhysicsRayQueryParameters3D.create(origin,target,1,[world.player.get_rid()])
			check(world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == prop,
					"operator ray reaches projector above stand")
	check(subjects.size() == 3, "all authored apartment media markers have projectors")
	var loader := preload("res://scripts/building/orison_v2_projectors.gd").new()
	check(loader.validate(source,dry_adapter), "projector manifest accepts complete stand roster")
	check(not loader.validate(source,world.adapter), "duplicate projector installation refused")
	for mutation: String in ["missing", "support", "pose", "reel", "duplicate"]:
		var bad := source.duplicate(true)
		if mutation == "missing": bad.projectors.pop_back()
		elif mutation == "support": bad.projectors[0].support = "3B_projector_stand"
		elif mutation == "pose": bad.projectors[0].position[1] = NAN
		elif mutation == "reel": bad.projectors[0].reel = "../unlisted"
		else: bad.projectors[1] = bad.projectors[0].duplicate(true)
		check(not loader.validate(bad,dry_adapter), "projector source rejects " + mutation)
	for i in subjects.size():
		var prop := subjects[i]
		var state_before := JSON.stringify(RealityState.data)
		prop.interact(world.player)
		check(JSON.stringify(RealityState.data) == state_before, "projector switch leaves campaign state untouched")
		for j in subjects.size(): check(subjects[j].powered == (j <= i), "projector switches remain household-local")
		check(bool(prop.get("_running")) and (prop.get("_screen") as MeshInstance3D).visible,
				"loaded projector finds a continuous physical image surface: " + prop.unit)
	await get_tree().create_timer(.4).timeout
	for prop in subjects:
		var video := prop.get("_video") as VideoStreamPlayer
		var position_before := video.stream_position
		check(video.is_playing(), "projector reel is decoding")
		check(position_before > 0, "projector reel advances from its opening frame")
		prop.set_npc(true)
		prop.interact(world.player)
		check(prop.powered and bool(prop.get("_running")), "NPC latch keeps projector running after player releases")
		check(video.stream_position >= position_before, "overlapping latches preserve reel position")
		prop.set_npc(false)
		check(not video.is_playing() and not (prop.get("_screen") as MeshInstance3D).visible,
				"last released latch stops decoder and projection")
		for key in ["_feed", "_accum"]:
			check((prop.get(key) as SubViewport).render_target_update_mode == SubViewport.UPDATE_DISABLED,
					"last released latch parks render buffers")
		var saved_reel := prop.reel
		prop.load_reel("missing_v2_test_reel")
		prop.interact(world.player)
		check(prop.reel.is_empty() and video.stream == null and not bool(prop.get("_running")),
				"invalid reel releases previous decoder and stays dark")
		prop.load_reel(saved_reel)
		check(bool(prop.get("_running")), "valid reel resumes an already-powered machine")
		prop.interact(world.player)
	await _check_projector_surface_failures(world)
	# All machines must retire while decoding with their exposure buffers live.
	for prop in subjects: prop.interact(world.player)

func _check_projector_surface_failures(world: OrisonV2RuntimeRoot) -> void:
	var holder := Node3D.new()
	world.add_child(holder)
	holder.global_position = Vector3(0,1000,0)
	var projector := preload("res://scripts/building/orison_v2_projector_prop.gd").new()
	projector.setup_v2("projection_test","ch_01")
	holder.add_child(projector)
	var wall := StaticBody3D.new()
	wall.position = Vector3(0,.205,-2)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2,2,.1)
	collision.shape = shape
	wall.add_child(collision)
	holder.add_child(wall)
	await get_tree().physics_frame
	projector.interact(world.player)
	check(bool(projector.get("_running")), "continuous test wall admits full projection")
	projector.interact(world.player)
	shape.size = Vector3(.1,.1,.1)
	await get_tree().physics_frame
	projector.interact(world.player)
	check(not bool(projector.get("_running")) and not projector._screen.visible,
			"centre-only jamb hit cannot display a floating full image")
	projector.interact(world.player)
	wall.position.z = -10
	await get_tree().physics_frame
	projector.interact(world.player)
	check(not bool(projector.get("_running")) and not projector._screen.visible \
			and not projector._video.is_playing(), "missed wall keeps projection and decoder off")
	holder.free()

func _check_heating(world: OrisonV2RuntimeRoot, refs: Array[WeakRef]) -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/heating.json"))
	var balance := world.heat_balance
	check(balance != null and balance.all_results().size() == 23, "all authored demands share one heat budget")
	if balance == null: return
	refs.append(weakref(balance))
	check(world.boiler_tend.heat_balance == balance, "real boiler drives radiator and tap supply")
	var boiler := world.adapter.resolve("B1_BOILER_01") as BoilerProp
	check(boiler != null, "heating plant resolves")
	if boiler == null: return
	var total := balance.total_delivered_heat()
	check(is_equal_approx(total,23.0*HeatBalance.DEFAULT_TARGET*boiler.boiler_output()), "full building budget conserved")
	var target := world.adapter.resolve("F03_A_RADIATOR_01") as RadiatorProp
	var neighbor_before := float(balance.result_for("F06_C_RADIATOR_01").heat)
	if target != null:
		target.set_supply_open(false,0)
		check(is_zero_approx(float(balance.result_for(target.graph_node_id).heat)), "closed radiator receives no steam")
		check(float(balance.result_for("F06_C_RADIATOR_01").heat) > neighbor_before, "unbuilt household retains its share of released steam")
		check(is_equal_approx(total,balance.total_delivered_heat()), "closing one valve does not manufacture steam")
		target.set_supply_open(true,0)
	var dry_adapter := SurfaceSourceAdapter.new()
	var packing_before := JSON.stringify(world.maintenance_inventory.serialize())
	var count := 0
	for record: Dictionary in source.installed:
		var radiator := world.adapter.resolve(record.id) as RadiatorProp
		check(radiator != null, "installed radiator exists: " + str(record.id))
		if radiator == null: continue
		count += 1
		refs.append(weakref(radiator))
		check(radiator.get("_balance") == balance and radiator.unit == record.unit and radiator.riser == record.riser, "radiator identity and model binding")
		var acoustic: Dictionary = AcousticGraphData.nodes[record.id]
		check(Vector3(acoustic.pos[0],acoustic.pos[2],-acoustic.pos[1]).is_equal_approx(radiator.global_position), "heating acoustic endpoint follows installed pose")
		check(radiator.section_count == record.sections, "household casting count retained")
		var body := radiator.get_node_or_null("InstalledRadiatorCollision") as StaticBody3D
		check(body != null and body.get_child_count() == 2, "installed radiator blocks movement with case and pipe hulls")
		if body != null: refs.append(weakref(body))
		var stance := world.adapter.resolve(str(record.id).replace("_01","_STANCE")) as Node3D
		var area := radiator.get_node_or_null("TurnValveSurface") as Area3D
		check(stance != null and area != null, "physical handwheel and stance resolve")
		if stance != null and area != null:
			var origin := stance.global_position + Vector3.UP*1.41
			var query := PhysicsRayQueryParameters3D.create(origin,area.global_position,1,[world.player.get_rid()])
			query.collide_with_areas = true
			check(world.get_world_3d().direct_space_state.intersect_ray(query).get("collider") == area, "handwheel ray clears furniture and radiator hull: " + str(record.id))
		var anchor := Node3D.new()
		dry_adapter.supports[record.id] = anchor
		if record.unit == "2B":
			check(radiator.inventory == world.maintenance_inventory, "2B keeps its packing custodian")
		else:
			radiator.bind_inventory(world.maintenance_inventory)
			check(radiator.inventory == null, "household radiator refuses 2B packing custody")
			check(radiator.get_node_or_null("OpenServiceSurface") == null and radiator.get_node_or_null("CommitRepairSurface") == null, "2B union situation is not duplicated")
			radiator.perform_physical_action("open_service")
			radiator.perform_physical_action("inspect_union")
			radiator.apply_maintenance_result({"mechanism_patch":{"vent_grade":radiator.vent_grade,"supply_position":1.0}})
			radiator.set_supply_open(false)
			check(radiator.perform_physical_action("turn_valve").observation == "supply_open", "household valve reaches healthy detent")
	check(count == 12, "complete developed-home heating category")
	check(JSON.stringify(world.maintenance_inventory.serialize()) == packing_before, "household actions cannot acquire or consume 2B packing")
	var water := boiler.water_level
	boiler.set_water_level(0)
	check(is_zero_approx(balance.total_delivered_heat()), "cold plant cannot leave artificial radiator heat")
	for tap: TapProp in world.boiler_tend.taps: check(is_equal_approx(float(tap.get("_boiler_temperature")),.18), "same cold plant updates hot-water curve")
	if target != null: check(int(target.visual_state_receipt().warm_sections) == 0, "household casting tint follows cold boiler")
	boiler.set_water_level(water)
	check(balance.total_delivered_heat() > 0, "plant supply restores through the real binding")
	var loader := preload("res://scripts/building/orison_v2_heating.gd").new()
	check(loader.validate(source,dry_adapter), "heating manifest accepts unoccupied anchors")
	check(not loader.validate(source,world.adapter), "duplicate installation refused")
	for mutation: String in ["demand", "unit", "riser", "sections", "fractional_sections"]:
		var bad := source.duplicate(true)
		if mutation == "demand": bad.network.pop_back()
		elif mutation == "unit": bad.installed[0].unit = "2B"
		elif mutation == "riser": bad.installed[0].riser = "H-D"
		elif mutation == "fractional_sections": bad.installed[0].sections = 8.5
		else: bad.installed[0].sections = 30
		check(not loader.validate(bad,dry_adapter), "invalid heating roster rejected: " + mutation)
	for anchor: Node in dry_adapter.supports.values(): anchor.free()

func _check_bath_details(world: OrisonV2RuntimeRoot, refs: Array[WeakRef]) -> void:
	var loader := preload("res://scripts/building/orison_v2_bath_details.gd").new()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(loader.DETAIL_PATH))
	var dry := SurfaceSourceAdapter.new()
	var shared := {}
	check(source.props.size() == 36, "twelve complete sets of bath details")
	for record: Dictionary in source.props:
		var support := world.adapter.resolve(str(record.support)) as Node3D
		dry.supports[record.support] = support
		var detail := world.adapter.resolve(str(record.id)) as Node3D
		check(detail != null and detail.get_parent() == support, "bath detail belongs to physical support: " + str(record.id))
		if detail == null: continue
		refs.append(weakref(detail))
		check(detail.transform.is_equal_approx(Transform3D.IDENTITY), "bath contact remains support-local")
		var visuals := detail.get_children()
		check(visuals.size() == record.surfaces.size(), "bath has only its material batches")
		for i in visuals.size():
			var visual := visuals[i] as MeshInstance3D
			check(visual != null, "bath detail adds no interaction, light or collision owner")
			if visual == null: continue
			check(visual.mesh != null and visual.material_override != null, "bath material is bound")
			if shared.has(record.kind):
				check(visual.mesh == shared[record.kind][i].mesh, "same bath geometry shares mesh resources across homes")
		if not shared.has(record.kind): shared[record.kind] = visuals
	check(loader.validate(source, dry), "complete bath roster accepts real supports")
	var integer_origin := source.duplicate(true)
	for record: Dictionary in integer_origin.props:
		record.position = [0, 0, 0]
		record.yaw = 0
	check(loader.validate(integer_origin, dry), "integer and JSON float origins have the same contact")
	check(not loader.validate(source, world.adapter), "duplicate bath mount refused")
	for mutation: String in ["missing", "support", "offset", "yaw", "numeric_string", "bounds", "surface", "material"]:
		var bad := source.duplicate(true)
		match mutation:
			"missing": bad.props.pop_back()
			"support": bad.props[0].support = "2B_wc"
			"offset": bad.props[0].position = [0,0,1]
			"yaw": bad.props[0].yaw = .001
			"numeric_string": bad.props[0].position = ["0", 0, 0]
			"bounds": bad.props[0].bounds[1][0] = 2.0
			"surface": bad.props[0].surfaces[0].vertices[0] = 5.0
			"material": bad.props[0].surfaces[0].material = "missing_bath_finish"
		check(not loader.validate(bad, dry), "invalid bath detail batch rejected: " + mutation)
