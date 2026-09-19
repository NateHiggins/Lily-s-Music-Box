extends Node
## Two actual props share a clip; each must retire only its own pooled voice.

var work_orders: WorkOrders
var checks := 0
var failures := 0

func _ready() -> void:
	RealityState.persistence_enabled = false
	work_orders = WorkOrders.new()
	add_child(work_orders)
	for cycle in range(2):
		await _cycle(cycle)
	work_orders.free()
	print("NIGHT REGISTER AUDIO LIFECYCLE: %s %d/%d" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(1 if failures else 0)

func _cycle(cycle: int) -> void:
	RealityState.reset_campaign_for_tests()
	work_orders.setup(null)
	work_orders.bind_job_library(MaintenanceJobLibrary.load_default())
	var first := _make_register("AstraRegisterFirst")
	var second := _make_register("AstraRegisterSecond")
	work_orders.issue_job("vantry_chirp_2a", "reported")
	var first_audio := _observe_voice(&"AstraRegisterFirst")
	var second_audio := _observe_voice(&"AstraRegisterSecond")
	_check(not first_audio.is_empty() and not second_audio.is_empty(),
			"cycle %d: real arriving reports start two owned voices" % cycle)
	if first_audio.is_empty() or second_audio.is_empty():
		first.free()
		second.free()
		AudioPolicy.release_source(&"AstraRegisterFirst")
		AudioPolicy.release_source(&"AstraRegisterSecond")
		return
	_check(first_audio.clip.get_ref() == second_audio.clip.get_ref(),
			"two registers share the recorded clip")
	var before := work_orders.job_state("vantry_chirp_2a").duplicate(true)
	first.free()
	_check(first_audio.player.stream == null,
			"retired register detaches its pooled stream")
	_check(second_audio.player.playing and second_audio.player.stream != null,
			"retiring one register leaves the other's playback running")
	await _settle()
	_check(first_audio.decoder.get_ref() == null,
			"retired register releases its decoder while shared clip stays live")
	second.free()
	_check(second_audio.player.stream == null,
			"last register detaches its pooled stream")
	await _settle()
	_check(second_audio.decoder.get_ref() == null and first_audio.clip.get_ref() == null,
			"last owner releases decoder and clip without global cache clearing")
	_check(work_orders.job_state("vantry_chirp_2a") == before,
			"teardown preserves authoritative work facts")
	# Recover the fixture after a red assertion so the next cycle remains
	# independent. The assertions above have already failed and stay failed.
	AudioPolicy.release_source(&"AstraRegisterFirst")
	AudioPolicy.release_source(&"AstraRegisterSecond")
	await _settle()

func _make_register(identity: String) -> NightRegisterProp:
	var register := NightRegisterProp.new()
	register.name = identity
	register.prop_type = "night_register"
	add_child(register)
	return register

func _observe_voice(identity: StringName) -> Dictionary:
	var voice := AudioPolicy.active_voice(identity, &"interaction.register_paper")
	if voice == null or voice.stream == null or not voice.has_stream_playback():
		return {}
	return {"player": voice, "clip": weakref(voice.stream),
			"decoder": weakref(voice.get_stream_playback())}

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout

func _check(ok: bool, label: String) -> void:
	checks += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1
