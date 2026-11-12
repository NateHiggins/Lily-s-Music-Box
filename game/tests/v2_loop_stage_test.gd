extends Node
## The temporal loop's rooms in the V2 world: every object a lead names is in
## the building and in the right flat, the first lead is played through the
## same grips the hand uses (grab, carry, let go), its evidence is picked up,
## carried home and pinned to the case wall in 4B. With SHOT_DIR set and a
## window, it also takes review captures (not runtime proof).
const State := preload("res://scripts/game/prologue_state.gd")

var _fails := 0
var _checks := 0
var world: Node3D
var loop: Node
var stage: Node3D
var _feet := Vector3.ZERO
var _look := Vector3.ZERO
var _pinned := false


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _settle(node: Node) -> void:
	var began := Time.get_ticks_msec()
	var quiet := 0
	while (quiet < 60 or not node.can_process()) and Time.get_ticks_msec() - began < 90000:
		var before := Time.get_ticks_msec()
		await get_tree().process_frame
		quiet = quiet + 1 if Time.get_ticks_msec() - before < 250 else 0


func _frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func _process(_delta: float) -> void:
	if not _pinned or world == null or not is_instance_valid(world.player):
		return
	world.player.global_position = _feet
	world.player.camera.look_at(_look)
	var companion: Variant = world.get("service_set_carrier")
	if companion is Node3D:
		(companion as Node3D).visible = false


## Work a grip as the hand does: take hold, carry it the whole way, let go.
func _carry(grip: Node) -> bool:
	var hold: Dictionary = grip.grip()
	if hold.is_empty() or not bool(hold.begin.call()):
		return false
	var steps := 8
	for index in steps:
		hold.write.call(float(hold.maximum) * float(index + 1) / float(steps))
	hold.end.call()
	return true


