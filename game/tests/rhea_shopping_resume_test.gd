extends "res://tests/harukiya_natural_selection_preflight.gd"
## Real-owner diagnostic, not body/arrival proof. No pantry/destination edits.
var original_files: Dictionary = {}
var original_mouse := 0
var evidence: Dictionary = {}

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory)!=OK: get_tree().quit(2); return
	logger = preload("res://tests/guide_bell_error_capture.gd").new(); OS.add_logger(logger)
	paths = TEXT.duplicate()
	paths.append(get_script().resource_path); paths.append(scene_file_path)
	paths.append("res://scripts/game/person_inventory.gd"); paths.append("res://scripts/game/door_keyring.gd")
	paths.append("res://tests/guide_bell_error_capture.gd")
	paths.append("res://tests/harukiya_natural_selection_preflight.gd")
	var route_files: Dictionary = Routes.ROUTES.duplicate(); route_files["mina_vale"] = Routes.MINA_ROUTE
	for id: String in route_files: paths.append(route_files[id])
	hashes = _snapshot()
	prior_data = RealityState.data; prior_data_hash = JSON.stringify(prior_data).sha256_text()
	prior_mode = GameBoot.launch_mode; prior_freeze = CampaignTime._frozen_for_tests
	original_files = _files(); original_mouse = Input.mouse_mode
	var profile: String = OS.get_environment("RHEA_RESUME_ISOLATED_APPDATA").replace("\\","/").simplify_path()
	_check(profile.begins_with("C:/ov/reports/harukiya_overhaul_20261112/performance_intake_06/") and OS.get_environment("APPDATA").replace("\\","/").simplify_path()==profile and OS.get_user_data_dir().replace("\\","/").simplify_path()==profile.path_join("PleaseRemainOnTheLine"),"dedicated APPDATA before autoload")
	for key: String in ["SCHEDULE","SCHEDULE_DAY","SCHEDULE_DOY","SCHEDULE_FIRST_SAT","SCHEDULE_MINUTE","AGENDA","CAMPAIGN_TIME_FREEZE"]:
		_check(OS.get_environment(key).is_empty(),"no selection/clock override "+key)
	if not failures.is_empty(): _finish(); return
	CampaignTime.set_frozen_for_tests(true)
	owned = RealityState.begin_preview_campaign(self)
	if not _check(owned,"exclusive fresh nonpersistent preview"): _finish(); return
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	_check(PersonInventory.valid(PersonInventory.book()),"actual seeded inventory valid")
	inventory_before = PersonInventory.book().duplicate(true)
	unchanged_preview = _nonhousehold(RealityState.data)
	if not _check(clock.configure_date(1929,6,15,21*60+59),"same fresh-seeded Saturday21:59 as natural selection fixture"): _finish(); return
	director = ScheduleDirector.new(); add_child(director); director.set_process(false)
	director.setup(null,JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json")))
	if not _check(director.enabled and not director.data.is_empty(),"actual ScheduleDirector enabled with authored data"): _finish(); return
	agenda = ResidentAgenda.new(); add_child(agenda); agenda.set_process(false)
	if not _check(agenda.setup(director,Callable(),Callable(),RealityState.has_knowledge,RealityState.resident_trust),"actual agenda with preview knowledge/trust"): _finish(); return
	for id: String in route_files:
		var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(route_files[id]))
		if not _check(Routes.valid_route_header(route,id),"unchanged real route header "+id): _finish(); return
		var allowed: Array = route.places.keys()
		if not allowed.has("harukiya_bar"): allowed.append("harukiya_bar")
		agenda.restrict(id,allowed); restrictions[id] = allowed
	larder = KitchenLarder.new()
	if not _check(larder.load_data(agenda.homes()) and larder.bind(RealityState.data,RealityState.commit),"actual default-seeded household larder"): _finish(); return
	agenda.larder = larder
	var seeded: Dictionary = _durable()
	agenda._process(1.0) # Actual hook: reconstruction, not a forced choice.
	_check(_durable()==seeded,"reconstruction never replays historical purchases or household effects")
	var state: Dictionary = agenda.get("_live").get("rhea_sato",{}).duplicate(true)
	var pick: Dictionary = state.get("choice",{}).duplicate(true)
	if not _check(str(pick.get("source",""))=="kitchen" and str(pick.get("activity",""))=="shopping" and str(pick.get("shop",""))=="bodega" and int(state.get("until",9999))<=1319,"actual reconstructed expired Rhea bodega selection"): _finish(); return
	evidence.reconstructed = {"state":state,"missing":larder.missing("rhea_sato"),"bag":PersonInventory.items("rhea_sato").duplicate(true),"durable":seeded}
	var before_queries: Dictionary = _durable()
	agenda.day_plan("rhea_sato","sat",166,false)
	agenda.decide("rhea_sato","sat",1000.0,166,false)
	_check(_durable()==before_queries,"pure day plan/lookback do not mutate bags stock or event log")
	if agenda.has_method("_resume_selected_shopping"):
		_check(bool(agenda.call("_resume_selected_shopping","rhea_sato",state,pick)),"actual current reconstructed shop has missing goods and qualifies")
		_predicate_negatives(state,pick)
	var shop_events_before: int = _shopping_events()
	_advance_owner(1320)
	_check(PersonInventory.items("rhea_sato")!=evidence.reconstructed.bag,"first live same-key handoff buys actual missing selected-shop goods")
	_check(_shopping_events()==shop_events_before+1,"exactly one actual Rhea shopping event")
	var handed_off: bool = not _missing_at("bodega")
	_check(handed_off,"carried goods count toward selected-shop missing predicate")
	var after_handoff: Dictionary = _durable()
	agenda._process(1.0)
	_check(_durable()==after_handoff,"repeated same minute causes no duplicate goods/events")
	# Never let this duplicate-call control buy goods on the failing original
	# source: only call it AFTER the actual agenda already filled the shortage.
	if handed_off:
		_check(larder.shop("rhea_sato","bodega",clock.elapsed_minutes()).is_empty() and _durable()==after_handoff,"actual KitchenLarder same-shop retry is idempotent through PersonInventory")
	if _check(agenda.has_method("_resume_selected_shopping"),"reviewed shopping-only predicate installed"):
		_check(not bool(agenda.call("_resume_selected_shopping","rhea_sato",state,pick)),"same selected shop without missing goods is a no-op")
	evidence.after_handoff = {"choice":agenda.get("_live").rhea_sato.duplicate(true),"durable":after_handoff,"shopping_events_before":shop_events_before,"shopping_events_after":_shopping_events(),"selected_shop_shortage_filled":handed_off}
	_advance_owner(1330) # Actual motives.step_minutes=10, not a five-minute tick.
	var successor: Dictionary = agenda.get("_live").rhea_sato.duplicate(true)
	_check(str(successor.key)!=str(state.key),"ordinary next choice changes through actual owners after goods are carried")
	evidence.successor = successor
	evidence.final_missing = larder.missing("rhea_sato")
	inventory_after = PersonInventory.book().duplicate(true)
	_nonhousehold_snapshot = _nonhousehold(RealityState.data)
	_check(_nonhousehold_snapshot==unchanged_preview,"no key/goods/story/trust/nonhousehold changes")
	_finish()

