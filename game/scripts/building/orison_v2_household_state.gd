extends Node
## Durable control settings by semantic ID. RealityState alone writes saves.
## Physical library stock also keeps its pose and velocity here. No second save
## owner is introduced; animations, playing audio and service panels do not persist.
const KEY := "v2_household_controls"
const GASKET_COUNTER := "FireMaintenanceCounter"
const GASKET_ITEM := "fire_hose_spare_gasket"
const Book := preload("res://scripts/props/v2_readable_book.gd")
const TraceCustody := preload("res://scripts/songbook/found_trace_custody.gd")
const PlayerOriginals := preload("res://scripts/songbook/player_original_custody.gd")
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
var _purchased_gasket_commit_active := false
const SERVICE_KINDS := {"B1_FUSE_PANEL":"fuse_service", "ROOF_TANK_BALLCOCK":"tank_service", "B1_BOILER_01":"boiler_service"}
const SAVED_KINDS := ["mechanism", "light", "blind", "radiator", "prep", "books", "mirror", "window", "fuse_service", "tank_service", "boiler_service"]
## Saved identities set aside because the world no longer builds their fitting.
var retired_identities: Array[String] = []
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
	var explicit_owners: Dictionary = {}  # Node -> true; looked up once per world node below
	for identity: String in _kinds:
		var subject: Node = adapter.resolve(identity)
		if subject == null: continue
		if _kinds[identity]=="window": subject=subject.get_node_or_null("OperatingWindow")
		elif _kinds[identity]=="blind": subject=subject.get_node_or_null("WindowTreatment")
		if subject != null: explicit_owners[subject] = true
	for mechanism: Node in adapter.root.find_children("*","Node3D",true,false):
		if not mechanism.has_method("mechanism_snapshot") or explicit_owners.has(mechanism): continue
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
	return _without_retired_fittings(RealityState.data[KEY] if RealityState.data.has(KEY) else {"schema_version":1, "records":{}})

## A save written before a fitting left the world keeps that fitting's record
## (F01_INNER_DOOR was unhung on 2026-10-26). Nothing owns it any more, so the
## record is set aside instead of refusing the whole household and with it the
## world: _restore() and snapshot() only walk owned fittings, so the next save
## omits it. Only well-formed records of a saved kind are set aside; malformed
## records and kind mismatches still fail validation.
func _without_retired_fittings(saved: Variant) -> Variant:
	if _kinds.is_empty() or saved is not Dictionary or saved.get("records") is not Dictionary: return saved
	var retired: Array[String] = []
	for identity: Variant in saved.records:
		if identity is not String or _kinds.has(identity): continue
		var record: Variant = saved.records[identity]
		if record is Dictionary and record.size() == 2 and record.has("value") \
				and record.get("kind") is String and record.kind in SAVED_KINDS:
			retired.append(identity)
	if retired.is_empty(): return saved
	var kept: Dictionary = saved.duplicate()
	kept.records = saved.records.duplicate()
	for identity: String in retired: kept.records.erase(identity)
	if retired != retired_identities:
		retired_identities = retired
		push_warning("V2 household: set aside saved records for fittings the world no longer has: %s" % [retired])
	return kept

func validate(value: Variant, kinds: Dictionary) -> bool:
	# Public/load validation always checks the complete payload.
	return _validate(value, kinds, {}, RealityState.data)

func _validate(value: Variant, kinds: Dictionary, trusted_records: Dictionary, document: Dictionary) -> bool:
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
	var adopted_gasket_station := ""
	for identity: Variant in value.records:
		var record: Variant = value.records[identity]
		if identity is not String or not kinds.has(identity) or record is not Dictionary \
				or record.size() != 2 or record.get("kind") is not String \
				or record.kind != kinds[identity]:
			errors.append("unknown or malformed household save identity: %s (saved %s, world %s)" % [
				str(identity), str(record.get("kind")) if record is Dictionary else type_string(typeof(record)),
				str(kinds.get(identity, "absent")) if identity is String else "not a name"])
			continue
		var setting: Variant = record.get("value")
		if record.kind == "mechanism" and setting is Dictionary and setting.has("replacement_gasket"):
			if not adopted_gasket_station.is_empty() or _gasket_station_id(_subjects.get(identity)) != identity:
				errors.append("duplicate or unknown purchased gasket cabinet")
				continue
			adopted_gasket_station = identity
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
	if errors.is_empty() and not _valid_purchased_gasket_pair(value.records, document, adopted_gasket_station):
		errors.append("inconsistent purchased gasket custody")
	if errors.is_empty() and not CarriedCase.valid_packed_inserts(document.get(CarriedCase.KEY, {}), value.records):
		errors.append("inconsistent packed vent insert custody")
	if errors.is_empty() and not valid_kitchen_custody(document.get(CarriedCase.KEY, {}), value.records):
		errors.append("inconsistent kitchen tool custody")
	_profile_end("validate",profile_started)
	return errors.is_empty()


