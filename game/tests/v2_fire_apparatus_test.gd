extends Node
## The apparatus set in V2 (v1r_extinguisher_20261109, v1r_door_closer_b_20261109):
## the soda-acid extinguisher beside a fire cabinet and the liquid door check on
## the roof stair leaf, mounted on the booted V2 world by their own composer.
##
## It checks where they hang (rays against the real wall, the cabinet's own
## frame, the leaf's own body), drives V1's seal/charge and arm/port authority
## and reads the cards, lets the real leaf go and times the spring, and works
## every operable part with mouse button and mouse motion events through the
## player's own input handler. With SHOT_DIR set in a windowed run it also
## writes the captures.
const Apparatus := preload("res://scripts/building/orison_v2_fire_apparatus.gd")
const WORLD := "res://scenes/building/orison_v2_runtime.tscn"


## Holds the player's eye where a check or a capture needs it. The V2 opening
## and the room lighting both follow the player, so the player stands there.
class ViewPin extends Node:
	var player: Node3D
	var eye := Vector3.ZERO
	var look := Vector3.ZERO
	var active := false

	func _init() -> void:
		process_priority = 1000

	func _process(_delta: float) -> void:
		apply()

	func apply() -> void:
		if not active or player == null:
			return
		var camera: Camera3D = player.camera
		player.global_position += eye - camera.global_position
		camera.look_at(look)


var _checks := 0
var _fails := 0
var _world: Node
var _player: Node3D
var _pin: ViewPin
var _shots := ""
var _space: PhysicsDirectSpaceState3D
var _proved: Array[Dictionary] = []
var _inspected: Array[Dictionary] = []


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)
	return ok


func _near(a: float, b: float, tolerance: float) -> bool:
	return absf(a - b) <= tolerance


## A V1 refusal holds its pose for a second or two. A check of where a part
## rests does not wait for it.
func _calm(prop: Node3D) -> void:
	prop._balk_left = 0.0
	prop._balk_focus = ""
	if prop.has_method("_refresh_extinguisher"):
		prop._refresh_extinguisher()
	else:
		prop._refresh_closer()


func _ready() -> void:
	# A script error in a coroutine never reaches quit(); this does.
	get_tree().create_timer(430.0).timeout.connect(func() -> void:
		print("[V2 FIRE APPARATUS] RESULT: FAIL (watchdog)")
		get_tree().quit(2))
	_run.call_deferred()


func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_world = (load(WORLD) as PackedScene).instantiate()
	add_child(_world)
	while not _world.startup_failed and _world.startup_ms <= 0.0:
		await get_tree().process_frame
	if not _check(not _world.startup_failed, "the V2 world starts"):
		_finish()
		return
	var blockout: Node3D = _world._blockout
	var result: Dictionary = _world.fire_apparatus
	_check(result.errors.is_empty(), "the apparatus set mounts: %s" % [result.errors])
	var units: Array = result.extinguishers
	var check: Node3D = result.door_check
	if not _check(units.size() >= 1 and check != null, "one extinguisher or more, and the door check, are mounted"):
		_finish()
		return
	# The world keeps loading after it reports ready: wait for it to run evenly.
	var even := 0
	var last := Time.get_ticks_msec()
	while even < 60:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		even = even + 1 if now - last < 250 else 0
		last = now
	_check(check.can_process() and units[0].can_process(), "the mounted apparatus processes")
	_player = _world.player
	_player.set_physics_process(false)
	_player.call_locked = false
	_player.set_mouse_released(false)
	if _world.service_set_carrier != null:
		_world.service_set_carrier.hide()
	_pin = ViewPin.new()
	_pin.player = _player
	add_child(_pin)
	_space = (_world as Node3D).get_world_3d().direct_space_state
	_shots = OS.get_environment("SHOT_DIR") if DisplayServer.get_name() != "headless" else ""
	if not _shots.is_empty():
		DirAccess.make_dir_recursive_absolute(_shots)
		for layer: Node in _world.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).hide()
		_player.set_lamp_enabled(false)

	_surfaces(units, check)
	for unit: Node3D in units:
		await _extinguisher_place(unit, blockout)
		await _extinguisher_authority(unit)
	await _extinguisher_hand(units[0])
	await _check_place(check, blockout)
	await _check_authority(check)
	await _check_hand(check)
	if not _shots.is_empty():
		await _captures(units, check)
	_finish()


# --- surfaces ------------------------------------------------------------------

func _surfaces(units: Array, check: Node3D) -> void:
	var owners: Array = units.duplicate()
	owners.append(check)
	var drawn := 0
	var sound := true
	for owner_node: Node3D in owners:
		for draw: MeshInstance3D in owner_node.find_children("*", "MeshInstance3D", true, false):
			drawn += 1
			var problem := ""
			if not draw.has_meta("v2_native_fire_apparatus_part"):
				problem = "not native stock"
			elif draw.mesh == null or draw.mesh is PrimitiveMesh:
				problem = "no authored mesh"
			else:
				for surface in draw.mesh.get_surface_count():
					var arrays := draw.mesh.surface_get_arrays(surface)
					var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var charts: Variant = arrays[Mesh.ARRAY_TEX_UV]
					var tangents: Variant = arrays[Mesh.ARRAY_TANGENT]
					if not charts is PackedVector2Array or (charts as PackedVector2Array).size() != points.size():
						problem = "no UV array"
					elif not tangents is PackedFloat32Array or (tangents as PackedFloat32Array).size() != points.size() * 4:
						problem = "no tangents"
				var finish := draw.material_override as StandardMaterial3D
				if finish == null or finish.albedo_texture == null or finish.roughness_texture == null \
						or finish.normal_texture == null or finish.uv1_triplanar:
					problem = "finish is not an authored-UV catalogue material"
			if not problem.is_empty():
				sound = false
				print("  [surface] ", draw.name, ": ", problem)
	var expected := 14 * units.size() + 8
	_check(drawn == expected, "every draw is one of the %d native parts (found %d)" % [expected, drawn])
	_check(sound, "every surface has UVs, tangents and a catalogue finish with albedo, roughness and normal maps, read through its UVs")
	var unit: Node3D = units[0]
	var legend := unit.find_child("ChargeLegend", true, false) as Label3D
	var legend_2 := unit.find_child("ChargeLegend2", true, false) as Label3D
	var head := check.find_child("HeadLegend", true, false) as Label3D
	_check(legend != null and legend.text == unit.CHARGE_LEGEND and legend_2 != null and legend_2.text == unit.CHARGE_LEGEND_2
			and not legend.double_sided, "the charge plate carries V1's words as single-sided Label3D")
	_check(head != null and head.text == check.HEAD_LEGEND and not head.double_sided,
			"the door check carries V1's legend as single-sided Label3D")


