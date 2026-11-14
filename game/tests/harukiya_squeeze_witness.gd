extends RefCounted
## Read-only test observer; never grants permission or changes gameplay state.
## Each physics frame call observe_pair(key, route_a, actor_a, route_b, actor_b,
## overlaps, delta) for every measured pair, INCLUDING pairs now separated.
## Keep key and A/B ordering stable. Either route may be null for a bystander.
## For the actual PlayerController pass player as BOTH route and actor; its
## own _squeeze timer is read. No proxy body or permission calls are used.
## Caller owns actual capsule overlap measurement and native/admission checks.
## Call finish_frame() after all pairs: an omitted active pair is a failure,
## not silent retirement. Every call returns {ok, reason, pair}.
## observe_pair(..., false, ...) clears an ended pair after identity checks.
## snapshot() returns detached serializable active/completed episode evidence.
## A stationary overlap lasting 10s fails; separation does not need a renewed
## contact timer because production deliberately permits moving apart.

const STATIONARY_SECONDS := 10.0
const PROGRESS_METRES := 0.02
var _episodes: Dictionary = {}
var _completed: Array[Dictionary] = []

func _result(key: String, reason: String = "") -> Dictionary:
	return {"ok": reason.is_empty(), "reason": reason, "pair": key}

func _live(actor: Node3D) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.is_visible_in_tree()

func _ordinary(route: Node3D, actor: Node3D) -> bool:
	if not is_instance_valid(route) or route.is_queued_for_deletion(): return false
	if not route.is_physics_processing() or not route.can_process(): return false
	if route is PlayerController:
		return route == actor and not route.call_locked and not route.inspecting() and not is_instance_valid(route.seated_on) and not route.noclip
	if route.get("actor") != actor: return false
	var guide: Variant = route.get("_bar_route")
	if guide == null or guide.visit == null: return false
	return str(guide._transition).is_empty() and str(guide.visit.phase()) != "occupied"

func _permission(route: Node3D, actor: Node3D, peer: Node3D, frame: int) -> Dictionary:
	if not _ordinary(route, actor): return {}
	var helper: Variant = route.get("_squeeze" if route is PlayerController else "squeeze")
	if helper == null: return {}
	var contact: Dictionary = helper._contacts.get(peer.get_instance_id(), {})
	if contact.is_empty(): return {}
	var age := frame - int(contact.frame)
	if age < 0 or age > 1 or not is_finite(float(contact.seconds)) or float(contact.seconds) < float(helper.WAIT): return {}
	return {"wait_seconds": float(contact.seconds), "required_wait_seconds": float(helper.WAIT),
		"contact_frame": int(contact.frame), "author": "player" if route is PlayerController else str(route.get("resident")),
		"author_route_id": route.get_instance_id(), "author_actor_id": actor.get_instance_id()}

func observe_pair(key: String, route_a: Node3D, actor_a: Node3D,
		route_b: Node3D, actor_b: Node3D, overlaps: bool, delta: float) -> Dictionary:
	var frame := Engine.get_physics_frames()
	if key.is_empty() or not is_finite(delta) or delta <= 0.0: return _result(key, "invalid pair key or physics delta")
	if not _live(actor_a) or not _live(actor_b) or actor_a == actor_b: return _result(key, "pair actor hidden, deleted or invalid")
	for pair: Array in [[route_a, actor_a], [route_b, actor_b]]:
		if pair[0] != null:
			if not is_instance_valid(pair[0]): return _result(key, "observed route deleted")
			var owned: bool = pair[0] == pair[1] if pair[0] is PlayerController else pair[0].get("actor") == pair[1]
			if not owned: return _result(key, "route no longer owns the exact observed actor")
	var actor_ids := [actor_a.get_instance_id(), actor_b.get_instance_id()]
	var route_ids := [route_a.get_instance_id() if is_instance_valid(route_a) else 0,
		route_b.get_instance_id() if is_instance_valid(route_b) else 0]
	if _episodes.has(key):
		var existing: Dictionary = _episodes[key]
		if existing.evidence.actor_ids != actor_ids or existing.evidence.route_ids != route_ids:
			return _result(key, "active overlap actor or route replaced/reordered")
		if frame <= int(existing.evidence.last_frame): return _result(key, "pair observed twice or physics frame reversed")
		if frame != int(existing.evidence.last_frame) + 1: return _result(key, "active overlap observation missed a physics frame")
		if not overlaps:
			var ended: Dictionary = existing.evidence.duplicate(true)
			ended.ended_frame = frame
			_completed.append(ended)
			_episodes.erase(key)
			return _result(key)
	elif not overlaps:
		return _result(key)
	else:
		var permission := _permission(route_a, actor_a, actor_b, frame)
		var author := route_a
		if permission.is_empty():
			permission = _permission(route_b, actor_b, actor_a, frame)
			author = route_b
		if permission.is_empty(): return _result(key, "overlap began without a current timed ordinary-travel permission")
		permission.merge({"pair": key, "actor_ids": actor_ids, "route_ids": route_ids,
			"started_frame": frame, "last_frame": frame - 1, "duration_seconds": 0.0,
			"stationary_seconds": 0.0})
		_episodes[key] = {"evidence": permission, "author": weakref(author),
			"anchor_a": actor_a.global_position, "anchor_b": actor_b.global_position}
	var episode: Dictionary = _episodes[key]
	var mover := episode.author.get_ref() as Node3D
	var mover_actor := actor_a if int(episode.evidence.author_actor_id) == actor_a.get_instance_id() else actor_b
	if not _ordinary(mover, mover_actor): return _result(key, "overlap author stopped ordinary travel or began seating")
	var evidence: Dictionary = episode.evidence
	evidence.last_frame = frame
	evidence.duration_seconds = float(evidence.duration_seconds) + delta
	evidence.current_phase = "player_travel" if mover is PlayerController else str(mover._bar_route.visit.phase())
	if actor_a.global_position.distance_to(episode.anchor_a) >= PROGRESS_METRES or actor_b.global_position.distance_to(episode.anchor_b) >= PROGRESS_METRES:
		episode.anchor_a = actor_a.global_position; episode.anchor_b = actor_b.global_position
		evidence.stationary_seconds = 0.0
	else:
		evidence.stationary_seconds = float(evidence.stationary_seconds) + delta
	if float(evidence.stationary_seconds) >= STATIONARY_SECONDS: return _result(key, "authorized overlap persisted stationary for ten seconds")
	return _result(key)

func finish_frame() -> Dictionary:
	var frame := Engine.get_physics_frames()
	for key: String in _episodes:
		if int(_episodes[key].evidence.last_frame) != frame:
			return _result(key, "active overlap pair omitted from this physics frame")
	return _result("")

func snapshot() -> Dictionary:
	var active := {}
	for key: String in _episodes: active[key] = _episodes[key].evidence.duplicate(true)
	return {"active": active, "completed": _completed.duplicate(true),
		"stationary_limit_seconds": STATIONARY_SECONDS, "progress_metres": PROGRESS_METRES}
