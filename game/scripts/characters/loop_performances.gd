extends Node
## Authored visit activity, beneath the existing clock, route and dialogue owners.
## Phase time selects a destination; only the route's actual arrival admits a
## performance. No evidence, trust, inventory, door key or calendar writes here.
const SOURCE := "res://data/temporal/performances.json"

var world: Node3D
var loop: Node
var conversations: ResidentConversations
var data: Dictionary = {}
var errors: Array[String] = []
var _identity := ""
var _heard: Dictionary = {}
var _presenting: Dictionary = {}
var _gaze: Dictionary = {}
var _poll := 0.0
var _talk_phase := ""


func setup(runtime: Node3D, temporal: Node, talk: ResidentConversations) -> bool:
	world = runtime
	loop = temporal
	conversations = talk
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if parsed is not Dictionary:
		errors.append("unreadable performance data")
		return false
	data = parsed
	if int(data.get("schema_version", 0)) != 1 or data.get("profiles") is not Dictionary \
			or data.get("anchors") is not Dictionary:
		errors.append("invalid performance schema")
		return false
	for resident: String in data.profiles:
		var profile: Variant = data.profiles[resident]
		if profile is not Dictionary or profile.get("topic") is not String or profile.get("line") is not String:
			errors.append("invalid profile: " + resident)
	for anchor: String in loop.table.anchors:
		var spec: Variant = data.anchors.get(anchor)
		if spec is not Dictionary or spec.get("actors") is not Dictionary:
			errors.append("missing anchor: " + anchor)
			continue
		for resident: String in spec.actors:
			var phases: Variant = spec.actors[resident]
			if phases is not Array or phases.is_empty():
				errors.append("missing phases: " + anchor + "/" + resident)
				continue
			var previous := 0.0
			for phase: Variant in phases:
				if phase is not Dictionary or not (typeof(phase.get("until")) in [TYPE_INT, TYPE_FLOAT]):
					errors.append("invalid phase: " + anchor + "/" + resident)
					continue
				for field: String in ["place", "activity", "focus", "topic", "line"]:
					if phase.get(field) is not String:
						errors.append("missing phase field: " + field)
				if float(phase.until) <= previous:
					errors.append("non-increasing phases: " + anchor + "/" + resident)
				previous = float(phase.until)
			if not is_equal_approx(previous, float(loop.table.anchors[anchor].minutes)):
				errors.append("phases do not cover visit: " + anchor + "/" + resident)
	if not errors.is_empty():
		return false
	# These visits already exist in the timetable; reuse their hosts' actual
	# graph geometry, not an invented straight line through the flats.
	# Off-travel room endpoints keep a parked guest off the host's kitchen
	# path. Do not park them on a transit waypoint merely to compose a two-shot.
	_extend_visit("nadia_quell", "mae_kessler", "visit:6C", "studio")
	_extend_visit("juno_kells", "cal_dwyer", "visit:5B", "alcove")
	add_to_group("loop_performances")
	loop.changed.connect(_sync_visit)
	_sync_visit()
	return true


func _extend_visit(guest: String, host: String, place: String, arrival_node: String) -> void:
	var visitor: Node = world.resident_routes.get(guest)
	var resident: Node = world.resident_routes.get(host)
	if visitor == null or resident == null or visitor.places.has(place):
		return
	var target := int(resident.identities.get(arrival_node, -1))
	if target < 0:
		push_warning("loop visit has no arrival vertex: " + host + "/" + arrival_node)
		return
	var shared: Dictionary = {}
	for host_id: int in resident.graph.get_point_ids():
		for guest_id: int in visitor.graph.get_point_ids():
			if resident.graph.get_point_position(host_id).distance_squared_to(visitor.graph.get_point_position(guest_id)) < 0.000001:
				shared[host_id] = guest_id
				break
	if shared.is_empty():
		push_warning("loop visit has no shared route: " + guest + " -> " + host)
		return
	var mapped := shared.duplicate()
	for host_id: int in resident.graph.get_point_ids():
		if not mapped.has(host_id):
			mapped[host_id] = visitor._point(place + ":" + str(host_id), resident.graph.get_point_position(host_id))
	for host_id: int in resident.graph.get_point_ids():
		for next: int in resident.graph.get_point_connections(host_id):
			if not visitor.graph.are_points_connected(int(mapped[host_id]), int(mapped[next])):
				visitor.graph.connect_points(int(mapped[host_id]), int(mapped[next]))
	if not mapped.has(target):
		return
	# The identity may already have been a shared point, so explicitly alias it.
	var identity := place + ":arrival"
	visitor.identities[identity] = int(mapped[target])
	visitor.places[place] = identity
	for door: DoorProp in resident._doors:
		if is_instance_valid(door) and not visitor._doors.has(door):
			visitor._doors.append(door)
	# npc_set_open still requires real access. This grants no key or invitation.


