extends Node
## Controlled owner-query diagnostic; no bodies, attendance or arrival proof.
const Routes := preload("res://scripts/characters/orison_v2_resident_route.gd")
const IDS := ["rhea_sato", "transient_guests", "juno_kells"]
const TEXT := ["res://tests/harukiya_natural_selection_preflight.gd", "res://tests/HarukiyaNaturalSelectionPreflight.tscn",
	"res://scripts/characters/schedule_director.gd", "res://scripts/characters/resident_agenda.gd",
	"res://scripts/game/kitchen_larder.gd", "res://scripts/game/campaign_clock.gd",
	"res://scripts/game/campaign_clock_driver.gd", "res://scripts/game/reality_game_state.gd",
	"res://scripts/characters/orison_v2_resident_route.gd", "res://scripts/characters/orison_v2_bar_route.gd",
	"res://scripts/building/orison_v2_runtime_root.gd", "res://scripts/building/WeatherManager.gd",
	"res://data/resident_schedules.json", "res://data/resident_motives.json", "res://data/reality_cases.json",
	"res://data/kitchen/groceries.json", "res://data/kitchen/cookbook.json",
	"res://data/apartment_life_profiles.json", "res://data/building_layout.json", "res://data/campaign_calendar.json"]
var director: ScheduleDirector
var agenda: ResidentAgenda
var larder: KitchenLarder
var clock := CampaignClock.new()
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var rows: Array[Dictionary] = []
var restrictions: Dictionary = {}
var hashes: Dictionary = {}
var paths: Array = []
var prior_data: Dictionary
var prior_data_hash := ""
var prior_mode: int
var prior_freeze := false
var owned := false
var unchanged_preview: Dictionary = {}
var directory := ""
var _nonhousehold_snapshot: Dictionary = {}
var inventory_before: Dictionary = {}
var inventory_after: Dictionary = {}
var logger

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> bool:
	checks.append({"ok": ok, "label": message})
	if not ok: failures.append(message); push_error("NATURAL QUERY: " + message)
	return ok

