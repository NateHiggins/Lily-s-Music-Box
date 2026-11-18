extends Node
## The reality-affected props and the storage-room rule board in V2
## (v1r_case_presentation_20261109). Mounts the family on the booted V2 world
## through its one entry point, then checks: all 62 catalogue ids are present
## or bound; each cluster's three stand in their case's flat and are registered
## with that flat's controller; added library objects rest on real supports
## and wear authored charts and catalogue finishes; a live rule seizes a flat's
## props and stabilising puts every one back; the rule board lists a rule the
## case manager records. Windowed with SHOT_DIR it photographs each in place.
const CaseProps := preload("res://scripts/building/orison_v2_case_props.gd")
const Prop := preload("res://scripts/building/orison_v2_reality_affected_prop.gd")
const Binding := preload("res://scripts/building/orison_v2_reality_affected_binding.gd")
const REST_TOLERANCE := 0.004

var _fails := 0
var _checks := 0
var world: Node
var _view := Vector3.ZERO
var _target := Vector3.ZERO
var _eye := Vector3(0, 1.6, 0)
var _filming := false


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _ready() -> void:
	process_priority = 1000
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not world.startup_failed, "the V2 world starts")
	if world.startup_failed:
		_finish()
		return
	var controllers: Dictionary = world.reality_controllers
	var before := world.find_children("*", "MeshInstance3D", true, false).size()
	var result: Dictionary = world.case_props
	var props: Dictionary = result.props
	var drivers: Dictionary = result.drivers
	_check((result.errors as Array).is_empty(), "the family mounts without errors: %s" % [result.errors])
	var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CaseProps.CATALOGUE))
	var placements: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CaseProps.PLACEMENTS)).props
	_check(int(catalogue.expected_prop_count) == 62 and props.size() == 62, "62 of 62 present or bound (%d)" % props.size())
	_check(placements.size() == 62, "the placement table accounts for exactly the 62 ids (%d)" % placements.size())
	_check(get_tree().get_nodes_in_group("reality_affected_props").size() >= 62,
		"all 62 carry V1's affected-prop behaviour (group)")

	# Let the world finish loading before anything timed.
	var steady := 0
	var waited := 0
	var last := Time.get_ticks_usec()
	while steady < 60 and waited < 3000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		steady = steady + 1 if now - last < 250000 else 0
		last = now
		waited += 1
	var any_driver: Node = drivers.values()[0] if not drivers.is_empty() else null
	_check(steady >= 60 and any_driver != null and any_driver.can_process(), "the world is steady and the props process")

	var added := 0
	var bound := 0
	var registered: Dictionary = {}
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for cluster: Dictionary in catalogue.case_clusters:
		var case_id := str(cluster.case_id)
		var controller: ApartmentRealityController = controllers.get(case_id)
		_check(controller != null and controller.unit == str(cluster.unit), "%s has its flat's controller" % case_id)
		for spec: Dictionary in cluster.props:
			var id := str(spec.id)
			var node: Node3D = props.get(id)
			var driver: Node3D = drivers.get(id)
			_check(node != null and driver != null, "%s is present or bound" % id)
			if node == null or driver == null or controller == null:
				continue
			_check(driver.prop_id == id and driver.display_name == str(spec.name) and driver.kind == str(spec.kind)
				and driver.case_id == case_id, "%s keeps its catalogue identity" % id)
			var probe := _centre(node, driver)
			_check(world.unit_at_world(probe) == str(cluster.unit),
				"%s stands in %s (found '%s' at %s)" % [id, cluster.unit, world.unit_at_world(probe), probe])
			_check(controller._snapshots.has(node), "%s is registered with %s's controller" % [id, cluster.unit])
			registered[id] = node.transform
			if controller._snapshots.has(node):
				var snapshot: Dictionary = controller._snapshots[node]
				registered[id] = snapshot.transform
			if driver is Binding:
				bound += 1
				_check(str(placements[id].get("counterpart", "")) == str(node.name), "%s is V2's own %s" % [id, node.name])
			else:
				added += 1
				_rests(space, id, node, driver)
	for spec: Dictionary in catalogue.shared_props:
		var id := str(spec.id)
		var node: Node3D = props.get(id)
		var driver: Node3D = drivers.get(id)
		_check(node != null and driver != null, "shared %s is present or bound" % id)
		if node == null or driver == null:
			continue
		_check(driver.case_id == "" and driver.display_name == str(spec.name), "shared %s keeps its catalogue identity" % id)
		var level := "B1" if str(placements[id].get("level", "")) == "B1" else ""
		if driver is Binding:
			bound += 1
		else:
			added += 1
			_rests(space, id, node, driver)
			if level == "B1":
				_check(str(world.room_at_world(_centre(node, driver))).begins_with("B1_"), "shared %s is in the basement store" % id)
	print("[V2 CASE PROPS] bound to V2 objects %d, added from the library %d" % [bound, added])
	_check(bound + added == 62, "every id is one or the other")

	# Surfaces: authored charts and catalogue finishes on every added mesh.
	var board: Node3D = result.rule_board
	var holders: Array = []
	for id: String in drivers:
		if drivers[id] is not Binding:
			holders.append(drivers[id])
	if board != null:
		holders.append(board)
	var surfaces := 0
	var triangles := 0
	for holder: Node3D in holders:
		var draws := holder.find_children("*", "MeshInstance3D", true, false)
		_check(not draws.is_empty(), "%s draws its library object" % holder.name)
		for draw: MeshInstance3D in draws:
			_check(draw.mesh is ArrayMesh and draw.mesh is not PrimitiveMesh, "%s/%s is authored geometry" % [holder.name, draw.name])
			var finish := draw.material_override as StandardMaterial3D
			_check(finish != null and finish.albedo_texture != null and finish.roughness_texture != null
				and finish.normal_texture != null and not finish.uv1_triplanar
				and finish.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,
				"%s/%s wears a catalogue finish on its own chart" % [holder.name, draw.name])
			for surface in draw.mesh.get_surface_count():
				var arrays := draw.mesh.surface_get_arrays(surface)
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
				var finite := true
				for value in uv:
					finite = finite and is_finite(value.x) and is_finite(value.y)
				_check(uv.size() == vertices.size() and finite and tangents.size() == vertices.size() * 4,
					"%s/%s has a finite UV and tangent per vertex" % [holder.name, draw.name])
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
				surfaces += 1
	print("[V2 CASE PROPS] added draws %d, triangles %d, mesh instances in the world before %d" % [surfaces, triangles, before])

	# The rule board hangs on the storage-room wall and reads V1's record.
	_check(board != null, "the rule board is mounted")
	if board != null:
		_check(str(world.room_at_world(board.global_position)) == "B1_RESIDENT_STORAGE",
			"the board is in the resident storage room (%s)" % world.room_at_world(board.global_position))
		var back := -board.global_transform.basis.z
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(board.global_position, board.global_position + back * 0.5))
		var gap: float = board.global_position.distance_to(hit.position) if not hit.is_empty() else -1.0
		_check(not hit.is_empty() and absf(gap - board.WALL_OFFSET) <= 0.006,
			"the board's straps reach the wall (wall %.3f m behind, built for %.3f)" % [gap, board.WALL_OFFSET])
		var labels := board.find_children("*", "Label3D", true, false)
		_check(labels.size() == 2, "the board carries V1's header and rule list")
		for label: Label3D in labels:
			_check(not label.double_sided, "board lettering is single-sided")
		_check(board.rules_text().contains("NO EXCEPTIONS ACCEPTED"), "an empty record reads as V1 wrote it")
		_check(board.find_children("*", "MeshInstance3D", true, false).all(
			func(draw: MeshInstance3D) -> bool: return draw.mesh is not PrimitiveMesh), "V1's slab is retired")

	# Live rules seize each flat's props; stabilising restores every one.
	var shots := OS.get_environment("SHOT_DIR")
	if shots != "":
		await _film_all(shots, catalogue, props, drivers, board, "")
	for cluster: Dictionary in catalogue.case_clusters:
		RealityRules._refresh(str(cluster.case_id), {"stage": RealityRules.LIVE_STAGES[0], "manifestation_intensity": 1.0})
	for i in 45: await get_tree().process_frame
	var spinning := 0
	for cluster: Dictionary in catalogue.case_clusters:
		for spec: Dictionary in cluster.props:
			var id := str(spec.id)
			var node: Node3D = props.get(id)
			var driver: Node3D = drivers.get(id)
			if node == null or driver == null:
				continue
			var state: Dictionary = driver.affected_state()
			_check(driver.affected() and is_equal_approx(float(state.intensity), 1.0), "%s is seized by its live rule" % id)
			_check(bool(state.glowing), "%s wears the glow on its own finishes" % id)
			_check(float(driver.glow_level()) > 0.004, "%s's finishes are lit by V1's emission (%.2f)" % [id, float(driver.glow_level())])
			if bool(state.fixed):
				_check(node.transform.is_equal_approx(registered[id]), "%s is a fixed fitting and is not carried" % id)
			else:
				_check(not node.transform.is_equal_approx(registered[id]), "%s is carried off its place" % id)
			if "duplicate" in (state.verbs as Array):
				_check(bool(state.duplicate) and driver._echo_root.find_children("*", "MeshInstance3D", true, false).size() > 0,
					"%s shows its impossible duplicate" % id)
			for part: Dictionary in driver._parts:
				if str(part.motion) == "spin" and "freeze" not in (state.verbs as Array):
					spinning += 1
					_check(not (part.draw as MeshInstance3D).transform.is_equal_approx(part.rest), "%s's %s turns" % [id, part.component])
	print("[V2 CASE PROPS] spinning parts seen turning: %d" % spinning)
	if shots != "":
		await _film_live(shots, catalogue, props, drivers)
	for cluster: Dictionary in catalogue.case_clusters:
		RealityRules._refresh(str(cluster.case_id), {"stage": "unseen"})
	for pass_index in 2:
		for cluster: Dictionary in catalogue.case_clusters:
			for spec: Dictionary in cluster.props:
				var id := str(spec.id)
				var node: Node3D = props.get(id)
				var driver: Node3D = drivers.get(id)
				if node == null or driver == null:
					continue
				_check(node.transform.is_equal_approx(registered[id]),
					"%s is back at its registered transform (%s)" % [id, "at once" if pass_index == 0 else "and stays"])
				if pass_index == 1:
					_check(not driver.affected() and not bool(driver.affected_state().glowing),
						"%s has given its shared finishes back" % id)
		if pass_index == 0:
			for i in 240: await get_tree().process_frame

	# The board gains a rule by the case manager's own resolve path.
	if board != null:
		var solved := ""
		for case_id: String in RealityCases.definitions:
			if str(RealityCases.definition(case_id).get("portal_rule", "")) != "":
				solved = case_id
				break
		_check(solved != "", "a case carries a portal rule")
		if solved != "":
			_check(RealityCases.activate_case(solved), "%s opens through the case manager" % solved)
			var state: Dictionary = RealityState.case_state(solved)
			state.stage = "integration_ready"
			state.repair_count = int(RealityCases.definition(solved).get("repairs_required", 2))
			_check(RealityCases.resolve_case(solved), "%s resolves through the case manager" % solved)
			var rule := str(RealityCases.definition(solved).portal_rule)
			_check(rule in RealityState.data.portal_rules, "the campaign records its rule")
			for i in 3: await get_tree().process_frame
			_check(board.rules_text().contains(rule.to_upper()), "the board lists it: %s" % board.rules_text())
			if shots != "":
				await _film(shots, "rule_board_with_rule", board.global_position, board.global_transform.basis.z, 1.9, 0.0)
	_finish()


