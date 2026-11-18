extends Node
## Panel-only diagnostic. The real panels and rules receive ordinary viewport
## input. Minimal nodes supply only the panels' declared lock/close interfaces.
const DartsSource := preload("res://scripts/ui/darts_panel.gd")
const PoolSource := preload("res://scripts/ui/point_ball_panel.gd")
const LIMIT_SECONDS := 19.0
const POOL_SECONDS := 12.0
const CASE_ROOT := "C:/ov/reports/harukiya_overhaul_20261112/occupied_service_gap_01/panel_probe/"
const SOURCE_PATHS := ["res://scripts/ui/darts_panel.gd", "res://scripts/ui/point_ball_panel.gd",
	"res://scripts/minigames/trivia_darts.gd", "res://scripts/minigames/darts_game.gd",
	"res://scripts/minigames/point_ball.gd", "res://scripts/minigames/point_ball_ai.gd",
	"res://data/trivia_darts.json"]

class LockTarget extends Node:
	var call_locked := false

class CloseTarget extends Node:
	var closed_calls := 0
	func panel_closed() -> void:
		closed_calls += 1

var player: LockTarget
var prop: CloseTarget
var active_panel: Node
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var outcomes: Dictionary = {}
var contracts := {"darts_viewport_scored_input": {"executed": false, "status": "NOT_RUN"},
	"pool_viewport_scored_input": {"executed": false, "status": "NOT_RUN"}}
var initial_sources: Dictionary = {}
var directory := ""
var started := 0
var preview_owned := false
var prior_data: Dictionary
var prior_hash := ""
var prior_mouse := Input.MOUSE_MODE_VISIBLE
var prior_mode := 0
var prior_frozen := false
var prior_scene: Node
var mouse_held := false
var pointer := Vector2.ZERO
var last_gui: Dictionary = {}

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "ok": ok})
	if not ok:
		failures.append(label)
		print("HARUKIYA PANEL INPUT FAIL: ", label)
	return ok

func _run() -> void:
	started = Time.get_ticks_msec()
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK:
		get_tree().quit(2); return
	if FileAccess.file_exists(directory.path_join("runtime_contract.json")):
		push_error("Panel probe refuses an existing receipt destination"); get_tree().quit(2); return
	prior_data = RealityState.data
	prior_hash = JSON.stringify(prior_data).sha256_text()
	prior_mouse = Input.mouse_mode
	prior_mode = GameBoot.launch_mode
	prior_frozen = CampaignTime._frozen_for_tests
	prior_scene = get_tree().current_scene
	initial_sources = _sources()
	var profile := OS.get_environment("PANEL_PROBE_ISOLATED_APPDATA").replace("\\", "/").simplify_path()
	var live := OS.get_environment("APPDATA").replace("\\", "/").simplify_path()
	var user_dir := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	if not _check(profile.begins_with(CASE_ROOT) and live == profile
		and user_dir == profile.path_join("PleaseRemainOnTheLine"), "explicit case-local APPDATA was applied before autoload startup"):
		await _finish(); return
	if not _check(DisplayServer.get_name() != "headless" and prior_scene == self,
		"windowed diagnostic owns the ordinary current scene binding"):
		await _finish(); return
	preview_owned = RealityState.begin_preview_campaign(self)
	if not _check(preview_owned, "exclusive nonpersistent preview campaign"):
		await _finish(); return
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	CampaignTime.set_frozen_for_tests(true)
	player = LockTarget.new(); player.name = "DeclaredPanelLockTarget"; add_child(player)
	prop = CloseTarget.new(); prop.name = "DeclaredCloseCallbackTarget"; add_child(prop)
	pointer = get_viewport().get_visible_rect().size * Vector2(.35, .50)
	await _darts()
	await _pool()
	await _finish()

func _dispatch(event: InputEvent) -> void:
	get_viewport().push_input(event, true)
	if event is InputEventMouseButton and event.pressed:
		var hovered: Control = get_viewport().gui_get_hovered_control()
		last_gui = {"path": str(hovered.get_path()) if hovered != null else "", "mouse_filter": hovered.mouse_filter if hovered != null else -1}
	await get_tree().process_frame
	await get_tree().physics_frame