func _valid_purchased_gasket_pair(records: Dictionary, document: Dictionary, adopted_station: String) -> bool:
	var counter_row := _gasket_counter_row(records)
	if not counter_row.has("fitted_station"):
		# A legacy inventory-only consumption has no installed provenance.
		return adopted_station.is_empty()
	var fitted: Variant = counter_row.fitted_station
	var counter: Node = _subjects.get(GASKET_COUNTER)
	return fitted is String and not fitted.is_empty() and fitted == adopted_station \
			and is_instance_valid(counter) and counter.has_method("adopt_purchased_gasket_handoff") \
			and _gasket_payment_valid(document, true)


func _gasket_counter_row(records: Dictionary) -> Dictionary:
	var counter: Dictionary = records.get(GASKET_COUNTER, {})
	var mechanism: Variant = counter.get("value")
	if counter.get("kind") != "mechanism" or mechanism is not Dictionary:
		return {}
	var row: Variant = mechanism.get(GASKET_ITEM)
	return row if row is Dictionary else {}


func _cached_gasket_payment_valid(value: Dictionary) -> bool:
	# Unchanged household records keep the normal fast path. An adopted pair
	# also depends on the inventory and receipt in the current document.
	return not _gasket_counter_row(value.records).has("fitted_station") \
			or _gasket_payment_valid(RealityState.data, true)


func _gasket_payment_valid(document: Dictionary, consumed: bool) -> bool:
	var items: Variant = document.get("maintenance_items")
	var ledger: Variant = document.get("caretaker_economy")
	if items is not Dictionary or ledger is not Dictionary:
		return false
	var item: Variant = items.get(GASKET_ITEM)
	var purchases: Variant = ledger.get("purchases")
	if item is not Dictionary or item.get("shop_id") != "hardware_paint" \
			or item.get("consumed") is not bool or bool(item.consumed) != consumed \
			or purchases is not Dictionary:
		return false
	var receipt: Variant = purchases.get("maintenance_supply:" + GASKET_ITEM)
	if receipt is not Dictionary or receipt.size() != 3 or receipt.get("merchant") != "hardware_paint" \
			or receipt.get("item") != GASKET_ITEM or typeof(receipt.get("cents")) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return float(receipt.cents) == 10.0


func _gasket_station_id(cabinet: Node) -> String:
	if not is_instance_valid(cabinet) or not cabinet.has_method("stage_purchased_gasket"):
		return ""
	var identity := str(cabinet.get("station_id"))
	return identity if str(cabinet.name) == identity and _subjects.get(identity) == cabinet else ""


## Invoked by the counter only after an authorized primary release. Staging
## allocates a hidden cabinet body before save preparation. It stays absent
## from the live mechanism snapshot until the verified publication.
func commit_purchased_gasket(counter: Node, cabinet: Node, pickup: Node, fit: Dictionary) -> bool:
	if _purchased_gasket_commit_active or fit.is_empty() \
			or not _gasket_handoff_bound(counter, cabinet, pickup) \
			or not RealityState.has_method("commit_purchased_gasket_handoff") \
			or not _gasket_payment_valid(RealityState.data, false):
		return false
	var merchant := counter.get("merchant") as MaintenanceShopService
	if not is_instance_valid(merchant) or not is_instance_valid(merchant.inventory):
		return false
	var inventory: MaintenanceInventory = merchant.inventory
	var station_id := _gasket_station_id(cabinet)
	_purchased_gasket_commit_active = true
	var staged: Dictionary = cabinet.call("stage_purchased_gasket", pickup, fit)
	var saved := false
	if not staged.is_empty():
		var prepare := func(document: Dictionary) -> Dictionary:
			if not is_instance_valid(counter) or not is_instance_valid(merchant) \
					or counter.get("merchant") != merchant or merchant.inventory != inventory:
				return {}
			return _prepare_gasket_household(counter, cabinet, pickup, station_id, staged, document)
		var publish := func(verified: Dictionary) -> void:
			_publish_gasket_household(counter, cabinet, station_id, verified)
		saved = bool(RealityState.call("commit_purchased_gasket_handoff", inventory, prepare, publish))
	if not saved and is_instance_valid(cabinet):
		cabinet.call("discard_staged_purchased_gasket")
	_purchased_gasket_commit_active = false
	return saved


