extends Node
## Focused M11B proof for the two lateral service hall/core openings.
##
## Coordinates are never copied from the milestone prose. Each aperture and
## traversal is derived independently from the two connected space records.
## The runtime portion uses the production PlayerController's collision-bearing
## autopilot; the only position assignment is the legitimate initial stance,
## made before that controller enters the SceneTree.

const LAYOUT_PATH := "res://data/orison_v2_blockout.json"
const BLOCKOUT_SCENE_PATH := "res://scenes/building/orison_v2_blockout.tscn"
const RECEIPT_ENV := "M11B_OBJECTIVE_RECEIPT"
const PlayerScript := preload("res://scripts/player/player_controller.gd")

const BODY_RADIUS := 0.33
const STANDING_HEIGHT := 1.524
const MAINTENANCE_MIN_WIDTH := 0.91
const MAINTENANCE_MIN_HEAD := 2.13
const EPS := 0.001

const CASES := [
	{
		"opening_id": "F02_SERVICE_HALL_CORE_OPENING",
		"level": "F02",
		"hall_id": "F02_SERVICE_HALL",
		"core_id": "F02_SERVICE_CORE",
	},
	{
		"opening_id": "F04_SERVICE_HALL_CORE_OPENING",
		"level": "F04",
		"hall_id": "F04_SERVICE_HALL",
		"core_id": "F04_SERVICE_CORE",
	},
]

var failures := 0
var passes := 0
var _layout: Dictionary = {}
var _spaces := {}
var _levels := {}
var _blockout_scene: PackedScene
var _receipt := {
	"schema_version": 1,
	"task": "ORISON-V2-M11B",
	"checks": [],
	"contracts": {},
	"traversal": {},
	"teardown": {},
	"piece_two": {},
}


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			LAYOUT_PATH))
	_check(parsed is Dictionary, "authoritative blockout source parses")
	if not parsed is Dictionary:
		_finish()
		return
	_layout = parsed
	_index_source()
	_blockout_scene = load(BLOCKOUT_SCENE_PATH) as PackedScene
	_check(_blockout_scene != null, "production blockout scene loads")
	if _blockout_scene == null:
		_finish()
		return

	var contracts: Array[Dictionary] = []
	for case_record: Dictionary in CASES:
		contracts.append(_prove_source_contract(case_record))
	_check(contracts.size() == 2 and not contracts[0].is_empty()
			and not contracts[1].is_empty(),
			"both focused opening contracts derive independently")
	if contracts.size() != 2 or contracts[0].is_empty() \
			or contracts[1].is_empty():
		_finish()
		return

	await _warm_runtime(contracts[0])
	var baseline := _object_counts()
	_receipt.teardown["warmed_baseline"] = baseline.duplicate(true)

	var first: Dictionary = await _run_fresh_cycle(CASES[0], contracts[0])
	await _settle_teardown()
	var after_first := _object_counts()
	_receipt.teardown["after_f02"] = after_first.duplicate(true)

	var second: Dictionary = await _run_fresh_cycle(CASES[1], contracts[1])
	await _settle_teardown()
	var after_second := _object_counts()
	_receipt.teardown["after_f04"] = after_second.duplicate(true)

	_check(bool(first.get("released", false))
			and bool(second.get("released", false)),
			"both fresh worlds and PlayerControllers release through public queue_free")
	_check(int(after_second.objects) <= int(after_first.objects)
			and int(after_second.resources) <= int(after_first.resources)
			and int(after_second.orphan_nodes) <= int(after_first.orphan_nodes),
			"second warmed cycle causes no ObjectDB, resource, or orphan amplification")
	_check(int(after_second.objects) <= int(baseline.objects)
			and int(after_second.resources) <= int(baseline.resources)
			and int(after_second.orphan_nodes) <= int(baseline.orphan_nodes),
			"final teardown returns to the warmed ownership baseline")

	var same_topology: bool = contracts[0].topology == contracts[1].topology
	var same_cost: bool = first.get("opening_cost", {}) \
			== second.get("opening_cost", {})
	_receipt.piece_two = {
		"f02_topology": contracts[0].topology,
		"f04_topology": contracts[1].topology,
		"f02_cost": first.get("opening_cost", {}),
		"f04_cost": second.get("opening_cost", {}),
		"same_generic_topology": same_topology,
		"same_generic_cost": same_cost,
	}
	_check(same_topology and same_cost,
			"F04 is piece two: the same generic topology and build cost as F02")
	_finish()


func _index_source() -> void:
	for level: Dictionary in _layout.get("levels", []):
		_levels[str(level.get("id", ""))] = float(level.get("y", 0.0))
	for space: Dictionary in _layout.get("spaces", []):
		_spaces[str(space.get("id", ""))] = space


