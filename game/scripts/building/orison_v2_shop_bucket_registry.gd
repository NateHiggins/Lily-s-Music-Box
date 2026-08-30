class_name OrisonV2ShopBucketRegistry
extends RefCounted
## Source-owned exterior commerce simulation.
##
## RealityState owns durability. ScheduleDirector owns resident timetable
## facts. MaintenanceInventory and MaintenanceShopService continue to own every
## maintenance part transaction. This registry consumes those facts but never
## invents a periodic restock, a job transition, an item, or a world position.

const DATA_PATH := "res://data/orison_v2/exterior/shop_buckets.json"
const STATE_KEY := "shop_buckets"
const LineageRegistry := preload(
		"res://scripts/reality/corruption_lineage_registry.gd")
const SOURCE_KEYS := ["schema_version", "shops"]
const RECORD_KEYS := ["id", "region_id", "lineage_id", "simulation_tier",
		"rendering_tier", "schedule_place", "stock_units_per_visit",
		"initial_state"]
const STATE_KEYS := ["stock", "staffing", "hours", "condition",
		"last_advanced_minute", "transactions"]
const STAFFING_KEYS := ["mode", "roles"]
const HOURS_KEYS := ["open_minute", "close_minute"]
const FACT_KEYS := ["authority", "place", "from_minute", "to_minute",
		"visits"]
const VISIT_KEYS := ["resident_id", "activity", "at_minute",
		"minute_of_day"]

var errors: Array[String] = []
var _records: Dictionary = {}
var _source: Dictionary = {}
var _bound_shop_id := ""


func load_source(path: String = DATA_PATH) -> bool:
	errors.clear()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("shop bucket source missing or empty: %s" % path)
		_clear_source()
		return false
	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Dictionary:
		errors.append("shop bucket source is not a dictionary")
		_clear_source()
		return false
	return configure(parsed as Dictionary)


func configure(source: Dictionary) -> bool:
	errors.clear()
	var indexed := _validated_records(source)
	if not errors.is_empty():
		_clear_source()
		return false
	_source = source.duplicate(true)
	_records = indexed
	_bound_shop_id = ""
	return true


func source_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id: Variant in _records:
		ids.append(str(raw_id))
	ids.sort()
	return ids


func source_record(shop_id: String) -> Dictionary:
	return (_records.get(shop_id, {}) as Dictionary).duplicate(true)


## Seed every missing bucket only after the whole source and every existing
## bucket validate. One malformed sibling therefore leaves RealityState byte
## for byte unchanged.
func initialize_missing_state() -> bool:
	errors.clear()
	if _records.is_empty() and not load_source():
		return false
	return _initialize_missing_state()


func _initialize_missing_state() -> bool:
	var existing_value: Variant = RealityState.data.get(STATE_KEY, {})
	if existing_value is not Dictionary:
		errors.append("RealityState.%s is not a dictionary" % STATE_KEY)
		return false
	var candidate: Dictionary = (existing_value as Dictionary).duplicate(true)
	for raw_id: Variant in candidate:
		var existing_id := str(raw_id)
		if not _records.has(existing_id):
			errors.append("durable state has no source record: %s" % existing_id)
			return false
	for shop_id: String in source_ids():
		if candidate.has(shop_id):
			if not _valid_state(candidate[shop_id]):
				errors.append("existing shop bucket is malformed: %s" % shop_id)
				return false
		else:
			candidate[shop_id] = _initial_state(_records[shop_id])
	if candidate != existing_value:
		RealityState.data[STATE_KEY] = candidate
		RealityState.commit()
	return true


func bind_state(shop_id: String) -> bool:
	errors.clear()
	_bound_shop_id = ""
	if _records.is_empty() and not load_source():
		return false
	if shop_id.is_empty() or not _records.has(shop_id):
		errors.append("unknown shop bucket identity: %s" % shop_id)
		return false
	if not _initialize_missing_state():
		return false
	if not _valid_state(_state_for(shop_id)):
		errors.append("bound shop bucket is malformed: %s" % shop_id)
		return false
	_bound_shop_id = shop_id
	return true