## Kitchen prep stock in the inventory (order w4b7f08c909bb; Lily 2026-11-24 and ruling
## held_put_down_20261124). Taking moves a tool into the carried case and into the hand;
## the station marks it stowed. The case and the station save together, so a reload never
## shows both copies. Putting it down empties the hand; the item stays in the case.
## Using it at its own station puts it back at its authored rest.
func kitchen_station(identity: String) -> Node:
	var station: Node = _subjects.get(identity)
	return station if is_instance_valid(station) and _kinds.get(identity) == "mechanism" \
			and station.has_method("rest_clear") else null


func packed_kitchen_tool(item: String) -> Dictionary:
	var parts := CarriedCase.kitchen_tool_parts(item)
	if parts.is_empty() or not CarriedCase.book().places.has(item):
		return {}
	var station := kitchen_station(parts[0])
	if station == null or not station.stowed.has(parts[1]):
		return {}
	return {"station": station, "assembly": parts[1]}


func _kitchen_ready() -> bool:
	return _bound and not _restoring and not _blocked and not RealityState.save_write_blocked


func take_kitchen_tool(station: Node, assembly: String) -> bool:
	var identity := str(station.name)
	if not _kitchen_ready() or kitchen_station(identity) != station or not station.tools.has(assembly) \
			or station.stowed.has(assembly) or station.bearing_load(assembly):
		return false
	var item := CarriedCase.kitchen_tool_item(identity, assembly)
	var place := CarriedCase.first_fit(item, CarriedCase.kitchen_tool_form(item))
	if place.is_empty():
		return false
	var prepare := func(document: Dictionary) -> bool:
		var controls: Dictionary = document.get(KEY, {})
		if not controls.get("records", {}).has(identity) or station.stowed.has(assembly) \
				or station.bearing_load(assembly):
			return false
		controls.records[identity].value[assembly] = {"stowed": true}
		var grid: Dictionary = document.get_or_add(CarriedCase.KEY, {"version": 1, "places": {}})
		grid.places[item] = place
		grid[CarriedCase.HAND] = item
		return CarriedCase.valid(grid) and _validate(controls, _kinds, _last_saved.get("records", {}), document)
	return _commit_kitchen(prepare, station, identity)


func return_kitchen_tool(station: Node, assembly: String) -> bool:
	var identity := str(station.name)
	var item := CarriedCase.kitchen_tool_item(identity, assembly)
	if not _kitchen_ready() or kitchen_station(identity) != station or packed_kitchen_tool(item).is_empty() \
			or not station.rest_clear(assembly):
		return false
	var prepare := func(document: Dictionary) -> bool:
		var controls: Dictionary = document.get(KEY, {})
		if not controls.get("records", {}).has(identity) or not station.rest_clear(assembly):
			return false
		var rest: Transform3D = station.rests[assembly]
		var q := rest.basis.get_rotation_quaternion()
		controls.records[identity].value[assembly] = {"position": [rest.origin.x, rest.origin.y, rest.origin.z],
			"rotation": [q.x, q.y, q.z, q.w]}
		var grid: Dictionary = document[CarriedCase.KEY]
		grid.places.erase(item)
		if str(grid.get(CarriedCase.HAND, "")) == item:
			grid[CarriedCase.HAND] = ""
		return CarriedCase.valid(grid) and _validate(controls, _kinds, _last_saved.get("records", {}), document)
	return _commit_kitchen(prepare, station, identity)


## The station of a packed tool when the holder stands at it, for the case view's "use".
func kitchen_tool_destination(holder: PlayerController, item: String) -> Node3D:
	var packed := packed_kitchen_tool(item)
	if packed.is_empty() or not _kitchen_ready() or not is_instance_valid(holder):
		return null
	var station: Node3D = packed.station
	var rest: Vector3 = station.global_transform * station.rests[packed.assembly].origin
	# Across the floor from where the holder stands, within the reach of a hand.
	var across := Vector2(holder.global_position.x - rest.x, holder.global_position.z - rest.z).length()
	if across > 1.6 or absf(holder.global_position.y + 1.0 - rest.y) > 1.0 or not station.rest_clear(packed.assembly):
		return null
	return station if _kitchen_reach_clear(holder, station, rest) else null