func _snapshot() -> Dictionary:
	var result := {}
	for path: String in paths:
		result[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text() if FileAccess.file_exists(path) else ""
	return result

func _nonhousehold(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	result.erase("campaign_clock"); result.erase(KitchenLarder.STATE_KEY)
	if result.has(PersonInventory.KEY):
		for holder: String in result[PersonInventory.KEY].holders:
			var items: Dictionary = result[PersonInventory.KEY].holders[holder]
			for id: String in items.keys():
				if str(items[id].get("kind", "")) == "grocery": items.erase(id)
	return result

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK: get_tree().quit(2); return
	logger = preload("res://tests/guide_bell_error_capture.gd").new(); OS.add_logger(logger)
	paths = TEXT.duplicate(); paths.append("res://scripts/game/person_inventory.gd"); paths.append("res://scripts/game/door_keyring.gd"); paths.append("res://tests/guide_bell_error_capture.gd")
	var route_files: Dictionary = Routes.ROUTES.duplicate(); route_files["mina_vale"] = Routes.MINA_ROUTE
	for id: String in route_files: paths.append(route_files[id])
	hashes = _snapshot()
	for path: String in paths: _check(FileAccess.file_exists(path), "bound source exists " + path)
	for key: String in ["SCHEDULE", "SCHEDULE_DAY", "SCHEDULE_DOY", "SCHEDULE_FIRST_SAT", "SCHEDULE_MINUTE", "AGENDA"]:
		_check(OS.get_environment(key).is_empty(), "no schedule/agenda override " + key)
	prior_data = RealityState.data; prior_data_hash = JSON.stringify(prior_data).sha256_text()
	prior_mode = GameBoot.launch_mode; prior_freeze = CampaignTime._frozen_for_tests
	CampaignTime.set_frozen_for_tests(true)
	owned = RealityState.begin_preview_campaign(self)
	if not _check(owned, "exclusive nonpersistent preview ownership"): _finish(); return
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	_check(PersonInventory.valid(PersonInventory.book()), "actual carried inventory initialized and valid")
	inventory_before = PersonInventory.book().duplicate(true)
	unchanged_preview = _nonhousehold(RealityState.data)
	if not _check(clock.configure_date(1929, 6, 15, 21 * 60 + 59), "one declared Saturday21:59 epoch"): _finish(); return
	director = ScheduleDirector.new(); add_child(director); director.set_process(false)
	director.setup(null, JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json")))
	if not _check(director.enabled and not director.data.is_empty(), "real ScheduleDirector enabled; DAYNIGHT must allow schedules"): _finish(); return
	agenda = ResidentAgenda.new(); add_child(agenda); agenda.set_process(false)
	if not _check(agenda.setup(director, Callable(), Callable(), RealityState.has_knowledge, RealityState.resident_trust), "real agenda with actual preview knowledge/trust callbacks"): _finish(); return
	for id: String in route_files:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(route_files[id]))
		if not _check(Routes.valid_route_header(source, id), "original current route header " + id): _finish(); return
		var allowed: Array = source.places.keys()
		if not allowed.has("harukiya_bar"): allowed.append("harukiya_bar")
		# Production BarRoute.attach adds this place before ResidentRoute.restrict.
		agenda.restrict(id, allowed); restrictions[id] = allowed
	larder = KitchenLarder.new()
	if not _check(larder.load_data(agenda.homes()) and larder.bind(RealityState.data, RealityState.commit), "actual preview-backed household stock owner"): _finish(); return
	agenda.larder = larder
	var minutes: Array = [1319]
	for minute in range(1320, 1411, 10): minutes.append(minute)
	for minute: int in minutes:
		clock.advance_seconds((minute - clock.minute_of_day()) * 60.0)
		_check(absf(clock.minute_of_day() - minute) < .00001, "controlled campaign minute " + str(minute))
		agenda._process(1.0) # Actual one-second owner hook; no alternative choice/scoring logic.
		var info := director.day_info()
		_check(info.get("valid", false) and info.day == "sat" and int(info.doy) == 166, "ordinary clock date remains June15Saturday")
		var row := {"minute": minute, "clock": info, "elapsed_minutes": clock.elapsed_minutes(),
			"live_minute": agenda.live_minute, "weather_scores": agenda._weather(int(info.doy)), "residents": {}}
		for id: String in IDS:
			var raw := director.resolve(id, str(info.day), clock.minute_of_day(), int(info.doy), bool(info.first_sat))
			var selected := agenda.decide(id, str(info.day), clock.minute_of_day(), int(info.doy), bool(info.first_sat))
			_check(not selected.is_empty(), "selected owner decision " + id + " " + str(minute))
			row.residents[id] = {"raw": raw, "selected": selected, "trust": RealityState.resident_trust(id),
				"story_arc": agenda._arc(id), "unit": larder.unit_of(id), "household": larder.state.units.get(larder.unit_of(id), {}).duplicate(true)}
		rows.append(row)
		if not failures.is_empty(): break
	inventory_after = PersonInventory.book().duplicate(true)
	_check(PersonInventory.valid(inventory_after), "carried inventory remains valid after pantry activity")
	_nonhousehold_snapshot = _nonhousehold(RealityState.data)
	_check(_nonhousehold_snapshot == unchanged_preview, "no story/trust/nonhousehold state changes")
	_finish()

func _finish() -> void:
	if is_instance_valid(agenda): remove_child(agenda); agenda.free()
	if is_instance_valid(director): remove_child(director); director.free()
	larder = null
	if owned: _check(RealityState.end_preview_campaign(self) and is_same(RealityState.data, prior_data), "exact original preview context restored")
	GameBoot.launch_mode = prior_mode; CampaignTime.set_frozen_for_tests(prior_freeze)
	_check(CampaignTime._frozen_for_tests == prior_freeze and GameBoot.launch_mode == prior_mode, "original mode/freeze restored")
	_check(JSON.stringify(prior_data).sha256_text() == prior_data_hash, "original campaign dictionary unchanged")
	_check(hashes == _snapshot(), "LF source bindings stable before/after")
	var errors: Array = []
	for error: String in logger.errors:
		if not error.contains("NATURAL QUERY:"): errors.append(error)
	_check(errors.is_empty(), "no unexpected engine errors"); OS.remove_logger(logger)
	var result := {"schema_version": 2, "evidence_kind": "diagnostic", "production_runtime": false,
		"status": "PASS" if failures.is_empty() else "FAIL", "scope": "controlled owner queries only; no physical attendance/arrival/full-world parity",
		"callbacks": {"knowledge_trust": "actual RealityState preview owners", "larder": "actual preview data/commit; default seeded households",
			"weather": "invalid conditions callback uses real agenda seasonal_snapshot fallback; no live WakingAtmosphere",
			"player": "invalid callback gives empty place; no physical player/room resolver", "loop_performance": "absent, not the full world resident_whereabouts priority chain"},
		"clock_control": "configure once21:59; explicit advance_seconds to ten-minute queries; driver frozen; actual agenda._process(1) per query",
		"inventory_before": inventory_before, "inventory_after": inventory_after, "inventory_projection": "only grocery-kind rows omitted from comparison; keys/goods/other domains exact; full inventories recorded", "nonhousehold_before": unchanged_preview, "nonhousehold_after": _nonhousehold_snapshot, "source_hashes": hashes, "restrictions": restrictions, "rows": rows, "checks": checks, "failures": failures, "engine_errors": errors}
	var file := FileAccess.open(directory.path_join("natural_selection.json"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush()
	var written := file.get_error() == OK; file.close()
	get_tree().quit(0 if failures.is_empty() and written else 1)