func _prove_source_contract(case_record: Dictionary) -> Dictionary:
	var ident := str(case_record.opening_id)
	var matches: Array[Dictionary] = []
	for candidate: Dictionary in _layout.get("openings", []):
		if str(candidate.get("id", "")) == ident:
			matches.append(candidate)
	_check(matches.size() == 1, ident + " is declared exactly once")
	if matches.size() != 1:
		return {}
	var opening: Dictionary = matches[0]
	var connects: Array = opening.get("connects", [])
	var expected_connects := [str(case_record.hall_id), str(case_record.core_id)]
	var endpoints_exist := connects.size() == 2
	for endpoint: String in expected_connects:
		endpoints_exist = endpoints_exist and _spaces.has(endpoint)
	_check(endpoints_exist and connects == expected_connects,
			ident + " names the existing hall and core endpoints")
	if not endpoints_exist:
		return {}
	var hall: Dictionary = _spaces[str(case_record.hall_id)]
	var core: Dictionary = _spaces[str(case_record.core_id)]
	var level := str(case_record.level)
	_check(str(hall.get("class", "")) == "service"
			and str(core.get("class", "")) == "core"
			and str(hall.get("level", "")) == level
			and str(core.get("level", "")) == level
			and str(opening.get("level", "")) == level,
			ident + " endpoints have the required service/core classes and level")

	# This call is independent for each record. No F02 boundary or center is
	# reused when the F04 contract is derived.
	var boundary := _shared_boundary(hall, core)
	_check(not boundary.is_empty(), ident + " endpoints share a positive wall")
	if boundary.is_empty():
		return {}
	var center: Array = opening.get("center", [])
	var axis := str(opening.get("axis", ""))
	var fixed := float(center[1] if axis == "x" else center[0]) \
			if center.size() == 2 else INF
	var along := float(center[0] if axis == "x" else center[1]) \
			if center.size() == 2 else INF
	var width := float(opening.get("width", 0.0))
	var height := float(opening.get("height", 0.0))
	var aperture_lo := along - width * 0.5
	var aperture_hi := along + width * 0.5
	_check(axis == str(boundary.axis) and is_equal_approx(fixed,
			float(boundary.fixed)), ident + " lies on the independently derived wall")
	_check(aperture_lo >= float(boundary.start) - EPS
			and aperture_hi <= float(boundary.finish) + EPS,
			ident + " entire width lies on the shared boundary")
	_check(width >= MAINTENANCE_MIN_WIDTH and width > BODY_RADIUS * 2.0
			and height >= MAINTENANCE_MIN_HEAD
			and height > STANDING_HEIGHT,
			ident + " clears the maintenance minimum and production capsule")
	var owner_id := str(opening.get("shared_wall_owner", ""))
	_check(owner_id == str(case_record.core_id),
			ident + " assigns the one physical shared wall to the core")

	# The traversal normal comes from the actual shared side, not from either
	# room's center. F04's hall and core have different depths, so a center-to-
	# center vector would be diagonal and would not prove the aperture normal.
	var hall_direction := _direction_from_core_to_space(str(boundary.a_side))
	var route_rect := _opening_route_rect(boundary, aperture_lo, aperture_hi)
	_prove_hazard_separation(ident, level, route_rect)

	var owner_side := str(boundary.b_side)
	if owner_id == str(case_record.hall_id):
		owner_side = str(boundary.a_side)
	var hall_side := str(boundary.a_side)
	var topology := {
		"axis": axis,
		"boundary_length_mm": roundi((float(boundary.finish)
				- float(boundary.start)) * 1000.0),
		"opening_offset_mm": roundi((along - float(boundary.start)) * 1000.0),
		"width_mm": roundi(width * 1000.0),
		"height_mm": roundi(height * 1000.0),
		"endpoint_classes": [str(hall.get("class", "")),
				str(core.get("class", ""))],
		"owner_role": "core",
		"owner_side": owner_side,
		"nonowner_side": hall_side,
	}
	var contract := {
		"id": ident,
		"level": level,
		"level_y": float(_levels.get(level, 0.0)),
		"opening": opening,
		"hall": hall,
		"core": core,
		"boundary": boundary,
		"aperture_lo": aperture_lo,
		"aperture_hi": aperture_hi,
		"along": along,
		"width": width,
		"height": height,
		"owner_id": owner_id,
		"owner_side": owner_side,
		"hall_side": hall_side,
		"hall_direction": hall_direction,
		"route_rect": route_rect,
		"topology": topology,
	}
	_receipt.contracts[ident] = _contract_receipt(contract)
	return contract