# --- the extinguisher --------------------------------------------------------

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	if _player is CollisionObject3D:
		query.exclude = [(_player as CollisionObject3D).get_rid()]
	return _space.intersect_ray(query)


func _extinguisher_place(unit: Node3D, blockout: Node3D) -> void:
	await get_tree().physics_frame
	var made: Dictionary = unit.stock.data.extinguisher
	var back := float(made.wall_plane_z)
	var left := float(made.board_x[0])
	var right := float(made.board_x[1])
	var top := float(made.board_height)
	# The whole board stands on real wall: five rays through it, each landing
	# on the plaster the board is packed off (over the landing wainscot).
	var on_wall := true
	for at: Vector2 in [Vector2(left + 0.03, 0.03), Vector2(right - 0.03, 0.03), Vector2(left + 0.03, top - 0.03),
			Vector2(right - 0.03, top - 0.03), Vector2((left + right) * 0.5, top * 0.5)]:
		var hit := _ray(unit.to_global(Vector3(at.x, at.y, 0.5)), unit.to_global(Vector3(at.x, at.y, -0.4)))
		if hit.is_empty() or not _near(unit.to_local(hit.position).z, back, 0.004) \
				or (unit.global_basis.inverse() * hit.normal).z < 0.99:
			on_wall = false
			print("  [wall] ", at, " -> ", unit.to_local(hit.position) if not hit.is_empty() else "nothing")
	_check(on_wall, "%s: the backboard stands flat to a real wall, packed %.0f mm off the plaster over the wainscot cap"
			% [unit.name, (float(made.board_back_z) - back) * 1000.0])
	var cap_rail := 0.050
	_check(float(made.board_back_z) - back >= cap_rail and float(made.board_back_z) - back < cap_rail + 0.006,
			"%s: the board's back clears the 50 mm cap rail it bears on" % unit.name)
	var floor_hit := _ray(unit.to_global(Vector3(0.0, 0.3, 0.5)), unit.to_global(Vector3(0.0, -1.5, 0.5)))
	var drop := -unit.to_local(floor_hit.position).y if not floor_hit.is_empty() else -1.0
	_check(drop > 0.55 and drop < 0.95, "%s: there is landing in front of it, and the board's foot is %.2f m above it" % [unit.name, drop])
	_check(_ray(unit.to_global(Vector3(0.0, 0.45, 0.30)), unit.to_global(Vector3(0.0, 0.45, 1.10))).is_empty(),
			"%s: a man can stand in front of it" % unit.name)
	var cabinet := _world.adapter.resolve(str(unit.get_meta("beside_fire_station"))) as Node3D
	if _check(cabinet != null and cabinet.get_script() != null and cabinet.has_method("line_made_up"),
			"%s hangs beside a fire cabinet station" % unit.name):
		var here := cabinet.to_local(unit.global_position)
		var gap := minf(absf(here.x + right), absf(here.x + left)) - 0.325
		_check(_near(here.z, -back, 0.006) and unit.global_basis.z.dot(cabinet.global_basis.z) > 0.999,
				"%s is on the cabinet's own wall, facing the same landing" % unit.name)
		_check(gap > 0.15 and gap < 0.80 and absf(here.x) < 1.6,
				"%s: %.2f m of clear wall between its board and the cabinet (%.2f m centre to centre)" % [unit.name, gap, absf(here.x)])
		# The cabinet door is hung on the far edge and swings away; nothing of
		# this reaches the cabinet's own envelope.
		_check(absf(here.x) - 0.31 - 0.325 > 0.0, "%s stands clear of the cabinet and its hose" % unit.name)
	var plan := blockout.to_local(unit.global_position)
	var clear_of_doors := true
	for door: Dictionary in blockout.layout.doors:
		var anchor := _world.adapter.resolve(str(door.id)) as Node3D
		if anchor != null and anchor.global_position.distance_to(unit.global_position) < float(door.width) + 0.9:
			clear_of_doors = false
	_check(clear_of_doors, "%s is out of every door's swing (plan %.2f, %.2f)" % [unit.name, plan.x, plan.z])
	# The vessel stands in the foot cup, the cap on the collar.
	var foot := unit.to_local(unit._vessel.global_position)
	_check(_near(foot.y - 0.016, float(made.shelf_top_y) + 0.0415, 0.002), "%s: the vessel's foot is in the cup on the shelf" % unit.name)


