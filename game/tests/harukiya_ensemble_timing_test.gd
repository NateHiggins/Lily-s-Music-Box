extends Node
## Samples the shipped recording's sidecar through a linear take and shuffled retakes.
const Timing := preload("res://scripts/characters/harukiya_ensemble_timing.gd")
const Transport := preload("res://scripts/characters/harukiya_show_transport.gd")
var _failures := 0
var _ends := 0
var _movie_positions := PackedFloat64Array()


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		push_error("[ENSEMBLE] " + label)


func _ready() -> void:
	var transport := Transport.new()
	add_child(transport)
	if not transport.prepare():
		push_error("[ENSEMBLE] shipped recording or score refused")
		get_tree().quit(1)
		return
	var clock := Timing.new()
	clock.prepare(transport.score.voices)
	_check(not clock.lead_entries.is_empty() and not clock.harmony_entries.is_empty(), "both vocal parts have entrances")
	var lead := float(transport.score.voices.adela_voss[0].start)
	var harmony := float(transport.score.voices.lily[0].start)
	_check(clock.look_to_lead("stacy", lead) == 1.0 and clock.look_to_lead("lily", lead) == 0.0,
			"drummer looks to the lead on Adela's opening")
	_check(clock.look_to_lead("lily", harmony) == 1.0 and clock.look_to_lead("adela_voss", harmony) == 0.0,
			"bassist takes her harmony entrance from the lead")
	_check(clock.look_to_lead("stacy", lead - .46) == 0.0 and clock.look_to_lead("stacy", lead + .41) == 0.0,
			"anticipation and release stop outside the cue")
	_check(Timing.frame_seconds(24, 24, transport.score.duration) == 1.0
			and Timing.frame_seconds(30, 30, transport.score.duration) == 1.0
			and Timing.frame_seconds(-1, 24, transport.score.duration) == 0.0
			and Timing.frame_seconds(9000, 24, transport.score.duration) == transport.score.duration,
			"frame time respects rate, zero and song end")
	var first_frame := floori((harmony - 2.0) * 24.0)
	var take := PackedFloat64Array()
	for frame in range(first_frame, first_frame + 360):
		take.append(clock.look_to_lead("lily", Timing.frame_seconds(frame, 24, transport.score.duration)))
	var other := Timing.new()
	other.prepare(transport.score.voices)
	var identical := true
	for i in 360:
		# 137 is coprime to 360. Visit every frame in a different order.
		var cut := (i * 137) % 360
		var sample := Timing.frame_seconds(first_frame + cut, 24, transport.score.duration)
		if other.look_to_lead("lily", sample) != take[cut]:
			identical = false
	_check(identical and take.has(1.0) and take.has(0.0), "two 15-second takes agree through a real harmony cue")
	_check(is_equal_approx(Timing.audible_seconds(0.0, 1.0, .01, .06, 5.0), .95)
			and Timing.audible_seconds(.95, .96, .0, .06, 5.0) == .95
			and Timing.audible_seconds(0.0, .0, .001, .06, 5.0) == 0.0,
			"hearable position absorbs mix-boundary jitter and device latency")
	transport.ended.connect(_count_end)
	_check(transport.start() and not transport.start(), "one spatial playback starts")
	transport.stop()
	transport.stop()
	_check(_ends == 1 and transport.start(), "stop is idempotent and a new take can start")
	transport.stop()
	_check(_ends == 2, "the next take releases exactly once")
	if not Engine.get_write_movie_path().is_empty():
		# The project's MovieWriter runner sets this alongside --fixed-fps.
		# A manual --fixed-fps 24 run can use the default.
		var setting := OS.get_environment("ORISON_FILM_FPS")
		var fps := 24 if setting.is_empty() else setting.to_int()
		transport.played_at.connect(_sample_movie)
		_check(transport.start(), "ordinary transport starts a MovieWriter take")
		for _frame in 26:
			await get_tree().process_frame
		transport.stop()
		var aligned := fps > 0 and _movie_positions.size() >= 24
		for i in _movie_positions.size():
			if _movie_positions[i] != Timing.frame_seconds(i, fps, transport.score.duration):
				aligned = false
		_check(aligned, "MovieWriter emitted one score time per fixed output frame")
	print("[ENSEMBLE] ", "PASS" if _failures == 0 else "FAIL", " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _count_end() -> void:
	_ends += 1


func _sample_movie(at: float) -> void:
	_movie_positions.append(at)
