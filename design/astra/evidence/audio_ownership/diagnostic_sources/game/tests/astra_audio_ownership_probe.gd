extends Node
## Diagnostic controls: real audio owners, weak references, no fixture-owned clips.

var failures := 0
var observations: Array[Dictionary] = []

func _ready() -> void:
	RealityState.persistence_enabled = false
	var scenario := OS.get_environment("ASTRA_AUDIO_CASE")
	var manual_cleanup := OS.get_environment("ASTRA_AUDIO_MANUAL_CLEANUP") == "1"
	for cycle in range(2):
		await _cycle(scenario, manual_cleanup, cycle)
	print("ASTRA_AUDIO_OBSERVATIONS " + JSON.stringify(observations))
	print("ASTRA AUDIO OWNERSHIP: %s retained=%d" % [
			"PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)

func _cycle(scenario: String, manual_cleanup: bool, cycle: int) -> void:
	var watched: Dictionary = {}
	var device: ServiceSetProp
	var register: WatchRegisterProp
	if scenario in ["service_idle", "shared", "printing", "printing_early"]:
		device = ServiceSetProp.new()
		add_child(device)
		watched.device = weakref(device)
		watched.tick_player = weakref(device._printer_tick)
		watched.feed_player = weakref(device._printer_feed)
		watched.tick_stream = weakref(device._printer_tick.stream)
		watched.pop_stream = weakref(device._printer_feed.stream)
	if scenario in ["register", "shared"]:
		register = WatchRegisterProp.new()
		add_child(register)
		watched.register = weakref(register)
		watched.pop_stream = weakref(register._click.stream)
		if register.receive_signal({"station_number": 9}) or not register._click.playing:
			push_error("Diagnostic refusal did not start the real register sound")
			failures += 1
		if register._click.has_stream_playback():
			watched.register_playback = weakref(register._click.get_stream_playback())
	if scenario in ["printing", "printing_early"]:
		if not device.print_telegram_card("AUDIO OWNER INTERRUPTION"):
			push_error("Diagnostic printing was refused")
			failures += 1
		if scenario == "printing":
			var deadline := Time.get_ticks_msec() + 1000
			while not device._printer_feed.playing and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
			if not device._printer_feed.playing:
				push_error("Diagnostic never observed the real feed playback")
				failures += 1
			elif device._printer_feed.has_stream_playback():
				watched.feed_playback = weakref(device._printer_feed.get_stream_playback())
	if scenario == "cache":
		watched.pop_stream = weakref(PropAudio.get_stream("pop"))
	if register != null:
		remove_child(register)
		register.free()
	if device != null:
		if manual_cleanup:
			_detach_device_audio(device)
		remove_child(device)
		device.free()
	# Diagnostic process boundary only: separate intentional cache residency
	# from retired owner/decoder residency. Production owners never flush it.
	PropAudio.clear_cache()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	var retained: Array[String] = []
	for label: String in watched:
		if watched[label].get_ref() != null:
			retained.append(label)
	failures += retained.size()
	observations.append({"case": scenario, "cycle": cycle,
			"manual_cleanup": manual_cleanup, "retained": retained,
			"watched": watched.keys()})

func _detach_device_audio(device: ServiceSetProp) -> void:
	if device._receipt_tween != null:
		device._receipt_tween.kill()
		device._receipt_tween = null
	for entry: Array in [[device._printer_tick, "tick"], [device._printer_feed, "pop"]]:
		var player: AudioStreamPlayer = entry[0]
		var stream := player.stream
		player.stop()
		player.stream = null
		PropAudio.release_stream(entry[1], stream)