func _extinguisher_authority(unit: Node3D) -> void:
	var found: Dictionary = unit.maintenance_snapshot()
	if not unit.extinguisher_inspected.is_connected(_on_inspected):
		unit.extinguisher_inspected.connect(_on_inspected)
	_inspected.clear()
	# As found: sealed, charged, correctly heavy, and it cannot work.
	_check(unit.sealed() and unit.charged() and not unit.will_lift() and not unit.usable(),
			"%s as found is sealed and charged and not usable" % unit.name)
	_check(unit.service_wire_card().condition == "SEALED YES / CHARGED YES / USABLE NO"
			and unit.service_wire_card().title == "SODA ACID EXTINGUISHER", "its card answers as V1's does")
	_check(is_equal_approx(unit.heft(), unit.GROSS_POUNDS), "it weighs what a sound one weighs")
	_check(not unit.invert() and unit.balk_focus() == "invert", "it will not be turned over")
	unit.restore_maintenance_snapshot(found)
	_check(not unit.unscrew_cap() and unit.balk_focus() == "seal" and unit.cap_on, "the wired seal stops the cap")
	_check(unit.cut_seal() and not unit.sealed() and not unit._seal.visible, "cutting the seal breaks sealed() and takes the wire away")
	_check(unit.service_wire_card().condition == "SEALED NO / CHARGED YES / USABLE NO", "the card follows the seal")
	_check(unit.unscrew_cap() and not unit.cap_on, "the cap unscrews")
	_calm(unit)
	await get_tree().process_frame
	var rest: Vector3 = unit.stock.datum("extinguisher", "cap_rest")
	_check(unit.to_local(unit._cap.global_position).distance_to(rest) < 0.001, "the cap stands on its rest")
	var caged: Vector3 = unit._cap.to_global(unit.stock.datum("extinguisher", "bottle_in_cage"))
	_check(unit._bottle.global_position.distance_to(caged) < 0.001, "the bottle is still in the cage, under the cap")
	_check(unit.charged(), "the charge is untouched by taking the cap off")
	_check(unit.draw_bottle() and not unit.charged() and unit.bottle_drawn, "drawing the bottle breaks charged()")
	await get_tree().process_frame
	var standing := unit.to_local(unit._bottle.global_position)
	_check(standing.distance_to(unit.stock.datum("extinguisher", "bottle_drawn")) < 0.001
			and _near(standing.y - 0.056, float(unit.stock.data.extinguisher.shelf_top_y), 0.001), "the bottle stands on the shelf")
	_check(not unit.try_loose_cap() and unit.cap_tested and unit.balk_focus() == "loose" and not unit.will_lift(),
			"lifting at the loose cap brings the bottle with it: the fault")
	_check(unit.to_local(unit._bottle.global_position).y > standing.y + 0.07, "and the refusal shows it: the bottle is in the air")
	_calm(unit)
	_check(unit.free_loose_cap() and unit.will_lift(), "the cap is worked free")
	_check(unit.seat_bottle() and unit.charged() and unit.screw_cap() and unit.wire_seal() and unit.sealed(),
			"bottle seated, cap down, fresh seal wired")
	await get_tree().process_frame
	_check(unit._cap.position.distance_to(unit.V1_CAP_ON) < 0.0005 and unit._seal.visible, "the cap is home and the seal is on it")
	_check(unit.usable() and unit.service_wire_card().condition == "SEALED YES / CHARGED YES / USABLE YES",
			"now it is usable, and the card says so")
	_check(unit.certifiable() and unit.sign_tag() and unit.tag_signed and unit.tag_reads().ends_with("IN ORDER")
			and unit._tag_label.text.contains("IN ORDER"), "the tag is signed in V1's words")
	var record: Dictionary = unit.last_record()
	var complete := _inspected.size() == 1
	for field: String in unit.RECORD_FIELDS:
		complete = complete and record.has(field)
	_check(complete and record.station_id == unit.station_id and record.usable == true,
			"one inspection record is published, with every field")
	unit.restore_maintenance_snapshot(found)
	await get_tree().process_frame
	_check(unit.sealed() and unit.charged() and not unit.usable() and unit._cap.position.distance_to(unit.V1_CAP_ON) < 0.0005,
			"restoring the snapshot puts every fact and part back as found")


func _on_inspected(record: Dictionary) -> void:
	_inspected.append(record)


# --- the hand ------------------------------------------------------------------

func _click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_player._unhandled_input(event)


## Mouse motion through the player's own input handler, in steps a hand makes.
func _drag(relative: Vector2, steps: int = 4) -> void:
	for i in steps:
		var event := InputEventMouseMotion.new()
		event.relative = relative / float(steps)
		_player._unhandled_input(event)
		await get_tree().physics_frame
	await get_tree().process_frame


## Stand in front of a point on a node and look at it; returns what the
## player's own ray finds there.
func _aim(frame: Node3D, at: Vector3, from: Vector3) -> Dictionary:
	_pin.eye = frame.to_global(from)
	_pin.look = frame.to_global(at)
	_pin.active = true
	_pin.apply()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_pin.apply()
	return _player._grab.find_target()


func _holding() -> bool:
	_player._grab.validate()
	return _player._grab.active()


