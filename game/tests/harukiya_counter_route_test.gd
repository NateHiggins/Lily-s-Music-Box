extends "res://tests/carried_case_route_test.gd"
## The Harukiya counter in the production V2 root with real input: a click grabs the
## empty glass, mouse motion slides it across the top toward the back bar, and on a
## night the staff clock has Stacy on shift her conversation opens; on her night off
## nobody comes. Released, the glass slides back to the customer's side.

const Glass := preload("res://scripts/props/harukiya_counter_glass.gd")
const Cast := preload("res://scripts/characters/harukiya_cast.gd")
const CastModel := preload("res://scripts/characters/cast_model_presentation.gd")
const THURSDAY := [1928, 11, 15]
const MONDAY := [1928, 11, 12]
const EIGHT_PM := 1200
var _cast_started_ms := 0
var _cast_initial_inputs: Dictionary = {}

func _init() -> void:
	route_label = "HARUKIYA COUNTER ROUTE"

func _click() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	await get_tree().physics_frame

func _aim(part: Node3D) -> Dictionary:
	var at: Vector3 = part.global_position + Vector3.UP * 0.05
	player.camera.look_at(at)
	await get_tree().physics_frame
	player.camera.look_at(at)
	return player._grab.find_target()

## Slides toward the goal and returns the farthest the glass got: once Stacy takes it the
## hand lets go and it starts back, so the reach is measured while it is pushed.
func _push(grip: Dictionary, goal: float) -> Dictionary:
	var reach := 0.0
	var home: Vector3 = grip.part.global_position
	var distance := 0.0
	for _step in 200:
		reach = maxf(reach, float(grip.read.call()))
		distance = maxf(distance, grip.part.global_position.distance_to(home))
		if reach >= goal or not player._grab.active():
			return {"reach": reach, "distance": distance}
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(0, -6)
		player._unhandled_input(motion)
		reach = maxf(reach, float(grip.read.call()))
		distance = maxf(distance, grip.part.global_position.distance_to(home))
		await get_tree().physics_frame
	return {"reach": reach, "distance": distance}

func _slide_across(counter: Node3D) -> Dictionary:
	var grip: Dictionary = await _aim(counter.glass)
	_require(grip.get("owner") == counter and grip.get("part") == counter.glass,
			"the player's ray reaches the glass: %s" % str(grip.get("part")))
	if grip.is_empty():
		return grip
	await _click()
	_require(player._grab.active() and is_zero_approx(float(grip.read.call())), "a click grabs without sliding")
	var pushed: Dictionary = await _push(grip, Glass.SLIDE * Glass.ACROSS_AT)
	_require(float(pushed.reach) >= Glass.SLIDE * Glass.ACROSS_AT, "motion slides it across: %f" % float(pushed.reach))
	# Read the actual part while pushing: Stacy's synchronous arrival releases
	# it, and the return animation can advance before this coroutine resumes.
	_require(float(pushed.distance) > Glass.SLIDE * 0.8, "the glass has crossed the top: %f" % float(pushed.distance))
	return grip

