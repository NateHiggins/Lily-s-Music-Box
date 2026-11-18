extends RefCounted
## Test-only instrument. Classifies authored passage interior, never grants a
## token, changes a motor/collision shape, or alters the production release point.
const PROXIMITY_M := .45
const ENDPOINT_EXEMPTION_M := .4
const FEATURE_EPSILON_M := .00001

static func classify(at: Vector3, points: PackedVector3Array) -> Dictionary:
	var result := {"valid":false, "requires_admission":false,
		"legacy_requires_admission":false, "endpoint_cap":""}
	if not at.is_finite() or points.size() < 2: return result
	for point: Vector3 in points:
		if not point.is_finite(): return result
	var best_distance := INF
	var best_point := Vector3.ZERO
	var best_index := -1
	var best_t := 0.0
	for i in points.size()-1:
		var edge := points[i+1]-points[i]
		if edge.length_squared() <= .0000000001: return result
		var t := (at-points[i]).dot(edge)/edge.length_squared()
		var nearest := points[i]+edge*clampf(t,0.0,1.0)
		var distance := at.distance_to(nearest)
		if distance < best_distance:
			best_distance=distance; best_point=nearest; best_index=i; best_t=t
	# Diagnostic only. Admission geometry below keeps its original decision.
	var arc_from_a := 0.0
	var total_arc := 0.0
	for i in points.size()-1:
		var length := points[i].distance_to(points[i+1])
		if i < best_index: arc_from_a += length
		elif i == best_index: arc_from_a += length*clampf(best_t,0.0,1.0)
		total_arc += length
	var distance_a := at.distance_to(points[0])
	var distance_b := at.distance_to(points[-1])
	var legacy := best_distance < PROXIMITY_M and distance_a > ENDPOINT_EXEMPTION_M and distance_b > ENDPOINT_EXEMPTION_M
	var cap := ""
	# Clip only when the globally nearest feature is a terminal endpoint.
	# A final tangent plane applied to the whole curved polyline can incorrectly
	# exclude earlier interior edges. Internal turns retain their clamped coverage.
	if best_point.distance_to(points[0]) <= FEATURE_EPSILON_M and (at-points[0]).dot(points[1]-points[0]) < 0.0:
		cap="before_start"
	elif best_point.distance_to(points[-1]) <= FEATURE_EPSILON_M and (at-points[-1]).dot(points[-1]-points[-2]) > 0.0:
		cap="after_end"
	result.merge({"valid":true, "requires_admission":legacy and cap.is_empty(),
		"legacy_requires_admission":legacy, "endpoint_cap":cap,
		"segment_index":best_index, "segment_a":points[best_index], "segment_b":points[best_index+1],
		"unclamped_t":best_t, "nearest":best_point, "distance":best_distance,
		"distance_a":distance_a, "distance_b":distance_b,
		"arc_from_a":arc_from_a, "arc_from_b":total_arc-arc_from_a},true)
	return result

static func check_admission(at: Vector3, points: PackedVector3Array, registry: Node,
		passage: String, resident: String, actor: Node3D) -> Dictionary:
	var result := classify(at,points)
	var available := is_instance_valid(registry) and registry.has_method("has_admission")
	var admitted := bool(registry.call("has_admission",passage,resident,actor)) if available else false
	result.merge({"passage":passage, "resident":resident,
		"actor_instance_id":actor.get_instance_id() if is_instance_valid(actor) else 0,
		"registry_available":available, "has_admission":admitted,
		"ok":bool(result.valid) and available and (not bool(result.requires_admission) or admitted)},true)
	return result

## Narrow observer exception for a reached source endpoint and its actual
## outgoing edge. Not a grant/release operation. The caller still checks exact
## live admission whenever geometric coverage applies and this returns false.
static func is_released_departure(at: Vector3, current_id: int, next_id: int,
		passage_path: PackedInt64Array, graph: AStar3D) -> bool:
	if not at.is_finite() or not is_instance_valid(graph) or passage_path.size() < 2: return false
	if current_id != passage_path[0] and current_id != passage_path[-1]: return false
	if passage_path.has(next_id) or not graph.has_point(next_id): return false
	var points := PackedVector3Array()
	for i in passage_path.size():
		var point_id := passage_path[i]
		if not graph.has_point(point_id): return false
		if i > 0 and not graph.are_points_connected(passage_path[i-1],point_id,false): return false
		points.append(graph.get_point_position(point_id))
	if not graph.are_points_connected(current_id,next_id,false): return false
	var observation := classify(at,points)
	if not bool(observation.valid): return false
	var end_arc := float(observation.arc_from_a) if current_id == passage_path[0] else float(observation.arc_from_b)
	if end_arc > ENDPOINT_EXEMPTION_M+FEATURE_EPSILON_M: return false
	var start := graph.get_point_position(current_id)
	var finish := graph.get_point_position(next_id)
	if not finish.is_finite(): return false
	var edge := Vector2(finish.x-start.x,finish.z-start.z)
	if edge.length_squared() <= .0000000001: return false
	var offset := Vector2(at.x-start.x,at.z-start.z)
	var t := offset.dot(edge)/edge.length_squared()
	if t < 0.0 or t > 1.0: return false
	var nearest := start.lerp(finish,t)
	# Existing reached-vertex horizontal tolerance and a narrow supported-height
	# bound. No collider, motor tolerance, endpoint or release policy changes.
	return Vector2(at.x-nearest.x,at.z-nearest.z).length() <= .04+FEATURE_EPSILON_M and absf(at.y-nearest.y) <= .06+FEATURE_EPSILON_M
