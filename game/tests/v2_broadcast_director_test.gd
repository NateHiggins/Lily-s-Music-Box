extends Node
## The station's programme director in V2 (v1r_broadcast_director_20261109):
## it stands behind the house broadcast, breaks the running order for a card
## after every third record, and when an intrusion takes the transmission it
## takes every wireless in the building, then lets them go.
const Broadcast := preload("res://scripts/audio/orison_v2_broadcast.gd")
const Director := preload("res://scripts/building/orison_v2_broadcast_director.gd")

var _fails := 0
var _checks := 0
var _longest_frame := 0.0
var _last_frame_msec := 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _last_frame_msec > 0:
		_longest_frame = maxf(_longest_frame, (now - _last_frame_msec) / 1000.0)
	_last_frame_msec = now


## Waits on real frames until `ready` answers true, or the deadline passes.
func _until(ready: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if ready.call():
			return true
		await get_tree().process_frame
	return bool(ready.call())


## The world goes on loading for a while after it reports ready. A card lasts
## 3.6 s, so wait until frames are short enough that one cannot be slept through.
func _settle() -> float:
	var began := Time.get_ticks_msec()
	var quiet := 0
	while quiet < 60 and Time.get_ticks_msec() - began < 60000:
		var before := Time.get_ticks_msec()
		await get_tree().process_frame
		quiet = quiet + 1 if Time.get_ticks_msec() - before < 250 else 0
	return (Time.get_ticks_msec() - began) / 1000.0


## Runs the station's clock to `lead` seconds before the end of a record and
## puts the set's emitter there, as it would be had it been on all along.
func _near_end_of(record: Dictionary, lead: float, programme: AudioStreamPlayer3D) -> void:
	Broadcast.request(str(record.id))
	Broadcast._started_msec -= int((float(record.length) - lead) * 1000.0)
	Broadcast.join(programme, float(programme.get_meta("broadcast_db")))
	_longest_frame = 0.0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	Broadcast.reset_for_test()
	var world := (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not world.startup_failed, "the V2 world starts")
	var station: Node = world.get("broadcast")
	_check(station != null and station.get_script() == Director, "V2 composes the programme director as world.broadcast")
	if station == null:
		_finish(world)
		return
	_check(station.radios.size() == 18, "it knows every wireless (%d)" % station.radios.size())
	_check(not "clips" in station, "it holds no film clips: those go with the projectors")
	_check(Broadcast.break_every == 3 and Broadcast.break_seconds > 0.0, "the running order breaks after every third record")

	var radio: Node = null
	var quiet: Node = null
	for candidate in station.radios:
		if str(candidate.unit) == "4B":
			radio = candidate
		elif quiet == null and not candidate.powered and str(candidate.family) != "crystal_set":
			quiet = candidate
	_check(radio != null and quiet != null, "the player's set and a neighbour's silent set are found")
	if radio == null or quiet == null:
		_finish(world)
		return
	var settled: float = await _settle()
	print("[V2 BROADCAST DIRECTOR] frames settled after %.1f s" % settled)
	if radio.powered:
		radio.interact()
	radio.interact()
	var programme: AudioStreamPlayer3D = radio._programme
	var order := Broadcast.records()
	_check(order.size() >= 6, "the running order is long enough to break twice")
	var pools: Array = []
	for lines: Array in Director.ADVERTS + Director.TRIVIA + Director.IDENTS:
		pools.append(" ".join(lines.filter(func(line: String) -> bool: return line != "")))

	# The third record ends: a card, on the set's own carrier.
	_near_end_of(order[2], 0.8, programme)
	_check(str(Broadcast.now_playing().get("id", "")) == str(order[2].id), "the third record is ending")
	_check(await _until(func() -> bool: return programme.has_meta("broadcast_break"), 4.0),
		"after the third record the set goes to the break (longest frame %.2f s)" % _longest_frame)
	_check(bool(Broadcast.now_playing().get("break", false)), "the station is in a card break")
	_check(programme.stream == programme.get_meta("broadcast_carrier") and programme.playing,
		"the set carries the break on its own carrier")
	await get_tree().process_frame
	await get_tree().process_frame
	var card := " ".join(station.card_lines)
	_check(card in pools, "the director reads one of V1's cards (%s)" % card)
	_check(Broadcast.card_on_air(programme) == card and Broadcast.on_air(programme).is_empty(),
		"the set carries the card and no record")
	_check(str(radio.service_wire_card().body).contains(card), "the wireless's slip says the card (%s)" % radio.service_wire_card().body)
	_check(station.stats().card, "the director reports the card")

	# The card ends: the fourth record, from its first bar.
	_check(await _until(func() -> bool: return str(programme.get_meta("broadcast_record", "")) == str(order[3].id),
		Director.CARD_SECONDS + 3.0), "after the card the fourth record goes out")
	_check(programme.stream == order[3].stream and programme.get_playback_position() < 1.5,
		"from its first bar (%.2f s)" % programme.get_playback_position())
	await get_tree().process_frame
	await get_tree().process_frame
	_check(station.card_lines.is_empty() and Broadcast.card_on_air(programme).is_empty(), "the card is gone")

	# No card between the fourth record and the fifth.
	_near_end_of(order[3], 0.8, programme)
	_check(await _until(func() -> bool: return str(programme.get_meta("broadcast_record", "")) == str(order[4].id), 4.0),
		"the fifth record follows the fourth directly (longest frame %.2f s)" % _longest_frame)
	_check(not programme.has_meta("broadcast_break") and station.cards_shown == 1,
		"with no card between them (%d shown)" % station.cards_shown)

	# The hand: an intrusion's own act takes the transmission.
	_check(not quiet.powered, "%s's set is off before the intrusion" % quiet.unit)
	_check(world.intrusions.perform("tv_infect", 4.0), "tv_infect finds the station")
	_check(station.possessed, "the transmission is taken")
	_check(quiet.powered and quiet.possessed, "a silent set switches itself on")
	var seized := 0
	for candidate in station.radios:
		if candidate.powered and candidate.possessed:
			seized += 1
	_check(seized == station.radios.size(), "every wireless in the building is taken (%d)" % seized)
	for i in 3: await get_tree().process_frame
	_check(programme.volume_db <= radio.BROADCAST_DB - radio.POSSESSED_DUCK_DB + 0.01,
		"a set that was playing has its programme sunk (%.1f dB)" % programme.volume_db)
	_check(await _until(func() -> bool: return not station.possessed, 7.0), "the director lets go when the time is up")
	_check(not quiet.powered and not quiet.possessed, "the silent set is silent again")
	_check(radio.powered and is_equal_approx(programme.volume_db, radio.BROADCAST_DB)
			and is_equal_approx(programme.pitch_scale, 1.0), "the playing set is back at its own level")
	var let_go := 0
	for candidate in station.radios:
		if not candidate.possessed:
			let_go += 1
	_check(let_go == station.radios.size() and station.stats().on == 1, "every wireless is as its listener left it")
	radio.interact()
	_finish(world)


func _finish(world: Node) -> void:
	var ok := _fails == 0
	print("[V2 BROADCAST DIRECTOR] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	if world.has_method("shutdown_for_tests"):
		world.shutdown_for_tests()
	get_tree().quit(0 if ok else 1)