func _centre(node: Node3D, driver: Node3D) -> Vector3:
	return node.global_position + Vector3(0, 0.05, 0)


## An added object's base is its origin plane: the support must be right under it.
func _rests(space: PhysicsDirectSpaceState3D, id: String, node: Node3D, driver: Node3D) -> void:
	var exclude: Array[RID] = []
	for body in node.find_children("*", "CollisionObject3D", true, false):
		exclude.append((body as CollisionObject3D).get_rid())
	var box: AABB = driver.stock.bounds(driver.asset)
	var turn := Basis(Vector3.UP, float(driver.yaw))
	var worst := 0.0
	var missed := 0
	var samples := [Vector2(0.5, 0.5), Vector2(0.3, 0.3), Vector2(0.7, 0.7), Vector2(0.3, 0.7), Vector2(0.7, 0.3)]
	var found := 0
	for sample: Vector2 in samples:
		var local := Vector3(box.position.x + box.size.x * sample.x, 0.0, box.position.z + box.size.z * sample.y)
		var at: Vector3 = node.global_transform * (turn * local)
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.06, at + Vector3.DOWN * 0.5)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			missed += 1
			continue
		found += 1
		worst = maxf(worst, absf(float(hit.position.y) - at.y))
	_check(found >= 3 and worst <= REST_TOLERANCE,
		"%s rests on its support (worst gap %.4f m over %d of %d samples)" % [id, worst, found, samples.size()])


