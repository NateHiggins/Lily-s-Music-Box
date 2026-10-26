extends RefCounted
## A private perceptual companion. Reads repair owners; never advances work,
## writes saves, emits NPC stimuli or registers a collision/perception target.
var building: Node
var player: Node3D
var specimen_id := -1
var target := Vector3.INF
var target_id := ""
var state := "explore"
var _refresh := 0.0
var _people: Array[Node] = []
var _anchor_key := ""
var _anchor_node: WeakRef
var lunch = preload("res://scripts/dream/critters/tardigrade_lunch.gd").new()

func _init() -> void: lunch.owner = self

func near_resident(pos: Vector3) -> Vector3:
	var nearest := Vector3.INF
	var distance := 2.2
	for person in _people:
		if not is_instance_valid(person) or person == player or not person is Node3D: continue
		var d := pos.distance_to(person.global_position)
		if d < distance:
			distance = d
			nearest = person.global_position
	return nearest

func setup(world: Node, observer: Node3D) -> void:
	building = world
	player = observer

func refresh(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0 or not is_instance_valid(building): return
	_refresh = .25
	_people = building.get_tree().get_nodes_in_group("resident_placeholders")
	target = Vector3.INF
	target_id = ""
	if not "work_orders" in building: return
	var orders: WorkOrders = building.work_orders
	if orders == null or orders.job_library == null: return
	var jobs: Dictionary = RealityState.data.get("maintenance_jobs", {})
	var preferred := str(RealityState.data.get("first_shift", {}).get("report_id", ""))
	var ids: Array = jobs.keys()
	ids.sort()
	if ids.has(preferred):
		ids.erase(preferred)
		ids.push_front(preferred)
	for id in ids:
		# Completed work must stop attracting it immediately. Awaiting parts
		# still indicates the fault, not an invented shopping objective.
		if orders.job_stage(str(id)) in ["repaired", "closed", "missing"]: continue
		var spec := orders.job_library.job(str(id))
		var anchor := str(spec.get("repair_target_id", ""))
		if anchor.is_empty(): continue
		var node: Node3D
		if str(id) == "vantry_chirp_2a" and "vantry_points" in building:
			var network = building.vantry_points
			if is_instance_valid(network) and is_instance_valid(network.active_owner):
				node = network.active_owner
				anchor = network.active_point_id
		else:
			if anchor == _anchor_key and _anchor_node != null:
				node = _anchor_node.get_ref() as Node3D
			if not is_instance_valid(node):
				node = building.find_child(anchor, true, false) as Node3D
				_anchor_key = anchor
				_anchor_node = weakref(node) if node != null else null
		if is_instance_valid(node):
			target = node.global_position
			target_id = anchor
			return

func steer(c: Dictionary, controller, delta: float) -> void:
	if not is_instance_valid(player): return
	c.lunch_speed = 1.0
	var pos: Vector3 = c.pos
	var nearest := Vector3.INF
	var distance := 2.2
	for person in _people:
		if not is_instance_valid(person) or person == player or not person is Node3D: continue
		var d := pos.distance_to(person.global_position)
		if d < distance:
			distance = d
			nearest = person.global_position
	var want := Vector3.ZERO
	if nearest != Vector3.INF:
		state = "retreat"
		want = pos - nearest
		c.moving = distance > .7
		c.tun = move_toward(float(c.tun), .65 if distance < .7 else .12, delta * 2.0)
		c.pause = .4
	elif float(c.tun) > .08:
		state = "peek"
		c.moving = false
		c.tun = move_toward(float(c.tun), 0.0, delta * .25)
		want = player.global_position - pos
	elif lunch.steer_tardi(c, controller, delta):
		state = lunch.state
		return
	else:
		var player_distance := pos.distance_to(player.global_position)
		if player_distance > 2.8:
			state = "return"
			want = player.global_position - pos
			c.moving = true
		elif target != Vector3.INF:
			# Lead a short distance, then wait/look back. Never teleport or
			# walk through architecture; the controller retains surface casts.
			var cycle := fmod(float(c.age), 6.0)
			state = "point" if cycle < 3.5 else "check_player"
			want = target - pos if cycle < 3.5 else player.global_position - pos
			var across: Vector3 = target-pos
			across -= (c.up as Vector3)*across.dot(c.up)
			c.moving = cycle < 2.4 and across.length() > .45 and player_distance < 2.0
		else:
			state = "explore"
			var cycle := fmod(float(c.age), 5.0)
			want = player.global_position - pos
			want = want.rotated(c.up, sin(float(c.age) * .55) * .7)
			c.moving = player_distance > 1.1 and cycle < 2.0
	# A planted, startled animal cannot rotate its trunk over eight fixed feet.
	# Idle attention uses the head sweep; body turns accompany actual steps.
	if bool(c.moving) and float(c.tun) < .2:
		controller._turn_toward(c, want, delta * (2.5 if state == "retreat" else 1.1))
	c.companion_state = state
	c.companion_target = target_id
	c.spin = float(c.age) * .8
