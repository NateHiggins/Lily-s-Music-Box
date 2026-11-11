extends Node
## The house fitted for the day: in a visit every window stands as that day
## has it, a rerun sets them so again, and coming home puts each one back
## exactly as its tenant had it. The occasion follows the date the clock reads.
const State := preload("res://scripts/game/prologue_state.gd")

var _fails := 0
var _checks := 0
var world: Node3D
var told: Array[String] = []


## Stands in for the occasion props: it only records what it is told.
func dress(occasion: String) -> void:
	told.append(occasion)


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


func _matches(treatment: Node, pose: Dictionary) -> bool:
	var now: Dictionary = treatment.settings_snapshot()
	return is_equal_approx(float(now.raise), float(pose.raise)) and is_equal_approx(float(now.tilt_degrees), float(pose.tilt_degrees)) \
			and is_equal_approx(float(now.curtain_open), float(pose.curtain_open))


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not world.startup_failed, "the V2 world starts")
	var fittings: Node = world.get("season_fittings")
	var loop: Node = world.get("temporal_loop")
	_check(fittings != null and loop != null, "V2 composes the season fittings")
	if fittings == null or loop == null:
		_finish()
		return
	await _settle(fittings)
	_check(fittings.treatments.size() >= 60, "it has the building's windows (%d)" % fittings.treatments.size())
	var before: Array[Dictionary] = []
	var open_windows := 0
	for treatment: Node in fittings.treatments:
		var had: Dictionary = treatment.settings_snapshot()
		before.append(had.duplicate())
		open_windows += 0 if (float(had.raise) <= 0.001 and float(had.curtain_open) <= 0.001) else 1
	_check(open_windows >= 40, "most are not shut tight to begin with (%d)" % open_windows)

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

	# A visit borrows the windows.
	_check(loop.jump("tea").ok, "the jump to 13 June")
	var pose: Dictionary = loop.windows_of("tea")
	var dressed := 0
	var asleep_kept := true
	for index in fittings.treatments.size():
		var was: Dictionary = before[index]
		if float(was.raise) <= 0.001 and float(was.curtain_open) <= 0.001:
			asleep_kept = asleep_kept and _matches(fittings.treatments[index], was)
		elif _matches(fittings.treatments[index], pose):
			dressed += 1
	_check(dressed == open_windows, "every open window stands as an early summer afternoon has it (%d of %d)" % [dressed, open_windows])
	_check(asleep_kept, "a window shut on a sleeper stays shut")
	_check(((loop.ledger().visit as Dictionary).get("windows", []) as Array).size() == fittings.treatments.size(),
			"what the tenants had is kept in the visit's record, for a save made away")

	# The player meddles; a rerun sets the day's windows again.
	var one: Node = null
	for index in fittings.treatments.size():
		if _matches(fittings.treatments[index], pose):
			one = fittings.treatments[index]
			break
	one.restore_settings({"raise": 0.0, "tilt_degrees": 75.0, "curtain_open": 0.0})
	_check(not _matches(one, pose) and loop.reset_loop().ok and _matches(one, pose), "a blind pulled down in one run is up again in the next")

	# Home: exactly as the tenants had them.
	_check(loop.go_home().ok, "home")
	var restored := true
	for index in fittings.treatments.size():
		restored = restored and _matches(fittings.treatments[index], before[index])
	_check(restored, "every window is exactly as its tenant had it")

	# A different day dresses differently.
	loop.ledger().items["order_slip"] = {"pinned": true, "anchor": "tea", "run": 1, "slot": 0}
	loop.ledger().bank_cents = 500
	_check(loop.jump("stairs").ok and _matches(one, loop.windows_of("stairs")) and not _matches(one, pose),
			"the night after the storm has them nearly shut")
	_check(loop.go_home().ok and _matches(one, before[fittings.treatments.find(one)]), "and home again they are the tenant's")

	# The occasion follows the date the clock reads.
	fittings.occasion = self
	_check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 7, 3, 600.0)), "the present is set to 3 July")
	fittings._poll = 9.0
	fittings._process(0.1)
	_check(told == (["Independence Day"] as Array[String]), "the house is told to dress for Independence Day (%s)" % str(told))
	fittings._poll = 9.0
	fittings._process(0.1)
	_check(told.size() == 1, "once for the day, not every tick")
	_check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 8, 6, 600.0)), "and to 6 August")
	fittings._poll = 9.0
	fittings._process(0.1)
	_check(told.size() == 2 and told[1] == "", "an ordinary day takes the dressing down")
	fittings.occasion = null
	_finish()


func _finish() -> void:
	print("[V2 SEASON FITTINGS] RESULT: %s (%d checks, %d failures)" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	await get_tree().process_frame
	if world != null:
		world.shutdown_for_tests()
		remove_child(world)
		world.free()
	get_tree().quit(0 if _fails == 0 else 1)
