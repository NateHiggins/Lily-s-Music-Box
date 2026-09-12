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
		var refs: Array[WeakRef] = []
		_check_room_circuits(world, refs)
		_check_apartment_doors(world, refs)
		_check_surface_props(world, refs)
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
