extends Node
## Durable control settings by semantic ID. RealityState alone writes saves.
## No coordinates, animations, playing audio or transient service panels persist.
const KEY := "v2_household_controls"
var errors: Array[String] = []
var _subjects: Dictionary = {}
var _kinds: Dictionary = {}
var _defaults: Dictionary = {}
var _last_saved: Dictionary = {}
var _connections: Array = []
var _bound := false
var _restoring := false
var _blocked := false
const SERVICE_KINDS := {"B1_FUSE_PANEL":"fuse_service", "ROOF_TANK_BALLCOCK":"tank_service"}
var _service_defaults: Dictionary = {}
var _service_completed: Dictionary = {}
var _service_library: MaintenanceActivityLibrary

func bind(adapter: Variant, switches: SwitchSystem) -> bool:
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
	for record: Dictionary in furniture.furniture:
		if record.kind == "prep_cabinet": _kinds[str(record.id)] = "prep"
	var accessories: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/household_accessories.json"))
	for record: Dictionary in accessories.accessories:
		if record.kind == "mirror": _kinds[str(record.id)] = "mirror"
	var heating: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/heating.json"))
	for record: Dictionary in heating.installed:
		# Lena's packing/situation owner retains sole custody of the 2B valve.
		if record.unit != "2B": _kinds[str(record.id)] = "radiator"
	var shelves: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/bookshelves.json"))
	for record: Dictionary in shelves.shelves: _kinds[str(record.id)] = "books"
	_kinds.merge(SERVICE_KINDS)
	_service_library = MaintenanceActivityLibrary.load_default()
	if not _service_library.is_valid():
		errors.append("invalid maintenance restoration profiles")
		return false
	for identity: String in _kinds:
		var prop: Node = adapter.resolve(identity)
		var kind: String = _kinds[identity]
		if (kind == "light" and not prop is LightFixtureProp) \
				or (kind == "fuse_service" and not prop is FusePanelProp) \
				or (kind == "tank_service" and not prop is RoofTankBallcockProp) \
				or (kind == "radiator" and not prop is RadiatorProp) \
				or (kind == "books" and (not prop is BookshelfProp or not prop.has_method("restore_order"))) \
				or (kind in ["prep", "mirror"] and (prop == null or not prop.has_method("restore_open_state"))):
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
		elif _kinds[identity] == "radiator":
			_connect(_subjects[identity], "supply_changed", _on_valve_changed)
		elif _kinds[identity] in ["prep", "mirror"]:
			_connect(_subjects[identity], "open_state_changed", _on_cabinet_changed)
		elif _kinds[identity] == "books":
			_connect(_subjects[identity], "order_changed", _commit_change)
	return true

func _connect(owner: Object, event: String, callback: Callable) -> void:
	owner.connect(event, callback)
	_connections.append([owner, event, callback])

func _saved_value() -> Variant:
	return RealityState.data[KEY] if RealityState.data.has(KEY) else {"schema_version":1, "records":{}}

func validate(value: Variant, kinds: Dictionary) -> bool:
	errors.clear()
	if value is not Dictionary or value.size() != 2 \
			or value.get("records") is not Dictionary:
		errors.append("invalid household save schema")
		return false
	if typeof(value.get("schema_version")) not in [TYPE_INT, TYPE_FLOAT] \
			or not is_finite(float(value.schema_version)) or float(value.schema_version) != 1.0:
		errors.append("household save version must be numeric")
		return false
	for identity: Variant in value.records:
		var record: Variant = value.records[identity]
		if identity is not String or not kinds.has(identity) or record is not Dictionary \
				or record.size() != 2 or record.get("kind") is not String \
				or record.kind != kinds[identity]:
			errors.append("unknown or malformed household save identity")
			continue
		var setting: Variant = record.get("value")
		if record.kind == "radiator":
			if typeof(setting) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(setting)) \
					or float(setting) < 0.0 or float(setting) > 1.0:
				errors.append("invalid saved radiator position")
		elif record.kind == "books":
			if not _valid_book_order(str(identity), setting): errors.append("saved books must be the resident library permutation")
		elif setting is not bool:
			errors.append("household switch/door value must be boolean")
	return errors.is_empty()

func _valid_book_order(identity: String, value: Variant) -> bool:
	if value is not Array or not _defaults.get("records", {}).has(identity): return false
	var expected: Array = _defaults.records[identity].value
	if value.size() != expected.size(): return false
	var seen := {}
	for book: Variant in value:
		if book is not String or not expected.has(book) or seen.has(book): return false
		seen[book] = true
	return true

func snapshot() -> Dictionary:
	var records := {}
	for identity: String in _subjects:
		var prop = _subjects[identity]
		if not is_instance_valid(prop) or not prop.is_inside_tree() or prop.is_queued_for_deletion(): return {}
		var kind: String = _kinds[identity]
		var setting: Variant
		match kind:
			"fuse_service", "tank_service": setting = _service_completed[identity]
			"light": setting = prop.get("powered")
			"radiator": setting = prop.get("supply_position")
			"prep": setting = prop.get("opened")
			"mirror": setting = prop.call("is_door_open")
			"books": setting = prop.get("sorter").order.duplicate()
		records[identity] = {"kind":kind, "value":setting}
	return {"schema_version":1, "records":records}

func _restore(saved: Dictionary) -> void:
	_restoring = true
	for identity: String in _subjects:
		var record: Dictionary = saved.records.get(identity, _defaults.records[identity])
		var prop: Node = _subjects[identity]
		match record.kind:
			"fuse_service", "tank_service": _restore_service(identity, record.value)
			"light": prop.call("set_powered", record.value)
			"radiator": prop.call("set_supply_position", float(record.value), 0.0)
			"books": prop.call("restore_order", record.value)
			_: prop.call("restore_open_state", record.value)
	_last_saved = saved.duplicate(true)
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
		var activity := "fuse_panel_rating_service" if SERVICE_KINDS[identity] == "fuse_service" else "roof_tank_ballcock_service"
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
	var completed: bool = (prop.get("panel_safe") and prop.call("protects_conductor")) \
		if SERVICE_KINDS[identity] == "fuse_service" else (prop.get("ballcock_serviced") and prop.call("valve_holds"))
	if not completed: return
	_service_completed[identity] = true
	_commit_change()

func _on_state_changed() -> void:
	if not _bound or _restoring: return
	var saved: Variant = _saved_value()
	# A load/reset replaces facts underneath an existing world. Adopt only a
	# fully valid document; never flush stale controls back into the new save.
	if not validate(saved, _kinds):
		_blocked = true
		return
	var current := snapshot()
	if current.is_empty(): return
	var expected := _defaults.duplicate(true)
	for identity: String in saved.records: expected.records[identity] = saved.records[identity]
	if not _blocked and saved == _last_saved and current == expected: return
	_restore(saved)

func capture_now() -> bool:
	if not _bound or _restoring or _blocked or RealityState.save_write_blocked or not is_inside_tree(): return false
	var saved: Variant = _saved_value()
	if saved != _last_saved:
		_on_state_changed()
		return false
	var current := snapshot()
	if current.is_empty() or not validate(current, _kinds) or current == saved: return false
	RealityState.data[KEY] = current
	_last_saved = current.duplicate(true)
	return true

func _capture_snapshot() -> void:
	capture_now()

func _commit_change() -> void:
	if capture_now(): RealityState.commit()

func _on_room_changed(_room: String, _on: bool) -> void:
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