func _prove_hazard_separation(ident: String, level: String,
		route_rect: Array) -> void:
	var lift_clear := true
	for landing: Dictionary in _layout.get("lift_landings", []):
		if str(landing.get("level", "")) != level \
				or not str(landing.get("id", "")).contains("SERVICE"):
			continue
		lift_clear = lift_clear and not _rects_overlap(route_rect,
				_landing_clearance_rect(landing))
	_check(lift_clear, ident + " avoids the service-lift landing envelope")

	var risers_clear := true
	var floor_y := float(_levels.get(level, 0.0))
	for riser: Dictionary in _layout.get("risers", []):
		if float(riser.get("from_y", INF)) <= floor_y + STANDING_HEIGHT \
				and float(riser.get("to_y", -INF)) >= floor_y:
			risers_clear = risers_clear and not _rects_overlap(route_rect,
					riser.get("rect", []))
	_check(risers_clear, ident + " avoids all live riser and shaft footprints")

	var stairs_clear := true
	for stair: Dictionary in _layout.get("stairs", []):
		if level not in [str(stair.get("from", "")),
				str(stair.get("to", ""))]:
			continue
		stairs_clear = stairs_clear and not _rects_overlap(route_rect,
				_stair_footprint(stair))
	_check(stairs_clear,
			ident + " avoids stair starts, flights, void, and half-landing footprint")

	var returns_clear := true
	for platform: Dictionary in _layout.get("platforms", []):
		if str(platform.get("level", "")) == level \
				and str(platform.get("id", "")).contains("SERVICE_RETURN"):
			returns_clear = returns_clear and not _rects_overlap(route_rect,
					platform.get("rect", []))
	_check(returns_clear, ident + " avoids the service landing return")

	var swings_clear := true
	for door: Dictionary in _layout.get("doors", []):
		if str(door.get("level", "")) != level:
			continue
		swings_clear = swings_clear and not _rects_overlap(route_rect,
				_door_swing_rect(door))
	_check(swings_clear, ident + " avoids every same-level door swing")

	var envelopes_clear := true
	for envelope: Dictionary in _layout.get("envelopes", []):
		if str(envelope.get("level", "")) == level \
				and str(envelope.get("class", "")) == "clearance":
			envelopes_clear = envelopes_clear and not _rects_overlap(route_rect,
					envelope.get("rect", []))
	_check(envelopes_clear,
			ident + " avoids every same-level required clearance envelope")


func _warm_runtime(contract: Dictionary) -> void:
	var world := Node3D.new()
	world.name = "M11BWarmWorld"
	add_child(world)
	var blockout := _blockout_scene.instantiate() as Node3D
	world.add_child(blockout)
	await get_tree().process_frame
	var player: PlayerController = PlayerScript.new()
	player.position = _initial_core_stance(contract)
	world.add_child(player)
	for ignored in 8:
		await get_tree().physics_frame
	world.queue_free()
	world = null
	blockout = null
	player = null
	await _settle_teardown()