func _extinguisher_hand(unit: Node3D) -> void:
	var found: Dictionary = unit.maintenance_snapshot()
	var cap_at := Vector3(0.0, 0.80, 0.135)
	var front := Vector3(0.0, 0.05, 0.85)
	# -- the cap against a wired seal --
	var grip: Dictionary = await _aim(unit, cap_at, cap_at + front)
	_check(grip.get("owner") == unit and grip.get("part") == unit._cap, "the cursor ray finds the cap itself")
	_click()
	_check(_holding() and is_zero_approx(unit.cap_travel) and unit.cap_on, "taking the cap moves nothing")
	await _drag(Vector2(60, 0))
	_check(_near(unit.cap_travel, unit.SEAL_SLACK, 0.0001) and unit.cap_on and unit.balk_focus() == "seal",
			"the wired seal is a travel stop: the cap takes up the slack and no more")
	await _drag(Vector2(200, 0))
	_check(_near(unit.cap_travel, unit.SEAL_SLACK, 0.0001), "more motion does not move it past the wire")
	_click()
	_check(not _holding() and _near(unit.cap_travel, unit.SEAL_SLACK, 0.0001), "letting go leaves it where it stopped")
	# -- the seal --
	grip = await _aim(unit, Vector3(0.0, 0.715, 0.20), Vector3(0.0, 0.76, 1.0))
	_check(grip.get("owner") == unit and grip.get("part") == unit._vessel, "the cursor ray finds the seal on the neck")
	_click()
	_check(_holding() and unit.seal_wired and is_zero_approx(unit.seal_pull), "taking the seal cuts nothing")
	await _drag(Vector2(0, 45), 3)
	_check(_near(unit.seal_pull, 0.3, 0.001) and unit.seal_wired, "the first pull takes up the wire (%.2f)" % unit.seal_pull)
	await _drag(Vector2(0, 150), 5)
	_check(not unit.seal_wired and not unit.sealed() and not _holding(), "pulled through, the wire parts and the hand has nothing left to hold")
	# -- the cap, free --
	grip = await _aim(unit, cap_at, cap_at + front)
	_click()
	var before: float = unit.cap_travel
	await _drag(Vector2(56, 0), 2)
	_check(_near(unit.cap_travel - before, 0.1, 0.001) and unit.cap_on, "first increment: 56 px is a tenth of the cap's travel")
	var turned: float = unit._cap.rotation.y
	await _drag(Vector2(84, 0), 3)
	_calm(unit)
	_check(_near(unit.cap_travel - before, 0.25, 0.001) and unit.cap_on and not is_equal_approx(unit._cap.rotation.y, turned)
			and unit._cap.position.y > unit.V1_CAP_ON.y, "continued motion turns the cap up its thread")
	_click()
	var left_at: float = unit.cap_travel
	for i in 20:
		await get_tree().process_frame
	_check(not _holding() and is_equal_approx(unit.cap_travel, left_at) and unit.cap_on, "released on the thread, it stays exactly there")
	grip = await _aim(unit, cap_at, cap_at + front)
	_click()
	await _drag(Vector2(560, 0), 8)
	_check(is_equal_approx(unit.cap_travel, 1.0) and not unit.cap_on, "carried through, the cap comes off the thread and on to its rest")
	await _drag(Vector2(200, 0), 2)
	_check(is_equal_approx(unit.cap_travel, 1.0), "the rest is the end of its travel")
	_click()
	var rest: Vector3 = unit.stock.datum("extinguisher", "cap_rest")
	_calm(unit)
	_check(not _holding() and unit.to_local(unit._cap.global_position).distance_to(rest) < 0.001, "released on the rest, it stands there")
	# -- the bottle --
	var bottle_at := unit.to_local(unit._bottle.global_position)
	grip = await _aim(unit, bottle_at, bottle_at + Vector3(0.0, 0.05, 0.8))
	_check(grip.get("owner") == unit and grip.get("part") == unit._bottle, "the cursor ray finds the bottle in its cage")
	_click()
	_check(_holding() and is_zero_approx(unit.bottle_travel) and unit.charged(), "taking the bottle does not draw it")
	await _drag(Vector2(-26, 0), 2)
	_check(_near(unit.bottle_travel, 0.05, 0.001) and unit.charged(), "a little way, it is still in the clips")
	await _drag(Vector2(-234, 0), 5)
	_check(_near(unit.bottle_travel, 0.5, 0.001) and unit.bottle_drawn and not unit.charged(), "half way out, the charge is broken")
	await _drag(Vector2(-400, 0), 6)
	_check(is_equal_approx(unit.bottle_travel, 1.0), "the shelf is the end of its travel")
	_click()
	_calm(unit)
	_check(not _holding() and unit.to_local(unit._bottle.global_position).distance_to(unit.V1_BOTTLE_DRAWN) < 0.001,
			"released, the bottle stands on the shelf")
	# -- the loose cap: the diagnosis, by hand --
	var stopple_at: Vector3 = unit.V1_BOTTLE_DRAWN + Vector3(0.0, 0.070, 0.0)
	grip = await _aim(unit, stopple_at, stopple_at + Vector3(0.0, 0.10, 0.75))
	_check(grip.get("owner") == unit and grip.get("part") == unit._loose_cap, "the cursor ray finds the bottle's little cap")
	_click()
	_check(_holding() and not unit.cap_tested, "taking it tests nothing")
	await _drag(Vector2(0, -150), 3)
	var lifted: float = unit.to_local(unit._bottle.global_position).y - unit.V1_BOTTLE_DRAWN.y
	_check(unit.cap_tested and not unit.will_lift() and _near(unit.stopple_lift, 0.026, 0.0005) and _near(lifted, 0.026, 0.0005),
			"lifted at its cap, the bottle comes up with it (%.3f m)" % lifted)
	await _drag(Vector2(0, -600), 6)
	_check(_near(unit.stopple_lift, unit.STOPPLE_SEIZED_LIFT, 0.0005), "and stops at the reach of the hand")
	_click()
	for i in 40:
		await get_tree().process_frame
	_check(unit.to_local(unit._bottle.global_position).distance_to(unit.V1_BOTTLE_DRAWN) < 0.001, "let go, the bottle sits back down")
	grip = await _aim(unit, stopple_at, stopple_at + Vector3(0.0, 0.10, 0.75))
	_click()
	for stroke in 4:
		if unit.will_lift():
			break
		await _drag(Vector2(0, -460), 5)
		await _drag(Vector2(0, 460), 5)
	_check(unit.will_lift(), "worked back and forth, the cap comes free")
	await _drag(Vector2(0, -600), 4)
	var proud: float = unit._loose_cap.position.y - unit.V1_STOPPLE_Y
	_check(_near(proud, unit.V1_STOPPLE_PROUD, 0.0005)
			and unit.to_local(unit._bottle.global_position).distance_to(unit.V1_BOTTLE_DRAWN) < 0.001,
			"and now it lifts off the neck and the bottle stays down")
	_click()
	# -- taking its weight, and tipping it --
	grip = await _aim(unit, Vector3(0.0, 0.40, 0.25), Vector3(0.0, 0.45, 1.05))
	_check(grip.get("owner") == unit and grip.get("part") == unit._vessel and float(grip.maximum) == unit.HEFT_LIFT,
			"the cursor ray finds the vessel")
	_click()
	await _drag(Vector2(0, -200), 8)
	_check(_holding() and is_equal_approx(unit.heft_lift, unit.HEFT_LIFT), "it lifts in its straps as far as they allow")
	_click()
	for i in 30:
		await get_tree().process_frame
	_check(is_zero_approx(unit.heft_lift), "and sits back in the cup")
	grip = await _aim(unit, Vector3(0.0, 0.18, 0.27), Vector3(0.0, 0.25, 1.05))
	_check(grip.get("owner") == unit and float(grip.maximum) == unit.TIP_LIMIT, "the cursor ray finds its foot")
	_click()
	await _drag(Vector2(-110, 0), 3)
	_check(_near(unit.tip, unit.TIP_LIMIT * 0.5, 0.001) and _near(unit._vessel.rotation.z, unit.tip, 0.0001), "it tips on its foot")
	await _drag(Vector2(-400, 0), 4)
	_check(is_equal_approx(unit.tip, unit.TIP_LIMIT) and unit.balk_focus() == "invert" and not unit.usable(),
			"and stops on its hooks: there is no turning it over")
	_click()
	for i in 40:
		await get_tree().process_frame
	_check(is_zero_approx(unit.tip), "let go, it stands upright again")
	_player._grab.release()
	unit.restore_maintenance_snapshot(found)