func _route() -> void:
	_cast_started_ms = Time.get_ticks_msec()
	_cast_initial_inputs = _cast_input_snapshot()
	var clock := CampaignClock.new()
	clock.configure_date(THURSDAY[0], THURSDAY[1], THURSDAY[2], EIGHT_PM)
	world.resident_agenda.enabled = false
	var counter: Node3D = world.harukiya_counter
	if not _require(counter != null and counter.glass != null, "the Harukiya has a counter glass"): return
	_require(str(world.resident_whereabouts("stacy").get("place", "")) == "harukiya_bar",
			"the staff clock has Stacy behind the bar on Thursday night")
	player.global_position = counter.glass.global_position + Vector3(0.0, -1.08, 1.25)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.camera.look_at(counter.glass.global_position)
	await get_tree().create_timer(0.3).timeout
	var cast := counter.get("cast") as Cast
	if not _require(cast != null and cast.ready_ok, "actual two-person cast is ready beside the authoritative counter"): return
	_require(cast.actors.size() == 2 and cast.actors.has("lily") and cast.actors.has("stacy"), "only Lily and Stacy are presented")
	_require(cast.get_parent().find_children("HarukiyaCast", "Node3D", false, false).size() == 1,
			"the bar has one cast manager")
	_require(cast.find_children("Harukiya_*", "Node3D", false, false).size() == 2,
			"each person has exactly one actor")
	for actor: CastModel in cast.actors.values():
		_require(actor.ready_ok and actor.is_visible_in_tree(), actor.person_id + " appears during the staff attendance window")
	await _capture_interaction("harukiya_counter")
	await _capture_cast_views(cast)

	var started: Array = []
	world.conversations.conversation_started.connect(func(resident: String, _entry: String): started.append(resident))
	var home: Vector3 = counter.glass.global_position
	await _slide_across(counter)
	await get_tree().create_timer(0.3).timeout
	_require(started == ["stacy"], "Stacy comes over and talks: %s" % str(started))
	_require(world.conversations.dialogue.attention_active(), "her conversation is open")
	var displayed: Dictionary = world.conversations.dialogue.displayed_line()
	_require(str(displayed.get("speaker", "")).strip_edges().to_lower() == "stacy"
			and not str(displayed.get("text", "")).strip_edges().is_empty(),
			"the actual dialogue panel displays Stacy's authored line")
	_require(cast.actors["stacy"].face.is_speaking() and not cast.actors["lily"].face.is_speaking(),
			"only the displayed speaker receives face speech")
	_require(not player._grab.active(), "she takes the glass: the hand has let go")
	await _capture_interaction("harukiya_counter_stacy")
	world.conversations.dialogue.close()
	await get_tree().create_timer(1.0).timeout
	_require(not cast.actors["stacy"].face.is_speaking(), "closing the existing dialogue interrupts Stacy's face speech")
	_require(counter.glass.global_position.distance_to(home) < 0.02, "released, it slides back to the customer's side")

	# Monday is her night off: the glass crosses, nobody comes.
	clock.configure_date(MONDAY[0], MONDAY[1], MONDAY[2], EIGHT_PM)
	_require(str(world.resident_whereabouts("stacy").get("place", "")) != "harukiya_bar", "Monday night she isn't on")
	await get_tree().create_timer(0.3).timeout
	for actor: CastModel in cast.actors.values():
		_require(not actor.visible and not actor.is_processing() and not actor.face.is_processing()
				and not actor.attention.pipeline.active and not actor.face.is_speaking(),
				actor.person_id + " disappears and suspends presentation on the existing night off")
	started.clear()
	await _slide_across(counter)
	await get_tree().create_timer(0.3).timeout
	_require(started.is_empty(), "nobody answers on her night off: %s" % str(started))
	_require(counter.notice.text == Glass.NOBODY, "the counter says so: %s" % counter.notice.text)
	await _click()
	_require(not player._grab.active(), "the next click lets go")
	await get_tree().create_timer(4.0).timeout
	_require(counter.notice.text == "", "the line clears")
	clock.configure_date(THURSDAY[0], THURSDAY[1], THURSDAY[2], EIGHT_PM)
	await get_tree().create_timer(0.3).timeout
	for actor: CastModel in cast.actors.values():
		_require(actor.ready_ok and actor.is_visible_in_tree() and not actor.face.is_speaking(),
				actor.person_id + " returns with attendance without resuming interrupted speech")
	_write_cast_contract()


func _capture_cast_views(cast: Cast) -> void:
	if OS.get_environment("SHOT_DIR").is_empty() or DisplayServer.get_name() == "headless": return
	# Diagnostic framing only; the real counter input below resumes unchanged.
	var camera_transform := player.camera.global_transform
	var was_physics := player.is_physics_processing()
	player.set_physics_process(false)
	var middle: Vector3 = (cast.actors["lily"].global_position + cast.actors["stacy"].global_position) * 0.5 + Vector3.UP * 1.30
	player.camera.global_position = middle - world.harukiya_counter.across() * 3.2 + Vector3.UP * 0.1
	player.camera.look_at(middle)
	await get_tree().process_frame
	await _capture_interaction("cast_pair_diagnostic")
	for id: String in ["lily", "stacy"]:
		var target: Vector3 = cast.actors[id].global_position + Vector3.UP * 1.48
		player.camera.global_position = target - world.harukiya_counter.across() * 1.25 + Vector3.RIGHT * 0.4
		player.camera.look_at(target)
		await get_tree().process_frame
		await _capture_interaction("cast_" + id + "_diagnostic")
	player.camera.global_transform = camera_transform
	player.set_physics_process(was_physics)
	await get_tree().physics_frame