func _button(pressed: bool, point: Vector2) -> void:
	mouse_held = pressed
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	await _dispatch(event)

func _escape(panel: Node, callback_before: int, label: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		await _dispatch(event)
	await get_tree().process_frame
	var closed := not is_instance_valid(panel) and prop.closed_calls == callback_before + 1
	_check(closed and not player.call_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		label + " actual Escape frees panel, calls prop once and restores lock/mouse")
	if is_instance_valid(panel):
		# Cleanup only after the ordinary Escape contract has already failed.
		outcomes[label].cleanup_fallback = "ordinary close authority after failed Escape"
		panel.close()
		await get_tree().process_frame
	active_panel = null

func _within_budget() -> bool:
	return Time.get_ticks_msec() - started < int(LIMIT_SECONDS * 1000.0)

func _wait(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and _within_budget():
		if bool(predicate.call()): return true
		await get_tree().physics_frame
	return false

func _darts() -> void:
	var before := failures.size()
	contracts.darts_viewport_scored_input = {"executed": true, "status": "FAIL"}
	var callback_before := prop.closed_calls
	var panel: DartsPanel = DartsSource.new()
	active_panel = panel
	panel.open(player, prop)
	get_tree().current_scene.add_child(panel)
	await get_tree().process_frame
	_check(player.call_locked and panel.step == DartsPanel.Step.ASK and panel.trivia.thrown.is_empty(),
		"real DartsPanel.open owns lock and original untouched question")
	await _button(true, pointer)
	var held := panel.holding
	var press_gui: Dictionary = last_gui.duplicate(true)
	_check(held, "ordinary viewport GUI dispatch reaches darts holding handler")
	if held:
		_check(await _wait(func(): return panel.hold_t >= 1.05, 2.5), "original darts hold process reaches steady interval")
	await _button(false, pointer)
	var scored := panel.trivia.thrown.has(0) and not panel._landed.is_empty()
	_check(scored, "ordinary viewport release invokes original dart rule scoring")
	outcomes.darts = {"pressed_holding": held, "scored": scored, "point": pointer, "press_gui": press_gui,
		"question": panel.trivia.card.duplicate(true), "thrown": panel.trivia.thrown.duplicate(true),
		"landed": panel._landed.duplicate(), "player_score": int(panel.trivia.players[0].score)}
	if scored:
		var result: Dictionary = panel.trivia.thrown[0]
		var landed: Vector2 = panel._landed[0]
		_check(landed.is_finite() and int(result.points) >= 0 and int(panel.trivia.players[0].score) == int(result.points),
			"original darts finite landing evaluates matching player points")
	await _capture("darts")
	await _escape(panel, callback_before, "darts")
	contracts.darts_viewport_scored_input.status = "PASS" if failures.size() == before else "FAIL"

func _pool() -> void:
	var before := failures.size()
	contracts.pool_viewport_scored_input = {"executed": true, "status": "FAIL"}
	if not _check(_within_budget(), "pool diagnostic starts within total19s budget"): return
	var callback_before := prop.closed_calls
	var panel: PointBallPanel = PoolSource.new()
	active_panel = panel
	panel.open(player, prop)
	get_tree().current_scene.add_child(panel)
	await get_tree().process_frame
	_check(player.call_locked and panel.table.shots == 0 and panel.table.turn == 0,
		"real PointBallPanel.open owns lock and original untouched rack")
	await _button(true, pointer)
	var aimed := panel.aiming
	var press_gui: Dictionary = last_gui.duplicate(true)
	_check(aimed, "ordinary viewport GUI dispatch reaches pool aiming handler")
	var pulled := pointer - Vector2(120, 0)
	var motion := InputEventMouseMotion.new()
	motion.position = pulled
	motion.global_position = pulled
	motion.relative = pulled - pointer
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	await _dispatch(motion)
	await _button(false, pulled)
	var shot_started := panel.table.shots == 1 and panel.table.moving
	_check(shot_started, "ordinary viewport pull/release starts exactly one real pool shot")
	var settled := false
	if shot_started:
		settled = await _wait(func(): return not panel.table.moving, POOL_SECONDS)
		_check(settled, "original pool physics settles inside12s and total19s")
	outcomes.pool = {"pressed_aiming": aimed, "shot_started": shot_started, "settled": settled,
		"press_gui": press_gui,
		"point": pointer, "pull_px": 120, "shots": panel.table.shots, "turn": panel.table.turn,
		"last_points": panel.table.last_points, "player_score": int(panel.table.players[0].score),
		"log": panel.table.log_lines.duplicate()}
	if settled:
		_check(panel.table.shots == 1 and panel.table.turn == 1 and panel.table.last_points >= 0
			and int(panel.table.players[0].score) == panel.table.last_points and not panel.table.log_lines.is_empty(),
			"original pool shot owns evaluated score and next turn")
	await _capture("pool")
	await _escape(panel, callback_before, "pool")
	contracts.pool_viewport_scored_input.status = "PASS" if failures.size() == before else "FAIL"

func _capture(identity: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path := directory.path_join(identity + ".png")
	_check(image != null and not image.is_empty() and image.save_png(path) == OK, "actual panel diagnostic capture " + identity)
	outcomes[identity].capture = path

func _sources() -> Dictionary:
	var paths: Array = SOURCE_PATHS.duplicate()
	paths.append(get_script().resource_path)
	paths.append(scene_file_path)
	var result := {}
	for path: String in paths:
		var text := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
		_check(not text.is_empty(), "panel diagnostic input exists " + path)
		result[path] = text.sha256_text()
	return result

func _finish() -> void:
	if is_instance_valid(active_panel):
		active_panel.close()
		await get_tree().process_frame
	if mouse_held:
		await _button(false, pointer)
	if preview_owned:
		_check(RealityState.end_preview_campaign(self) and is_same(RealityState.data, prior_data), "original preview reference restored")
	_check(JSON.stringify(prior_data).sha256_text() == prior_hash, "original campaign content preserved")
	CampaignTime.set_frozen_for_tests(prior_frozen)
	GameBoot.launch_mode = prior_mode
	Input.mouse_mode = prior_mouse
	_check(get_tree().current_scene == prior_scene and Input.mouse_mode == prior_mouse
		and CampaignTime._frozen_for_tests == prior_frozen and GameBoot.launch_mode == prior_mode,
		"original current scene, mouse, launch and clock freeze restored")
	_check(initial_sources == _sources(), "original panels, rules, deck and probe source stay frozen")
	_check(_within_budget(), "entire panel-only diagnostic completes inside19s")
	var code := 0 if failures.is_empty() else 1
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "production_runtime": false,
		"suite": "HarukiyaPanelInputProbe", "status": "PASS" if code == 0 else "FAIL",
		"scope": "Panel-only diagnostic with actual retained panels/rules and ordinary viewport dispatch. Minimal declared call_locked and panel_closed stubs only. No world/player/crowd/gameplay, schedule, save persistence, cost or artistic acceptance.",
		"execution": {"completed": true, "exit_code": code, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
		"source": {"test_path": "game/" + get_script().resource_path.trim_prefix("res://"),
			"test_sha256": FileAccess.get_sha256(get_script().resource_path), "test_scene_path": "game/" + scene_file_path.trim_prefix("res://"),
			"test_scene_sha256": FileAccess.get_sha256(scene_file_path), "test_dependencies": initial_sources},
		"contracts": contracts, "checks": checks, "failures": failures, "outcomes": outcomes,
		"fixture": {"only_stubs": ["call_locked", "panel_closed"], "viewport_local_input": true, "seconds_limit": LIMIT_SECONDS}}
	var file := FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush()
	var written := file.get_error() == OK
	file.close()
	get_tree().quit(code if written else 2)