## Reach is a hand's, not a radius: the eye must see the rest with nothing but the
## station's own table and stock in between (a wall between rooms is not reach).
func _kitchen_reach_clear(holder: PlayerController, station: Node, rest: Vector3) -> bool:
	var excluded: Array[RID] = [holder.get_rid()]
	for body: CollisionObject3D in station.find_children("*", "CollisionObject3D", true, false):
		excluded.append(body.get_rid())
	var eye: Vector3 = holder.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(eye, rest + Vector3.UP * .03, 0xFFFFFFFF, excluded)
	return holder.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func deliver_kitchen_tool(holder: PlayerController, item: String) -> bool:
	var station := kitchen_tool_destination(holder, item)
	return station != null and return_kitchen_tool(station, packed_kitchen_tool(item).assembly)


## Change only what the hand shows: an item already in the case, or nothing.
func set_hand(item: String) -> bool:
	if not _kitchen_ready() or CarriedCase.hand() == item:
		return false
	if not item.is_empty():
		if item.begins_with(CarriedCase.FOUND_TRACE_PREFIX):
			if not TraceCustody.is_packed(item.trim_prefix(CarriedCase.FOUND_TRACE_PREFIX)):
				return false
		elif item.begins_with(CarriedCase.RECORDED_TRACE_PREFIX):
			if not PlayerOriginals.is_packed(PlayerOriginals.id_from_item(item)):
				return false
		elif packed_kitchen_tool(item).is_empty() and packed_book(item) == null:
			return false
	var prepare := func(document: Dictionary) -> bool:
		var grid: Dictionary = document.get_or_add(CarriedCase.KEY, {"version": 1, "places": {}})
		grid[CarriedCase.HAND] = item
		return CarriedCase.valid(grid)
	return RealityState.commit_case_and_household(prepare)


func _commit_kitchen(prepare: Callable, station: Node, identity: String) -> bool:
	var publish := func(verified: Dictionary) -> void:
		_last_saved = verified.duplicate(true)
		_restoring = true
		station.restore_mechanism(verified.records[identity].value)
		_restoring = false
	return RealityState.commit_case_and_household(prepare, publish)


## A stowed tool and its case item exist together or not at all; the hand names a packed
## kitchen tool, library book or original trace.
func valid_kitchen_custody(case_book: Variant, records: Dictionary) -> bool:
	var places: Dictionary = case_book.get("places", {}) if case_book is Dictionary else {}
	for item: String in places:
		var parts := CarriedCase.kitchen_tool_parts(item)
		if item.begins_with(CarriedCase.KITCHEN_TOOL_PREFIX) and parts.is_empty():
			return false
		if parts.is_empty():
			continue
		var record: Variant = records.get(parts[0])
		if kitchen_station(parts[0]) == null or record is not Dictionary or record.get("value") is not Dictionary \
				or record.value.get(parts[1]) is not Dictionary or record.value[parts[1]].get("stowed") != true:
			return false
	for identity: String in records:
		if kitchen_station(identity) == null or records[identity].get("value") is not Dictionary:
			continue
		for assembly: Variant in records[identity].value:
			var pose: Variant = records[identity].value[assembly]
			if pose is Dictionary and pose.get("stowed") == true \
					and not places.has(CarriedCase.kitchen_tool_item(identity, str(assembly))):
				return false
	var held: String = case_book.get(CarriedCase.HAND, "") if case_book is Dictionary else ""
	if held.begins_with(CarriedCase.FOUND_TRACE_PREFIX):
		return TraceCustody.case_contains(case_book, held.trim_prefix(CarriedCase.FOUND_TRACE_PREFIX))
	if held.begins_with(CarriedCase.RECORDED_TRACE_PREFIX):
		return PlayerOriginals.case_contains(case_book, PlayerOriginals.id_from_item(held))
	return held.is_empty() or (places.has(held) and (held.begins_with(CarriedCase.KITCHEN_TOOL_PREFIX) \
		or held.begins_with(CarriedCase.BOOK_PREFIX)))


func packed_vent_insert(item: String) -> Dictionary:
	var stock: Node = _subjects.get(CarriedCase.vent_insert_stock_id())
	if not is_instance_valid(stock) or not item.begins_with(CarriedCase.VENT_INSERT_PREFIX):
		return {}
	var row: Dictionary = stock.rows.get(item.trim_prefix(CarriedCase.VENT_INSERT_PREFIX), {})
	return row if row.get("packed", false) else {}


