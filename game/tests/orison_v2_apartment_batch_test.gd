extends Node
## Prepared category-level composition/lifetime check. No played route claim.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const UNITS := ["2A", "2B", "3B", "4B"]
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
		_check_room_circuits(world, refs)
		_check_apartment_doors(world, refs)
		_check_surface_props(world, refs)
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
		for unit: String in UNITS:
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
			if record.kind == "wardrobe":
				check(prop.get("_case_wood") == record.mechanism.case_wood,
						"wardrobe retains its household wood: " + str(record.id))
				prop.call("interact", world.player)
				check("Close" in str(prop.call("interact_prompt")),
						"production wardrobe opens: " + str(record.id))
		# Free while cistern/wardrobe tweens are active, exercising their existing
		# teardown owners instead of waiting until all temporary state is idle.
		world.shutdown_for_tests()
		world.free()
		for ref in refs: check(ref.get_ref() == null, "batch subject retires with its world")
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("apartment_batch.json"),FileAccess.WRITE).store_string(
				JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("APARTMENT BATCH: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _check_room_circuits(world: OrisonV2RuntimeRoot, refs: Array[WeakRef]) -> void:
	var lighting: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/room_lighting.json"))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2_blockout.json"))
	var rooms: Dictionary = {}
	for space: Dictionary in layout.spaces:
		var identity := str(space.id)
		for prefix in ["F02_A_", "F02_B_", "F03_B_", "F04_B_"]:
			if identity.begins_with(prefix): rooms[identity] = true
	check(rooms.size() == 26, "all detailed apartment spaces covered")
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
			for candidate: String in UNITS:
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
	check(covered == 16, "all doors across all four detailed apartments covered")

func _check_surface_props(world: OrisonV2RuntimeRoot, refs: Array[WeakRef]) -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/domestic_surface_props.json"))
	var counts := {"2A":0, "2B":0, "3B":0, "4B":0}
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
	check(counts == {"2A":5, "2B":4, "3B":8, "4B":2}, "surface category roster across all apartments")
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
				var shape := mesh.get_node("Collision/CollisionShape3D") as CollisionShape3D
				check((shape.shape as BoxShape3D).size.is_equal_approx(size),
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
	check(count == 15, "all fifteen missing intervals have build coverage")
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
	var expected := {"cupboard":4, "coffee":2, "pinboard":2, "toolboard":1, "crate":1}
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
			var local := world.adapter.root.to_local(body.global_position)
			var floor := 3.2 if str(record.id).begins_with("2") else 6.4 if str(record.id).begins_with("3") else 9.6
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
	check(cupboards == ["2A", "2B", "3B", "4B"], "one kitchen wall cupboard per detailed apartment")
	check(timber_surfaces == 4 and plywood_surfaces == 1 and glass_surfaces == 2,
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
		for mesh: MeshInstance3D in radio.find_children("*", "MeshInstance3D", true, false):
			var material := mesh.material_override as StandardMaterial3D
			check(material != null and material.albedo_texture != null, "all receiver parts have texture-backed materials")
	check(radios.size() == 4 and emitters.size() == 4, "all four households have complete receivers")
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
	var reality_before := JSON.stringify(RealityState.data)
	for i in radios.size():
		radios[i].interact(world.player)
		for j in radios.size(): check(radios[j].powered == (i == j), "one household switch cannot power another")
		if i < emitters.size(): check(emitters[i].playing, "powered radio starts its programme")
		radios[i].interact(world.player)
		if i < emitters.size(): check(not emitters[i].playing, "radio switch returns programme to silence")
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
	for unit: String in UNITS:
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
	check(cabinets.size() == 4 and panels.size() == 4, "complete four-kitchen preparation category")
	for i in cabinets.size():
		var state_before := JSON.stringify(RealityState.data)
		cabinets[i].call("interact", world.player)
		check(JSON.stringify(RealityState.data) == state_before, "cabinet opening does not write campaign state")
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
		var state_before := JSON.stringify(RealityState.data)
		panel.call("interact", world.player)
		check(JSON.stringify(RealityState.data) == state_before, "cabinet closing does not write campaign state")
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