func _snap(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	await _frames(50)
	for index in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	print("LOOP STAGE SHOT: ", label)


func _ready() -> void:
	process_priority = 1000
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not world.startup_failed, "the V2 world starts")
	loop = world.get("temporal_loop")
	stage = world.get("loop_stage")
	_check(loop != null and stage != null, "V2 composes the loop and its stage")
	if loop == null or stage == null:
		_finish()
		return
	await _settle(stage)
	_check(stage.errors.is_empty(), "every lead could be staged (%s)" % str(stage.errors))

	# Every object a lead names is in the building, in the flat the lead names.
	var objects := 0
	for anchor_id: String in loop.table.anchors:
		var anchor: Dictionary = loop.table.anchors[anchor_id]
		for step: Dictionary in anchor.steps:
			if str(step.kind) != "shift":
				continue
			objects += 1
			var grip: Node = stage.grips.get(str(step.object))
			_check(grip != null and is_instance_valid(grip.part), "%s: %s is in the building" % [anchor_id, str(step.object)])
			if grip == null:
				continue
			_check(world.unit_at_world(grip.part.global_position) == str(anchor.place),
					"%s: %s stands in %s (%s)" % [anchor_id, str(step.object), str(anchor.place), world.unit_at_world(grip.part.global_position)])
			_check(grip.grip().is_empty(), "%s: %s is ordinary furniture outside its lead" % [anchor_id, str(step.object)])
			_check(not grip.part.find_children("*", "MeshInstance3D", true, false).is_empty() or grip.part is MeshInstance3D,
					"%s: %s has something to take hold of" % [anchor_id, str(step.object)])
		_check(stage.cards.has(str(anchor.clue.id)) and not (stage.cards[str(anchor.clue.id)] as Node3D).visible,
				"%s: its evidence is staged and out of sight" % anchor_id)
	_check(objects == 30 and stage.grips.size() == 29, "thirty lifts across the eleven leads, on twenty-nine objects (%d, %d)" % [objects, stage.grips.size()])
	_check(stage.wall != null and world.unit_at_world(stage.wall.global_position) == "4B", "the case wall is in 4B")
	_check(stage.tucked != null and not stage.tucked.visible and stage.wall_cards.is_empty(), "the wall is bare and nothing waits to be pinned")

	# Give the campaign its historical year, as the prologue does.
	var clock: CampaignClock = world.campaign_clock
	var opening := State.request_skip(State.initial())
	for index in State.PHASES.size() - 1:
		var phase: String = State.PHASES[index]
		if phase == "companion_crossing":
			opening = State.applied(opening, "companion_materialized")
		if phase == "temporal_command":
			opening = State.with_target(opening, {"utc_unix_seconds": 1856345696, "local_bias_minutes": -300, "local_zone": "Test"})
		if phase == "temporal_synchronization":
			break
		opening = State.advance(opening, State.PHASES[index + 1])
	RealityState.data.prologue = opening
	_check(clock.bind_state() and clock.apply_prologue_destination(), "the prologue hands over the year")
	world.player.set_physics_process(false)

	# The house before the visit: one door and one light, as the tenants left them.
	var house: Node = world.household_state
	var door: DoorProp = null
	var door_id := ""
	var lamp: Node = null
	var lamp_id := ""
	for identity: String in house._subjects:
		var subject: Node = house._subjects[identity]
		if door == null and house._kinds[identity] == "mechanism" and subject is DoorProp and (subject as DoorProp).leaf_state != "locked":
			door = subject
			door_id = identity
		if lamp == null and house._kinds[identity] == "light":
			lamp = subject
			lamp_id = identity
	_check(door != null and lamp != null, "the house has a door and a light to borrow (%s, %s)" % [door_id, lamp_id])
	var door_home := float(door.mechanism_snapshot().angle)
	var lamp_home: bool = lamp.get("powered")
	var door_ajar := door.motion_target_angle(true) * (0.8 if absf(door_home) < 0.2 else 0.0)

	# The first lead, by hand.
	var tray: Node = stage.grips["6C_tea_tray"]
	var slip: Node3D = stage.cards["order_slip"]
	var went: Dictionary = loop.jump("tea")
	_check(went.ok, "the jump to the tea")
	_check((loop.ledger().visit as Dictionary).get("household") is Dictionary and (loop.ledger().visit.household as Dictionary).has(door_id)
			and (loop.ledger().visit.household as Dictionary).has(lamp_id), "the visit borrows the house as it stood")
	_check(not (loop.ledger().visit.household as Dictionary).values().any(func(record: Variant) -> bool: return str(record.kind) in ["blind", "fuse_service", "tank_service", "boiler_service"]),
			"and borrows no blind and no work done")
	_check((loop.ledger().visit.household as Dictionary).keys().all(func(identity: String) -> bool:
		return house._kinds[identity] in house.VISIT_KINDS or house._subjects[identity] is DoorProp),
			"only doors, windows, lights, radiators, cabinets, mirrors and shelves: the lift, the clocks and the kitchens keep their own state (%d of %d records)"
			% [(loop.ledger().visit.household as Dictionary).size(), house._subjects.size()])
	door.restore_mechanism({"angle": door_ajar})
	lamp.call("set_powered", not lamp_home)
	_check(absf(float(door.mechanism_snapshot().angle) - door_home) > 0.5 and lamp.get("powered") != lamp_home, "in the visit a door is moved and a light switched")
	var tray_rest: Vector3 = tray.part.global_position
	_check(_carry(tray) and loop.steps_done() == 0 and tray.part.visible and tray.part.global_position.distance_to(tray_rest) < 0.002,
			"lifted before the player has arrived in 6C, the tray goes straight back and nothing happens")
	_feet = Vector3(tray_rest.x, floorf((tray_rest.y + 0.05) / 3.2) * 3.2, tray_rest.z) + Vector3(0.9, 0.0, 0.5)
	_look = tray_rest
	_pinned = true
	await _frames(40)
	_check(world.player_unit() == "6C", "the player stands in 6C (%s)" % world.player_unit())
	_check(loop.steps_done() == 1, "arriving is seen by the room")
	_check(not tray.grip().is_empty(), "now the tray answers the hand")
	await _snap("tea_before")
	var hold: Dictionary = tray.grip()
	_check(bool(hold.begin.call()), "the hand takes the tray")
	hold.write.call(float(hold.maximum) * 0.5)
	_check(tray.part.global_position.y > tray_rest.y + 0.05 and loop.steps_done() == 1, "half lifted, it has moved and nothing has happened yet")
	hold.end.call()
	await _frames(90)
	_check(tray.part.global_position.distance_to(tray_rest) < 0.002, "let go half way, it settles back")
	_check(_carry(tray), "lifted the whole way")
	_check(loop.clue_ready() and not tray.part.visible and slip.visible, "the tray is set aside and the order slip lies where it stood")
	_check(slip.global_position.distance_to(tray_rest) < 0.01, "the slip lies where the tray stood")
	await _snap("tea_slip")
	var take: Node = slip.get_meta("grip")
	_check(_carry(take), "the hand picks the slip up")
	_check(loop.holds("order_slip") and not slip.visible, "the slip is taken and kept")

	# A rerun puts the room back and keeps the evidence.
	# A door the visit never touched, caught mid-swing: the rerun must leave it alone.
	var bystander: DoorProp = null
	for identity: String in house._subjects:
		var other: Node = house._subjects[identity]
		if other is DoorProp and other != door and house._kinds[identity] == "mechanism":
			bystander = other
			break
	_check(bystander != null, "there is a second door to stand by")
	bystander._moving = true
	_check(loop.reset_loop().ok, "the hours again")
	_check(bystander._moving, "putting the house back touches only what was moved: a door mid-swing elsewhere swings on")
	bystander._moving = false
	await _frames(5)
	_check(tray.part.visible and tray.part.global_position.distance_to(tray_rest) < 0.002, "the tray is back exactly")
	_check(absf(float(door.mechanism_snapshot().angle) - door_home) < 0.001 and lamp.get("powered") == lamp_home, "the door and the light are as the hours began")
	door.restore_mechanism({"angle": door_ajar})
	lamp.call("set_powered", not lamp_home)
	_check(loop.holds("order_slip") and not slip.visible, "the slip stays taken")

	# Home, and the wall.
	_check(loop.go_home().ok, "home")
	await _frames(5)
	_check(absf(float(door.mechanism_snapshot().angle) - door_home) < 0.001 and lamp.get("powered") == lamp_home, "home, the door and the light are as the tenants left them")
	door.restore_mechanism({"angle": door_ajar})
	# A conversation that ended without saying so does not hold the clock for good.
	var held_pace: CampaignPace = loop._pace_owner()
	stage._talk_held = true
	loop.hold_pace("talk")
	_check(held_pace != null and held_pace.held(), "a conversation holds the clock")
	await _frames(40)
	_check(not held_pace.held() and not stage._talk_held, "and with nobody talking the hold is let go")
	_check(loop.go_home().ok == false and absf(float(door.mechanism_snapshot().angle) - door_ajar) < 0.001, "and at home a door moved stays moved")
	door.restore_mechanism({"angle": door_home})
	_check(stage.tucked.visible and stage.tucked_item == "order_slip"
			and absf(stage._wall_frame.basis.z.dot(stage.tucked.global_transform.basis.z.normalized()) - 1.0) < 0.001,
			"the carried slip waits at the foot of the wall, face out")
	_check(not stage.tucked.find_children("*", "MeshInstance3D", true, false).is_empty(), "and it is the modelled slip, with a shape to take hold of")
	var wall_face: Vector3 = stage.slot_position(1)
	var out: Vector3 = stage._wall_frame.basis.z
	_feet = Vector3(wall_face.x, floorf((wall_face.y + 0.05) / 3.2) * 3.2, wall_face.z) + out * 1.3
	_look = wall_face - Vector3.UP * 0.2
	await _frames(20)
	_check(world.player_unit() == "4B", "the player stands at the wall in 4B (%s)" % world.player_unit())
	await _snap("wall_carried")
	_check(_carry(stage.tucked_grip), "the hand slides it up the wall")
	await _frames(5)
	_check(loop.pinned("order_slip") and stage.wall_cards.has("order_slip") and not stage.tucked.visible, "it is pinned and nothing waits")
	_check((stage.wall_cards["order_slip"] as Node3D).global_position.distance_to(stage.slot_position(0)) < 0.12, "over the wall's first slip")
	_check(stage.stock.has("order_slip") and stage.stock.has("bundle") and stage.stock.has("pin"), "the pieces of evidence are modelled objects")
	_check("friday" in loop.unlocked() and "stairs" in loop.unlocked(), "the wall has opened two leads")
	await _snap("wall_pinned")

	# Making sense of it. Two more pieces come home (given directly; their rooms are the engine test's).
	for item_id: String in ["route_leaf", "nurse_note"]:
		loop.ledger().items[item_id] = {"pinned": false, "anchor": str(loop.table.clue_anchor[item_id]), "run": 1}
		loop.changed.emit()
		await _frames(3)
		_check(stage.tucked.visible and _carry(stage.tucked_grip), "%s is pinned by hand" % item_id)
		await _frames(3)
	_check(stage.wall_cards.size() == 3 and loop.strings().is_empty() and "notebook" not in loop.unlocked(),
			"three pieces on the wall, nothing joined, and the writer upstairs still shut")
	var pull_order: Node = (stage.wall_cards["order_slip"] as Node3D).get_meta("grip")

	# Filing: the year across the board, and the building map beside it.
	_check(stage.year_parts == 6 and stage.cell_pins.size() == 26, "the year is on the board in five seasons with the market's break marked, and the map has a pin for every flat, the roof and the basement (%d, %d)" % [stage.year_parts, stage.cell_pins.size()])
	_check(stage.loose_tag.visible and stage.loose_tag_item == "order_slip", "the order slip's tag waits at the start of the year")
	_check(_carry(pull_order) and _carry(pull_order), "string taken up and put down")
	var slide: Dictionary = stage.loose_tag_grip.grip()
	_check(not slide.is_empty() and bool(slide.begin.call()), "the hand takes the tag")
	slide.write.call(stage.year_length() * 100.0 / 365.0)
	slide.end.call()
	_check(not loop.dated("order_slip") and stage.date_tags.is_empty(), "let go in February, it does not stay")
	stage.loose_tag_grip.put_back()
	slide = stage.loose_tag_grip.grip()
	slide.begin.call()
	slide.write.call(stage.year_length() * 217.0 / 365.0)
	slide.end.call()
	await _frames(3)
	_check(loop.dated("order_slip") and stage.date_tags.has("order_slip") and stage.loose_tag_item == "route_leaf",
			"let go in the middle of June, it stays, and the next piece's tag is waiting")
	_check(absf(((stage.date_tags["order_slip"] as Node3D).get_meta("at") as Vector2).x - stage.day_x(215)) < 0.001, "its tag hangs at 13 June")
	_check(_carry(pull_order) and _carry((stage.cell_pins["5B"] as Node3D).get_meta("grip")) and not loop.placed("order_slip") and stage.place_strings.is_empty(),
			"string run to 5B on the map falls")
	_check(_carry(pull_order) and _carry((stage.cell_pins["6C"] as Node3D).get_meta("grip")), "string run to 6C")
	await _frames(3)
	_check(loop.filed("order_slip") and stage.place_strings.has("order_slip"), "it holds: the slip has its day and its place")
	await _snap("wall_filed")
	for item_id: String in ["route_leaf", "nurse_note"]:
		loop.file_date(item_id, loop.item_day(item_id))
		loop.file_place(item_id, loop.item_where(item_id))
	await _frames(3)
	_check(stage.date_tags.size() == 3 and stage.place_strings.size() == 3 and not stage.loose_tag.visible, "all three pieces filed")
	var pull_nurse: Node = (stage.wall_cards["nurse_note"] as Node3D).get_meta("grip")
	var pull_route: Node = (stage.wall_cards["route_leaf"] as Node3D).get_meta("grip")
	_check(_carry(pull_order) and stage.string_from == "order_slip" and stage.loose_end != null, "the order slip's pin pulled: a loose red end hangs from it")
	await _snap("wall_loose_end")
	_check(_carry(pull_nurse) and stage.string_from == "" and stage.string_nodes.is_empty() and loop.strings().is_empty(),
			"run to the nurse's note, the string falls: those two do not belong")
	_check(_carry(pull_order) and _carry(pull_order) and stage.string_from == "" and stage.loose_end == null, "pulled twice, the string is put down again")
	_check(_carry(pull_order) and _carry(pull_route), "from the order slip to the route leaf")
	await _frames(3)
	_check(stage.string_nodes.size() == 1 and stage.deduction_cards.has("she_asked_first") and "notebook" in loop.unlocked(),
			"it holds: a red string, the deduction written under it, and the writer upstairs open")
	await _frames(20)
	_check(stage.surveyed and stage.spots.size() >= 300 and stage.pile_spots.size() >= 20 and stage.high_spots.size() >= 20,
			"the whole flat has been surveyed (%d places for paper, %d for piles, %d overhead)" % [stage.spots.size(), stage.pile_spots.size(), stage.high_spots.size()])
	var early: int = stage.papers.size()
	_check(early >= 10 and early < stage.spots.size() / 4 and loop.spread_fraction() < 0.25,
			"with three pieces and one string the case has only begun to spread (%d sheets, %.2f of the way)" % [early, loop.spread_fraction()])
	var early_piles := 0
	for pile: Node3D in stage.piles:
		early_piles += 1 if pile.visible else 0
	_check(early_piles >= 1 and early_piles <= 8, "and the first newspapers have been kept (%d piles)" % early_piles)
	var inside := true
	for sheet: Node3D in stage.papers:
		inside = inside and world.unit_at_world(sheet.global_position) == "4B"
	_check(inside, "every sheet is in 4B")
	await _snap("wall_first_string")

	# Review only: the whole case on the wall, to look at the flat taken over.
	if not OS.get_environment("SHOT_DIR").is_empty() and DisplayServer.get_name() != "headless":
		var slot := 3
		for anchor_id: String in loop.table.anchors:
			var item_id := str(loop.table.anchors[anchor_id].clue.id)
			if not loop.holds(item_id):
				loop.ledger().items[item_id] = {"pinned": true, "anchor": anchor_id, "run": 1, "slot": slot, "dated": true, "placed": true}
				slot += 1
		for deduction_id: String in loop.table.deductions:
			var needs: Array = loop.table.deductions[deduction_id].needs
			for index in range(1, needs.size()):
				if not loop.joined(str(needs[index - 1]), str(needs[index])):
					loop.strings().append([str(needs[index - 1]), str(needs[index])])
			if deduction_id not in loop.ledger().deductions:
				loop.ledger().deductions.append(deduction_id)
		# Half way first.
		var half_items: Dictionary = (loop.ledger().items as Dictionary).duplicate(true)
		var half_strings: Array = loop.strings().duplicate(true)
		var half_deductions: Array = (loop.ledger().deductions as Array).duplicate()
		var kept := 0
		for item_id: String in half_items.keys():
			kept += 1
			if kept > 6:
				half_items.erase(item_id)
		var whole_items: Dictionary = loop.ledger().items
		var whole_strings: Array = loop.strings().duplicate(true)
		var whole_deductions: Array = (loop.ledger().deductions as Array).duplicate()
		loop.ledger().items = half_items
		loop.ledger().strings = half_strings.slice(0, 2)
		loop.ledger().deductions = half_deductions.slice(0, 2)
		loop.changed.emit()
		await _frames(10)
		print("LOOP STAGE: half way %.2f, %d sheets" % [loop.spread_fraction(), stage.papers.filter(func(n: Node3D) -> bool: return n.visible).size()])
		var back_off: Vector3 = stage._wall_frame.origin + out * 2.8
		_feet = Vector3(back_off.x, _feet.y, back_off.z)
		_look = stage._wall_frame.origin
		await _snap("stage_half")
		loop.ledger().items = whole_items
		loop.ledger().strings = whole_strings
		loop.ledger().deductions = whole_deductions
		loop.changed.emit()
		await _frames(10)
		_check(is_equal_approx(loop.spread_fraction(), 1.0) and stage.papers.size() == stage.spots.size()
				and stage.strands.size() == stage.MAX_STRANDS, "at the finished case every place is papered and the web is whole (%d sheets, %d piles, %d strands)" % [
				stage.papers.size(), stage.piles.size(), stage.strands.size()])
		await _snap("stage_full")
		_feet = Vector3(wall_face.x, _feet.y, wall_face.z) + out * 1.3
		_look = wall_face - Vector3.UP * 0.2
		await _snap("wall_whole_case")
		var centre: Vector3 = stage._wall_frame.origin + out * 1.6
		_feet = Vector3(centre.x, _feet.y, centre.z) + out * 1.2
		_look = stage._wall_frame.origin
		await _snap("flat_from_back")
		_look = _feet + stage._wall_frame.basis.x * 2.0 + Vector3.UP * 1.4
		await _snap("flat_side_a")
		_look = _feet - stage._wall_frame.basis.x * 2.0 + Vector3.UP * 1.4
		await _snap("flat_side_b")
		_look = _feet + out * 2.0 + Vector3.UP * 1.4
		await _snap("flat_behind")
	_pinned = false
	_finish()


func _finish() -> void:
	print("[V2 LOOP STAGE] RESULT: %s (%d checks, %d failures)" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	await get_tree().process_frame
	if world != null:
		world.shutdown_for_tests()
		remove_child(world)
		world.free()
	get_tree().quit(0 if _fails == 0 else 1)