func phase_for(resident: String) -> Dictionary:
	if loop == null or not loop.in_visit():
		return {}
	var anchor := str(loop.visit_anchor())
	var actors: Dictionary = data.anchors.get(anchor, {}).get("actors", {})
	var phases: Array = actors.get(resident, [])
	var elapsed := float(loop.loop_minutes())
	var start := 0.0
	for i in phases.size():
		var phase: Dictionary = phases[i]
		if elapsed >= start and elapsed < float(phase.until):
			var result := phase.duplicate()
			result["phase_id"] = "%s:%s:%d" % [anchor, resident, i]
			result["start"] = start
			return result
		start = float(phase.until)
	return {}


## Empty means inherit the current agenda, including sleep and hard work blocks.
func whereabouts(resident: String) -> Dictionary:
	var phase := phase_for(resident)
	if phase.is_empty() or str(phase.place).is_empty():
		return {}
	var route: Node = world.resident_routes.get(resident)
	if route == null or not route.places.has(str(phase.place)):
		return {} # Never silently send an unsupported target to the away exit.
	var anchor: Dictionary = loop.table.anchors[loop.visit_anchor()]
	var parts := str(anchor.start).split(":")
	var minute := int(parts[0]) * 60 + int(parts[1])
	var destination := str(phase.place)
	var activity := str(phase.activity)
	# Hosts clear the shared approach while a scheduled guest comes through.
	# The guest yields to the real body, so a slow/blocked host never gets walked
	# through. Once the guest reaches the off-travel endpoint, normal work resumes.
	var guest := "nadia_quell" if resident == "mae_kessler" else "juno_kells" if resident == "cal_dwyer" else ""
	if not guest.is_empty():
		var visitor := phase_for(guest)
		if not visitor.is_empty() and str(visitor.place).begins_with("visit:") and not _arrived(guest):
			destination = "unit:kitchen"
			activity = "chores"
	return {"place": destination, "activity": activity,
			"start_min": minute + float(phase.start), "end_min": minute + float(phase.until),
			"source": "loop_performance"}


func allow_step(resident: String, next: Vector3) -> bool:
	if loop == null or not loop.in_visit():
		return true
	var route: Node = world.resident_routes.get(resident)
	if route == null or route.actor == null:
		return true
	var at: Vector3 = route.actor.global_position
	for other: String in world.resident_routes:
		if other == resident:
			continue
		var other_route: Node = world.resident_routes[other]
		var body: Node3D = other_route.actor as Node3D
		if body == null or other_route.outside or not body.is_visible_in_tree():
			continue
		if absf(next.y - body.global_position.y) > 0.65:
			continue
		var now_gap := Vector2(at.x - body.global_position.x, at.z - body.global_position.z).length()
		var next_gap := Vector2(next.x - body.global_position.x, next.z - body.global_position.z).length()
		if next_gap < 0.72 and next_gap < now_gap - 0.00001:
			return false # Moving apart is always permitted; no new sidestep geometry.
	return true


func _visit_identity() -> String:
	if loop == null or not loop.in_visit():
		return ""
	var ledger: Dictionary = loop.ledger()
	var visit: Dictionary = ledger.visit
	var record: Dictionary = ledger.anchors.get(str(visit.anchor), {})
	return "%s|%s|%s|%s|%s" % [visit.anchor, visit.left_at, visit.loop_started,
			record.get("paid", 0), record.get("loops", 0)]


func _sync_visit() -> void:
	var current := _visit_identity()
	if current == _identity:
		return # A strict-object order fault is not a new visit or a new performance.
	_identity = current
	_heard.clear()
	_talk_phase = ""
	if conversations != null:
		conversations.cancel_performance()
	_clear_activities()
	# Existing bodies walk from their actual positions toward the reconstructed
	# phase. No visible teleport on jump, home, load or immediate rerun.


func _arrived(resident: String) -> bool:
	var route: Node = world.resident_routes.get(resident)
	if route == null or route.actor == null or not route.actor.is_visible_in_tree() \
			or route.outside or route.desired_id < 0 or route.current_id != route.desired_id \
			or not route.path.is_empty() or route.actor._walking or route.force_destination != "":
		return false
	return route.actor.global_position.distance_to(route.graph.get_point_position(route.desired_id)) < 0.15


