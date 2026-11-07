extends "res://tests/carried_case_route_test.gd"
## The Harukiya counter in the production V2 root with real input: a click grabs the
## empty glass, mouse motion slides it across the top toward the back bar, and on a
## night the staff clock has Stacy on shift her conversation opens; on her night off
## nobody comes. Released, the glass slides back to the customer's side.

const Glass := preload("res://scripts/props/harukiya_counter_glass.gd")
const THURSDAY := [1928, 11, 15]
const MONDAY := [1928, 11, 12]
const EIGHT_PM := 1200

func _init() -> void:
	route_label = "HARUKIYA COUNTER ROUTE"

func _click() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	await get_tree().physics_frame

func _aim(part: Node3D) -> Dictionary:
	var at: Vector3 = part.global_position + Vector3.UP * 0.05
	player.camera.look_at(at)
	await get_tree().physics_frame
	player.camera.look_at(at)
	return player._grab.find_target()

func _push(grip: Dictionary, goal: float) -> void:
	for _step in 200:
		if float(grip.read.call()) >= goal or not player._grab.active():
			return
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(0, -6)
		player._unhandled_input(motion)
		await get_tree().physics_frame

func _slide_across(counter: Node3D) -> Dictionary:
	var grip: Dictionary = await _aim(counter.glass)
	_require(grip.get("owner") == counter and grip.get("part") == counter.glass,
			"the player's ray reaches the glass: %s" % str(grip.get("part")))
	if grip.is_empty():
		return grip
	await _click()
	_require(player._grab.active() and is_zero_approx(float(grip.read.call())), "a click grabs without sliding")
	await _push(grip, Glass.SLIDE * Glass.ACROSS_AT)
	_require(float(grip.read.call()) >= Glass.SLIDE * Glass.ACROSS_AT, "motion slides it across: %f" % float(grip.read.call()))
	return grip

func _route() -> void:
	var clock := CampaignClock.new()
	clock.configure_date(THURSDAY[0], THURSDAY[1], THURSDAY[2], EIGHT_PM)
	world.resident_agenda.enabled = false
	var counter: Node3D = world.harukiya_counter
	if not _require(counter != null and counter.glass != null, "the Harukiya has a counter glass"): return
	_require(str(world.resident_whereabouts("stacy").get("place", "")) == "harukiya_bar",
			"the staff clock has Stacy behind the bar on Thursday night")
	player.global_position = counter.glass.global_position + Vector3(0.0, -1.08, 1.25)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.camera.look_at(counter.glass.global_position)
	await get_tree().create_timer(0.3).timeout
	await _capture_interaction("harukiya_counter")

	var started: Array = []
	world.conversations.conversation_started.connect(func(resident: String, _entry: String): started.append(resident))
	var home: Vector3 = counter.glass.global_position
	await _slide_across(counter)
	_require(counter.glass.global_position.distance_to(home) > Glass.SLIDE * 0.8, "the glass has crossed the top")
	await get_tree().create_timer(0.3).timeout
	_require(started == ["stacy"], "Stacy comes over and talks: %s" % str(started))
	_require(world.conversations.dialogue.attention_active(), "her conversation is open")
	_require(not player._grab.active(), "she takes the glass: the hand has let go")
	await _capture_interaction("harukiya_counter_stacy")
	world.conversations.dialogue.close()
	await get_tree().create_timer(1.0).timeout
	_require(counter.glass.global_position.distance_to(home) < 0.02, "released, it slides back to the customer's side")

	# Monday is her night off: the glass crosses, nobody comes.
	clock.configure_date(MONDAY[0], MONDAY[1], MONDAY[2], EIGHT_PM)
	_require(str(world.resident_whereabouts("stacy").get("place", "")) != "harukiya_bar", "Monday night she isn't on")
	await get_tree().create_timer(0.3).timeout
	started.clear()
	await _slide_across(counter)
	await get_tree().create_timer(0.3).timeout
	_require(started.is_empty(), "nobody answers on her night off: %s" % str(started))
	_require(counter.notice.text == Glass.NOBODY, "the counter says so: %s" % counter.notice.text)
	await _click()
	_require(not player._grab.active(), "the next click lets go")
	await get_tree().create_timer(4.0).timeout
	_require(counter.notice.text == "", "the line clears")