func _run_fresh_cycle(case_record: Dictionary,
		contract: Dictionary) -> Dictionary:
	var ident := str(contract.id)
	var world := Node3D.new()
	world.name = ident + "_FreshWorld"
	add_child(world)
	var blockout := _blockout_scene.instantiate() as Node3D
	blockout.name = "Blockout"
	world.add_child(blockout)
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(blockout.get("failures") is Array
			and (blockout.get("failures") as Array).is_empty(),
			ident + " production blockout builds without schema refusal")
	var opening_cost := _prove_built_opening(blockout, contract)

	# The sole position assignment happens while the production controller is
	# detached. It enters the tree already standing on the service landing.
	var player: PlayerController = PlayerScript.new()
	player.name = str(case_record.level) + "PlayerController"
	player.position = _initial_core_stance(contract)
	var position_assignments := 1
	world.add_child(player)
	for ignored in 12:
		await get_tree().physics_frame
	var player_shapes := player.find_children("*", "CollisionShape3D", true, false)
	var collision_shape: CollisionShape3D = player_shapes[0] as CollisionShape3D \
			if player_shapes.size() == 1 else null
	_check(collision_shape != null and collision_shape.shape is CapsuleShape3D
			and not collision_shape.disabled and not player.noclip,
			ident + " uses the live production capsule with collision enabled")
	_check(player.is_on_floor(), ident + " initial service-landing stance is grounded")

	var direction := contract.hall_direction as Vector2
	var normal3 := Vector3(direction.x, 0.0, direction.y)
	var plane_point := _opening_plane_point(contract)
	var core_near := plane_point - normal3 * 0.68
	var hall_target := plane_point + normal3 * 0.72
	var core_start := _initial_core_stance(contract)
	var facts := {
		"position_assignments": position_assignments,
		"noclip_observed": false,
		"teleport_observed": false,
		"ungrounded_frames": 0,
		"plane_crossings": [],
		"directions": [],
	}
	var arrival: Dictionary = await _autopilot_to(player, core_near,
			contract, 0, facts)
	var outbound: Dictionary = await _autopilot_to(player, hall_target,
			contract, 1, facts)
	var inbound: Dictionary = await _autopilot_to(player, core_near,
			contract, -1, facts)
	var landing_return: Dictionary = await _autopilot_to(player, core_start,
			contract, 0, facts)
	player.autopilot = Vector3.ZERO

	_check(bool(arrival.get("arrived", false))
			and bool(outbound.get("arrived", false)),
			str(case_record.level)
			+ " service landing/core -> opening -> service hall traverses")
	_check(bool(inbound.get("arrived", false))
			and bool(landing_return.get("arrived", false)),
			str(case_record.level)
			+ " service hall -> opening -> core/landing traverses")
	_check(bool(outbound.get("crossed", false))
			and bool(inbound.get("crossed", false))
			and (facts.plane_crossings as Array).size() == 2,
			ident + " records one aperture-plane crossing in each direction")
	_check(position_assignments == 1 and not bool(facts.noclip_observed)
			and not bool(facts.teleport_observed)
			and int(facts.ungrounded_frames) == 0,
			ident + " traversal stays grounded with no noclip or teleport")
	_receipt.traversal[ident] = facts.duplicate(true)

	var world_weak: WeakRef = weakref(world)
	var blockout_weak: WeakRef = weakref(blockout)
	var player_weak: WeakRef = weakref(player)
	world.queue_free()
	world = null
	blockout = null
	player = null
	await _settle_teardown()
	var released: bool = world_weak.get_ref() == null \
			and blockout_weak.get_ref() == null and player_weak.get_ref() == null
	_check(released, ident + " world, blockout, and controller weakrefs release")
	return {
		"opening_cost": opening_cost,
		"released": released,
	}