func _line_for(resident: String, entry_admitted := false) -> Dictionary:
	if _identity.is_empty() or resident == "mina_vale":
		return {}
	if not _arrived(resident) and not (entry_admitted and not world.resident_routes.has(resident)):
		return {}
	var block: Dictionary = world.resident_whereabouts(resident)
	if str(block.get("activity", "")) in ["sleeping", "dressing", "shower"]:
		return {}
	var phase := phase_for(resident)
	if not phase.is_empty():
		# Inherited travel/arrival phases deliberately have no replacement line.
		if str(phase.place).is_empty():
			return {}
		if world.resident_routes[resident].destination != str(phase.place):
			return {}
	else:
		phase = (data.profiles.get(resident, {}) as Dictionary).duplicate()
		phase["phase_id"] = "baseline:" + resident
	var key := str(phase.get("phase_id", ""))
	if _heard.has(key) or str(phase.get("line", "")).is_empty() or str(phase.get("topic", "")).is_empty():
		return {}
	return phase


func conversation_prompt(resident: String) -> String:
	_sync_visit()
	return str(_line_for(resident).get("topic", ""))


func try_entry(resident: String, player: Node) -> bool:
	_sync_visit()
	if world.resident_routes.has(resident):
		return false
	# Rhea/guests retain existing door entry, Stacy her staff/counter entry.
	# Use a dedicated bounded line, never copy it into a tree that can outlive
	# the visit. This does not create routes or historical bodies.
	return _begin_line(resident, _line_for(resident, true), player)


func try_conversation(resident: String, player: Node) -> bool:
	_sync_visit()
	return _begin_line(resident, _line_for(resident), player)


func _begin_line(resident: String, line: Dictionary, player: Node) -> bool:
	if line.is_empty() or conversations == null:
		return false
	if not conversations.start_performance(resident, str(line.line), player):
		return false
	_talk_phase = str(line.phase_id)
	_heard[_talk_phase] = true # Presentation only; never a knowledge/visit grant.
	return true


func _process(delta: float) -> void:
	if data.is_empty() or not is_instance_valid(world) or not is_instance_valid(loop):
		return
	_poll += delta
	if _poll < 0.25:
		return
	_poll = 0.0
	_sync_visit()
	if _identity.is_empty():
		return
	for resident: String in world.resident_routes:
		var route: Node = world.resident_routes[resident]
		var actor: Node = route.actor
		var phase := phase_for(resident)
		var talking := conversations != null and conversations._active_resident == resident
		if talking and not _talk_phase.is_empty() and conversations.performance_active() \
				and _talk_phase != str(phase.get("phase_id", "baseline:" + resident)):
			conversations.cancel_performance()
		if actor == null or not actor.has_method("set_loop_activity"):
			continue
		# Bar seats have their own exact posture/route owner. Sleeping, unseen,
		# obstructed and moving residents keep their existing presentation.
		var block: Dictionary = world.resident_whereabouts(resident)
		var activity := str(block.get("activity", ""))
		var case_id := RealityCases.case_for_resident(resident)
		var case_active := not case_id.is_empty() and str(RealityState.case_state(case_id).get("stage", "unseen")) in ["active", "reopened"]
		if not _arrived(resident) or talking or str(route.destination) == "harukiya_bar" \
				or case_active or activity in ["sleeping", "dressing", "shower"]:
			_release_activity(resident)
			continue
		actor.set_loop_activity(activity)
		_presenting[resident] = actor
		# Optional authored gaze uses the existing attention owner, never IK grips.
		var attention: Node = actor.get_node_or_null("Attention")
		var focus := str(phase.get("focus", ""))
		if focus.is_empty() or attention == null:
			_release_gaze(resident)
			continue
		var target: Node3D = world.adapter.resolve(focus) as Node3D
		if target != null and target.global_position.distance_to(route.actor.global_position) < 3.2 \
				and (attention.staged_target == null or _gaze.has(resident)):
			attention.staged_target = target.global_position
			_gaze[resident] = {"owner": attention, "point": target.global_position}
		else:
			_release_gaze(resident)


func _release_gaze(resident: String) -> void:
	if not _gaze.has(resident):
		return
	var held: Dictionary = _gaze[resident]
	if is_instance_valid(held.owner) and held.owner.staged_target == held.point:
		held.owner.staged_target = null
	_gaze.erase(resident)


func _release_activity(resident: String) -> void:
	_release_gaze(resident)
	if _presenting.has(resident) and is_instance_valid(_presenting[resident]):
		_presenting[resident].clear_loop_activity()
	_presenting.erase(resident)


func _clear_activities() -> void:
	for resident: String in _presenting.keys():
		_release_activity(resident)


func _exit_tree() -> void:
	_clear_activities()
	if is_instance_valid(conversations):
		conversations.cancel_performance()
