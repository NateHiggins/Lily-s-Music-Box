extends RefCounted
## Test-only graph traversal. The caller supplies its existing real-player
## motor; this helper chooses authored waypoints and never moves a body itself.

static func walk(bar: OrisonV2BarRegion, from_id: String, to_id: String,
		move_world: Callable, require: Callable) -> bool:
	var destination := bar.get("destination") as Node3D
	if not bool(require.call(destination != null, "production bar destination supplies route datums")): return false
	var spec: Dictionary = destination.get("spec")
	var points := {}
	for row: Dictionary in spec.navigation.nodes:
		if not bool(require.call(not points.has(str(row.id)), "unique bar route datum " + str(row.id))): return false
		points[str(row.id)] = GameBoot.b2g(row.at)
	if not bool(require.call(points.has(from_id) and points.has(to_id), "bar route endpoints " + from_id + " -> " + to_id)): return false
	var previous := {from_id: ""}
	var queue: Array[String] = [from_id]
	while not queue.is_empty():
		var here: String = queue.pop_front()
		if here == to_id: break
		for edge: Array in spec.navigation.edges:
			var other := ""
			if str(edge[0]) == here: other = str(edge[1])
			elif str(edge[1]) == here: other = str(edge[0])
			if other.is_empty() or previous.has(other): continue
			previous[other] = here; queue.append(other)
	if not bool(require.call(previous.has(to_id), "authored bar route is connected " + from_id + " -> " + to_id)): return false
	var route: Array[String] = [to_id]
	var cursor := to_id
	while cursor != from_id:
		cursor = str(previous[cursor]); route.push_front(cursor)
	for identity: String in route:
		# Include the first datum so a nearby door/interaction approach returns
		# to the graph by ordinary movement, without an invisible placement.
		if not await move_world.call(bar.to_global(points[identity])): return false
	return true