func vent_insert_fit(holder: PlayerController) -> Dictionary:
	var stock: Node = _subjects.get(CarriedCase.vent_insert_stock_id())
	if not _bound or _restoring or _blocked or RealityState.save_write_blocked or not is_instance_valid(stock):
		return {}
	var identity: String = stock.held_workshop_spare(holder)
	if identity.is_empty():
		return {}
	var item := CarriedCase.VENT_INSERT_PREFIX + identity
	var place := CarriedCase.first_fit(item, CarriedCase.VENT_INSERT_FORM)
	return {"identity": identity, "item": item, "place": place} if not place.is_empty() else {}


func pack_vent_insert(holder: PlayerController) -> String:
	var fit := vent_insert_fit(holder)
	if fit.is_empty():
		return ""
	var stock: Node = _subjects[CarriedCase.vent_insert_stock_id()]
	var prepare := func(document: Dictionary) -> bool:
		if vent_insert_fit(holder) != fit:
			return false
		var controls: Dictionary = document[KEY]
		var parts: Array = controls.records[CarriedCase.vent_insert_stock_id()].value.parts
		var index := parts.find_custom(func(part): return part.id == fit.identity)
		if index < 0:
			return false
		var row: Dictionary = stock.rows[fit.identity]
		parts[index] = {"id": fit.identity, "grade": row.grade, "rack": row.before_rack}
		var grid: Dictionary = document.get_or_add(CarriedCase.KEY, {"version": 1, "places": {}})
		grid.places[fit.item] = fit.place
		return _validate(controls, _kinds, _last_saved.get("records", {}), document)
	if not _commit_vent_insert(prepare, stock):
		return ""
	holder._grab.validate()
	return fit.item


func vent_insert_destination(holder: PlayerController, item: String) -> Node3D:
	if not _bound or _restoring or _blocked or RealityState.save_write_blocked or packed_vent_insert(item).is_empty():
		return null
	return _subjects[CarriedCase.vent_insert_stock_id()].case_destination(holder, item.trim_prefix(CarriedCase.VENT_INSERT_PREFIX))


func deliver_vent_insert(holder: PlayerController, item: String) -> bool:
	var destination := vent_insert_destination(holder, item)
	if not is_instance_valid(destination):
		return false
	var stock: Node = _subjects[CarriedCase.vent_insert_stock_id()]
	var identity := item.trim_prefix(CarriedCase.VENT_INSERT_PREFIX)
	var prepare := func(document: Dictionary) -> bool:
		if vent_insert_destination(holder, item) != destination:
			return false
		var controls: Dictionary = document[KEY]
		var parts: Array = controls.records[CarriedCase.vent_insert_stock_id()].value.parts
		var index := parts.find_custom(func(part): return part.id == identity)
		if index < 0:
			return false
		if destination != stock:
			var grade: int = parts[index].grade
			var slot: String = destination.graph_node_id
			parts[index] = {"id": identity, "grade": grade, "slot": slot, "turn": stock.THREAD_END}
			controls.records[slot].value.vent_grade = grade
		document[CarriedCase.KEY].places.erase(item)
		return _validate(controls, _kinds, _last_saved.get("records", {}), document)
	return _commit_vent_insert(prepare, stock)


func _commit_vent_insert(prepare: Callable, stock: Node) -> bool:
	var publish := func(verified: Dictionary) -> void:
		_last_saved = verified.duplicate(true)
		_restoring = true
		stock.restore_mechanism(verified.records[CarriedCase.vent_insert_stock_id()].value)
		_restoring = false
	return RealityState.commit_case_and_household(prepare, publish)


func packed_book(item: String) -> Book:
	if not item.begins_with(CarriedCase.BOOK_PREFIX):
		return null
	var place := CarriedCase.place_of(item)
	var collection: Node = _subjects.get(place.get("collection", ""))
	if not is_instance_valid(collection) or not collection.has_method("book_copy"):
		return null
	return collection.book_copy(str(place.form).trim_prefix(CarriedCase.BOOK_PREFIX))


## Ruling held_books_reading_20261125: a click on a closed copy takes it into the case
## and the hand at once; nothing is carried loose.
func can_take_book(copy: Book) -> bool:
	if not _bound or _restoring or _blocked or RealityState.save_write_blocked or not is_instance_valid(copy) \
			or copy.valise_packed or copy.hand_reading or copy._held or copy.opening != 0.0 \
			or not copy.shelf.library_hand_is_free():
		return false
	var collection := str(copy.shelf.name)
	return _subjects.get(collection) == copy.shelf \
		and not CarriedCase.library_fit(collection, copy.stock_id).is_empty()


