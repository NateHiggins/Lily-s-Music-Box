extends RefCounted
## Authored ordinary exchanges. Eligibility observes actual bodies and existing
## schedules; it never summons a participant or grants a narrative consequence.
const SOURCE := "res://data/temporal/ordinary_performances.json"
var world: Node3D
var conversations: ResidentConversations
var arrived: Callable
var encounters: Array = []
var errors: Array[String] = []

func setup(runtime: Node3D, talk: ResidentConversations, arrival: Callable) -> bool:
	world = runtime; conversations = talk; arrived = arrival
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if parsed is not Dictionary or parsed.get("schema_version") != 1 or parsed.get("encounters") is not Array:
		errors.append("invalid ordinary performance schema")
		return false
	var seen := {}
	for value: Variant in parsed.encounters:
		if value is not Dictionary:
			errors.append("invalid encounter"); continue
		var item: Dictionary = value
		if str(item.get("id", "")).is_empty() or seen.has(item.get("id")):
			errors.append("missing/duplicate encounter id"); continue
		seen[item.id] = true
		if str(item.get("topic", "")).is_empty() or item.get("actors") is not Array \
				or item.get("lines") is not Array or item.get("places") is not Array \
				or item.get("excluded_anchors") is not Array:
			errors.append("invalid encounter fields: " + str(item.id)); continue
		if item.actors.is_empty() or item.lines.is_empty() or item.places.is_empty():
			errors.append("empty encounter: " + str(item.id)); continue
		for actor: Variant in item.actors:
			if actor is not String or not conversations.trees.has(actor) or actor == "mina_vale":
				errors.append("unsupported encounter actor: " + str(actor))
		for line: Variant in item.lines:
			if line is not Dictionary or line.get("speaker") not in item.actors \
					or line.get("text") is not String or str(line.text).is_empty() \
					or (line.has("choice") and (line.choice is not String or str(line.choice).is_empty())):
				errors.append("invalid line: " + str(item.id))
		if item.has("exclude_dates") and item.exclude_dates is not Array:
			errors.append("invalid excluded dates: " + str(item.id))
		if item.has("hours") and (item.hours is not Array or item.hours.size() != 2 \
				or float(item.hours[0]) < 0 or float(item.hours[1]) > 1440 \
				or float(item.hours[0]) >= float(item.hours[1])):
			errors.append("invalid encounter hours: " + str(item.id))
		encounters.append(item)
	return errors.is_empty() and not encounters.is_empty()

func eligible(item: Dictionary, anchor: String) -> bool:
	if anchor in item.excluded_anchors:
		return false
	var day := conversations.today()
	if day in item.get("exclude_dates", []):
		return false
	var minute := conversations.minute_now()
	if item.has("hours") and (minute < float(item.hours[0]) or minute >= float(item.hours[1])):
		return false
	var bodies: Array[Node3D] = []
	for identity: String in item.actors:
		var route: Node = world.resident_routes.get(identity)
		if route == null or not bool(arrived.call(identity)) or str(route.destination) not in item.places:
			return false
		var block: Dictionary = world.resident_whereabouts(identity)
		if str(block.get("activity", "")) in ["sleeping", "dressing", "shower", "transit"]:
			return false
		var case_id := RealityCases.case_for_resident(identity)
		if not case_id.is_empty() and str(RealityState.case_state(case_id).get("stage", "unseen")) in ["active", "reopened"]:
			return false
		var body: Node3D = route.actor
		for other: Node3D in bodies:
			var distance := body.global_position.distance_to(other.global_position)
			if absf(body.global_position.y - other.global_position.y) > 0.3 or distance < 0.65 or distance > 2.8:
				return false
			# Matching logical room names do not prove sight through a closed door.
			var ray := PhysicsRayQueryParameters3D.create(body.global_position + Vector3.UP * 1.35,
					other.global_position + Vector3.UP * 1.35, 1)
			if not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				return false
		bodies.append(body)
	return not bodies.is_empty()

func for_resident(identity: String, anchor: String, heard: Dictionary) -> Dictionary:
	for item: Dictionary in encounters:
		var key := "ordinary:" + str(item.id)
		if identity in item.actors and not heard.has(key) and eligible(item, anchor):
			return {"phase_id": key, "topic": str(item.topic), "line": str(item.lines[0].text),
					"sequence": item.lines, "encounter": item}
	return {}
