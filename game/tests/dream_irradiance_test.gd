extends Node
## IR-V1/IR-V2: reversible pointwise response and the unreliable lamp remain
## presentation beneath the existing boolean/gameplay owners.

const SEED_HEX := "f123456789abcdef"
const EXPECTED_CHECKS := 16
const PROFILE_PATH := "res://data/dream_profiles.json"

var checks := 0
var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[IRRADIANCE] START")
	var juno := await _spawn_root("juno_feedback_tetris", "juno_release_print")
	var player: PlayerController = juno.player
	_check(player.lamp_is_enabled(), "gutter begins inside the unchanged ON state")

	var trace := _trace(player)
	_check(float(trace.minimum) >= PlayerController.LAMP_GUTTER_FLOOR - 0.0001,
			"gutter never counterfeits darkness")
	_check(float(trace.maximum) <= 1.0001 and float(trace.maximum)
			- float(trace.minimum) > 0.35, "gutter spans the ruled painterly range")
	_check(absf(float(trace.mean) - PlayerController.LAMP_GUTTER_MEAN) <= 0.02,
			"180-second mean keeps dwell tuning honest")
	_check(float(trace.max_slope) <= PlayerController.LAMP_GUTTER_MAX_SLOPE + 0.002,
			"sampled waveform stays under the 0.30/s photosensitivity ceiling")
	var first_values: PackedFloat32Array = trace.values
	player.configure_dream_lamp_gutter(SEED_HEX, 0.0)
	var repeated := _trace(player)
	_check(first_values == repeated.values,
			"same campaign seed and run clock reproduce the same gutter")
	_check(player.lamp_is_enabled(),
			"a complete gutter trace creates zero lamp boolean edges")

	player.pin_lamp_gutter_for_proof(0.79)
	_check(is_equal_approx(player.lamp_delivered_multiplier(), 0.79),
			"diagnostic pin freezes one proof phase")
	var pinned_range := player.flashlight.spot_range
	player.set_lamp_gutter_clock(117.0)
	_check(is_equal_approx(player.lamp_delivered_multiplier(), 0.79)
			and is_equal_approx(player.flashlight.spot_range, pinned_range),
			"proof pin survives elapsed time without becoming configuration")
	player.pin_lamp_gutter_for_proof(-1.0)

	var event_before := int(juno.pursuer.run_parameters().profile_event_count)
	juno.advance_profile_grammar(4.2, true, 0.79)
	_check(juno.rooms.channel_partition_count() == 1,
			"the one real open edge still schedules Juno's partition")
	juno.advance_profile_grammar(4.2, true, 0.79)
	_check(juno.rooms.channel_partition_count() == 0
			and int(juno.pursuer.run_parameters().profile_event_count)
			== event_before + 1,
			"mean-energy sustain preserves Juno's ruled elapsed release")
	for i in 1800:
		var t := float(i) * 0.1
		player.set_lamp_gutter_clock(t)
		juno.advance_profile_grammar(0.1, true,
				player.lamp_delivered_multiplier())
	_check(int(juno.pursuer.run_parameters().profile_event_count)
			== event_before + 1,
			"guttering an open channel creates no phantom Juno edge")
	var acquisition_before := juno.pursuer.lamp_finds_target()
	player.set_lamp_gutter_clock(9.9)
	_check(juno.pursuer.lamp_finds_target() == acquisition_before,
			"delivered energy cannot change boolean pursuit acquisition")
	juno.queue_free()
	await get_tree().process_frame

	var mina := await _spawn_root("mina_caption_crisis", "mina_release_print")
	var hazard_conditions: Array[bool] = []
	for hazard in mina.hazards.hazards:
		hazard_conditions.append(hazard.call("_condition_live", true, 0.0))
	for i in 1800:
		mina.player.set_lamp_gutter_clock(float(i) * 0.1)
	var unchanged := true
	for i in mina.hazards.hazards.size():
		unchanged = unchanged and hazard_conditions[i] \
				== mina.hazards.hazards[i].call("_condition_live", true, 0.0)
	_check(unchanged, "one gutter cycle family changes zero hazard conditions")
	mina.queue_free()
	await get_tree().process_frame

	var a := _field_trace()
	var b := _field_trace()
	_check(a == b, "same gutter trace accrues identical exposure and irradiance")
	_check(float(a.durable) > 0.0 and float(a.reversible) > 0.0,
			"delivered average energy reaches both existing field meanings")

	if checks != EXPECTED_CHECKS:
		failures += 1
		printerr("[IRRADIANCE] HARNESS FAIL: %d checks ran, %d expected"
				% [checks, EXPECTED_CHECKS])
	print("DREAM IRRADIANCE TEST: %s (%d/%d)" % [
			"PASS" if failures == 0 else "FAIL %d" % failures,
			checks, EXPECTED_CHECKS])
	get_tree().quit(failures)


func _trace(player: PlayerController) -> Dictionary:
	var values := PackedFloat32Array()
	var minimum := INF
	var maximum := -INF
	var sum := 0.0
	var max_slope := 0.0
	var previous := 0.0
	var dt := 0.02
	for i in 9001:
		player.set_lamp_gutter_clock(float(i) * dt)
		var value := player.lamp_delivered_multiplier()
		values.append(value)
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
		sum += value
		if i > 0:
			max_slope = maxf(max_slope, absf(value - previous) / dt)
		previous = value
	return {"values": values, "minimum": minimum, "maximum": maximum,
			"mean": sum / float(values.size()), "max_slope": max_slope}


func _field_trace() -> Dictionary:
	var field := DreamExposureField.new()
	field.stamp_room("@", [0.0, 0.0, 4.0, 4.0], 0.0, 0.5)
	var player := PlayerController.new()
	add_child(player)
	player.configure_dream_lamp_gutter(SEED_HEX, 0.0)
	for i in 1800:
		var t := float(i) * 0.1
		player.set_lamp_gutter_clock(t)
		field.add_lamp(Vector3(0.5, 1.5, 2.0), Vector3.RIGHT,
				6.0, cos(deg_to_rad(40.0)), player.lamp_delivered_multiplier(),
				0.1)
	var result := {"durable": field.sample(Vector3(3.0, 1.5, 2.0)),
			"reversible": field.sample_irradiance(Vector3(3.0, 1.5, 2.0))}
	player.queue_free()
	return result


func _spawn_root(case_id: String, profile_id: String) -> DreamMazeRoot:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	var root := scene.instantiate() as DreamMazeRoot
	root.autonomous = false
	root.configure_dream({"case_id": case_id, "profile_id": profile_id,
			"window": {}, "seed_hex": SEED_HEX, "maze_revision": 1,
			"outcome": "", "night_index": 3, "spawn_anchor": 1})
	add_child(root)
	await get_tree().process_frame
	return root


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [irradiance ok] " + label)
	else:
		failures += 1
		printerr("  [IRRADIANCE FAIL] " + label)
