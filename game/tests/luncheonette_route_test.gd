extends "res://tests/carried_case_route_test.gd"
## The Luncheonette in the production V2 root with real input: the real hand orders,
## a click grabs the cup, mouse motion lifts it, it drains only at the top of the
## lift, the next click sets it down, a save restores what is left, and only a
## resident the timetable puts at the counter is overheard, which spends nothing.

const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")
const Counter := preload("res://scripts/props/luncheonette_counter.gd")
const IRIS := "iris_bell"
const THURSDAY := [1928, 11, 15]
const WEDNESDAY := [1928, 11, 14]
const TEN := 600

func _init() -> void:
	route_label = "LUNCHEONETTE ROUTE"

func _click() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	await get_tree().physics_frame

func _aim(part: Node3D) -> Dictionary:
	var at: Vector3 = part.global_position + Vector3.UP * 0.04
	player.camera.look_at(at)
	await get_tree().physics_frame
	player.camera.look_at(at)
	return player._grab.find_target()

func _raise(grip: Dictionary, goal: float) -> void:
	for _step in 200:
		if float(grip.read.call()) >= goal or not player._grab.active():
			return
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(0, -6)
		player._unhandled_input(motion)
		await get_tree().physics_frame

func _route() -> void:
	var clock := CampaignClock.new()
	clock.configure_date(WEDNESDAY[0], WEDNESDAY[1], WEDNESDAY[2], TEN)
	world.resident_agenda.enabled = false
	var point: Node3D = world.shop_counters.get("luncheonette")
	var counter: Node3D = world.luncheonette_counter
	if not _require(point != null and counter != null, "the Luncheonette has a counter"): return
	var cup: Node3D = counter.parts.cup
	var plate: Node3D = counter.parts.plate
	_require(not cup.visible and not plate.visible, "the counter starts clear")
	var economy: Node = world.get_node("CaretakerEconomy")
	economy.book().cash = 300
	var hand: Node = Hands.new()
	hand.set_meta("shared_world_validation", true)
	add_child(hand)
	hand.player = player
	player.global_position = point.global_position + Vector3(-1.35, -1.1, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.camera.look_at(point.global_position)
	await get_tree().create_timer(0.3).timeout
	_require(counter._player_in_room(), "the customer stands in the room: %s" % str(counter._source_xy(player.global_position)))
	await _capture_interaction("luncheonette_counter")

	point.select(point.item_ids.find("coffee_and_pie"))
	var cash := int(economy.book().cash)
	_require(await hand._stroke(point.terminal, point.terminal.TRAVEL), "the real hand orders coffee and pie")
	_require(int(economy.book().cash) == cash - 15, "fifteen cents goes on the radio: %d" % int(economy.book().cash))
	_require(cup.visible and plate.visible, "the order comes up as a cup and a plate")
	await _capture_interaction("luncheonette_served")

	var grip: Dictionary = await _aim(cup)
	_require(grip.get("owner") == counter and grip.get("part") == cup, "the player's ray reaches the cup: %s" % str(grip.get("part")))
	var full := float(Counter.served().cup)
	await _click()
	_require(player._grab.active() and is_zero_approx(float(grip.read.call())), "a click grabs without lifting")
	await get_tree().create_timer(0.5).timeout
	_require(is_equal_approx(float(Counter.served().cup), full), "nothing goes down on the counter")
	await _raise(grip, Counter.LIFT)
	_require(float(grip.read.call()) >= Counter.LIFT * Counter.AT_MOUTH, "motion lifts it: %f" % float(grip.read.call()))
	_require(cup.global_position.distance_to(player.camera.global_position) < 0.4, "up to the player's mouth: %f" % cup.global_position.distance_to(player.camera.global_position))
	await _capture_interaction("luncheonette_lifted")
	await get_tree().create_timer(1.5).timeout
	var after := float(Counter.served().cup)
	_require(after < full - 1.0, "at the top of the lift it goes down: %f" % after)
	await _click()
	_require(not player._grab.active(), "the next click lets go")
	await get_tree().create_timer(1.2).timeout
	_require(is_zero_approx(float(counter._lift.cup)), "the cup settles back on the counter")
	var settled := float(Counter.served().cup)
	await get_tree().create_timer(0.5).timeout
	_require(is_equal_approx(float(Counter.served().cup), settled), "nothing drains once it is down")

	RealityState.data[Counter.KEY] = {"cup": 3.0, "plate": 0.0}
	counter.refresh()
	_require(cup.visible and not plate.visible, "what is left on the counter follows the saved facts")
	_require(Counter.valid({"cup": 3.0, "plate": 0.0}) and not Counter.valid({"cup": -1.0, "plate": 0.0}) and not Counter.valid({"cup": 1.0}), "the save shape is validated")

	# Nobody is timetabled on this Wednesday morning: the counter stays quiet.
	counter._line_wait = 0.0
	await get_tree().create_timer(1.0).timeout
	_require(counter.bodies.is_empty(), "an empty counter has no bodies: %s" % str(counter.bodies.keys()))
	_require(counter.overheard_label.text == "", "and no voices: %s" % counter.overheard_label.text)

	# Leave, let Thursday's timetable seat Iris, and come back.
	player.global_position += Vector3(0, 0, 12)
	await get_tree().physics_frame
	clock.configure_date(THURSDAY[0], THURSDAY[1], THURSDAY[2], TEN)
	_require(str(world.resident_whereabouts(IRIS).get("place", "")) == "luncheonette", "Thursday puts Iris in the diner")
	counter._seat_customers()
	_require(counter.bodies.has(IRIS), "her own body is at the counter")
	if counter.bodies.has(IRIS):
		var seated: Node3D = counter.bodies[IRIS]
		var hips: float = counter._body_seated_support(seated, IRIS)
		var stool := int(counter._stools[IRIS])
		var want: Vector3 = world.passage_region.global_transform * GameBoot.b2g([Counter.STOOL_X, Counter.STOOLS[stool][1], Counter.STOOL_TOP - hips])
		_require(seated.global_position.distance_to(want) < 0.001 and not is_equal_approx(hips, Counter.SEATED_HIPS), "she sits at her own body's measured seat height (%.3f m)" % hips)
		_require(seated._animation_player.current_animation == Counter.SEATED_CLIP, "and on the seated clip: %s" % seated._animation_player.current_animation)
		var held_idle: String = seated.preferred_idle
		var held_animation: String = seated._animation_player.current_animation
		var held_mina: Variant = seated.mina_animation
		_require(not seated.hold_seated("__missing_seated_clip__"), "an unavailable seated clip is refused")
		_require(seated.preferred_idle == held_idle and seated._animation_player.current_animation == held_animation and seated.mina_animation == held_mina, "refused seating preserves the current presentation owner and animation")
	# An eligible resident can still be using the old model after a refused
	# rebuild. Build that actual supported fallback, not a fake eligibility flag.
	var fallback_actor := preload("res://scripts/characters/orison_v2_resident_presentation.gd").new()
	fallback_actor.setup("Iris fallback check", IRIS, "", CastBodies.old_model(IRIS))
	fallback_actor.externally_driven = true
	world.passage_region.transaction_actor_root().add_child(fallback_actor)
	_require(CastBodies.wears_cast_body(IRIS) and fallback_actor.cast_body == null, "the real old-model fallback can belong to an eligible resident")
	_require(is_equal_approx(counter._body_seated_support(fallback_actor, IRIS), Counter.SEATED_HIPS), "an actual old-body fallback keeps the original seated offset")
	fallback_actor.queue_free()
	# This is a synthetic presentation check, not Mina's natural attendance.
	# Observe a real counter poll first so its five-second reconciliation will
	# not retire this off-timetable body during the short animation blend check.
	var prior_poll: float = counter._poll
	var poll_observed := false
	for frame in 360:
		await get_tree().process_frame
		var live_poll: float = counter._poll
		if live_poll > prior_poll:
			poll_observed = true
			break
		prior_poll = live_poll
	_require(poll_observed, "the counter's actual owner polled before the isolated seating check")
	counter._seat("mina_vale")
	await get_tree().create_timer(0.4).timeout
	await get_tree().physics_frame
	var mina: Node3D = counter.bodies.get("mina_vale")
	_require(mina != null and mina._animation_player.current_animation == Counter.SEATED_CLIP, "Mina sits on her stool: %s" % (mina._animation_player.current_animation if mina else "no body"))
	if mina != null:
		# Inspect the actual held body before it leaves. The player stays outside,
		# so this review camera cannot advance the overheard conversation early.
		var seat_camera := Camera3D.new()
		add_child(seat_camera)
		seat_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		seat_camera.size = 2.7
		seat_camera.global_transform = player.camera.global_transform
		# Reuse the established counter stance and eye offset, not the outside
		# player's possibly falling height after the twelve-metre move.
		seat_camera.global_position = point.global_position + Vector3.LEFT * 1.35 + Vector3.DOWN * 1.1 + (player.camera.global_position - player.global_position)
		seat_camera.look_at(mina.global_position + Vector3.UP * 0.7)
		seat_camera.make_current()
		await _capture_interaction("luncheonette_mina_seated")
		if _require(mina.cast_body != null and bool(mina.cast_body.ready_ok), "Mina's actual rebuilt body is ready in the seating check"):
			var seated_skeleton: Skeleton3D = mina.cast_body.skeleton
			for side in ["Left", "Right"]:
				var thigh_id := seated_skeleton.find_bone(side + "UpLeg")
				var knee_id := seated_skeleton.find_bone(side + "Leg")
				if _require(thigh_id >= 0 and knee_id >= 0, "actual seated leg bones " + side):
					var thigh: Vector3 = seated_skeleton.global_basis * (seated_skeleton.get_bone_global_pose(knee_id).origin - seated_skeleton.get_bone_global_pose(thigh_id).origin)
					var lift := Vector3.DOWN.angle_to(thigh.normalized())
					_require(lift >= 0.35, "Mina's held %s thigh is actually raised, not a standing pose (%.2f degrees)" % [side, rad_to_deg(lift)])
		player.camera.make_current()
		seat_camera.queue_free()
		world.seat_gestures.taken.erase(Counter.STOOL_SEAT % int(Counter.STOOLS[int(counter._stools["mina_vale"])][0]))
		counter._stools.erase("mina_vale")
		counter.bodies.erase("mina_vale")
		mina.queue_free()
	var today: String = world.conversations.today()
	_require(not world.conversations.active_opinions(IRIS, today).is_empty(), "she has something to say on %s" % today)
	player.global_position = point.global_position + Vector3(-1.35, -1.1, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if counter.bodies.has(IRIS):
		player.camera.look_at(counter.bodies[IRIS].global_position + Vector3.UP * 0.7)
	counter._line_wait = 0.0
	await get_tree().create_timer(0.4).timeout
	_require(counter.overheard_label.text.begins_with("Iris Bell, down the counter: "), "her line is overheard: %s" % counter.overheard_label.text)
	await _capture_interaction("luncheonette_overheard")
	var heard := str(counter._opinion)
	var before: Array = RealityState.data.knowledge_flags.duplicate()
	counter._sentences.clear()
	counter._sentences.append("Last.")
	counter._line_wait = 0.0
	await get_tree().create_timer(0.2).timeout
	var added: Array = RealityState.data.knowledge_flags.filter(func(flag): return flag not in before)
	_require(added == [Counter.OVERHEARD_PREFIX + heard], "the only fact gained is that it was heard: %s" % str(added))
	var still: Array = world.conversations.active_opinions(IRIS, today).map(func(row): return str(row.id))
	_require(heard in still, "and she can still say it to the player's face")
	_require(Counter.sentences_of("One. Two? Three! Four").size() == 4, "lines break at sentence ends")
	_require(not Counter.SERVED.has("yesterdays_rolls"), "carried goods stay in the case")