func _advance_owner(minute: int) -> void:
	clock.advance_seconds((minute-clock.minute_of_day())*60.0)
	_check(absf(clock.minute_of_day()-minute)<.00001,"existing explicit campaign advance seam "+str(minute))
	agenda._process(1.0)

func _missing_at(shop: String) -> bool:
	for item: String in larder.missing("rhea_sato"):
		if str(larder.groceries.ingredients[item].shop)==shop: return true
	return false

func _shopping_events() -> int:
	var count: int = 0
	for event: Dictionary in larder.state.events:
		if str(event.resident)=="rhea_sato" and str(event.what)=="shopped": count+=1
	return count

func _predicate_negatives(state: Dictionary, pick: Dictionary) -> void:
	var before: Dictionary = _durable()
	for mode: String in ["unknown_shop","unselected_shop","cooking","eating"]:
		var candidate: Dictionary = pick.duplicate(true)
		var current: Dictionary = state.duplicate(true)
		if mode=="unknown_shop":
			candidate.shop="not_a_shop"; candidate.key="kitchen|shop|not_a_shop"
			current.key=candidate.key; current.choice=candidate.duplicate(true)
		elif mode=="unselected_shop":
			var other: String = ""
			for shop: String in larder.groceries.shops:
				if shop!=str(pick.shop): other=shop; break
			_check(not other.is_empty(),"real alternate shop available for unselected control")
			# Bodega still has actual missing goods here; another current choice
			# cannot authorize retrying that unselected old bodega pick.
			current.key="kitchen|shop|"+other
			current.choice=pick.duplicate(true)
			current.choice.shop=other; current.choice.key=current.key
		else:
			candidate.activity=mode; current.choice=candidate.duplicate(true)
		_check(not bool(agenda.call("_resume_selected_shopping","rhea_sato",current,candidate)),"refuse cloned predicate control "+mode)
	_check(_durable()==before,"all predicate controls are pure; no cook/eat or unselected purchase")

func _durable() -> Dictionary:
	return {"inventory":PersonInventory.book().duplicate(true),"larder":larder.state.duplicate(true)}

func _files() -> Dictionary:
	var result: Dictionary = {}
	for suffix: String in ["",".bak",".txn",".tmp"]:
		var path: String = RealityState.save_path+suffix
		result[suffix]={"exists":FileAccess.file_exists(path),"sha256":FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""}
	return result

func _finish() -> void:
	if is_instance_valid(agenda): agenda.free()
	if is_instance_valid(director): director.free()
	if owned: _check(RealityState.end_preview_campaign(self) and is_same(RealityState.data,prior_data),"original preview context restored")
	GameBoot.launch_mode=prior_mode; CampaignTime.set_frozen_for_tests(prior_freeze); Input.mouse_mode=original_mouse
	_check(JSON.stringify(prior_data).sha256_text()==prior_data_hash,"original campaign content unchanged")
	_check(_files()==original_files,"save backup/transaction bytes unchanged")
	_check(hashes==_snapshot(),"all actual source and observer bindings unchanged")
	var errors: Array = logger.get("errors")
	# Test assertion failures print through inherited _check; preserve other errors.
	var unexpected: Array[String] = []
	for message: String in errors:
		if not message.contains("NATURAL QUERY:"): unexpected.append(message)
	OS.remove_logger(logger); _check(unexpected.is_empty(),"no genuine unexpected engine errors")
	var result: Dictionary = {"schema_version":2,"evidence_kind":"diagnostic","production_runtime":false,"status":"PASS" if failures.is_empty() else "FAIL","scope":"Actual agenda/larder/inventory reconstruction-to-live shopping-only handoff. Explicit original1319/1320/1330 clock seam, unchanged default seeds/restrictions, no actors/force_destination/pantry edits. No natural bar arrival or design-preference claim.","source_hashes":hashes,"evidence":evidence,"checks":checks,"failures":failures,"engine_errors":unexpected}
	var file: FileAccess=FileAccess.open(directory.path_join("rhea_shopping_resume.json"),FileAccess.WRITE)
	if file==null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result,"\t")); file.flush()
	var written: bool=file.get_error()==OK
	file.close(); get_tree().quit(0 if failures.is_empty() and written else 1)