func _prove_built_opening(blockout: Node3D,
		contract: Dictionary) -> Dictionary:
	var ident := str(contract.id)
	var owner := blockout.get_node_or_null(str(contract.owner_id)) as Node3D
	var hall := blockout.get_node_or_null(str(contract.hall.id)) as Node3D
	_check(owner != null and hall != null,
			ident + " endpoint runtime nodes both exist")
	if owner == null or hall == null:
		return {}
	var reveal := blockout.get_node_or_null(ident) as Node3D
	var reveal_pieces := 0
	var reveal_collision := false
	if reveal != null:
		for child: Node in reveal.get_children():
			if child is MeshInstance3D:
				reveal_pieces += 1
				reveal_collision = reveal_collision \
						or _mesh_has_collision(child as MeshInstance3D)
	_check(reveal != null and bool(reveal.get_meta("non_colliding_reveal", false))
			and reveal_pieces == 3 and not reveal_collision,
			ident + " has one generic three-piece non-colliding cased reveal")
	var practical := reveal.get_node_or_null("ServicePractical") as Node3D \
			if reveal != null else null
	var practical_light := practical.get_node_or_null(
			"WarmServiceLight") as OmniLight3D if practical != null else null
	var practical_ok := practical != null and bool(practical.get_meta(
			"source_owned_service_practical", false)) \
			and practical.get_node_or_null("Backplate") is MeshInstance3D \
			and practical.get_node_or_null("OpalLens") is MeshInstance3D \
			and practical_light != null and practical_light.light_energy > 0.0 \
			and practical.find_children("Collision", "", true, false).is_empty()
	_check(practical_ok,
			ident + " has one generic source-owned non-colliding service practical")
	var owner_boxes := _side_wall_boxes(owner, str(contract.owner_side))
	var hall_boxes := _side_wall_boxes(hall, str(contract.hall_side))
	var owner_shared := _boxes_on_boundary(owner_boxes, contract.boundary)
	var hall_shared := _boxes_on_boundary(hall_boxes, contract.boundary)
	var head_count := 0
	var adjacent_count := 0
	var owner_collision_count := 0
	for box: Dictionary in owner_shared:
		owner_collision_count += int(bool(box.collision))
		if _box_is_aperture_head(box, contract):
			head_count += 1
		elif _box_vertical_overlaps(box, float(contract.level_y),
				float(contract.level_y) + float(contract.height)):
			adjacent_count += 1
	_check(owner_shared.size() == 3 and head_count == 1
			and adjacent_count == 2 and owner_collision_count == 3,
			ident + " core authors one cut as two jamb runs plus one colliding head")
	_check(hall_shared.is_empty(),
			ident + " hall omits the overlapping partition instead of duplicating it")
	var hall_nonoverlap := hall_boxes.size() - hall_shared.size()
	_check(hall_nonoverlap >= 1 and _all_boxes_collide(hall_boxes),
			ident + " hall wall outside the shared interval remains collision-bearing")

	var space_state := blockout.get_world_3d().direct_space_state
	var clear_rays := true
	for fraction: float in [0.08, 0.50, 0.92]:
		var y := float(contract.level_y) + float(contract.height) * fraction
		clear_rays = clear_rays and _wall_ray(space_state, contract, y,
				float(contract.along)).is_empty()
	_check(clear_rays, ident + " collision is absent throughout the aperture prism")
	_check(_capsule_prism_clear(space_state, contract),
			ident + " production capsule clears the wall plane and both approaches")

	var before := (float(contract.boundary.start)
			+ float(contract.aperture_lo)) * 0.5
	var after := (float(contract.aperture_hi)
			+ float(contract.boundary.finish)) * 0.5
	var adjacent_hits := 0
	for sample: float in [before, after]:
		var hit := _wall_ray(space_state, contract,
				float(contract.level_y) + minf(1.2, float(contract.height) * 0.5), sample)
		if not hit.is_empty() and _collider_belongs_to(hit.get("collider"), owner):
			adjacent_hits += 1
	_check(adjacent_hits == 2,
			ident + " adjacent shared-wall collision remains on both sides")
	var head_hit := _wall_ray(space_state, contract,
			float(contract.level_y) + float(contract.height)
			+ (float(_layout.dimensions.clear_height) - float(contract.height)) * 0.5,
			float(contract.along))
	_check(not head_hit.is_empty()
			and _collider_belongs_to(head_hit.get("collider"), owner),
			ident + " head collision remains above the opening")

	var floor_ok := _prove_floor_support(blockout, space_state, contract)
	var ceiling_ok := _prove_hall_ceiling(hall, contract)
	_check(floor_ok, ident + " floor support remains on both traversal sides")
	_check(ceiling_ok and not (contract.opening as Dictionary).has("no_ceiling")
			and not (contract.opening as Dictionary).has("no_floor"),
			ident + " introduces no floor or ceiling subtraction")

	return {
		"noncolliding_reveal_pieces": reveal_pieces,
		"source_practical_meshes": 2,
		"source_practical_lights": 1,
		"owner_partition_segments": owner_shared.size(),
		"owner_collision_segments": owner_collision_count,
		"head_segments": head_count,
		"adjacent_segments": adjacent_count,
		"nonowner_shared_segments": hall_shared.size(),
		"nonowner_retained_runs": hall_nonoverlap,
		"portal_clear_samples": 3,
		"floor_support_samples": 2,
	}


func _autopilot_to(player: PlayerController, target: Vector3,
		contract: Dictionary, expected_crossing: int, facts: Dictionary) -> Dictionary:
	var frames := 0
	var crossed := false
	var direction := contract.hall_direction as Vector2
	var previous_side := _plane_side(player.position, contract)
	var previous_position := player.position
	while _planar_distance(player.position, target) > 0.08:
		var offset := target - player.position
		offset.y = 0.0
		player.autopilot = offset.normalized()
		await get_tree().physics_frame
		frames += 1
		var here := player.position
		var step := here.distance_to(previous_position)
		if step > 0.13:
			facts.teleport_observed = true
		if player.noclip:
			facts.noclip_observed = true
		if not player.is_on_floor():
			facts.ungrounded_frames = int(facts.ungrounded_frames) + 1
		var side := _plane_side(here, contract)
		if expected_crossing != 0 and not crossed \
				and ((expected_crossing > 0 and previous_side <= 0.0 and side > 0.0)
				or (expected_crossing < 0 and previous_side >= 0.0 and side < 0.0)):
			var along := here.z if str(contract.boundary.axis) == "z" else here.x
			var within_aperture := along >= float(contract.aperture_lo) + BODY_RADIUS - 0.02 \
					and along <= float(contract.aperture_hi) - BODY_RADIUS + 0.02
			crossed = within_aperture
			(facts.plane_crossings as Array).append({
				"direction": "core_to_hall" if expected_crossing > 0 else "hall_to_core",
				"position": _vec3(here),
				"within_capsule_clear_span": within_aperture,
				"grounded": player.is_on_floor(),
				"noclip": player.noclip,
			})
		previous_side = side
		previous_position = here
		if frames > 360:
			break
	player.autopilot = Vector3.ZERO
	var arrived := _planar_distance(player.position, target) <= 0.08
	(facts.directions as Array).append({
		"target": _vec3(target),
		"arrived": arrived,
		"expected_crossing": expected_crossing,
		"crossed": crossed,
		"frames": frames,
	})
	return {"arrived": arrived, "crossed": crossed, "frames": frames}


