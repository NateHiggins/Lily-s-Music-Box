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

	# The first lead, by hand.
	var tray: Node = stage.grips["6C_tea_tray"]
	var slip: Node3D = stage.cards["order_slip"]
	var went: Dictionary = loop.jump("tea")
	_check(went.ok, "the jump to the tea")
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
	_check(loop.reset_loop().ok, "the hours again")
	await _frames(5)
	_check(tray.part.visible and tray.part.global_position.distance_to(tray_rest) < 0.002, "the tray is back exactly")
	_check(loop.holds("order_slip") and not slip.visible, "the slip stays taken")

	# Home, and the wall.
	_check(loop.go_home().ok, "home")
	await _frames(5)
	_check(stage.tucked.visible, "the carried slip waits at the foot of the wall")
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
	_check((stage.wall_cards["order_slip"] as Node3D).global_position.distance_to(stage.slot_position(0)) < 0.01, "written on the wall's first slip")
	_check(absf(stage._wall_frame.basis.z.dot((stage.tucked.global_transform.basis * stage._paper_square.inverse()).z) - 1.0) < 0.001,
			"the carried slip hangs square to the wall")
	_check("friday" in loop.unlocked() and "stairs" in loop.unlocked(), "the wall has opened two leads")
	await _snap("wall_pinned")
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
