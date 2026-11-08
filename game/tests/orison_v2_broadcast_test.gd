extends Node
## The house broadcast: Pull Up a Chair is the first record, the V1 library
## follows in catalogue order, and a receiver joins the live programme and
## hands its carrier back. Real playback on a real AudioStreamPlayer3D.
const Broadcast := preload("res://scripts/audio/orison_v2_broadcast.gd")

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	Broadcast.reset_for_test()
	var order := Broadcast.records()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/music_catalog.json"))
	_check("every record is playable (%s)" % [Broadcast.errors], Broadcast.errors.is_empty())
	_check("the song plus the whole V1 library are on the running order",
			order.size() == 1 + catalog.tracks.size())
	_check("Pull Up a Chair is the first record",
			not order.is_empty() and order[0].id == "pull_up_a_chair"
			and order[0].title == "Pull Up a Chair" and order[0].year == 1929
			and absf(float(order[0].length) - 182.137) < 0.05)
	var library_ids: Array = catalog.tracks.keys()
	_check("library records keep catalogue order and catalogue titles",
			order.slice(1).map(func(r): return r.id) == library_ids
			and order[1].title == str(catalog.tracks[library_ids[0]].title))
	_check("nothing is on the air before anyone tunes in",
			Broadcast.now_playing().is_empty())

	var carrier := AudioStreamGenerator.new()
	var player := AudioStreamPlayer3D.new()
	player.stream = carrier
	player.volume_db = -31.0
	add_child(player)
	var now := Broadcast.join(player, -18.0)
	await get_tree().process_frame
	_check("the first listener hears the first record from its top",
			now.get("id") == "pull_up_a_chair" and float(now.get("offset", 99.0)) < 0.5)
	_check("the receiver really plays the record",
			player.playing and player.stream == order[0].stream
			and is_equal_approx(player.volume_db, -18.0))
	_check("the receiver reports what is on the air",
			Broadcast.on_air(player) == "Pull Up a Chair")

	var second := AudioStreamPlayer3D.new()
	second.stream = carrier
	add_child(second)
	# The broadcast runs on the wall clock; a scene timer can run faster than it under a fixed-step runner, so the
	# check measures the real time that passed rather than trusting the timer's 0.4 s.
	var before := Time.get_ticks_msec()
	await get_tree().create_timer(0.4).timeout
	while Time.get_ticks_msec() - before < 300:
		await get_tree().process_frame
	var elapsed := (Time.get_ticks_msec() - before) / 1000.0
	var later := Broadcast.join(second, -18.0)
	_check("a second set joins the same record at the live position (%.3f s in after %.3f s)" % [float(later.get("offset", -1.0)), elapsed],
			later.get("id") == "pull_up_a_chair" and float(later.offset) >= elapsed - 0.05)

	Broadcast.leave(player)
	_check("switching off stops the record", not player.playing
			and Broadcast.on_air(player).is_empty())
	Broadcast.restore_carrier(second)
	_check("cleanup hands the carrier stream back",
			second.stream == carrier and is_equal_approx(second.volume_db, 0.0)
			and not second.playing)
	player.queue_free()
	second.queue_free()
	await get_tree().create_timer(0.2).timeout
	await _check_household_receiver()
	await _check_specialist_receivers()
	print("[V2 BROADCAST] RESULT: %s (%d failures)" % [
			"PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)


## The real V2 household receiver: switching it on puts the broadcast on its own
## emitter, its card names the record, and switching off and freeing it hands
## the murmur carrier back for the prop's own audio cleanup.
func _check_household_receiver() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/domestic_radios.json"))
	var profile: Dictionary = {}
	for entry: Dictionary in catalog.profiles:
		if str(entry.get("unit", "")) == "4B":
			profile = entry
	var radio: Node = preload("res://scripts/building/orison_v2_radio_prop.gd").new()
	radio.configure(profile)
	add_child(radio)
	await get_tree().process_frame
	var emitter: AudioStreamPlayer3D = radio._programme
	var on: Dictionary = radio.interact()
	var live := Broadcast.now_playing()
	_check("the household set switched on plays the broadcast record",
			emitter.playing and emitter.stream == live.get("stream") and str(on.get("on_air", "")) == str(live.get("title")))
	_check("the household set's card names the record",
			str(radio.service_wire_card().body).contains(str(live.get("title"))))
	_check("the household set reports the record in its public state",
			str(radio.public_state().get("on_air", "")) == str(live.get("title")))
	var off: Dictionary = radio.interact()
	_check("the household set switched off falls silent",
			not emitter.playing and str(off.get("on_air", "x")).is_empty())
	radio.interact()
	var record: AudioStream = emitter.stream
	remove_child(radio)
	_check("a playing set leaving the tree gives up the broadcast record",
			not emitter.playing and emitter.stream != record)
	radio.queue_free()


## The specialist valve sets (the five original household radios): switching one
## on joins the live programme at the broadcast level, two sets carry the same
## record, switching off falls silent, and leaving the tree hands the murmur
## carrier back before the prop releases it.
func _check_specialist_receivers() -> void:
	const Specialist := preload("res://scripts/building/orison_v2_specialist_radio.gd")
	var sets: Array = []
	for identity: String in ["2A_RADIO_TEST", "3B_RADIO_TEST"]:
		var radio: Node = Specialist.new()
		radio.setup({"asm": "radio", "id": identity})
		add_child(radio)
		sets.append(radio)
	await get_tree().process_frame
	var first: Node = sets[0]
	var carrier: AudioStream = first._radio_bed.stream
	_check("a specialist set starts on its murmur carrier, switched off",
			carrier != null and not first._powered and not first._radio_bed.playing)
	for radio: Node in sets:
		radio.interact()
	var live := Broadcast.now_playing()
	for radio: Node in sets:
		var bed: AudioStreamPlayer3D = radio._radio_bed
		_check("specialist %s switched on plays the broadcast record at %.0f dB" % [radio.record_id, Specialist.BROADCAST_DB],
				radio._powered and bed.playing and bed.stream == live.get("stream")
				and is_equal_approx(bed.volume_db, Specialist.BROADCAST_DB) and bed.bus == "Broadcast")
		_check("specialist %s reports the record on the air" % radio.record_id,
				Broadcast.on_air(bed) == str(live.get("title")))
	_check("two specialist sets carry the same record",
			sets[0]._radio_bed.stream == sets[1]._radio_bed.stream)
	first.interact()
	_check("a specialist set switched off falls silent and leaves the broadcast",
			not first._powered and not first._radio_bed.playing and Broadcast.on_air(first._radio_bed).is_empty())
	_check("the other set keeps playing", sets[1]._radio_bed.playing)
	# Leaving the tree while playing: the carrier comes back, then the prop's own cleanup releases it.
	var second: Node = sets[1]
	var bed: AudioStreamPlayer3D = second._radio_bed
	remove_child(second)
	_check("a playing specialist set leaving the tree stops and lets go of its streams",
			not bed.playing and bed.stream == null and not bed.has_meta("broadcast_on"))
	_check("the broadcast record is still on the air for other listeners",
			Broadcast.now_playing().get("stream") == live.get("stream"))
	for radio: Node in sets:
		radio.queue_free()
	await get_tree().process_frame
