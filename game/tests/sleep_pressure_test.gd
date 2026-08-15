extends Node
## N5: deterministic policy, safety and real-file mid-onset restore proof.

const SAVE_FILE := "user://tests/n5_sleep_pressure_save.json"
const CASE := "mina_caption_crisis"
const PROFILE := "mina_release_print"
const SEED := "f123456789abcdef"

var failures := 0
var checks := 0
var onset_starts := 0
var entry_requests := 0
var shell: CampaignShell
var waking: DreamBoundaryWakingStub
var _player_save_present := false
var _old_always_warn := false
var _finished := false


func _ready() -> void:
	print("[N5] START")
	_watchdog()
	_player_save_present = FileAccess.file_exists(RealityState.SAVE_PATH)
	_old_always_warn = bool(GameBoot.settings.get(
			"always_warn_before_sleep", false))
	GameBoot.settings.always_warn_before_sleep = false
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("user://tests"))
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))
	RealityState.save_path = SAVE_FILE
	RealityState.persistence_enabled = true
	RealityState.reset_campaign_for_tests()
	RealityState.data.dream_seed = SEED

	await _spawn_shell()
	var pressure := shell.sleep_pressure
	_check("seed choice can select a permitted sudden profile deterministically",
			pressure.choose_onset_form(["gradual", "sudden"],
					"0000000000000001", false) == "sudden")
	_check("Always warn overrides that same seeded choice without progression",
			pressure.choose_onset_form(["gradual", "sudden"],
					"0000000000000001", true) == "gradual")
	_check("Always warn rejects a future profile that cannot warn",
			pressure.choose_onset_form(["sudden"],
					"0000000000000001", true).is_empty())

	pressure.onset_started.connect(func(_case_id: String, _form: String,
			_duration: float) -> void: onset_starts += 1)
	pressure.sleep_entry_requested.connect(func(_case_id: String,
			_form: String) -> void: entry_requests += 1)
	shell.core_loop.dream_requested.emit(CASE, PROFILE, {
		"eligible_after_stage": "repaired",
		"protected_contexts": ["call", "conversation"],
	})
	_check("Mina arms one gradual 2.6-second onset from authored data",
			shell.dream_director.phase() == "armed"
			and pressure.onset_form() == "gradual"
			and is_zero_approx(pressure.pressure()))

	waking.player.call_locked = true
	pressure.advance_for_test(8.0)
	_check("the authoritative engaged flag pauses rather than cancels",
			pressure.blocked_reason() == "engaged"
			and is_zero_approx(pressure.pressure())
			and shell.dream_director.phase() == "armed")
	waking.player.call_locked = false
	waking.player.stable_floor = false
	pressure.advance_for_test(8.0)
	_check("an unresolved physics fall remains armed at zero pressure",
			pressure.blocked_reason() == "unstable_body"
			and is_zero_approx(pressure.pressure()))
	waking.player.stable_floor = true
	waking.elevator_gate.blocked = true
	pressure.advance_for_test(8.0)
	_check("the elevator car and threshold gate entry",
			pressure.blocked_reason() == "elevator_seam"
			and is_zero_approx(pressure.pressure()))
	waking.elevator_gate.blocked = false
	waking.traffic_gate.blocked = true
	pressure.advance_for_test(8.0)
	_check("the permanent traffic stream gates even a momentary road gap",
			pressure.blocked_reason() == "traffic"
			and is_zero_approx(pressure.pressure()))
	waking.traffic_gate.blocked = false
	pressure.advance_for_test(1.3)
	_check("stable release begins once and reaches the exact midpoint",
			onset_starts == 1 and pressure.blocked_reason().is_empty()
			and is_equal_approx(pressure.pressure(), 0.5))
	_check("visual, mix and service-set presentation share that pressure",
			is_equal_approx(pressure.presentation_progress(), 0.5)
			and is_equal_approx(waking.player.onset_progress, 0.5)
			and is_equal_approx(pressure.mix_cutoff_hz(), 12050.0)
			and pressure.room0_hum_is_playing())
	_check("the mid-onset checkpoint writes the real file",
			RealityState.save_game() and _saved_pressure_is(1.3, "armed"))

	_destroy_shell()
	RealityState.reset_campaign_for_tests()
	_check("destroying the live campaign removes the onset facts",
			RealityState.data.sleep_pressure.is_empty()
			and RealityState.data.dream.is_empty())
	RealityState.load_game()
	await _spawn_shell()
	pressure = shell.sleep_pressure
	pressure.onset_started.connect(func(_case_id: String, _form: String,
			_duration: float) -> void: onset_starts += 1)
	pressure.sleep_entry_requested.connect(func(_case_id: String,
			_form: String) -> void: entry_requests += 1)
	_check("real-file restore resumes the same request and exact midpoint",
			shell.dream_director.phase() == "armed"
			and pressure.onset_form() == "gradual"
			and is_equal_approx(pressure.pressure(), 0.5)
			and str(shell.dream_director.dream_state().seed_hex) == SEED)
	_check("restore reconstructs warning presentation without re-announcing it",
			onset_starts == 1
			and is_equal_approx(pressure.presentation_progress(), 0.5)
			and is_equal_approx(waking.player.onset_progress, 0.5))
	pressure.advance_for_test(1.3)
	_check("the completed warning commits entered before deferred replacement",
			shell.dream_director.phase() == "entered"
			and shell.world_kind() == "waking"
			and entry_requests == 1)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("safe onset enters once with the dream as the only world",
			shell.dream_director.phase() == "active"
			and shell.world_kind() == "dream"
			and shell.world_child_count() == 1)
	pressure.advance_for_test(8.0)
	_check("further clock input cannot duplicate an active entry",
			entry_requests == 1 and shell.dream_director.phase() == "active")

	_cleanup()
	_finished = true
	print("SLEEP PRESSURE TEST: %s (%d checks)" % [
			"PASS" if failures == 0 else "FAIL %d" % failures, checks])
	get_tree().quit(failures)


