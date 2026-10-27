extends Node
## Durable control settings by semantic ID. RealityState alone writes saves.
## Physical library stock also keeps its pose and velocity here. No second save
## owner is introduced; animations, playing audio and service panels do not persist.
const KEY := "v2_household_controls"
var errors: Array[String] = []
var _subjects: Dictionary = {}
var _kinds: Dictionary = {}
var _defaults: Dictionary = {}
var _last_saved: Dictionary = {}
var _state_document: Dictionary = {}
var _connections: Array = []
var _bound := false
var _restoring := false
var _blocked := false
const SERVICE_KINDS := {"B1_FUSE_PANEL":"fuse_service", "ROOF_TANK_BALLCOCK":"tank_service", "B1_BOILER_01":"boiler_service"}
const SERVICE_ACTIVITIES := {"fuse_service":"fuse_panel_rating_service",
	"tank_service":"roof_tank_ballcock_service", "boiler_service":"boiler_water_column_test"}
var _service_defaults: Dictionary = {}
var _service_completed: Dictionary = {}
var _service_library: MaintenanceActivityLibrary
var profiling:=false
var profile_records: Array[Dictionary]=[]
var profile_causes: Array[Dictionary]=[]
var reuse_unchanged_validation:=true
var background_persistence:=true

func _profile_start() -> int:
	return Time.get_ticks_usec() if profiling else 0