func take_book(copy: Book) -> bool:
	if not can_take_book(copy):
		return false
	var collection := str(copy.shelf.name)
	var item := CarriedCase.library_item(collection, copy.stock_id)
	var prepare := func(document: Dictionary) -> bool:
		if not can_take_book(copy):
			return false
		var grid: Dictionary = document.get_or_add(CarriedCase.KEY, {"version": 1, "places": {}})
		grid.places[item] = CarriedCase.library_fit(collection, copy.stock_id)
		grid[CarriedCase.HAND] = item
		return CarriedCase.valid(grid) and _stage_book_pose(document, collection, copy, copy.transform)
	var publish := func(verified: Dictionary) -> void:
		_last_saved = verified.duplicate(true)
		_restoring = true
		copy.shelf_slot = -1
		copy.set_valise_packed(true)
		_restoring = false
	return RealityState.commit_case_and_household(prepare, publish)


## The book in the hand goes back to its own shelf's next free place, closed.
func shelve_book(shelf: Node) -> bool:
	var item := CarriedCase.hand()
	var copy := packed_book(item)
	if not _bound or _restoring or _blocked or RealityState.save_write_blocked or not is_instance_valid(copy) \
			or copy.shelf != shelf or copy.hand_reading or not shelf.library_hand_is_free():
		return false
	var slot: int = shelf.next_free_slot(copy)
	if slot < 0:
		return false
	var collection := str(shelf.name)
	var pose: Transform3D = shelf.book_slots[slot]
	var prepare := func(document: Dictionary) -> bool:
		var current: Dictionary = document.get(KEY, {})
		if packed_book(item) != copy or not shelf.book_slot_is_free(slot, copy) \
				or not current.get("records", {}).has(collection):
			return false
		var grid: Dictionary = document[CarriedCase.KEY]
		grid.places.erase(item)
		grid[CarriedCase.HAND] = ""
		var record := copy.valise_snapshot(pose)
		record.slot = slot
		current.records[collection].value.books[copy.stock_id] = record
		return CarriedCase.valid(grid) and _validate(current, _kinds, _last_saved.get("records", {}), document)
	var publish := func(verified: Dictionary) -> void:
		_last_saved = verified.duplicate(true)
		_restoring = true
		copy.set_valise_packed(false)
		copy.restore_book(verified.records[collection].value.books[copy.stock_id])
		_restoring = false
		shelf.library_stock_changed.call_deferred(copy)
	return RealityState.commit_case_and_household(prepare, publish)


## A click with a book in the glove brings it up into the ordinary reading view, from
## the glove's own hold. Closing the view packs it again; its record never leaves the case.
func read_held_book(holder: PlayerController) -> bool:
	var copy := packed_book(CarriedCase.hand())
	if not _bound or _restoring or _blocked or not is_instance_valid(copy) or not copy.valise_packed \
			or holder.call_locked or holder.mouse_released or holder.inspecting() or holder._grab.active() \
			or not copy.shelf.library_hand_is_free():
		return false
	var camera_pose := holder.camera.global_transform
	var pose := Transform3D(camera_pose.basis, copy._hold_target(camera_pose, false))
	if not copy.valise_exit_is_clear(pose):
		return false
	copy.begin_hand_reading(pose)
	var grip := copy.grip()
	grip.hit_position = copy.to_global(copy.pickup_centre())
	if holder._grab.acquire(grip) and holder.begin_inspection():
		return true
	if holder._grab.active():
		holder._grab.release(false)
	copy.finish_hand_reading()
	return false


func can_pack_book(holder: PlayerController) -> bool:
	var copy := holder.held_stock_body() as Book
	if not _bound or _restoring or _blocked or RealityState.save_write_blocked \
			or not is_instance_valid(copy) or copy.valise_packed or copy.opening != 0.0:
		return false
	var collection := str(copy.shelf.name)
	return _subjects.get(collection) == copy.shelf \
		and not CarriedCase.library_fit(collection, copy.stock_id).is_empty()


func pack_book(holder: PlayerController) -> bool:
	if not can_pack_book(holder):
		return false
	var copy := holder.held_stock_body() as Book
	var collection := str(copy.shelf.name)
	var item := CarriedCase.library_item(collection, copy.stock_id)
	var prepare := func(document: Dictionary) -> bool:
		if not is_instance_valid(copy) or holder.held_stock_body() != copy or not can_pack_book(holder):
			return false
		document[CarriedCase.KEY].places[item] = CarriedCase.library_fit(collection, copy.stock_id)
		return _stage_book_pose(document, collection, copy, copy.transform)
	var publish := func(verified: Dictionary) -> void:
		_last_saved = verified.duplicate(true)
		_restoring = true
		copy.valise_packed = true
		holder._grab.release(false)
		copy.set_valise_packed(true)
		_restoring = false
	return RealityState.commit_case_and_household(prepare, publish)


