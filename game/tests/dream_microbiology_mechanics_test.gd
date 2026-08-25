extends Node
## MBIO-2: physical packets travel; organs decide what they can feel.

const Mechanics := preload("res://scripts/dream/dream_microbiology_mechanics.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	var director := DreamEcologyDirector.new()
	add_child(director)
	director.setup(711)
	director.emit_mechanical_packet(7, Vector3.ZERO, 3.0, 0.8,
			DreamEcologyDirector.Carrier.IMPULSE, Vector3.RIGHT, 2.0,
			DreamEcologyDirector.Substrate.FLOOR, 2.0)
	var packets: Array = []
	director.signals_near(Vector3(1.0, 0.0, 0.0), 0.0, packets)
	_check("a mechanical packet does not arrive instantaneously", packets.is_empty())
	director._process(0.40)
	director.signals_near(Vector3(1.0, 0.0, 0.0), 0.0, packets)
	_check("the receiver is still ahead of the wavefront", packets.is_empty())
	director._process(0.11)
	director.signals_near(Vector3(1.0, 0.0, 0.0), 0.0, packets)
	_check("the packet arrives after distance divided by speed", packets.size() == 1)
	_check("carrier and direction survive the signal bed",
			int(packets[0].carrier) == DreamEcologyDirector.Carrier.IMPULSE
			and (packets[0].direction as Vector3).dot(Vector3.RIGHT) > 0.99)

	var cilia := Mechanics.state()
	_check("floor cilia accept a floor impulse", Mechanics.accept(cilia,
			packets[0], Mechanics.IMPULSE | Mechanics.SCRAPE | Mechanics.HUM,
			DreamEcologyDirector.Substrate.FLOOR))
	_check("acceptance records one event and its strength",
			int(cilia.received) == 1 and is_equal_approx(float(cilia.response), 0.8))
	_check("the same wave cannot fire the receptor twice",
			not Mechanics.accept(cilia, packets[0], Mechanics.IMPULSE,
			DreamEcologyDirector.Substrate.FLOOR) and int(cilia.received) == 1)
	var suppressed: Dictionary = packets[0].duplicate()
	suppressed.src_id = 77
	suppressed.born = float(packets[0].born) + 0.01
	_check("a novel wave arriving during refractory is suppressed",
			not Mechanics.accept(cilia, suppressed, Mechanics.IMPULSE,
			DreamEcologyDirector.Substrate.FLOOR))
	Mechanics.advance(cilia, 0.30)
	_check("a suppressed impulse is not queued until recovery",
			not Mechanics.accept(cilia, suppressed, Mechanics.IMPULSE,
			DreamEcologyDirector.Substrate.FLOOR) and int(cilia.received) == 1)

	var wall := Mechanics.state()
	_check("wall tissue rejects the same floor packet",
			not Mechanics.accept(wall, packets[0], Mechanics.IMPULSE,
			DreamEcologyDirector.Substrate.WALL))
	var selective := Mechanics.state()
	_check("a scrape-only receptor ignores an impulse",
			not Mechanics.accept(selective, packets[0], Mechanics.SCRAPE,
			DreamEcologyDirector.Substrate.FLOOR))

	director.emit_mechanical_packet(8, Vector3.ZERO, 1.0, 0.5,
			DreamEcologyDirector.Carrier.HUM, Vector3.ZERO, 1.0,
			DreamEcologyDirector.Substrate.FLOOR, 4.0)
	director._process(0.01)
	director.signals_near(Vector3.ZERO, 0.0, packets)
	var hum: Dictionary = packets[packets.size() - 1]
	_check("recovered broad-band cilia accept a later hum",
			Mechanics.accept(cilia, hum, Mechanics.HUM,
			DreamEcologyDirector.Substrate.FLOOR) and int(cilia.received) == 2)

	var attention_before := director.attending
	director.on_mechanical_stimulus(Vector3.ZERO, &"scrape", 0.6,
			Vector3.FORWARD, 0.5, &"wall")
	_check("the player-facing seam publishes mechanical chemistry",
			int(director.signal_census().by_function.get("pulse", 0)) == 3)
	_check("ordinary physical disturbance never seizes global attention",
			director.attending == attention_before)

	var eviction := DreamEcologyDirector.new()
	add_child(eviction)
	eviction.setup(712)
	for i in 40:
		eviction.emit_mechanical_packet(i, Vector3.ZERO, 2.0, 1.0,
				DreamEcologyDirector.Carrier.IMPULSE, Vector3.ZERO, 99.0,
				DreamEcologyDirector.Substrate.FLOOR, 2.0)
	var census := eviction.signal_census()
	_check("the existing fixed bed still caps mechanical packets",
			int(census.live) == 32 and int(census.evicted) == 8)
	var live_ids: Array[int] = []
	for packet in eviction._signal_ring:
		if bool(packet.live):
			live_ids.append(int(packet.src_id))
	live_ids.sort()
	_check("overflow evicts the oldest packets deterministically",
			live_ids.front() == 8 and live_ids.back() == 39)
	_finish()


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("[PASS] ", label)
	else:
		failures += 1
		push_error("[FAIL] " + label)


func _finish() -> void:
	print("\nDreamMicrobiologyMechanicsTest: %d/%d passed" % [
			checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