func _process(_delta: float) -> void:
	if _filming and world != null:
		world.player.global_position = _view - _eye
		world.player.camera.look_at(_target)


func _film_all(dir: String, catalogue: Dictionary, props: Dictionary, drivers: Dictionary, board: Node3D, suffix: String) -> void:
	for layer in world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	if world.service_set_carrier != null:
		world.service_set_carrier.visible = false
	_eye = world.player.camera.global_position - world.player.global_position
	for cluster: Dictionary in catalogue.case_clusters:
		# One standing view of the flat's three (or of each, where rooms part them), then each close.
		var points: Array[Vector3] = []
		for spec: Dictionary in cluster.props:
			if props.has(str(spec.id)):
				points.append(_focus(props[str(spec.id)], drivers[str(spec.id)]))
		var middle := Vector3.ZERO
		for point in points:
			middle += point / points.size()
		var spread := 0.0
		for point in points:
			spread = maxf(spread, point.distance_to(middle))
		if spread < 1.6:
			await _film(dir, "%s_%s_flat%s" % [cluster.unit, cluster.case_id, suffix], middle, Vector3.ZERO, maxf(1.5, spread * 2.4), 0.45)
		for spec: Dictionary in cluster.props:
			var id := str(spec.id)
			if props.has(id):
				await _film(dir, "%s_%s%s" % [cluster.unit, id, suffix], _focus(props[id], drivers[id]), Vector3.ZERO, _reach(props[id], drivers[id]), 0.5)
	for spec: Dictionary in catalogue.shared_props:
		var id := str(spec.id)
		if props.has(id):
			await _film(dir, "shared_%s%s" % [id, suffix], _focus(props[id], drivers[id]), Vector3.ZERO, maxf(1.3, _reach(props[id], drivers[id])), 0.4)
	if board != null:
		await _film(dir, "rule_board_standing", board.global_position, board.global_transform.basis.z, 2.6, 0.05)
		await _film(dir, "rule_board_close", board.global_position + board.global_transform.basis.x * 0.3,
			(board.global_transform.basis.z + board.global_transform.basis.x * 0.5).normalized(), 1.2, 0.2)