func _prove_floor_support(blockout: Node3D,
		space_state: PhysicsDirectSpaceState3D, contract: Dictionary) -> bool:
	var direction := contract.hall_direction as Vector2
	var normal3 := Vector3(direction.x, 0.0, direction.y)
	var plane := _opening_plane_point(contract)
	var hall_point := plane + normal3 * (BODY_RADIUS + 0.18)
	var core_point := plane - normal3 * (BODY_RADIUS + 0.18)
	var hall_hit := _floor_ray(space_state, hall_point, float(contract.level_y))
	var core_hit := _floor_ray(space_state, core_point, float(contract.level_y))
	var hall_node := blockout.get_node_or_null(str(contract.hall.id)) as Node3D
	var platform := blockout.get_node_or_null(str(contract.level)
			+ "_SERVICE_LANDING")
	return not hall_hit.is_empty() and not core_hit.is_empty() \
			and _collider_belongs_to(hall_hit.get("collider"), hall_node) \
			and platform != null \
			and _collider_belongs_to(core_hit.get("collider"), platform)


func _prove_hall_ceiling(hall: Node3D, contract: Dictionary) -> bool:
	var ceiling := hall.get_node_or_null("Ceiling") as MeshInstance3D
	var floor := hall.get_node_or_null("Floor") as MeshInstance3D
	if ceiling == null or floor == null or not ceiling.mesh is BoxMesh \
			or not floor.mesh is BoxMesh:
		return false
	var expected_w := float(contract.hall.rect[2]) - float(contract.hall.rect[0])
	var expected_d := float(contract.hall.rect[3]) - float(contract.hall.rect[1])
	var ceiling_size := (ceiling.mesh as BoxMesh).size
	var floor_size := (floor.mesh as BoxMesh).size
	return is_equal_approx(ceiling_size.x, expected_w) \
			and is_equal_approx(ceiling_size.z, expected_d) \
			and is_equal_approx(floor_size.x, expected_w) \
			and is_equal_approx(floor_size.z, expected_d) \
			and _mesh_has_collision(floor)


func _capsule_prism_clear(space_state: PhysicsDirectSpaceState3D,
		contract: Dictionary) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = BODY_RADIUS
	shape.height = STANDING_HEIGHT
	var direction := contract.hall_direction as Vector2
	var normal3 := Vector3(direction.x, 0.0, direction.y)
	var plane := _opening_plane_point(contract)
	for offset: float in [-0.12, 0.0, 0.12]:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY,
				plane + normal3 * offset + Vector3.UP * (STANDING_HEIGHT * 0.5 + 0.025))
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if not space_state.intersect_shape(query, 16).is_empty():
			return false
	return true


func _wall_ray(space_state: PhysicsDirectSpaceState3D, contract: Dictionary,
		y: float, along: float) -> Dictionary:
	var direction := contract.hall_direction as Vector2
	var normal3 := Vector3(direction.x, 0.0, direction.y)
	var origin := _point_on_boundary(contract.boundary, along, y)
	var query := PhysicsRayQueryParameters3D.create(origin - normal3 * 0.38,
			origin + normal3 * 0.38)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_ray(query)


func _floor_ray(space_state: PhysicsDirectSpaceState3D, point: Vector3,
		floor_y: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
			Vector3(point.x, floor_y + 0.7, point.z),
			Vector3(point.x, floor_y - 0.45, point.z))
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_ray(query)


func _side_wall_boxes(space_node: Node3D, side: String) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	var prefix := "Wall" + side.capitalize()
	for child: Node in space_node.get_children():
		if child is MeshInstance3D and child.name.begins_with(prefix) \
				and (child as MeshInstance3D).mesh is BoxMesh:
			var mesh_node := child as MeshInstance3D
			var size := (mesh_node.mesh as BoxMesh).size
			boxes.append({
				"name": str(mesh_node.name),
				"center": mesh_node.global_position,
				"size": size,
				"collision": _mesh_has_collision(mesh_node),
			})
	return boxes


