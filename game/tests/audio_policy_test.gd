extends Node

const PolicyScript := preload("res://scripts/audio/audio_policy.gd")
var checks := 0
var failures := 0


func _ready() -> void:
	var policy = PolicyScript.new()
	add_child(policy)
	var master_before := AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("Master"))
	_check("catalog and bus tree build", policy.setup())
	_check("catalog owns twenty semantic cues", int(policy.census().catalog_size) == 20)
	_check("voice allocation is bounded at sixteen",
			int(policy.census().voices) == PolicyScript.VOICE_CAP
			and policy.find_children("*", "AudioStreamPlayer3D", true, false).size()
			== PolicyScript.VOICE_CAP)
	for spec in PolicyScript.BUS_SPECS:
		var index := AudioServer.get_bus_index(str(spec[0]))
		_check("bus %s has canonical parent %s" % [spec[0], spec[1]],
				index >= 0 and AudioServer.get_bus_send(index) == str(spec[1]))
	var nav: Dictionary = policy.cue(&"nav.vantry_fault")
	_check("Vantry is navigation, unique and not a generic tick",
			str(nav.purpose) == "navigation" and str(nav.bus) == "Navigation"
			and str(nav.stream_key) == "vantry_chirp"
			and int(nav.max_instances) == 1
			and is_equal_approx(float(nav.max_distance), 16.0)
			and is_equal_approx(float(nav.unit_size), 4.0)
			and is_equal_approx(float(nav.volume_db), -14.0))
	var switch_on: Dictionary = policy.cue(&"interaction.switch_on")
	var switch_off: Dictionary = policy.cue(&"interaction.switch_off")
	_check("switch throw and return keep one material but report opposite state",
			str(switch_on.stream_key) == "tick"
			and switch_on.stream_key == switch_off.stream_key
			and float(switch_on.pitch_scale) > 1.0
			and float(switch_off.pitch_scale) < 1.0
			and str(switch_on.caption) != str(switch_off.caption))
	_check("ordinary doors distinguish motion, completion and refusal",
			str(policy.cue(&"interaction.door_move").stream_key) == "door_squeak"
			and str(policy.cue(&"interaction.door_latch").caption).contains("latch")
			and str(policy.cue(&"interaction.door_locked").caption).contains("locked"))
	_check("register paper, index, key and refusal have separate answers",
			str(policy.cue(&"interaction.register_paper").stream_key) == "pop"
			and str(policy.cue(&"interaction.register_index").stream_key) == "tick"
			and float(policy.cue(&"interaction.register_key").pitch_scale) > 1.0
			and float(policy.cue(&"interaction.register_refuse").pitch_scale) < 1.0)
	_check("telephone phases answer above ordinary interaction noise",
			int(policy.cue(&"telephone.asking").priority)
			> int(policy.cue(&"interaction.switch_on").priority)
			and str(policy.cue(&"telephone.asking").bus) == "Telephone"
			and str(policy.cue(&"telephone.answered").caption).contains("answers")
			and str(policy.cue(&"telephone.connected").caption).contains("trunk")
			and str(policy.cue(&"telephone.released").caption).contains("return"))
	_check("first source-owned Vantry fact presents",
			policy.present_3d(&"nav.vantry_fault", Vector3(1, 2, 3), 1.0,
					&"F02_A_VANTRY"))
	_check("same source cannot chatter inside its cooldown",
			not policy.present_3d(&"nav.vantry_fault", Vector3.ZERO, 1.0,
					&"F02_A_VANTRY"))
	_check("unknown semantic cue is refused without allocating",
			not policy.present_3d(&"not.a.cue", Vector3.ZERO))
	policy.advance_for_test(2.0)
	_check("cooldown expiry permits the source again",
			policy.present_3d(&"nav.vantry_fault", Vector3.ZERO, 0.5,
					&"F02_A_VANTRY"))
	_check("repair can silence only the exact source and cue",
			policy.stop_source(&"wrong_owner", &"nav.vantry_fault") == 0
			and policy.stop_source(&"F02_A_VANTRY", &"nav.vantry_fault") == 1
			and int(policy.census().active) == 0)
	_check("presentation cannot mutate catalog truth",
			policy.cue(&"nav.vantry_fault") == nav)
	var history: Array[Dictionary] = policy.event_history()
	_check("diagnostics retain presented and refused outcomes in order",
			history.size() == 5 and str(history[0].outcome) == "presented"
			and str(history[1].reason) == "cooldown"
			and str(history[2].reason) == "unknown_cue"
			and str(history[3].outcome) == "presented"
			and str(history[4].outcome) == "stopped")
	var world_setting_before := float(GameBoot.settings.world_volume)
	GameBoot.settings.world_volume = 0.5
	GameBoot.apply_audio_settings(false)
	var world_baseline := GameBoot.audio_bus_db("World")
	_check("dialogue and sleep can request mix independently",
			policy.request_mix(&"dialogue_owner", &"dialogue", 1.0)
			and policy.request_mix(&"sleep_owner", &"sleep_onset", 0.5))
	var mixed: Dictionary = policy.mix_snapshot()
	_check("mix stack adds its deepest duck to the user's World baseline",
			is_equal_approx(float(mixed.buses.World), world_baseline - 5.0)
			and int(policy.census().mix_requests) == 2)
	_check("releasing one owner preserves the other request",
			policy.release_mix(&"dialogue_owner")
			and is_equal_approx(float(policy.mix_snapshot().buses.World),
					world_baseline - 2.0)
			and int(policy.census().mix_requests) == 1)
	_check("last release restores canonical zero without touching Master",
			policy.release_mix(&"sleep_owner")
			and is_equal_approx(float(policy.mix_snapshot().buses.World),
					world_baseline)
			and is_equal_approx(AudioServer.get_bus_volume_db(
					AudioServer.get_bus_index("Master")), master_before))
	GameBoot.settings.world_volume = world_setting_before
	GameBoot.apply_audio_settings(false)
	policy.clear_diagnostics()
	_check("diagnostic reset changes no catalog or mix truth",
			int(policy.census().history) == 0
			and int(policy.census().catalog_size) == 20
			and int(policy.census().mix_requests) == 0)
	_finish(policy)


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[AUDIO POLICY] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _finish(policy: Node) -> void:
	var result: Dictionary = policy.census()
	print("[AUDIO POLICY] CENSUS %s" % JSON.stringify(result))
	print("[AUDIO POLICY] RESULT: %s %d/%d" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	PropAudio.clear_cache()
	policy.queue_free()
	get_tree().quit(0 if failures == 0 else 1)
