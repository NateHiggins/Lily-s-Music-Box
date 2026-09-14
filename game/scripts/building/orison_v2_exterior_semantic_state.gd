class_name OrisonV2ExteriorSemanticState
extends RefCounted
## Identity-only durable route cursor for Orison v2 exterior reconstruction.
##
## RealityState remains the save authority. This boundary refuses raw world
## coordinates and asks the current public spatial resolver to derive the
## placement anew after destruction/reload.

const STATE_KEY := "exterior_semantics"
const PAYLOAD_KEYS := ["schema_version", "route_id", "waypoint_id",
		"threshold_id"]

var errors: Array[String] = []


func record_progress(state_id: String, resolver: Variant, route_id: String,
		waypoint_id: String, threshold_id: String) -> bool:
	errors.clear()
	if not _valid_state_id(state_id) or resolver == null \
			or not resolver.is_valid():
		errors.append("semantic exterior state owner or resolver is invalid")
		return false
	var reconstructed: Dictionary = resolver.reconstruct_route(
			route_id, waypoint_id)
	var threshold: Dictionary = resolver.resolve_threshold(threshold_id)
	var route: Dictionary = resolver.resolve_route(route_id)
	if reconstructed.is_empty() or threshold.is_empty() or route.is_empty():
		errors.append("semantic exterior route cursor does not resolve")
		return false
	var threshold_in_route := false
	for value: Variant in route.get("thresholds", []):
		if value is Dictionary and str(value.get("id", "")) == threshold_id:
			threshold_in_route = true
			break
	if not threshold_in_route:
		errors.append("semantic threshold is not owned by the selected route")
		return false
	var current: Variant = RealityState.data.get(STATE_KEY, {})
	if current is not Dictionary:
		errors.append("RealityState.%s is not a dictionary" % STATE_KEY)
		return false
	var candidate: Dictionary = (current as Dictionary).duplicate(true)
	candidate[state_id] = {
		"schema_version": 1,
		"route_id": route_id,
		"waypoint_id": waypoint_id,
		"threshold_id": threshold_id,
	}
	RealityState.data[STATE_KEY] = candidate
	RealityState.commit()
	return true


func snapshot(state_id: String) -> Dictionary:
	var container: Variant = RealityState.data.get(STATE_KEY, {})
	if container is not Dictionary:
		return {}
	var value: Variant = (container as Dictionary).get(state_id, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func reconstruct(state_id: String, resolver: Variant) -> Dictionary:
	errors.clear()
	if not _valid_state_id(state_id) or resolver == null \
			or not resolver.is_valid():
		errors.append("semantic exterior state owner or resolver is invalid")
		return {}
	var payload := snapshot(state_id)
	if not _valid_payload(payload):
		errors.append("saved semantic exterior route cursor is malformed")
		return {}
	var route_id := str(payload.get("route_id", ""))
	var waypoint_id := str(payload.get("waypoint_id", ""))
	var threshold_id := str(payload.get("threshold_id", ""))
	var cursor: Dictionary = resolver.reconstruct_route(route_id, waypoint_id)
	var threshold: Dictionary = resolver.resolve_threshold(threshold_id)
	var route: Dictionary = resolver.resolve_route(route_id)
	if cursor.is_empty() or threshold.is_empty() or route.is_empty():
		errors.append("saved semantic exterior route cursor no longer resolves")
		return {}
	var threshold_in_route := false
	for value: Variant in route.get("thresholds", []):
		if value is Dictionary and str(value.get("id", "")) == threshold_id:
			threshold_in_route = true
			break
	if not threshold_in_route:
		errors.append("saved threshold is not owned by the saved route")
		return {}
	return {
		"state_id": state_id,
		"route_id": route_id,
		"waypoint_id": waypoint_id,
		"threshold_id": threshold_id,
		"cursor": cursor,
		"threshold": threshold,
	}


func clear_progress(state_id: String) -> bool:
	errors.clear()
	if not _valid_state_id(state_id):
		errors.append("semantic exterior state identity is invalid")
		return false
	var current: Variant = RealityState.data.get(STATE_KEY, {})
	if current is not Dictionary:
		errors.append("RealityState.%s is not a dictionary" % STATE_KEY)
		return false
	if not (current as Dictionary).has(state_id):
		return true
	var candidate: Dictionary = (current as Dictionary).duplicate(true)
	candidate.erase(state_id)
	RealityState.data[STATE_KEY] = candidate
	RealityState.commit()
	return true


func teardown() -> void:
	errors.clear()


static func _valid_payload(payload: Dictionary) -> bool:
	if payload.size() != PAYLOAD_KEYS.size():
		return false
	for key: String in PAYLOAD_KEYS:
		if not payload.has(key):
			return false
	return int(payload.get("schema_version", -1)) == 1 \
			and not str(payload.get("route_id", "")).is_empty() \
			and not str(payload.get("waypoint_id", "")).is_empty() \
			and not str(payload.get("threshold_id", "")).is_empty()


static func _valid_state_id(value: String) -> bool:
	return not value.is_empty() and value == value.to_upper() \
			and value.contains("EXTERIOR")