# --- the door check ------------------------------------------------------------

func _check_place(check: Node3D, blockout: Node3D) -> void:
	var leaf: Node3D = check.door()
	var made: Dictionary = check.stock.data.door_check
	var record: Dictionary = {}
	for door: Dictionary in blockout.layout.doors:
		if str(door.id) == "ROOF_PUBLIC_DOOR":
			record = door
	_check(leaf != null and check.get_parent() == leaf and str(leaf.get_meta("semantic_id", "")) == "ROOF_PUBLIC_DOOR"
			and str(record.get("level", "")) == "ROOF" and "ROOF_PUBLIC_CORE" in record.get("connects", []),
			"the check is on the leaf at the head of the public stair")
	_check(check.fits(leaf), "the fitting was made for this leaf: height, hinge line and swing")
	# The plate is on the head casing, which is on the wall.
	var anchor := leaf.get_parent() as Node3D
	var casing := anchor.get_node_or_null("DoorCasings") as MultiMeshInstance3D
	if _check(casing != null, "the leaf's opening is cased"):
		var stock_box: AABB = casing.multimesh.mesh.get_aabb()
		var box: AABB = casing.multimesh.get_instance_transform(0) * stock_box
		for index in casing.multimesh.instance_count:
			box = box.merge(casing.multimesh.get_instance_transform(index) * stock_box)
		box = (leaf.global_transform.affine_inverse() * casing.global_transform) * box
		_check(_near(box.end.z, float(made.head_face_z), 0.003) and _near(box.end.y, float(made.leaf_height) + 0.09, 0.01),
				"the plate's back is the face of the head casing (%.3f)" % box.end.z)
	var hit := _ray(leaf.to_global(Vector3(0.22, float(made.leaf_height) + 0.16, 0.7)),
			leaf.to_global(Vector3(0.22, float(made.leaf_height) + 0.16, -0.5)))
	_check(not hit.is_empty() and _near(leaf.to_local(hit.position).z, float(made.wall_face_z), 0.004),
			"and that casing stands on the stair face of a real wall")
	# Nothing fixed stands where the leaf goes.
	var full: float = leaf.motion_target_angle(true)
	var clear := true
	for part_name: String in ["Check__Body_ON_iron_blackened", "Check__BodyBrass_ON_brass", "RegulatingScrew", "HoldOpenCatch"]:
		var draw := check.find_child(part_name, true, false) as MeshInstance3D
		var box: AABB = (leaf.global_transform.affine_inverse() * draw.global_transform) * draw.get_aabb()
		if box.position.z < float(made.head_face_z) - 0.001:
			clear = false
	_check(clear and full > 0.0, "every fixed part is on the stair side of the head; the leaf swings the other way")
	# The arm follows the leaf: the loop closes wherever the leaf stands.
	var found: Dictionary = check.maintenance_snapshot()
	check.hold_leaf()
	check.ship_arm()
	var pin_on_leaf := Vector3(check.shoe_pin.x, check.shoe_pin.y, check.shoe_pin.z - check.hinge_z)
	for share: float in [0.0, 0.5, 1.0]:
		leaf.restore_mechanism({"angle": full * share})
		# An AnimatableBody3D publishes a set pose over the next physics ticks.
		await _ticks(4)
		await get_tree().process_frame
		await get_tree().process_frame
		var on_leaf: Vector3 = leaf._body.to_global(pin_on_leaf)
		var shoe_gap: float = check.shoe_pin_world().distance_to(on_leaf)
		var loop_gap: float = check.forearm_eye().distance_to(check.shoe_pin_world())
		var elbow: Vector3 = check._forearm.global_position
		var link_a: float = elbow.distance_to(check._arm.global_position)
		_check(shoe_gap < 0.001 and loop_gap < 0.003 and _near(link_a, check.ARM_MAIN, 0.0005),
				"leaf at %3d%%: the shoe is on the leaf (%.1f mm) and the forearm's eye is on its pin (%.1f mm)"
				% [int(share * 100.0), shoe_gap * 1000.0, loop_gap * 1000.0])
		var elbow_off_leaf: float = leaf._body.to_local(elbow).z
		_check(elbow_off_leaf > 0.075, "leaf at %3d%%: the elbow stands %.0f mm off the leaf's stair face, never through it"
				% [int(share * 100.0), (elbow_off_leaf - 0.06) * 1000.0])
	leaf.restore_mechanism({"angle": 0.0})
	check.restore_maintenance_snapshot(found)
	await get_tree().process_frame