func _watchdog() -> void:
	await get_tree().create_timer(24.0, true, false, true).timeout
	if not _finished:
		printerr("[N5] WATCHDOG: run exceeded 24 seconds — FAIL")
		get_tree().quit(1)


func _spawn_shell() -> void:
	shell = CampaignShell.new()
	shell.name = "SleepPressureShellUnderTest"
	shell.waking_scene_path = "res://tests/DreamBoundaryWakingStub.tscn"
	shell.dream_scene_path = "res://scenes/dream/DreamMazeRoot.tscn"
	shell.sleep_manual_clock = true
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	waking = shell.active_world as DreamBoundaryWakingStub
	_check("the deterministic fixture starts as one waking world",
			waking != null and shell.world_kind() == "waking"
			and shell.world_child_count() == 1)


func _destroy_shell() -> void:
	if shell != null and is_instance_valid(shell):
		remove_child(shell)
		shell.free()
	shell = null
	waking = null


func _saved_pressure_is(elapsed: float, dream_phase: String) -> bool:
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(SAVE_FILE))
	if parsed is not Dictionary:
		return false
	var book := parsed as Dictionary
	return str(book.get("dream", {}).get("phase", "")) == dream_phase \
			and is_equal_approx(float(book.get("sleep_pressure", {}).get(
					"elapsed_s", -1.0)), elapsed)


func _cleanup() -> void:
	_destroy_shell()
	var resolved := ProjectSettings.globalize_path(SAVE_FILE)
	var test_dir := ProjectSettings.globalize_path("user://tests")
	if resolved.begins_with(test_dir) \
			and resolved.ends_with("n5_sleep_pressure_save.json"):
		DirAccess.remove_absolute(resolved)
	RealityState.save_path = RealityState.SAVE_PATH
	GameBoot.settings.always_warn_before_sleep = _old_always_warn
	_check("the contained save is removed and player save untouched",
			not FileAccess.file_exists(SAVE_FILE)
			and FileAccess.file_exists(RealityState.SAVE_PATH)
					== _player_save_present)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [sleep pressure ok] ", label)
	else:
		failures += 1
		printerr("  [SLEEP PRESSURE FAIL] ", label)