func _profile_end(stage: String,started: int) -> void:
	if started<=0:return
	profile_records.append({"stage":stage,"start_usec":started,"end_usec":Time.get_ticks_usec(),"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),"subjects":_subjects.size()})
	if profile_records.size()>4096:profile_records.pop_front()

func bind(adapter: Variant, switches: SwitchSystem, additional_mechanisms: Dictionary = {}) -> bool:
	if _bound or adapter == null or switches == null or not is_inside_tree(): return false
	if not get_tree().get_nodes_in_group("v2_household_state").is_empty():
		errors.append("another household save owner is already active")
		return false
	var lighting: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/room_lighting.json"))
	for record: Dictionary in lighting.fixtures:
		if record.kind != "lamp": _kinds[str(record.id)] = "light"
	var completion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/completion_interiors.json"))
	for record: Dictionary in completion.lighting.fixtures:
		if record.kind != "lamp": _kinds[str(record.id)] = "light"
	var furniture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/domestic_furniture.json"))
	var furniture_kinds: Dictionary = {}
	for record: Dictionary in furniture.furniture:
		furniture_kinds[str(record.id)] = str(record.kind)
		if record.kind == "prep_cabinet": _kinds[str(record.id)] = "prep"
	# Completion homes mount copies of the V1 cabinets (dossier slice 9); each
	# copy's panel is the same durable control under the copy's identity.
	for record: Dictionary in completion.furniture:
		if furniture_kinds.get(str(record.template), "") == "prep_cabinet": _kinds[str(record.id)] = "prep"
	var accessories: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/household_accessories.json"))
	for record: Dictionary in accessories.accessories:
		if record.kind == "mirror": _kinds[str(record.id)] = "mirror"
	var heating: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/heating.json"))
	for record: Dictionary in heating.installed:
		# This domain saves physical part positions. Lena's case and inventory
		# retain condition, work-order and packing-custody authority.
		_kinds[str(record.id)] = "radiator"
	var shelves: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/bookshelves.json"))
	for record: Dictionary in shelves.shelves: _kinds[str(record.id)] = "books"
	for collection: Node in get_tree().get_nodes_in_group("v2_library_collections"):
		if adapter.root.is_ancestor_of(collection): _kinds[str(collection.name)]="books"
	for window: Node in get_tree().get_nodes_in_group("v2_window_treatments"):
		if adapter.root.is_ancestor_of(window):_kinds[str(window.get_meta("semantic_window"))]="blind"
	_kinds.merge(SERVICE_KINDS)
	_kinds["B1_BOILER_AIR_E"]="window"
	_service_library = MaintenanceActivityLibrary.load_default()
	if not _service_library.is_valid():
		errors.append("invalid maintenance restoration profiles")
		return false
	# Named installed owners retain partial mechanical positions in the same
	# household save domain, without serializing pointer/grab/transient tweens.
	var explicit_owners: Array[Node] = []
	for identity: String in _kinds:
		var subject: Node = adapter.resolve(identity)
		if subject == null: continue
		if _kinds[identity]=="window": subject=subject.get_node_or_null("OperatingWindow")
		elif _kinds[identity]=="blind": subject=subject.get_node_or_null("WindowTreatment")
		if subject != null: explicit_owners.append(subject)
	for mechanism: Node in adapter.root.find_children("*","Node3D",true,false):
		if mechanism in explicit_owners or not mechanism.has_method("mechanism_snapshot"): continue
		var identity := str(mechanism.name)
		if adapter.resolve(identity) != mechanism: continue
		if _kinds.has(identity): continue
		_kinds[identity] = "mechanism"
		_subjects[identity] = mechanism
	# Streamed regions own actors outside the architectural adapter root.
	# Admit only explicitly supplied stable owners into this same save authority.
	for identity: String in additional_mechanisms:
		var mechanism: Node = additional_mechanisms[identity]
		if identity.is_empty() or _kinds.has(identity) or not is_instance_valid(mechanism) \
				or str(mechanism.name)!=identity or not mechanism.is_inside_tree() \
				or not mechanism.has_method("mechanism_snapshot") or not mechanism.has_method("valid_mechanism") \
				or not mechanism.has_method("restore_mechanism") or not mechanism.has_signal("manipulation_changed"):
			errors.append("invalid additional mechanism owner: "+identity)
			return false
		_kinds[identity]="mechanism"
		_subjects[identity]=mechanism
	for identity: String in _kinds:
		var prop: Node = _subjects.get(identity,adapter.resolve(identity))
		var kind: String = _kinds[identity]
		if kind=="blind" and prop!=null:prop=prop.get_node_or_null("WindowTreatment")
		if kind=="window" and prop!=null:prop=prop.get_node_or_null("OperatingWindow")
		if (kind == "blind" and (prop==null or not prop.has_method("settings_snapshot"))) \
				or (kind == "light" and not prop is LightFixtureProp) \
				or (kind == "fuse_service" and not prop is FusePanelProp) \
				or (kind == "tank_service" and not prop is RoofTankBallcockProp) \
				or (kind == "boiler_service" and not prop is BoilerProp) \
				or (kind == "radiator" and not prop is RadiatorProp) \
				or (kind == "books" and (not prop is BookshelfProp or not prop.has_method("restore_order"))) \
				or (kind in ["prep", "mirror", "window"] and (prop == null or not prop.has_method("restore_open_state"))):
			errors.append("missing household control: " + identity)
			return false
		_subjects[identity] = prop
		if SERVICE_KINDS.has(identity):
			_service_defaults[identity] = prop.call("maintenance_snapshot")
			_service_completed[identity] = false
	_defaults = snapshot()
	if _defaults.is_empty():
		errors.append("household controls detached before binding")
		return false
	var saved: Variant = _saved_value()
	if not validate(saved, _kinds): return false
	_restore(saved)
	_bound = true
	add_to_group("v2_household_state")
	_connect(RealityState, "snapshot_preparing", _capture_snapshot)
	_connect(RealityState, "state_changed", _on_state_changed)
	_connect(switches, "room_toggled", _on_room_changed)
	for identity: String in _subjects:
		if SERVICE_KINDS.has(identity):
			_connect(_subjects[identity], "maintenance_completed", _on_service_completed.bind(identity))
			if _subjects[identity].has_signal("manipulation_changed"): _connect(_subjects[identity], "manipulation_changed", _commit_change)
		elif _kinds[identity] == "radiator":
			_connect(_subjects[identity], "supply_changed", _on_valve_changed)
			_connect(_subjects[identity], "manipulation_changed", _commit_change)
			_connect(_subjects[identity], "vent_changed", _on_radiator_setting_changed)
			_connect(_subjects[identity], "pitch_changed", _on_radiator_setting_changed)
		elif _kinds[identity] in ["prep", "mirror", "window"]:
			_connect(_subjects[identity], "open_state_changed", _on_cabinet_changed)
		elif _kinds[identity] == "blind":
			_connect(_subjects[identity], "settings_changed", _commit_change)
		elif _kinds[identity] == "books":
			_connect(_subjects[identity], "order_changed", _commit_change)
		elif _kinds[identity] == "mechanism":
			_connect(_subjects[identity], "manipulation_changed", _commit_change)
	return true

func _connect(owner: Object, event: String, callback: Callable) -> void:
	owner.connect(event, callback)
	_connections.append([owner, event, callback])

func _saved_value() -> Variant:
	return RealityState.data[KEY] if RealityState.data.has(KEY) else {"schema_version":1, "records":{}}

func validate(value: Variant, kinds: Dictionary) -> bool:
	# Public/load validation always checks the complete payload.
	return _validate(value,kinds,{})

func _validate(value: Variant, kinds: Dictionary, trusted_records: Dictionary) -> bool:
	var profile_started:=_profile_start()
	errors.clear()
	if value is not Dictionary or value.size() != 2 \
			or value.get("records") is not Dictionary:
		errors.append("invalid household save schema")
		_profile_end("validate_invalid_schema",profile_started)
		return false
	if typeof(value.get("schema_version")) not in [TYPE_INT, TYPE_FLOAT] \
			or not is_finite(float(value.schema_version)) or float(value.schema_version) != 1.0:
		errors.append("household save version must be numeric")
		_profile_end("validate_invalid_version",profile_started)
		return false
	for identity: Variant in value.records:
		var record: Variant = value.records[identity]
		if identity is not String or not kinds.has(identity) or record is not Dictionary \
				or record.size() != 2 or record.get("kind") is not String \
				or record.kind != kinds[identity]:
			errors.append("unknown or malformed household save identity")
			continue
		var setting: Variant = record.get("value")
		# capture_now alone supplies the owner's previous validated deep copy.
		# Compare the complete record, including kind and nested values. Related
		# identities are checked below even when an individual record is reused.
		if trusted_records.has(identity) and trusted_records[identity]==record:continue
		if record.kind == "mechanism":
			if not _subjects.has(identity) or not _subjects[identity].valid_mechanism(setting): errors.append("invalid saved mechanism position")
		elif record.kind in SERVICE_KINDS.values() and setting is Dictionary:
			if setting.size()!=2 or setting.get("completed") is not bool or not _subjects[identity].has_method("valid_mechanism") or not _subjects[identity].valid_mechanism(setting.get("mechanism")):
				errors.append("invalid service mechanism position")
		elif record.kind == "window":
			if setting is not bool and not _subjects[identity].valid_mechanism(setting): errors.append("invalid window sash/cam position")
		elif record.kind == "radiator":
			if setting is Dictionary:
				if not _subjects[identity].valid_mechanism(setting): errors.append("invalid saved radiator mechanism")
			elif typeof(setting) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(setting)) \
					or float(setting) < 0.0 or float(setting) > 1.0:
				errors.append("invalid saved radiator position")
		elif record.kind == "blind":
			if not preload("res://scripts/building/orison_v2_window_treatment.gd").valid_settings(setting):errors.append("invalid saved blind settings")
		elif record.kind == "books":
			if not _valid_book_order(str(identity), setting): errors.append("saved books must be the resident library permutation")
		elif record.kind in ["prep","mirror"]:
			if setting is not bool and (typeof(setting) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(setting)) or float(setting)<0 or float(setting)>1):
				errors.append("invalid partial cabinet travel")
		elif setting is not bool:
			errors.append("household switch/door value must be boolean")
	if errors.is_empty():
		for identity: String in _subjects:
			if _subjects[identity].has_method("validate_related_records") and not _subjects[identity].validate_related_records(value.records):
				errors.append("inconsistent related mechanism identities")
	_profile_end("validate",profile_started)
	return errors.is_empty()

