extends Node
## Gate A/K0 contract: exact source envelope, unchanged portal clearance,
## historical exit-kiosk finish and visible architectural collision. No stair
## opening exists in this phase.

const PORTAL_W := 11.0
const PORTAL_E := 17.0
const KIOSK_W := 18.10
const KIOSK_E := 19.75
const KIOSK_S := -33.25
const KIOSK_N := -27.80

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
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/building_layout.json"))
	_check("generated layout parses", data is Dictionary)
	var floor_furniture: Array = []
	var records: Array = []
	var floor_markers: Array = []
	if data is Dictionary:
		for floor_data: Dictionary in data.get("floors", []):
			if String(floor_data.get("id", "")) != "F01":
				continue
			floor_markers = floor_data.get("markers", [])
			floor_furniture = floor_data.get("furniture", [])
			for item: Dictionary in floor_furniture:
				if String(item.get("batch", "")) == \
						"passage_proxy_gateway":
					records.append(item)
	_check("Gate A/K1 owns exactly 249 source records", records.size() == 249)
	_check("every Gate A record is STREET-owned", records.all(
			func(item: Dictionary) -> bool:
				return String(item.get("zone", "")) == "STREET"))
	var host := records.filter(func(item: Dictionary) -> bool:
		var item_id := String(item.get("id", ""))
		return item_id.contains("gateway_host_") \
				or item_id.ends_with("gateway_name_band") \
				or item_id.ends_with("gateway_hood"))
	var kiosk := records.filter(func(item: Dictionary) -> bool:
		return String(item.get("id", "")).contains("proxy_kiosk_"))
	_check("six host records and 243 kiosk records are distinct",
			host.size() == 6 and kiosk.size() == 243)
	var exit_letters := kiosk.filter(func(item: Dictionary) -> bool:
		return String(item.get("id", "")).contains("kiosk_exit_letter"))
	var transit_letters := kiosk.filter(func(item: Dictionary) -> bool:
		return String(item.get("id", "")).contains("kiosk_transit_letter"))
	_check("K0 carries player-facing geometric EXIT lettering",
			exit_letters.size() == 35
			and _letter_mean_x(exit_letters, "exit_letter_00_")
					> _letter_mean_x(exit_letters, "exit_letter_03_")
			and _record_x(exit_letters, "exit_letter_00_1_0")
					> _record_x(exit_letters, "exit_letter_00_0_2"))
	_check("K0 carries player-facing subordinate RAPID TRANSIT lettering",
			transit_letters.size() == 110
			and _letter_mean_x(transit_letters, "transit_letter_00_")
					> _letter_mean_x(transit_letters, "transit_letter_12_"))
	_check("K0 roof is four glass strips on four transverse ribs",
			kiosk.filter(func(item: Dictionary) -> bool:
				return String(item.get("id", "")).contains(
						"kiosk_canopy_glass")).size() == 4
			and kiosk.filter(func(item: Dictionary) -> bool:
				return String(item.get("id", "")).contains(
						"kiosk_roof_rib")).size() == 4)
	_check("K0 kiosk uses no reflective blockout metal",
			kiosk.all(func(item: Dictionary) -> bool:
				return String(item.get("mat", "")) != "metal"))
	var steps := kiosk.filter(func(item: Dictionary) -> bool:
		var item_id := String(item.get("id", ""))
		return item_id.contains("kiosk_stair_") \
				and not item_id.contains("stair_rail") \
				and not item_id.contains("stair_post"))
	steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", "")))
	var stair_ruled := steps.size() == 8
	for i in steps.size():
		var step: Dictionary = steps[i]
		var rect: Array = step.get("rect", [])
		var expected_n := KIOSK_N - 0.18 - i * 0.38
		var expected_top := -0.14 - i * 0.16
		stair_ruled = stair_ruled and rect.size() == 4 \
				and is_equal_approx(float(rect[0]), 18.40) \
				and is_equal_approx(float(rect[2]), 19.45) \
				and is_equal_approx(float(rect[1]), expected_n - 0.38) \
				and is_equal_approx(float(rect[3]), expected_n) \
				and is_equal_approx(float(step.get("z0", 0.0))
						+ float(step.get("h", 0.0)), expected_top)
	_check("K1 owns eight real descending treads in a 1.05 m clear stair",
			stair_ruled)
	_check("K1 owns tiled cheeks, masked turn and finite dark terminus",
			kiosk.filter(func(item: Dictionary) -> bool:
				return String(item.get("id", "")).contains(
						"kiosk_tiled_cheek")).size() == 2
			and kiosk.filter(func(item: Dictionary) -> bool:
				return String(item.get("id", "")).contains(
						"kiosk_tiled_turn")).size() == 1
			and kiosk.filter(func(item: Dictionary) -> bool:
				return String(item.get("id", "")).contains(
						"kiosk_dark_terminus")).size() == 1)
	_check("K1 handrails stay in the existing pipe draw",
			kiosk.filter(func(item: Dictionary) -> bool:
				return String(item.get("id", "")).contains(
						"kiosk_stair_rail")).size() == 2
			and kiosk.filter(func(item: Dictionary) -> bool:
				return String(item.get("id", "")).contains(
						"kiosk_stair_post")).size() == 4)
	var sidewalk_pieces := floor_furniture.filter(func(item: Dictionary) -> bool:
		return String(item.get("id", "")).contains("sidewalk_s_"))
	_check("K1 replaces the solid south sidewalk with three exact cut pieces",
			sidewalk_pieces.size() == 3
			and floor_furniture.all(func(item: Dictionary) -> bool:
				return String(item.get("id", "")) != "site_sidewalk_s"))
	var gateway_lights := floor_markers.filter(func(item: Dictionary) -> bool:
		return String(item.get("id", "")).begins_with("PASSAGE_PORTAL_LT_"))
	var east_lights := gateway_lights.filter(func(item: Dictionary) -> bool:
		return String(item.get("id", "")) == "PASSAGE_PORTAL_LT_E" \
				and item.get("pos", []) == [19.88, -27.516, 2.82])
	_check("K0 reuses exactly two lights and moves the east one to the kiosk",
			gateway_lights.size() == 2 and east_lights.size() == 1)

	var bounds := _record_bounds(kiosk)
	_check("kiosk x envelope is exactly 18.10..19.75",
			is_equal_approx(bounds.x, KIOSK_W)
			and is_equal_approx(bounds.z, KIOSK_E))
	_check("kiosk y envelope is exactly -33.25..-27.80",
			is_equal_approx(bounds.y, KIOSK_S)
			and is_equal_approx(bounds.w, KIOSK_N))
	var low_route_intrusions := records.filter(func(item: Dictionary) -> bool:
		if item.has("asm") or float(item.get("z0", 0.0)) >= 2.10:
			return false
		var rect: Array = item.get("rect", [])
		return rect.size() == 4 and float(rect[2]) > PORTAL_W + 0.001 \
				and float(rect[0]) < PORTAL_E - 0.001)
	_check("no player-height Gate A record enters the six-metre route",
			low_route_intrusions.is_empty())

	var root: Node3D = load(
			"res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	await get_tree().physics_frame
	var hoarding_faces := root.find_child(
			"StreetEndHoardingFaces", true, false) as MultiMeshInstance3D
	_check("both sides of all four containment boards are visibly finished",
			hoarding_faces != null and hoarding_faces.multimesh != null
			and hoarding_faces.multimesh.instance_count == 8)
	_space = root.get_viewport().find_world_3d().direct_space_state
	_capsule.radius = 0.33
	_capsule.height = 1.524
	_check("portal centre remains capsule-clear",
			_sweep(Vector3(14.0, 0.80, 26.0),
					Vector3(14.0, 0.80, 34.0)) > 0.999)
	_check("the visible kiosk gate prevents entry",
			_sweep(Vector3(18.925, 0.80, 26.0),
					Vector3(18.925, 0.80, 29.0)) < 0.999)
	_check("the visible kiosk wainscot owns its side collision",
			_sweep(Vector3(17.30, 0.80, 30.0),
					Vector3(18.60, 0.80, 30.0)) < 0.999)
	var stair_hit := _ray_down(Vector3(18.925, 1.0, 28.10))
	var walk_hit := _ray_down(Vector3(17.80, 1.0, 28.10))
	var stair_pos: Vector3 = stair_hit.get("position", Vector3.ZERO)
	var walk_pos: Vector3 = walk_hit.get("position", Vector3.ZERO)
	var stair_collider: Node = stair_hit.get("collider", null)
	var walk_collider: Node = walk_hit.get("collider", null)
	print("[VANTRY K1] cut ray y=%.4f collider=%s; walk y=%.4f collider=%s"
			% [stair_pos.y,
				root.get_path_to(stair_collider) if stair_collider != null else "none",
				walk_pos.y,
				root.get_path_to(walk_collider) if walk_collider != null else "none"])
	_check("the pavement is physically cut above the first descending tread",
			not stair_hit.is_empty()
			and stair_pos.y < -0.10)
	_check("the sidewalk beside the kiosk remains at street level",
			not walk_hit.is_empty()
			and absf(walk_pos.y - 0.01) < 0.02)
	print("[VANTRY GATEWAY] RESULT: %s (%d failures)" %
			["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)


func _record_x(records: Array, id_fragment: String) -> float:
	for item: Dictionary in records:
		if String(item.get("id", "")).contains(id_fragment):
			var rect: Array = item.get("rect", [])
			if rect.size() == 4:
				return (float(rect[0]) + float(rect[2])) * 0.5
	return -INF


func _letter_mean_x(records: Array, id_fragment: String) -> float:
	var total := 0.0
	var count := 0
	for item: Dictionary in records:
		if not String(item.get("id", "")).contains(id_fragment):
			continue
		var rect: Array = item.get("rect", [])
		if rect.size() != 4:
			continue
		total += (float(rect[0]) + float(rect[2])) * 0.5
		count += 1
	return total / float(count) if count > 0 else -INF


func _record_bounds(records: Array) -> Vector4:
	var x0 := INF
	var y0 := INF
	var x1 := -INF
	var y1 := -INF
	for item: Dictionary in records:
		if item.has("rect"):
			var rect: Array = item["rect"]
			x0 = minf(x0, float(rect[0]))
			y0 = minf(y0, float(rect[1]))
			x1 = maxf(x1, float(rect[2]))
			y1 = maxf(y1, float(rect[3]))
		elif item.has("p0") and item.has("p1"):
			var radius := float(item.get("r", 0.0))
			for point: Array in [item["p0"], item["p1"]]:
				x0 = minf(x0, float(point[0]) - radius)
				y0 = minf(y0, float(point[1]) - radius)
				x1 = maxf(x1, float(point[0]) + radius)
				y1 = maxf(y1, float(point[1]) + radius)
	return Vector4(x0, y0, x1, y1)


func _sweep(from: Vector3, to: Vector3) -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.transform = Transform3D(Basis(), from)
	query.motion = to - from
	query.collide_with_areas = false
	var result := _space.cast_motion(query)
	return float(result[0]) if result.size() >= 1 else 0.0


func _ray_down(at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
			at, Vector3(at.x, -2.0, at.z))
	query.collide_with_areas = false
	return _space.intersect_ray(query)
