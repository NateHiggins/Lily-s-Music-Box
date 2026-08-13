extends Node
## Phase 4 proof: both pavements and the carriageway end in authored visible
## fabric.  The test deliberately starts inside the approved stage and sweeps
## outward with the player's capsule; a clear result recreates Check 1's leak.

const STAGE_W := -20.10
const STAGE_E := 20.60
const NORTH_WALK_Z := 12.10
const ROAD_Z := 19.322
const SOUTH_WALK_Z := 26.105
const BOUNDARY_MASK := 1 << 20

var _fails := 0
var _space: PhysicsDirectSpaceState3D
var _capsule := CapsuleShape3D.new()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root: Node3D = load(
			"res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	await get_tree().physics_frame
	_space = root.get_viewport().find_world_3d().direct_space_state
	_capsule.radius = 0.33
	_capsule.height = 1.524

	var old: Node = root.find_child(
			"ExteriorStreetStageBoundary", true, false)
	var boundary: Node = root.find_child(
			"StreetEndWeatherBoundary", true, false)
	_check("the temporary partial stage boundary is retired", old == null)
	_check("the final street-end boundary exists", boundary is StaticBody3D)
	if boundary is StaticBody3D:
		var shapes: Array[Node] = boundary.get_children()
		_check("six named collision spans cover two complete street sections",
				shapes.size() == 6)
		var unexplained := []
		for child in shapes:
			if child is not CollisionShape3D \
					or String(child.get_meta("visible_owner", "")) == "":
				unexplained.append(child.name)
		_check("every collision span names its visible owner",
				unexplained.is_empty())

	var detail: ExteriorDetailPass = root.exterior_detail_pass
	var spans: Array = detail.boundary_visible_spans if detail else []
	var works := spans.filter(func(row):
		return row.get("owner", "") == "construction_hoarding")
	var storms := spans.filter(func(row):
		return row.get("owner", "") == "storm_curtain")
	_check("four pavement spans are owned by visible construction hoarding",
			works.size() == 4)
	_check("the hoarding faces and work beacons are live rendered architecture",
			get_tree().get_nodes_in_group("street_end_architecture").size() == 2)
	_check("both carriageway spans are owned by visible weather",
			storms.size() == 2)
	var weather := get_tree().get_nodes_in_group("street_end_weather")
	_check("both street ends own live weather geometry", weather.size() == 2)
	for end in weather:
		_check("%s carries three local storm layers" % end.name,
				end.get_child_count() == 3
				and end.get_children().all(func(node):
					return node is MeshInstance3D and node.visible))

	_check("the central north pavement remains reachable",
			_not_stuck_world(Vector3(0.0, 0.9, NORTH_WALK_Z)))
	_check("the central south pavement remains reachable",
			_not_stuck_world(Vector3(0.0, 0.9, SOUTH_WALK_Z)))

	# All three lanes remain on the playable side of the final owner. Other
	# local scenery is deliberately excluded here: the extra collision bit asks
	# only whether the new boundary itself was placed inward of its ruled x.
	for row in [["west north pavement", Vector3(-18.0, 0.9, NORTH_WALK_Z)],
			["west carriageway", Vector3(-18.0, 0.9, ROAD_Z)],
			["west south pavement", Vector3(-18.0, 0.9, SOUTH_WALK_Z)],
			["east north pavement", Vector3(18.0, 0.9, NORTH_WALK_Z)],
			["east carriageway", Vector3(18.0, 0.9, ROAD_Z)],
			["east south pavement", Vector3(18.0, 0.9, SOUTH_WALK_Z)]]:
		_check("%s remains inside the final boundary" % row[0],
				_not_stuck(row[1]))

	# And each lane terminates at the same approved x control.  Naming the
	# collider guards against a crate, lamp or passing prop accidentally making
	# this test green.
	for row in [["west north pavement", Vector3(-18.0, 0.9, NORTH_WALK_Z),
				Vector3(-23.0, 0.9, NORTH_WALK_Z), STAGE_W],
			["west carriageway", Vector3(-18.0, 0.9, ROAD_Z),
				Vector3(-23.0, 0.9, ROAD_Z), STAGE_W],
			["west south pavement", Vector3(-18.0, 0.9, SOUTH_WALK_Z),
				Vector3(-23.0, 0.9, SOUTH_WALK_Z), STAGE_W],
			["east north pavement", Vector3(18.0, 0.9, NORTH_WALK_Z),
				Vector3(23.5, 0.9, NORTH_WALK_Z), STAGE_E],
			["east carriageway", Vector3(18.0, 0.9, ROAD_Z),
				Vector3(23.5, 0.9, ROAD_Z), STAGE_E],
			["east south pavement", Vector3(18.0, 0.9, SOUTH_WALK_Z),
				Vector3(23.5, 0.9, SOUTH_WALK_Z), STAGE_E]]:
		var result := _sweep(row[1], row[2])
		print("    %s fraction=%.3f collider=%s" % [row[0],
				float(result.get("fraction", 1.0)),
				String(result.get("collider_name", ""))])
		_check("%s is contained by the authored street end" % row[0],
				float(result.get("fraction", 1.0)) < 0.999
				and result.get("collider_name", "")
				== "StreetEndWeatherBoundary")
		var stop_x: float = lerpf(row[1].x, row[2].x,
				float(result.get("fraction", 1.0)))
		_check("%s stops at the ruled x control" % row[0],
				absf(stop_x - float(row[3])) < 0.75)

	print("[STREET CONTAINMENT] RESULT: %s (%d failures)" %
			["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)


func _query(at: Vector3) -> PhysicsShapeQueryParameters3D:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _capsule
	params.transform = Transform3D(Basis(), at)
	params.collide_with_areas = false
	params.collision_mask = BOUNDARY_MASK
	return params


func _not_stuck(at: Vector3) -> bool:
	return _space.intersect_shape(_query(at), 8).is_empty()


func _not_stuck_world(at: Vector3) -> bool:
	var params := _query(at)
	params.collision_mask = 1
	return _space.intersect_shape(params, 8).is_empty()


func _sweep(from: Vector3, to: Vector3) -> Dictionary:
	var params := _query(from)
	params.motion = to - from
	var cast := _space.cast_motion(params)
	var fraction: float = cast[0] if not cast.is_empty() else 1.0
	var collider_name := ""
	if fraction < 0.999:
		# Put the capsule a centimetre into the contact manifold so the direct
		# overlap names the body that stopped it.
		var contact := from + (to - from) * minf(1.0, fraction + 0.01)
		for hit in _space.intersect_shape(_query(contact), 8):
			var collider = hit.get("collider")
			if collider != null and collider.name == "StreetEndWeatherBoundary":
				collider_name = collider.name
				break
	return {"fraction": fraction, "collider_name": collider_name}
