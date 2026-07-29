extends Node
## Headless smoke driver — not part of the game. Run with:
##   godot --headless res://tests/AutoTest.tscn
## Plays the full sequence in real time (isolate -> capture -> route ->
## complete -> restart), asserting state after each step. Exits with the
## number of failed checks as the process exit code.

var main: Node
var _failures := 0


func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	_run()


func _run() -> void:
	var ok: bool = await _wait_until(func(): return not main._isolate_btn.disabled, 30.0)
	_check(ok, "isolate tool unlocks after intro dialogue")

	main._isolate_btn.button_pressed = true
	_check(GameState.is_noise_isolated, "isolation state set")
	_check(GameState.call_stage == GameState.Stage.ISOLATION, "stage -> ISOLATION")

	ok = await _wait_until(func(): return not main._capture_btn.disabled, 30.0)
	_check(ok, "capture unlocks after hearing the motif")

	main._on_capture_pressed()
	_check(GameState.motif_captured, "motif captured")
	_check(GameState.call_stage == GameState.Stage.CAPTURE, "stage -> CAPTURE")
	main._on_capture_pressed()  # repeated press must not break anything
	_check(GameState.motif_captured, "repeated capture press is safe")

	main._route_btns[GameState.ROUTE_HEADSET].button_pressed = true
	_check(GameState.current_route == GameState.ROUTE_HEADSET, "headset route set")
	_check(GameState.caller_infection_level > 0.0, "headset raises caller infection")
	_check(GameState.call_stage == GameState.Stage.CAPTURE, "headset alone does not start transmission")

	main._route_btns[GameState.ROUTE_SPEAKERS].button_pressed = true
	_check(GameState.current_route == GameState.ROUTE_SPEAKERS, "route switched while playing")

	ok = await _wait_until(func(): return GameState.call_stage == GameState.Stage.RESPONSE, 40.0)
	_check(ok, "transmission reaches RESPONSE stage")
	_check(GameState.radiator_infected, "radiator infected")
	_check(GameState.computer_infected, "computer infected")
	_check(main.radiator_r.playing, "radiator renderer looping")
	_check(GameState.room_infection_level > 0.2, "room infection ramped")

	main._do_outcome(GameState.Response.COMPLETE)
	_check(GameState.outcome_triggered, "outcome latched")
	_check(GameState.player_response == GameState.Response.COMPLETE, "response recorded")
	_check(not GameState.try_commit_outcome(GameState.Response.INTERRUPT),
			"second outcome rejected by latch")

	ok = await _wait_until(func(): return main._corporate.visible, 30.0)
	_check(ok, "corporate resolution screen appears")

	# Restart mid-audio must produce a clean run without reloading anything.
	main.start_run()
	await get_tree().create_timer(1.0).timeout
	_check(GameState.call_stage == GameState.Stage.ORDINARY_CALL, "restart resets stage")
	_check(not GameState.outcome_triggered, "restart clears outcome latch")
	_check(not GameState.motif_captured, "restart clears capture")
	_check(main.breath_r.playing, "breathing loop restarted")

	print("AUTOTEST RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d checks)" % _failures))
	get_tree().quit(_failures)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  [ok] %s" % label)
	else:
		_failures += 1
		printerr("  [FAIL] %s" % label)


func _wait_until(cond: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if cond.call():
			return true
		await get_tree().create_timer(0.25).timeout
		elapsed += 0.25
	return cond.call()