func _valid_book_order(identity: String, value: Variant) -> bool:
	if not _defaults.get("records", {}).has(identity): return false
	if value is Dictionary:
		return _subjects[identity].has_method("valid_library") and _subjects[identity].valid_library(value)
	if value is not Array: return false
	var original: Variant = _defaults.records[identity].value
	var expected: Array = original.order if original is Dictionary else original
	if value.size() != expected.size(): return false
	var seen := {}
	for book: Variant in value:
		if book is not String or not expected.has(book) or seen.has(book): return false
		seen[book] = true
	return true

func snapshot() -> Dictionary:
	var profile_started:=_profile_start()
	var records := {}
	for identity: String in _subjects:
		var prop = _subjects[identity]
		if not is_instance_valid(prop) or not prop.is_inside_tree() or prop.is_queued_for_deletion():
			_profile_end("snapshot_detached",profile_started);return {}
		var kind: String = _kinds[identity]
		var setting: Variant
		match kind:
			"mechanism": setting = prop.call("mechanism_snapshot")
			"fuse_service", "tank_service", "boiler_service":
				setting = {"completed":_service_completed[identity],"mechanism":prop.mechanism_snapshot()} if prop.has_method("mechanism_snapshot") else _service_completed[identity]
			"light": setting = prop.get("powered")
			"radiator": setting = prop.mechanism_snapshot()
			"window": setting = prop.mechanism_snapshot()
			"prep": setting = prop._slide.position.x/prop.TRAVEL
			"mirror": setting = prop.get("_swing")
			"blind": setting = prop.call("settings_snapshot")
			"books": setting = prop.library_snapshot() if prop.has_method("library_snapshot") else prop.get("sorter").order.duplicate()
		records[identity] = {"kind":kind, "value":setting}
	_profile_end("snapshot",profile_started)
	return {"schema_version":1, "records":records}

