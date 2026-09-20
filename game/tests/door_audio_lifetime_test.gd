extends Node3D
## Real pooled door ownership, with another live source as a negative control.
var checks := 0
var failures := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	var a := DoorProp.new()
	a.name = "LifetimeDoorA"
	var b := DoorProp.new()
	b.name = "LifetimeDoorB"
	b.position.x = 2.0
	add_child(a)
	add_child(b)
	a.interact(null)
	b.interact(null)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var own := _observe(&"LifetimeDoorA")
	var other := _observe(&"LifetimeDoorB")
	_check(not own.is_empty() and not other.is_empty(), "both real door interactions own pooled voices")
	if own.is_empty() or other.is_empty():
		a.free()
		b.free()
		_finish()
		return
	var door_ref: WeakRef = weakref(a)
	a.free()
	a = null
	_check(door_ref.get_ref() == null, "door actor retires synchronously")
	_check(AudioPolicy.active_voice(&"LifetimeDoorA") == null,
			"retired door owns no active pooled cue")
	_check((own.voice as WeakRef).get_ref() == null,
			"retiring source releases its pooled emitter")
	_check(_same_voice(&"LifetimeDoorB", other.voice),
			"another live door keeps the exact pooled emitter")
	_check(_decoder_playing(other.decoder), "another live door keeps playing")
	await _decoder_retires(own.decoder, "retired mixed door decoder")
	# A play removed before its first physics mix needs the same ownership path.
	var c := DoorProp.new()
	c.name = "LifetimeDoorQueued"
	add_child(c)
	c.interact(null)
	var queued := _observe(&"LifetimeDoorQueued")
	_check(not queued.is_empty(), "queued real door interaction owns a decoder")
	c.free()
	c = null
	if not queued.is_empty():
		_check((queued.voice as WeakRef).get_ref() == null,
				"unmixed source releases its emitter synchronously")
		await _decoder_retires(queued.decoder, "retired unmixed door decoder")
	b.free()
	b = null
	_check(AudioPolicy.active_voice(&"LifetimeDoorB") == null,
			"second source retires independently")
	await _decoder_retires(other.decoder, "second retired door decoder")
	# Failure cleanup uses the public owner API only after assertions. This keeps
	# a red control from leaving test-owned global pool slots for engine shutdown.
	for identity: StringName in [&"LifetimeDoorA", &"LifetimeDoorB", &"LifetimeDoorQueued"]:
		AudioPolicy.release_source(identity)
	_finish()


func _observe(identity: StringName) -> Dictionary:
	var voice := AudioPolicy.active_voice(identity)
	if voice == null or not voice.has_stream_playback(): return {}
	return {"voice": weakref(voice), "decoder": weakref(voice.get_stream_playback())}


func _same_voice(identity: StringName, reference: WeakRef) -> bool:
	return AudioPolicy.active_voice(identity) == reference.get_ref()


func _decoder_playing(reference: WeakRef) -> bool:
	var decoder := reference.get_ref() as AudioStreamPlayback
	return decoder != null and decoder.is_playing()


func _decoder_retires(reference: WeakRef, label: String) -> void:
	var began := Time.get_ticks_msec()
	var frames := 0
	while reference.get_ref() != null and Time.get_ticks_msec() - began < 1000:
		await get_tree().process_frame
		frames += 1
	_check(reference.get_ref() == null, label + " releases after AudioServer cleanup")
	print("DOOR DECODER: %s frames=%d elapsed_ms=%d live=%s" %
			[label, frames, Time.get_ticks_msec() - began, reference.get_ref() != null])


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("DOOR AUDIO: %s %s" % ["PASS" if ok else "FAIL", label])


func _finish() -> void:
	print("DOOR AUDIO LIFETIME: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