## Open the leaf the way a hand does, through the leaf's own grip, and let go.
func _open_and_let_go(leaf: Node3D, angle: float) -> void:
	var grip: Dictionary = leaf.manipulation_target({"collider": leaf._body})
	grip.begin.call()
	grip.write.call(angle)
	await get_tree().physics_frame
	grip.end.call()


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check_authority(check: Node3D) -> void:
	var leaf: Node3D = check.door()
	var found: Dictionary = check.maintenance_snapshot()
	var full: float = leaf.motion_target_angle(true)
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	if not check.closer_proved.is_connected(_on_proved):
		check.closer_proved.connect(_on_proved)
	_proved.clear()
	_check(not check.connected() and not check.metered() and not bool(check.call("ready")) and check.shuts_by_hand(),
			"as found the arm is off its spindle and the port is shut")
	_check(check.service_wire_card().condition == "ARM OFF / PORT 0/5 / READY NO"
			and check.service_wire_card().title == "OVERHEAD DOOR CHECK", "its card answers as V1's does")
	_check(not check.turn_check() and check.balk_focus() == "arm", "the port is not metered with the arm off")
	_check(not check.ship_arm() and check.balk_focus() == "hold", "the arm is not shipped with the catch off")
	# As found, a leaf let go stands where it was left: longer than the
	# building's ordinary easy-closing would have waited.
	await _open_and_let_go(leaf, 1.2)
	_check(_proved.is_empty() and check.balk_focus() == "arm", "nobody has looked at the arm: V1 records nothing")
	await _ticks(330)
	_check(_near(check.leaf_angle(), 1.2, 0.0005) and leaf.open and not check.closing,
			"as found, the leaf let go at 69 degrees is still there five and a half seconds later")
	check.read_arm()
	await _open_and_let_go(leaf, 1.2)
	_check(_proved.size() == 1 and check.last_attempt == "stopped_short" and _proved[0].stopped_short == true
			and _proved[0].requested_by_closer == false and not check.closes_itself(),
			"the arm seen, the leaf let go: V1 records that it stopped short")
	# Arm shipped, port still shut: the spring has nothing to move the liquid through.
	_check(check.hold_leaf() and check.ship_arm() and check.release_leaf() and check.connected() and not bool(check.call("ready")),
			"catch thrown, arm shipped, catch off: connected, and not ready")
	await _open_and_let_go(leaf, full)
	await _ticks(120)
	_check(_near(check.leaf_angle(), full, 0.0005) and check.last_attempt == "stopped_short" and check.balk_focus() == "valve",
			"with the port screwed shut the leaf comes off the hand and stops")
	# Three turns out: the port passes, and the spring brings the leaf home.
	for i in 3:
		check.turn_check()
	_check(bool(check.call("ready")) and check.port_reads() == "3/5" and check.service_wire_card().condition == "ARM SHIPPED / PORT 3/5 / READY YES",
			"three turns of the screw: ready, and the card says so")
	var rate: float = check.close_rate()
	_proved.clear()
	await _open_and_let_go(leaf, full)
	await _ticks(3)
	var from: float = check.leaf_angle()
	await _ticks(60)
	var travelled: float = from - check.leaf_angle()
	_check(check.closing and _near(travelled, rate * 60.0 * tick, rate * 3.0 * tick),
			"let go, the leaf comes home at the checked rate: %.3f rad in a second against %.3f" % [travelled, rate * 60.0 * tick])
	_check(_near(check.forearm_eye().distance_to(check.shoe_pin_world()), 0.0, 0.003), "and the arm is on the shoe all the way")
	# A hand on the leaf takes it from the spring.
	var grip: Dictionary = leaf.manipulation_target({"collider": leaf._body})
	grip.begin.call()
	var held: float = check.leaf_angle()
	await _ticks(20)
	_check(not check.closing and _near(check.leaf_angle(), held, 0.0005), "a hand on the leaf stops it: the spring does not fight the hand")
	grip.end.call()
	var waited := 0
	while check.leaf_angle() > 0.0 and waited < 900:
		await get_tree().physics_frame
		waited += 1
	await _ticks(2)
	_check(is_zero_approx(check.leaf_angle()) and not leaf.open and not check.closing, "the leaf reaches its latch")
	_check(check.closes_itself() and _proved.size() >= 1 and _proved[-1].reached_closed == true
			and _proved[-1].requested_by_closer == true and _proved[-1].door_name == str(leaf.name),
			"and V1's record says the closer closed it")
	# The port decides the speed.
	check.port_turns = 1.0
	var wide: float = check.close_rate()
	await _open_and_let_go(leaf, full)
	await _ticks(3)
	from = check.leaf_angle()
	await _ticks(30)
	travelled = from - check.leaf_angle()
	_check(wide > rate * 2.0 and _near(travelled, wide * 30.0 * tick, wide * 3.0 * tick),
			"with the screw right out it comes home faster: %.3f rad in half a second" % travelled)
	# The catch holds it.
	_check(check.hold_leaf(), "the catch can be thrown on an open leaf")
	held = check.leaf_angle()
	await _ticks(60)
	_check(_near(check.leaf_angle(), held, 0.0005) and not check.closing, "and the leaf stands on the catch")
	check.release_leaf()
	waited = 0
	while check.leaf_angle() > 0.0 and waited < 600:
		await get_tree().physics_frame
		waited += 1
	_check(is_zero_approx(check.leaf_angle()), "catch off, it finishes closing")
	# A locked leaf is refused, never opened.
	leaf.leaf_state = "locked"
	_check(not check.prove_close() and check.balk_focus() == "lock" and leaf.leaf_state == "locked", "a locked leaf is refused, not unlocked")
	leaf.leaf_state = "closed"
	check.restore_maintenance_snapshot(found)
	await get_tree().process_frame