func _cast_test_dependencies() -> Dictionary:
	var pending: Array[String] = [get_script().resource_path, scene_file_path]
	var result := {}
	var references := RegEx.new()
	references.compile("res://tests/[A-Za-z0-9_/.-]+\\.[A-Za-z0-9]+(?=[\"'])")
	while not pending.is_empty():
		var path: String = pending.pop_back()
		var key := "game/" + path.trim_prefix("res://")
		if result.has(key): continue
		if not _require(path.begins_with("res://tests/") and FileAccess.file_exists(path), "test dependency exists: " + path):
			continue
		var text := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
		result[key] = text.sha256_text()
		for match: RegExMatch in references.search_all(text):
			if not result.has("game/" + match.get_string().trim_prefix("res://")):
				pending.append(match.get_string())
	return result


func _cast_input_snapshot() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var runtime: Array = []
	var physical: Array = []
	_require(OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], runtime) == 0, "bind production runtime inputs")
	_require(OS.execute("python", [root.path_join("tools/v2_physical_inputs.py"), "--root", root], physical) == 0, "bind physical inputs")
	return {"runtime": str(runtime[0]).strip_edges() if not runtime.is_empty() else "",
		"physical": str(physical[0]).strip_edges() if not physical.is_empty() else "",
		"dependencies": _cast_test_dependencies(),
		"test": FileAccess.get_sha256(get_script().resource_path),
		"scene": FileAccess.get_sha256(scene_file_path)}


func _write_cast_contract() -> void:
	var inputs := _cast_input_snapshot()
	_require(inputs == _cast_initial_inputs, "production and transitive test inputs stay frozen throughout the route")
	_require(str(inputs.runtime).length() == 64 and str(inputs.physical).length() == 64, "input provenance digests are complete")
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array = []
	_require(OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head) == 0 and not head.is_empty(), "record repository provenance")
	var directory := OS.get_environment("SHOT_DIR")
	if not _require(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK, "explicit runtime contract destination"):
		return
	var file := FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE)
	if not _require(file != null, "runtime contract output opens"): return
	var passed := failures.is_empty()
	var status := "PASS" if passed else "FAIL"
	var source: String = get_script().resource_path
	var receipt := {"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2", "production_runtime": true,
		"scope": "Actual Harukiya counter grab/motion/release, authored Stacy conversation and displayed-speaker face binding, Monday absence and attendance return. Initial player placement is declared. No save/reconstruction, teardown, audio, whole-world surface or artistic acceptance claim.",
		"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - _cast_started_ms) / 1000.0},
		"source": {"test_path": "game/" + source.trim_prefix("res://"), "test_sha256": inputs.test,
			"test_scene_path": "game/" + scene_file_path.trim_prefix("res://"), "test_scene_sha256": inputs.scene,
			"test_dependencies": inputs.dependencies, "repository_head": str(head[0]).strip_edges() if not head.is_empty() else "",
			"runtime_inputs_sha256": inputs.runtime, "physical_inputs_sha256": inputs.physical},
		"contracts": {"harukiya_counter_interaction": {"executed": true, "status": status},
			"cast_attendance_and_dialogue": {"executed": true, "status": status}},
		"checks": interaction_checks.duplicate(true), "failures": failures.duplicate(),
		"viewport": {"width": get_viewport().get_visible_rect().size.x, "height": get_viewport().get_visible_rect().size.y}}
	file.store_string(JSON.stringify(receipt, "\t"))
	file.flush()
	_require(file.get_error() == OK, "runtime contract flushed")
	print("HARUKIYA CAST CONTRACT: ", status, "; ", interaction_checks.size(), " checks")