func _restore(saved: Dictionary) -> void:
	_restoring = true
	for player: Node in get_tree().get_nodes_in_group("player_controller"):
		if player.has_method("cancel_manipulation"): player.cancel_manipulation()
	for identity: String in _subjects:
		var record: Dictionary = saved.records.get(identity, _defaults.records[identity])
		var prop: Node = _subjects[identity]
		match record.kind:
			"mechanism":
				var value: Variant=record.value
				if not saved.records.has(identity) and prop.has_method("migrate_legacy_snapshot"):
					value=prop.migrate_legacy_snapshot(value,saved.records)
				prop.call("restore_mechanism",value)
			"fuse_service", "tank_service", "boiler_service":
				_restore_service(identity, record.value.completed if record.value is Dictionary else record.value)
				if record.value is Dictionary: prop.restore_mechanism(record.value.mechanism)
			"light": prop.call("set_powered", record.value)
			"radiator":
				if record.value is Dictionary: prop.restore_mechanism(record.value)
				else: prop.call("set_supply_position", float(record.value), 0.0)
			"blind": prop.call("restore_settings", record.value)
			"books": prop.call("restore_order", record.value)
			"window":
				if record.value is bool: prop.restore_open_state(record.value)
				else: prop.restore_mechanism(record.value)
			"prep", "mirror": prop.call("restore_travel",float(record.value))
			_: prop.call("restore_open_state", record.value)
	_last_saved = saved.duplicate(true)
	_state_document = RealityState.data
	_restoring = false
	_blocked = false

func _restore_service(identity: String, completed: bool) -> void:
	var prop: Node = _subjects[identity]
	# A loaded/reset world cannot keep an old preview that would later roll
	# back over the newly loaded result when the player cancels the panel.
	var panel: Variant = prop.get("_service_panel")
	if is_instance_valid(panel): panel.call("_close", true)
	var state: Dictionary = _service_defaults[identity].duplicate(true)
	if completed:
		var activity: String = SERVICE_ACTIVITIES[SERVICE_KINDS[identity]]
		var profile: Dictionary = _service_library.activity(activity)
		var patch: Dictionary = profile.completion.mechanism_patch
		for key: String in patch:
			if state.has(key): state[key] = patch[key]
		if state.has("load_proved"): state.load_proved = true
	prop.call("restore_maintenance_snapshot", state)
	_service_completed[identity] = completed