func _on_proved(record: Dictionary) -> void:
	_proved.append(record)


func _check_hand(check: Node3D) -> void:
	var leaf: Node3D = check.door()
	var found: Dictionary = check.maintenance_snapshot()
	var screw_at: Vector3 = check.stock.datum("door_check", "valve_rest") + Vector3(0.008, 0.0, 0.0)
	var screw_eye := screw_at + Vector3(0.32, -0.38, 0.62)
	# -- the screw is refused while the arm drives nothing --
	var grip: Dictionary = await _aim(check, screw_at, screw_eye)
	_check(grip.get("owner") == check and grip.get("part") == check._valve, "the cursor ray finds the regulating screw")
	_click()
	_check(not _holding() and check.balk_focus() == "arm" and is_zero_approx(check.port_turns),
			"with the arm off its spindle the screw is refused, as V1 refuses it")
	# -- the arm against a live spring --
	var arm_at: Vector3 = check.to_local(check._arm.to_global(Vector3(check.ARM_MAIN * 0.55, 0.0, 0.0)))
	grip = await _aim(check, arm_at, arm_at + Vector3(0.10, -0.10, 0.80))
	_check(grip.get("owner") == check and grip.get("part") == check._arm, "the cursor ray finds the hanging arm")
	_click()
	_check(_holding() and check.arm_seen and not check.arm_shipped and is_zero_approx(check.arm_seat),
			"taking the arm is looking at it, and moves nothing")
	await _drag(Vector2(0, -60), 2)
	_check(_near(check.arm_seat, 0.2, 0.001), "first increment: the arm comes up a fifth of the way")
	await _drag(Vector2(0, -200), 4)
	_check(_near(check.arm_seat, check.ARM_LIVE_STOP, 0.0001) and not check.arm_shipped and check.balk_focus() == "hold",
			"with the catch off the spring is live: the arm stops short of the spindle")
	_click()
	for i in 40:
		await get_tree().process_frame
	_check(not _holding() and is_zero_approx(check.arm_seat), "let go, it hangs again")
	# -- the catch --
	var catch_at: Vector3 = check.stock.datum("door_check", "hold_pivot") + Vector3(0.0, 0.022, 0.008)
	grip = await _aim(check, catch_at, catch_at + Vector3(-0.22, -0.34, 0.62))
	_check(grip.get("owner") == check and grip.get("part") == check._hold, "the cursor ray finds the hold-open catch")
	_click()
	_check(_holding() and not check.leaf_held and is_zero_approx(check.hold_throw), "taking the catch throws nothing")
	await _drag(Vector2(0, 60), 2)
	_check(_near(check.hold_throw, 0.4, 0.001) and not check.leaf_held, "part thrown, it holds nothing yet")
	await _drag(Vector2(0, 200), 4)
	_calm(check)
	_check(is_equal_approx(check.hold_throw, 1.0) and check.leaf_held and _near(check._hold.rotation.z, check.HOLD_THROW, 0.001),
			"over its centre and against its stop, the catch is thrown")
	_click()
	_check(not _holding() and is_equal_approx(check.hold_throw, 1.0), "released, it stays thrown")
	# -- the arm, with the catch on --
	arm_at = check.to_local(check._arm.to_global(Vector3(check.ARM_MAIN * 0.55, 0.0, 0.0)))
	grip = await _aim(check, arm_at, arm_at + Vector3(0.10, -0.10, 0.80))
	_click()
	await _drag(Vector2(0, -150), 3)
	_check(_near(check.arm_seat, 0.5, 0.001) and not check.arm_shipped, "half way up, it is not yet on the spindle")
	await _drag(Vector2(0, -300), 5)
	_check(check.arm_shipped and is_equal_approx(check.arm_seat, 1.0)
			and check.forearm_eye().distance_to(check.shoe_pin_world()) < 0.003, "lifted home, the arm is shipped and its eye is on the shoe pin")
	_click()
	# -- the catch off again --
	grip = await _aim(check, catch_at, catch_at + Vector3(-0.22, -0.34, 0.62))
	_click()
	await _drag(Vector2(0, -260), 5)
	_check(is_zero_approx(check.hold_throw) and not check.leaf_held, "the catch comes off the same way")
	_click()
	# -- the regulating screw --
	grip = await _aim(check, screw_at, screw_eye)
	_check(grip.get("owner") == check and grip.get("part") == check._valve, "the cursor ray finds the screw again")
	_click()
	_check(_holding() and is_zero_approx(check.port_turns) and is_zero_approx(check._valve.rotation.x), "taking the screw turns nothing")
	await _drag(Vector2(104, 0), 2)
	_check(_near(check.port_turns, 0.2, 0.001) and _near(check._valve.rotation.x, 0.2 * check.VALVE_SWEEP, 0.001) and not check.metered(),
			"first increment: 104 px is one turn of five, and the tang shows it")
	await _drag(Vector2(208, 0), 4)
	_check(_near(check.port_turns, 0.6, 0.001) and bool(check.call("ready")) and check.port_reads() == "3/5", "continued motion: three of five, and the port passes")
	_click()
	var left_at: float = check.port_turns
	for i in 20:
		await get_tree().process_frame
	_check(not _holding() and is_equal_approx(check.port_turns, left_at) and _near(check._valve.rotation.x, left_at * check.VALVE_SWEEP, 0.0001),
			"released, the screw stays exactly where the hand left it")
	grip = await _aim(check, screw_at, screw_eye)
	_click()
	await _drag(Vector2(600, 0), 6)
	_check(is_equal_approx(check.port_turns, 1.0), "the screw's travel stops at wide open")
	await _drag(Vector2(-1000, 0), 8)
	_check(is_zero_approx(check.port_turns), "and at home")
	await _drag(Vector2(312, 0), 4)
	_click()
	_check(_near(check.port_turns, 0.6, 0.001) and bool(check.call("ready")), "set back to three of five")
	# -- the real leaf, by mouse, and the spring --
	_proved.clear()
	grip = await _aim(leaf, Vector3(0.62, 1.15, 0.03), Vector3(0.62, 1.55, 1.05))
	_check(grip.get("owner") == leaf, "the cursor ray finds the leaf itself, not the check")
	_click()
	_check(_holding() and is_zero_approx(check.leaf_angle()), "taking the leaf opens nothing")
	await _drag(Vector2(120, 0), 3)
	var half: float = check.leaf_angle()
	_check(_near(half, leaf.motion_target_angle(true) * 0.5, 0.01) and check.forearm_eye().distance_to(check.shoe_pin_world()) < 0.003,
			"the leaf follows the mouse half open, and the arm goes with it")
	await _drag(Vector2(160, 0), 3)
	_check(is_equal_approx(check.leaf_angle(), leaf.motion_target_angle(true)), "to its stop")
	_click()
	await _ticks(4)
	_check(not _holding() and check.closing, "let go, the spring takes it")
	var waited := 0
	while check.leaf_angle() > 0.0 and waited < 900:
		await get_tree().physics_frame
		waited += 1
	await _ticks(2)
	_check(is_zero_approx(check.leaf_angle()) and check.closes_itself() and _proved.size() == 1 and _proved[0].reached_closed == true,
			"and it latches: the door closed itself, and the record says so")
	_player._grab.release()
	check.restore_maintenance_snapshot(found)
	await get_tree().process_frame