func unpack_book(holder: PlayerController, item: String) -> bool:
	var copy := packed_book(item)
	if not _bound or _restoring or _blocked or not is_instance_valid(copy) \
			or not copy.valise_packed or holder.call_locked or holder.inspecting() or holder._grab.active() \
			or not copy.shelf.library_hand_is_free():
		return false
	var collection := str(copy.shelf.name)
	var prepare := func(document: Dictionary) -> bool:
		if not is_instance_valid(copy) or packed_book(item) != copy or holder._grab.active() \
				or not copy.shelf.library_hand_is_free():
			return false
		var camera_pose := holder.camera.global_transform
		var grip_pose := Transform3D(camera_pose.basis, copy._hold_target(camera_pose, false))
		if not copy.valise_exit_is_clear(grip_pose):
			return false
		document[CarriedCase.KEY].places.erase(item)
		return _stage_book_pose(document, collection, copy, copy.get_parent_node_3d().global_transform.affine_inverse() * grip_pose)
	var publish := func(verified: Dictionary) -> void:
		_last_saved = verified.duplicate(true)
		_restoring = true
		copy.set_valise_packed(false)
		copy.restore_book(verified.records[collection].value.books[copy.stock_id])
		var grip := copy.grip()
		grip.hit_position = copy.to_global(copy.pickup_centre())
		var acquired: bool = holder._grab.acquire(grip)
		_restoring = false
		if not acquired:
			push_error("Verified valise exit lost the reserved library hand: " + item)
	return RealityState.commit_case_and_household(prepare, publish)


func _stage_book_pose(document: Dictionary, collection: String, copy: Book, pose: Transform3D) -> bool:
	# RealityState already asked this owner to capture live controls before
	# detaching the candidate. Change only the selected copy in that snapshot.
	var current: Dictionary = document.get(KEY, {})
	if not current.get("records", {}).has(collection):
		return false
	current.records[collection].value.books[copy.stock_id] = copy.valise_snapshot(pose)
	return _validate(current, _kinds, _last_saved.get("records", {}), document)


func _gasket_handoff_bound(counter: Node, cabinet: Node, pickup: Node) -> bool:
	if not _bound or _restoring or _blocked or not is_inside_tree() or RealityState.save_write_blocked \
			or not is_same(_state_document, RealityState.data):
		return false
	for subject: Node in [counter, cabinet, pickup]:
		if not is_instance_valid(subject) or not subject.is_inside_tree() or subject.is_queued_for_deletion():
			return false
	if _subjects.get(GASKET_COUNTER) != counter or str(counter.name) != GASKET_COUNTER \
			or _gasket_station_id(cabinet).is_empty() or counter == cabinet \
			or _kinds.get(GASKET_COUNTER) != "mechanism" or _kinds.get(str(cabinet.name)) != "mechanism":
		return false
	var pickups: Variant = counter.get("pickups")
	return pickups is Dictionary and pickups.get(GASKET_ITEM) == pickup \
			and pickup.get("item_id") == GASKET_ITEM \
			and counter.has_method("purchased_gasket_handoff_snapshot") \
			and counter.has_method("adopt_purchased_gasket_handoff") \
			and cabinet.has_method("finish_staged_purchased_gasket") \
			and cabinet.has_method("discard_staged_purchased_gasket") \
			and cabinet.has_signal("manipulation_changed") and counter.has_signal("manipulation_changed")


func _prepare_gasket_household(counter: Node, cabinet: Node, pickup: Node, station_id: String,
		staged: Dictionary, document: Dictionary) -> Dictionary:
	if not _gasket_handoff_bound(counter, cabinet, pickup) or _gasket_station_id(cabinet) != station_id:
		return {}
	var current := snapshot()
	if current.is_empty():
		return {}
	var projected_counter: Dictionary = counter.call("purchased_gasket_handoff_snapshot", station_id)
	var projected_row: Variant = projected_counter.get(GASKET_ITEM)
	# Legacy unbound records remain loadable, but a live handoff must project
	# both provenance records before its inventory row can be consumed.
	if not staged.has("replacement_gasket") or projected_row is not Dictionary \
			or projected_row.get("fitted_station") != station_id:
		return {}
	current.records[station_id].value = staged.duplicate(true)
	current.records[GASKET_COUNTER].value = projected_counter.duplicate(true)
	return current if _validate(current, _kinds, {}, document) else {}


