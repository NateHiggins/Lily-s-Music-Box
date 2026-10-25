extends Node
## Bounded observations of existing owners. No duplicate raycasts, catalogue
## scans, discovery grants, route invention or interpretation of saved prose.
var session: Node
var player: PlayerController
var world: Node
var last_read: Dictionary = {}
var _catalog: NewspaperCatalog
var _clock := CampaignClock.new()
var _campaign: Dictionary
var _known: Array = []
var _room := ""
var _candidate_room := ""
var _room_dwell := 0.0
var _sample_left := 0.0
var _target: Object
var _hesitation := 0.0
var _blocked := false

func setup(owner: Node, holder: PlayerController, root: Node) -> void:
	session = owner; player = holder; world = root
	_campaign = RealityState.data
	_known = RealityState.data.get("knowledge_flags", []).duplicate()
	RealityState.state_changed.connect(_state_changed)
	session.context_provider = context
	session.calendar_provider = calendar

func context() -> Dictionary:
	var result := {"visible":[], "inventory":PersonInventory.pocket_lines()}
	if is_instance_valid(world) and world.has_method("room_at_world"):
		var room: String = world.room_at_world(player.global_position)
		if not room.is_empty(): result.location = "Current space: " + room.replace("_", " ")
	if is_instance_valid(world) and world.get("objective_tracker") is ObjectiveTracker:
		var tracker: ObjectiveTracker = world.objective_tracker
		if not tracker.supplied_body.is_empty(): result.objective = tracker.supplied_body
	# The hand's already-resolved hit must still be in reach and under the
	# current gaze. Typing never revives a previous room's object description.
	var hit: Dictionary = player._grab.last_hit
	if not hit.is_empty() and is_instance_valid(hit.get("collider")) and hit.get("position") is Vector3:
		var point: Vector3 = hit.position
		var eye := player.camera
		if point.distance_to(eye.global_position) <= 2.1 and not eye.is_position_behind(point):
			var pixel := eye.unproject_position(point)
			if pixel.distance_to(eye.get_viewport().get_visible_rect().size * .5) < 32.0:
				var collider: Node = hit.collider
				if not session.get_parent().is_ancestor_of(collider):
					var label := str(collider.name).replace("_", " ")
					result.visible.append({"id":str(collider.get_instance_id()), "name":label,
						"observation":"In view: " + label + "."})
	return result

func calendar() -> Dictionary:
	var result := {"clock":_clock, "source":"", "conditions":{}, "catalog":_catalog if is_instance_valid(_catalog) else null, "read_issue":last_read.duplicate()}
	if not _clock.bind_state(): return {}
	var atmosphere: Node = world.get_node_or_null("WakingAtmosphere") if is_instance_valid(world) else null
	if atmosphere != null and atmosphere.get("weather_manager") != null:
		var manager: Node = atmosphere.weather_manager
		result.source = manager.source
		result.conditions = manager.current.duplicate(true)
	return result

func paper_shown(catalog: NewspaperCatalog, paper: String, date: String) -> void:
	if catalog == null or not catalog.published_now(paper, date): return
	_catalog = catalog
	last_read = {"paper":paper, "date":date}

func observe(delta: float) -> void:
	_sample_left -= delta
	if _sample_left > 0.0: return
	_sample_left = .25
	if get_tree().paused or player.protected_input_active() or session.typing or session.opening \
			or not session.get_parent().device.radio_powered:
		_hesitation = 0.0; _room_dwell = 0.0; return
	if is_instance_valid(world) and world.has_method("room_at_world"):
		var current: String = world.room_at_world(player.global_position)
		if current != _candidate_room:
			_candidate_room = current; _room_dwell = 0.0
		else: _room_dwell += .25
		if not current.is_empty() and current != _room and _room_dwell >= 2.0:
			var revisit: bool = current in session.visited
			if not revisit:
				if session.visited.size() == 64: session.visited.pop_front()
				session.visited.append(current)
			if not _room.is_empty(): session.queue_event("revisit" if revisit else "exploration")
			_room = current
	var hit: Dictionary = player._grab.last_hit
	var collider: Object = hit.get("collider")
	if not is_instance_valid(collider) or collider != _target or player.velocity.length() > .15 or player._grab.active():
		_target = collider; _hesitation = 0.0
	else:
		_hesitation += .25
		if _hesitation >= 20.0:
			session.queue_event("hesitation"); _hesitation = -120.0
	# This is the hand's constraint result, not a guessed jam or impact.
	var blocked: bool = player._grab.active() and player._grab.motion_feedback == "blocked"
	if blocked and not _blocked: session.queue_event("mechanical_resistance", 8.0)
	_blocked = blocked

func _state_changed() -> void:
	if not is_same(_campaign, RealityState.data):
		_campaign = RealityState.data
		_known = RealityState.data.get("knowledge_flags", []).duplicate()
		last_read.clear(); _catalog = null
		_room = ""; _candidate_room = ""; _target = null; _hesitation = 0.0
		return
	var current: Array = RealityState.data.get("knowledge_flags", [])
	for flag: Variant in current:
		if flag not in _known:
			# A newly granted player knowledge fact, not loading old discoveries.
			session.queue_event("story_discovery")
			break
	_known = current.duplicate()