# --- captures ------------------------------------------------------------------

func _shot(shot_name: String, frame: Node3D, at: Vector3, from: Vector3) -> void:
	_pin.eye = frame.to_global(from)
	_pin.look = frame.to_global(at)
	_pin.active = true
	for i in 10:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots.path_join(shot_name + ".png"))
	print("[V2 FIRE APPARATUS] capture ", shot_name)


func _captures(units: Array, check: Node3D) -> void:
	_player._grab.release()
	for unit: Node3D in units:
		var tag := str(unit.name).to_lower()
		await _shot(tag + "_station_standing", unit, Vector3(0.38, 0.50, 0.0), Vector3(0.60, 0.92, 1.80))
		await _shot(tag + "_front", unit, Vector3(0.0, 0.42, 0.10), Vector3(0.05, 0.62, 1.30))
		await _shot(tag + "_left", unit, Vector3(-0.02, 0.42, 0.10), Vector3(-1.05, 0.70, 0.95))
		await _shot(tag + "_cap_close", unit, Vector3(0.0, 0.76, 0.135), Vector3(0.30, 0.98, 0.62))
		await _shot(tag + "_plate_and_tag", unit, Vector3(-0.19, 0.52, 0.02), Vector3(-0.30, 0.62, 0.50))
		var found: Dictionary = unit.maintenance_snapshot()
		unit.cut_seal()
		unit.unscrew_cap()
		unit.draw_bottle()
		unit.try_loose_cap()
		unit.free_loose_cap()
		unit.restore_maintenance_snapshot(unit.maintenance_snapshot())
		await _shot(tag + "_opened", unit, Vector3(0.0, 0.42, 0.10), Vector3(-0.15, 0.80, 1.25))
		await _shot(tag + "_bottle_close", unit, Vector3(-0.192, 0.15, 0.15), Vector3(-0.36, 0.32, 0.62))
		unit.restore_maintenance_snapshot(found)
	var leaf: Node3D = check.door()
	var high: float = leaf.height
	var found_check: Dictionary = check.maintenance_snapshot()
	await _shot("check_found_stair_side", leaf, Vector3(0.28, high - 0.10, 0.22), Vector3(0.80, high - 0.50, 1.00))
	check.hold_leaf()
	check.ship_arm()
	check.release_leaf()
	check.port_turns = 0.6
	check.restore_maintenance_snapshot(check.maintenance_snapshot())
	await _shot("check_closed_stair_side", leaf, Vector3(0.28, high - 0.02, 0.22), Vector3(0.80, high - 0.42, 0.95))
	await _shot("check_closed_stair_standing", leaf, Vector3(0.45, high - 0.25, 0.05), Vector3(0.85, 1.62, 1.30))
	await _shot("check_closed_under", leaf, Vector3(0.26, high, 0.16), Vector3(0.30, high - 0.72, 0.72))
	await _shot("check_screw_close", leaf, check.stock.datum("door_check", "valve_rest"),
			check.stock.datum("door_check", "valve_rest") + Vector3(0.26, -0.10, 0.34))
	await _shot("check_closed_roof_side", leaf, Vector3(0.55, high - 0.35, 0.0), Vector3(0.55, 1.62, -2.0))
	# Held open on the catch, so the spring leaves the leaf where the camera wants it.
	check.hold_leaf()
	leaf.restore_mechanism({"angle": leaf.motion_target_angle(true)})
	await _shot("check_open_stair_side", leaf, Vector3(0.20, high - 0.02, 0.0), Vector3(0.85, high - 0.42, 0.95))
	await _shot("check_open_roof_side", leaf, Vector3(0.15, high - 0.03, -0.10), Vector3(0.80, high - 0.45, -0.95))
	await _shot("check_open_screw_close", leaf, check.stock.datum("door_check", "valve_rest"),
			check.stock.datum("door_check", "valve_rest") + Vector3(0.30, 0.02, 0.30))
	leaf.restore_mechanism({"angle": 0.0})
	check.restore_maintenance_snapshot(found_check)
	_pin.active = false


func _finish() -> void:
	var ok := _fails == 0
	print("[V2 FIRE APPARATUS] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	if _pin != null:
		_pin.active = false
	if _world != null:
		if _world.has_method("shutdown_for_tests"):
			_world.shutdown_for_tests()
		remove_child(_world)
		_world.free()
	get_tree().quit(0 if ok else 1)