## Deterministic catch-up. `_advanced_state` is pure: mutation happens only
## after it returns a complete valid replacement.
func advance(to_minute: float, schedule_facts: Dictionary) -> bool:
	errors.clear()
	if _bound_shop_id.is_empty() or not _records.has(_bound_shop_id):
		errors.append("no source-backed shop bucket is bound")
		return false
	var current := _state_for(_bound_shop_id)
	var computation := advance_record(current, to_minute, schedule_facts,
			_records[_bound_shop_id] as Dictionary)
	if not bool(computation.get("ok", false)):
		errors.append(str(computation.get("error", "shop advance refused")))
		return false
	var replacement: Dictionary = computation.get("state", {})
	if replacement == current:
		return true
	var buckets: Dictionary = (RealityState.data[STATE_KEY] as Dictionary).duplicate(true)
	buckets[_bound_shop_id] = replacement
	RealityState.data[STATE_KEY] = buckets
	RealityState.commit()
	return true


func snapshot(shop_id: String = "") -> Dictionary:
	var wanted := _bound_shop_id if shop_id.is_empty() else shop_id
	return _state_for(wanted).duplicate(true)


func bound_shop_id() -> String:
	return _bound_shop_id


func teardown() -> void:
	_bound_shop_id = ""
	_clear_source()
	errors.clear()


func _validated_records(source: Dictionary) -> Dictionary:
	var result := {}
	if not _has_exact_keys(source, SOURCE_KEYS):
		errors.append("shop bucket source has unknown or missing fields")
	if int(source.get("schema_version", -1)) != 1:
		errors.append("shop bucket schema_version must be 1")
	var shops_value: Variant = source.get("shops")
	if shops_value is not Array or (shops_value as Array).is_empty():
		errors.append("shops must be a non-empty array")
		return result
	var lineages := LineageRegistry.new()
	if not lineages.load_registry():
		errors.append("corruption lineage registry refused its source")
		return result
	var frame := OrisonV2FrameContract.load_default()
	if not frame.errors.is_empty():
		errors.append("Orison v2 shared-frame contract refused its source")
		return result
	var canonical_bodega := frame.shop_id("bodega")
	for value: Variant in shops_value:
		if value is not Dictionary:
			errors.append("shop bucket record is not a dictionary")
			continue
		var record: Dictionary = value as Dictionary
		var shop_id := str(record.get("id", ""))
		if not _has_exact_keys(record, RECORD_KEYS):
			errors.append("%s has unknown or missing fields" % shop_id)
		if frame.shop_id(shop_id) != shop_id or result.has(shop_id):
			errors.append("invalid or duplicate shop identity: %s" % shop_id)
			continue
		var lineage_id := str(record.get("lineage_id", ""))
		if lineage_id.is_empty() or not lineages.has_space(lineage_id):
			errors.append("%s has missing lineage %s" % [shop_id, lineage_id])
		if not str(record.get("region_id", "")).begins_with("REGION_"):
			errors.append("%s has invalid region_id" % shop_id)
		if str(record.get("simulation_tier", "")).is_empty() \
				or str(record.get("rendering_tier", "")).is_empty():
			errors.append("%s has incomplete simulation/rendering tiers" % shop_id)
		if str(record.get("schedule_place", "")).is_empty():
			errors.append("%s has no schedule_place" % shop_id)
		if int(record.get("stock_units_per_visit", 0)) <= 0:
			errors.append("%s has invalid transaction rules" % shop_id)
		if not _valid_state(record.get("initial_state")):
				errors.append("%s has invalid initial_state" % shop_id)
		result[shop_id] = record.duplicate(true)
	if canonical_bodega != "SHOP_BODEGA" or not result.has(canonical_bodega):
		errors.append("canonical SHOP_BODEGA record is missing")
	return result