func _on_service_completed(_result: Dictionary, identity: String) -> void:
	if _restoring or _blocked: return
	var prop: Node = _subjects[identity]
	var completed := false
	match SERVICE_KINDS[identity]:
		"fuse_service": completed = prop.get("panel_safe") and prop.call("protects_conductor")
		"tank_service": completed = prop.get("ballcock_serviced") and prop.call("valve_holds")
		"boiler_service": completed = prop.get("column_proved") and not prop.get("column_isolated")
	if not completed: return
	_service_completed[identity] = true
	_commit_change()

func _on_state_changed() -> void:
	if not _bound or _restoring: return
	var profile_started:=_profile_start()
	var saved: Variant = _saved_value()
	# A deep-equal copy of our last validated payload in the same campaign
	# document is already trusted. Load/reset replaces the document; changed
	# values or recovery from a blocked state still take full validation below.
	if reuse_unchanged_validation and not _blocked and saved == _last_saved and is_same(_state_document, RealityState.data):
		errors.clear();_profile_end("state_cached",profile_started);return
	# A load/reset replaces facts underneath an existing world. Adopt only a
	# fully valid document; never flush stale controls back into the new save.
	if not validate(saved, _kinds):
		_blocked = true
		_profile_end("state_invalid",profile_started)
		return
	# Ordinary commits can arrive while a hand or spring is moving. Their
	# unchanged household payload must not roll that live motion back. A real
	# load/reset replaces RealityState.data, even when its values are identical.
	if not _blocked and saved == _last_saved and is_same(_state_document, RealityState.data):
		_profile_end("state_unchanged",profile_started);return
	_restore(saved)
	_profile_end("state_restored",profile_started)

func capture_now() -> bool:
	if not _bound or _restoring or _blocked or RealityState.save_write_blocked or not is_inside_tree(): return false
	var profile_started:=_profile_start()
	var saved: Variant = _saved_value()
	if saved != _last_saved or not is_same(_state_document, RealityState.data):
		_on_state_changed()
		_profile_end("capture_replaced",profile_started)
		return false
	var current := snapshot()
	# A fresh snapshot equal to the same validated saved payload needs no
	# second validation. Changed records still pass their complete validators;
	# every related-record constraint runs against the complete fresh snapshot.
	if reuse_unchanged_validation and not current.is_empty() and current == saved:
		errors.clear();_profile_end("capture_cached",profile_started);return false
	var trusted: Dictionary=_last_saved.get("records",{}) if reuse_unchanged_validation else {}
	if current.is_empty() or not _validate(current, _kinds, trusted) or current == saved:
		_profile_end("capture_unchanged_or_invalid",profile_started);return false
	RealityState.data[KEY] = current
	_last_saved = current.duplicate(true)
	_profile_end("capture_changed",profile_started)
	return true

func _capture_snapshot() -> void:
	capture_now()

func _commit_change() -> void:
	var profile_started:=_profile_start()
	var previous: Dictionary = _last_saved if profiling else {}
	if capture_now():
		if profiling:
			var probe_started := Time.get_ticks_usec()
			var changed: Array = []
			for identity: String in _last_saved.get("records", {}):
				if previous.get("records", {}).get(identity) != _last_saved.records[identity]:
					changed.append(identity)
			profile_causes.append({"start_usec":profile_started,"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),"changed":changed,"stack":get_stack(),"probe_usec":Time.get_ticks_usec()-probe_started})
			if profile_causes.size()>128:profile_causes.pop_front()
		if background_persistence:RealityState.commit_background()
		else:RealityState.commit()
	_profile_end("commit_change",profile_started)

func _on_room_changed(_room: String, _on: bool) -> void:
	_commit_change()

func _on_radiator_setting_changed(_value: Variant) -> void:
	_commit_change()

func _on_valve_changed(_open: bool, _position: float) -> void:
	_commit_change()

func _on_cabinet_changed(_open: bool) -> void:
	_commit_change()

func shutdown() -> void:
	if not _bound: return
	capture_now()
	_bound = false
	remove_from_group("v2_household_state")
	for connection: Array in _connections:
		var owner = connection[0]
		if is_instance_valid(owner) and owner.is_connected(connection[1], connection[2]):
			owner.disconnect(connection[1], connection[2])
	_connections.clear()
	_subjects.clear()

func _exit_tree() -> void:
	shutdown()