func _film_live(dir: String, catalogue: Dictionary, props: Dictionary, drivers: Dictionary) -> void:
	for cluster: Dictionary in catalogue.case_clusters:
		if str(cluster.unit) not in ["2C", "3D", "4C", "5C"]:
			continue
		for spec: Dictionary in cluster.props:
			var id := str(spec.id)
			if props.has(id):
				await _film(dir, "live_%s_%s" % [cluster.unit, id], _focus(props[id], drivers[id]), Vector3.ZERO, _reach(props[id], drivers[id]), 0.5)


func _focus(node: Node3D, driver: Node3D) -> Vector3:
	var box := _box(node)
	return node.global_transform * box.get_center() if box.size != Vector3.ZERO else node.global_position


func _reach(node: Node3D, driver: Node3D) -> float:
	return clampf(_box(node).size.length() * 1.5 + 0.45, 0.7, 2.4)


func _box(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inverse := node.global_transform.affine_inverse()
	var stack: Array = [node]
	while not stack.is_empty():
		var item: Node = stack.pop_back()
		if item != node and item.has_meta("v2_surface_prop"):
			continue
		if item is MeshInstance3D and (item as MeshInstance3D).mesh != null:
			var local: Transform3D = inverse * (item as MeshInstance3D).global_transform
			var part: AABB = local * (item as MeshInstance3D).mesh.get_aabb()
			box = part if first else box.merge(part)
			first = false
		for child in item.get_children():
			if str(child.name) != "ImpossibleDuplicate":
				stack.append(child)
	return box


## Stands the player where the subject shows clearest and photographs it with
## the room's own lights. `facing` fixes the side to stand on (zero: search).
func _film(dir: String, label: String, subject: Vector3, facing: Vector3, reach: float, rise: float) -> void:
	# CASE_PROPS_FILM narrows a re-shoot to labels containing one of its words.
	var only := OS.get_environment("CASE_PROPS_FILM")
	if only != "":
		var wanted := false
		for word in only.split(","):
			wanted = wanted or label.contains(word)
		if not wanted:
			return
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var best := subject + Vector3(0, rise, 1.0) * reach
	var best_score := -1.0
	var bearings: Array[Vector3] = []
	if facing != Vector3.ZERO:
		bearings.append((facing + Vector3.UP * rise).normalized())
	else:
		for k in 12:
			var angle := TAU * k / 12.0
			bearings.append(Vector3(cos(angle), rise + 0.25, sin(angle)).normalized())
	for bearing in bearings:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(subject + bearing * 0.12, subject + bearing * (reach + 0.3)))
		var clear := reach if hit.is_empty() else minf(reach, subject.distance_to(hit.position) - 0.3)
		if clear > best_score:
			best_score = clear
			best = subject + bearing * maxf(clear, 0.35)
	_view = best
	_target = subject
	_filming = true
	for i in 32: await get_tree().process_frame
	for i in 10: await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(label + ".png"))
	_filming = false


func _finish() -> void:
	var ok := _fails == 0
	print("[V2 CASE PROPS] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	if world != null:
		if world.has_method("shutdown_for_tests"):
			world.shutdown_for_tests()
		remove_child(world)
		world.free()
	get_tree().quit(0 if ok else 1)