func _boxes_on_boundary(boxes: Array[Dictionary],
		boundary: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for box: Dictionary in boxes:
		var center: Vector3 = box.center
		var size: Vector3 = box.size
		var fixed := center.z if str(boundary.axis) == "x" else center.x
		var along := center.x if str(boundary.axis) == "x" else center.z
		var length := size.x if str(boundary.axis) == "x" else size.z
		var lo := along - length * 0.5
		var hi := along + length * 0.5
		if is_equal_approx(fixed, float(boundary.fixed)) \
				and minf(hi, float(boundary.finish)) \
				- maxf(lo, float(boundary.start)) > EPS:
			result.append(box)
	return result


func _box_is_aperture_head(box: Dictionary, contract: Dictionary) -> bool:
	var center: Vector3 = box.center
	var size: Vector3 = box.size
	var along := center.x if str(contract.boundary.axis) == "x" else center.z
	var length := size.x if str(contract.boundary.axis) == "x" else size.z
	var lo := along - length * 0.5
	var hi := along + length * 0.5
	var vertical_lo := center.y - size.y * 0.5
	return is_equal_approx(lo, float(contract.aperture_lo)) \
			and is_equal_approx(hi, float(contract.aperture_hi)) \
			and is_equal_approx(vertical_lo,
				float(contract.level_y) + float(contract.height))


func _box_vertical_overlaps(box: Dictionary, lo: float, hi: float) -> bool:
	var center: Vector3 = box.center
	var size: Vector3 = box.size
	return minf(center.y + size.y * 0.5, hi) \
			- maxf(center.y - size.y * 0.5, lo) > EPS


func _all_boxes_collide(boxes: Array[Dictionary]) -> bool:
	if boxes.is_empty():
		return false
	for box: Dictionary in boxes:
		if not bool(box.collision):
			return false
	return true


func _collider_belongs_to(value: Variant, owner: Node) -> bool:
	if not value is Node or owner == null:
		return false
	var cursor := value as Node
	while cursor != null:
		if cursor == owner:
			return true
		cursor = cursor.get_parent()
	return false


func _mesh_has_collision(mesh_node: MeshInstance3D) -> bool:
	for descendant: Node in mesh_node.find_children(
			"*", "CollisionShape3D", true, false):
		var shape_node := descendant as CollisionShape3D
		if shape_node != null and not shape_node.disabled \
				and shape_node.shape != null:
			return true
	return false


func _direction_from_core_to_space(space_side: String) -> Vector2:
	match space_side:
		"east":
			return Vector2.LEFT
		"west":
			return Vector2.RIGHT
		"north":
			return Vector2(0.0, -1.0)
		"south":
			return Vector2(0.0, 1.0)
	return Vector2.ZERO


func _shared_boundary(a: Dictionary, b: Dictionary) -> Dictionary:
	var ar: Array = a.get("rect", [])
	var br: Array = b.get("rect", [])
	if ar.size() != 4 or br.size() != 4:
		return {}
	var z_start := maxf(float(ar[1]), float(br[1]))
	var z_finish := minf(float(ar[3]), float(br[3]))
	if z_finish - z_start > EPS and is_equal_approx(float(ar[2]), float(br[0])):
		return {"a_side":"east", "b_side":"west", "axis":"z",
				"fixed":float(ar[2]), "start":z_start, "finish":z_finish}
	if z_finish - z_start > EPS and is_equal_approx(float(ar[0]), float(br[2])):
		return {"a_side":"west", "b_side":"east", "axis":"z",
				"fixed":float(ar[0]), "start":z_start, "finish":z_finish}
	var x_start := maxf(float(ar[0]), float(br[0]))
	var x_finish := minf(float(ar[2]), float(br[2]))
	if x_finish - x_start > EPS and is_equal_approx(float(ar[3]), float(br[1])):
		return {"a_side":"north", "b_side":"south", "axis":"x",
				"fixed":float(ar[3]), "start":x_start, "finish":x_finish}
	if x_finish - x_start > EPS and is_equal_approx(float(ar[1]), float(br[3])):
		return {"a_side":"south", "b_side":"north", "axis":"x",
				"fixed":float(ar[1]), "start":x_start, "finish":x_finish}
	return {}


func _opening_route_rect(boundary: Dictionary, lo: float, hi: float) -> Array:
	var depth := BODY_RADIUS + float(_layout.dimensions.partition_wall) * 0.5 + 0.20
	if str(boundary.axis) == "z":
		return [float(boundary.fixed) - depth, lo,
				float(boundary.fixed) + depth, hi]
	return [lo, float(boundary.fixed) - depth,
			hi, float(boundary.fixed) + depth]


func _landing_clearance_rect(landing: Dictionary) -> Array:
	var center := Vector2(float(landing.center[0]), float(landing.center[1]))
	var half_w := float(landing.width) * 0.5
	var depth := float(landing.clear_depth)
	var yaw := float(landing.yaw)
	var points: Array[Vector2] = []
	for local: Vector2 in [Vector2(-half_w, 0.0), Vector2(half_w, 0.0),
			Vector2(-half_w, depth), Vector2(half_w, depth)]:
		# Godot's positive Y rotation maps local +Z toward world +X.
		points.append(center + Vector2(local.x * cos(yaw) + local.y * sin(yaw),
				-local.x * sin(yaw) + local.y * cos(yaw)))
	return _aabb_of_points(points)


func _stair_footprint(stair: Dictionary) -> Array:
	var x0 := float(stair.origin[0])
	var z0 := float(stair.origin[1])
	var width := float(stair.width)
	var gap := float(stair.gap)
	var run := float(stair.tread) * float(stair.risers_per_flight)
	var finish_z := z0 + run + float(stair.landing_depth) + 0.7
	return [x0, z0, x0 + width * 2.0 + gap, finish_z]


func _door_swing_rect(door: Dictionary) -> Array:
	var x := float(door.center[0])
	var z := float(door.center[1])
	# A width-radius square conservatively contains either handed quarter-swing.
	var reach := float(door.width) + BODY_RADIUS
	return [x - reach, z - reach, x + reach, z + reach]


func _aabb_of_points(points: Array[Vector2]) -> Array:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for point: Vector2 in points:
		lo.x = minf(lo.x, point.x)
		lo.y = minf(lo.y, point.y)
		hi.x = maxf(hi.x, point.x)
		hi.y = maxf(hi.y, point.y)
	return [lo.x, lo.y, hi.x, hi.y]


func _rects_overlap(a: Variant, b: Variant) -> bool:
	if not a is Array or not b is Array or a.size() != 4 or b.size() != 4:
		return true
	return minf(float(a[2]), float(b[2])) - maxf(float(a[0]), float(b[0])) > EPS \
			and minf(float(a[3]), float(b[3])) - maxf(float(a[1]), float(b[1])) > EPS


func _initial_core_stance(contract: Dictionary) -> Vector3:
	var direction := contract.hall_direction as Vector2
	var normal3 := Vector3(direction.x, 0.0, direction.y)
	return _opening_plane_point(contract) - normal3 * 1.45


func _opening_plane_point(contract: Dictionary) -> Vector3:
	return _point_on_boundary(contract.boundary, float(contract.along),
			float(contract.level_y))


func _point_on_boundary(boundary: Dictionary, along: float, y: float) -> Vector3:
	if str(boundary.axis) == "z":
		return Vector3(float(boundary.fixed), y, along)
	return Vector3(along, y, float(boundary.fixed))


func _plane_side(point: Vector3, contract: Dictionary) -> float:
	var direction := contract.hall_direction as Vector2
	var normal3 := Vector3(direction.x, 0.0, direction.y)
	return (point - _opening_plane_point(contract)).dot(normal3)


func _rect_center_2d(rect: Array) -> Vector2:
	return Vector2((float(rect[0]) + float(rect[2])) * 0.5,
			(float(rect[1]) + float(rect[3])) * 0.5)


func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _contract_receipt(contract: Dictionary) -> Dictionary:
	return {
		"level": contract.level,
		"endpoints": [contract.hall.id, contract.core.id],
		"endpoint_classes": [contract.hall.get("class", ""),
				contract.core.get("class", "")],
		"boundary": contract.boundary.duplicate(true),
		"opening_interval": [contract.aperture_lo, contract.aperture_hi],
		"width": contract.width,
		"height": contract.height,
		"shared_wall_owner": contract.owner_id,
		"route_rect": contract.route_rect.duplicate(),
		"topology": contract.topology.duplicate(true),
	}


func _vec3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _object_counts() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(
				Performance.OBJECT_RESOURCE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(
				Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}


func _settle_teardown() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _check(ok: bool, label: String) -> void:
	(_receipt.checks as Array).append({"label":label, "pass":ok})
	if ok:
		passes += 1
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)


func _write_receipt_if_requested() -> void:
	var path := OS.get_environment(RECEIPT_ENV)
	if path.is_empty():
		return
	_receipt["result"] = "PASS" if failures == 0 else "FAIL"
	_receipt["passes"] = passes
	_receipt["failures"] = failures
	var absolute := ProjectSettings.globalize_path(path) \
			if path.begins_with("res://") or path.begins_with("user://") else path
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		failures += 1
		push_error("M11B objective receipt could not be written: " + absolute)
		return
	file.store_string(JSON.stringify(_receipt, "\t"))
	file = null
	print("[M11B RECEIPT] " + absolute)


func _finish() -> void:
	_write_receipt_if_requested()
	print("ORISON V2 M11B SERVICE OPENINGS: %s checks=%d" % [
			"PASS" if failures == 0 else "FAIL (%d)" % failures,
			passes + failures])
	get_tree().quit(failures)