## Pure state transition. It does not touch RealityState, the registry, or the
## filesystem, so identical inputs always produce an identical result.
static func advance_record(current: Dictionary, to_minute: float,
		schedule_facts: Dictionary, source: Dictionary) -> Dictionary:
	if not _valid_state(current):
		return {"ok": false, "error": "bound durable shop state is malformed"}
	var previous := float(current.get("last_advanced_minute", -1.0))
	if not is_finite(to_minute) or to_minute < 0.0:
		return {"ok": false, "error": "shop simulation target is malformed"}
	if to_minute < previous:
		return {"ok": false, "error": "shop simulation cannot run backward"}
	# Catch-up is idempotent by target: repeating an already-applied request is
	# a successful no-op even when the caller retains the original fact packet.
	if is_equal_approx(to_minute, previous):
		return {"ok": true, "state": current.duplicate(true)}
	if not _has_exact_keys(schedule_facts, FACT_KEYS) \
			or str(schedule_facts.get("authority", "")) != "ScheduleDirector" \
			or str(schedule_facts.get("place", "")) \
				!= str(source.get("schedule_place", "")) \
			or not is_equal_approx(float(schedule_facts.get(
				"from_minute", -1.0)), previous) \
			or not is_equal_approx(float(schedule_facts.get(
				"to_minute", -1.0)), to_minute):
		return {"ok": false,
				"error": "schedule facts do not cover the requested shop interval"}
	var visits_value: Variant = schedule_facts.get("visits")
	if visits_value is not Array:
		return {"ok": false, "error": "schedule facts visits are not an array"}
	var seen := {}
	var eligible := 0
	var hours: Dictionary = current.get("hours", {})
	for value: Variant in visits_value:
		if value is not Dictionary:
			return {"ok": false, "error": "schedule visit is not a dictionary"}
		var visit: Dictionary = value as Dictionary
		var resident_id := str(visit.get("resident_id", ""))
		var activity := str(visit.get("activity", ""))
		var at_minute := float(visit.get("at_minute", -1.0))
		var minute_of_day := int(visit.get("minute_of_day", -1))
		var key := "%s|%.6f" % [resident_id, at_minute]
		if not _has_exact_keys(visit, VISIT_KEYS) \
				or resident_id.is_empty() or activity.is_empty() or seen.has(key) \
				or not is_finite(at_minute) \
				or at_minute <= previous or at_minute > to_minute \
				or minute_of_day < 0 or minute_of_day >= 1440:
			return {"ok": false,
					"error": "schedule visit is malformed or outside the interval"}
		seen[key] = true
		if _open_at(hours, minute_of_day):
			eligible += 1
	var result := current.duplicate(true)
	var units_per_visit := int(source.get("stock_units_per_visit", 0))
	var available := int(result.get("stock", 0))
	var successful_visits := mini(eligible,
			int(floor(float(available) / float(units_per_visit))))
	var old_transactions := int(result.get("transactions", 0))
	var new_transactions := old_transactions + successful_visits
	result["stock"] = available - successful_visits * units_per_visit
	result["transactions"] = new_transactions
	# Condition is durable but does not decay from an invented timer or visit
	# counter. A later authored consequence may change it through its authority.
	result["condition"] = int(result.get("condition", 0))
	result["last_advanced_minute"] = to_minute
	return {"ok": true, "state": result} if _valid_state(result) else {
		"ok": false, "error": "shop advance produced invalid durable state"}


func _initial_state(source: Dictionary) -> Dictionary:
	return (source.get("initial_state", {}) as Dictionary).duplicate(true)


func _state_for(shop_id: String) -> Dictionary:
	var buckets: Variant = RealityState.data.get(STATE_KEY, {})
	if buckets is not Dictionary:
		return {}
	var state: Variant = (buckets as Dictionary).get(shop_id, {})
	return state as Dictionary if state is Dictionary else {}


static func _valid_state(value: Variant) -> bool:
	if value is not Dictionary:
		return false
	var state: Dictionary = value as Dictionary
	if not _has_exact_keys(state, STATE_KEYS):
		return false
	var staffing: Variant = state.get("staffing")
	var hours: Variant = state.get("hours")
	if staffing is not Dictionary or hours is not Dictionary:
		return false
	if not _has_exact_keys(staffing as Dictionary, STAFFING_KEYS) \
			or not _has_exact_keys(hours as Dictionary, HOURS_KEYS):
		return false
	var roles: Variant = (staffing as Dictionary).get("roles")
	if str((staffing as Dictionary).get("mode", "")) != "attended" \
			or roles is not Array or (roles as Array).is_empty():
		return false
	for role: Variant in roles:
		if not (role is String) or str(role).is_empty():
			return false
	var open_minute := int((hours as Dictionary).get("open_minute", -1))
	var close_minute := int((hours as Dictionary).get("close_minute", -1))
	return open_minute >= 0 and open_minute < 1440 \
			and close_minute > 0 and close_minute <= 1440 \
			and _nonnegative_number(state.get("stock")) \
			and _nonnegative_number(state.get("condition")) \
			and _nonnegative_number(state.get("last_advanced_minute")) \
			and _nonnegative_number(state.get("transactions"))


static func _open_at(hours: Dictionary, minute_of_day: int) -> bool:
	var opening := int(hours.get("open_minute", -1))
	var closing := int(hours.get("close_minute", -1))
	return opening <= minute_of_day and minute_of_day < closing


static func _nonnegative_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
			and float(value) >= 0.0


static func _has_exact_keys(value: Dictionary, allowed: Array) -> bool:
	if value.size() != allowed.size():
		return false
	for key: Variant in allowed:
		if not value.has(key):
			return false
	return true


func _clear_source() -> void:
	_source = {}
	_records = {}
	_bound_shop_id = ""