func _publish_gasket_household(counter: Node, cabinet: Node, station_id: String, verified: Dictionary) -> void:
	# Owner adoption methods are silent. All notifications follow both
	# physical projections and the cache update. The restoring guard prevents
	# the signals from capturing a second save during this verified handoff.
	_restoring = true
	cabinet.call("finish_staged_purchased_gasket", verified.records[station_id].value)
	counter.call("adopt_purchased_gasket_handoff", verified.records[GASKET_COUNTER].value)
	_last_saved = verified.duplicate(true)
	_state_document = RealityState.data
	cabinet.emit_signal("manipulation_changed")
	counter.emit_signal("manipulation_changed")
	_restoring = false


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

## What a visit to another day borrows and gives back: how the doors, windows,
## lights, radiators, cabinets, mirrors and shelves stand. Work done (the
## services), the lift, the watch's records and the fire stations are not a
## visit's to undo, and the blinds in a visit are the season fittings' own.
const VISIT_KINDS := ["light", "radiator", "prep", "books", "mirror", "window"]

func _borrowed_in_visit(identity: String) -> bool:
	if not _kinds.has(identity) or not _subjects.has(identity): return false
	return _kinds[identity] in VISIT_KINDS or (_kinds[identity] == "mechanism" and _subjects[identity] is DoorProp)

## The borrowed part of the household as it stands now, by identity.
func visit_snapshot() -> Dictionary:
	var kept := {}
	if not _bound: return kept
	var current := snapshot()
	for identity: String in current.get("records", {}):
		if _borrowed_in_visit(identity): kept[identity] = (current.records[identity] as Dictionary).duplicate(true)
	return kept

## Put the borrowed part back as `records` has it; everything else stays as it
## is. False when the house cannot take it, and then nothing has moved.
func visit_restore(records: Dictionary) -> bool:
	if not _bound or _restoring or _blocked or RealityState.save_write_blocked or not is_inside_tree(): return false
	var merged := snapshot()
	if merged.is_empty(): return false
	var moved := {}
	for identity: String in records:
		if not merged.records.has(identity) or not _borrowed_in_visit(identity): continue
		var was: Variant = records[identity]
		if was is not Dictionary or str(was.get("kind", "")) != str(_kinds[identity]): continue
		var restored: Dictionary = was.duplicate(true)
		if restored.kind == "radiator" and restored.value is Dictionary:
			var radiator := _subjects[identity] as RadiatorProp
			if is_instance_valid(radiator.native_orifices):
				# The rack and its insert identities stay outside visit rewinds.
				var insert: Dictionary = radiator.native_orifices.active(radiator)
				if not insert.is_empty():
					restored.value.vent_grade = int(insert.grade)
		if merged.records[identity] == restored: continue
		merged.records[identity] = restored
		moved[identity] = true
	if moved.is_empty(): return true
	if not validate(merged, _kinds): return false
	RealityState.data[KEY] = merged
	# Only what the visit borrowed is touched: nothing else is re-applied.
	_restore(merged, moved)
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
			"prep": setting = prop.travel_fraction()
			"mirror": setting = prop.get("_swing")
			"blind": setting = prop.call("settings_snapshot")
			"books": setting = prop.library_snapshot() if prop.has_method("library_snapshot") else prop.get("sorter").order.duplicate()
		records[identity] = {"kind":kind, "value":setting}
	_profile_end("snapshot",profile_started)
	return {"schema_version":1, "records":records}

## `only`, when given, names the identities to move; every other control is
## left exactly as it stands (a lift in travel, a clock running).
func _restore(saved: Dictionary, only: Dictionary = {}) -> void:
	_restoring = true
	for player: Node in get_tree().get_nodes_in_group("player_controller"):
		if player.has_method("cancel_manipulation"): player.cancel_manipulation()
	for identity: String in _subjects:
		if not only.is_empty() and not only.has(identity): continue
		var restore_started:=_profile_start()
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
		_profile_end("restore:"+identity,restore_started)
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
	if reuse_unchanged_validation and not _blocked and saved == _last_saved \
			and is_same(_state_document, RealityState.data) and _cached_gasket_payment_valid(saved):
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
	if reuse_unchanged_validation and not current.is_empty() and current == saved \
			and _cached_gasket_payment_valid(saved):
		errors.clear();_profile_end("capture_cached",profile_started);return false
	var trusted: Dictionary=_last_saved.get("records",{}) if reuse_unchanged_validation else {}
	if current.is_empty() or not _validate(current, _kinds, trusted, RealityState.data) or current == saved:
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
