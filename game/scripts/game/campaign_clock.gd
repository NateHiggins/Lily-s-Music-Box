class_name CampaignClock
extends RefCounted
## Authored civil date; local hour/minute sampled once, elapsed simulation saved.

const CALENDAR_PATH := "res://data/campaign_calendar.json"
const SCHEMA_VERSION := 2
const MINUTES_PER_DAY := 1440
const DAY_NAMES := ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
const MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const LAST_ORDINAL := 3652058 # 9999-12-31; 0001-01-01 = 0.

## Deterministic creation seam. Date fields have no authority; reload never calls it.
var creation_time_provider: Callable
var validation_error := ""
var _state: Dictionary = {}


func bind_state() -> bool:
	if RealityState.save_write_blocked:
		validation_error = "The saved campaign is protected; no new clock was created."
		return false
	if not validate_saved_state():
		return false
	_state = RealityState.data.get("campaign_clock", {})
	if _state.is_empty():
		return _initialize_authored_epoch()
	if not _state.has("schema_version"):
		return _migrate_legacy()
	return true


## No sampling or mutation; load validates before older save-version migration.
func validate_saved_state() -> bool:
	validation_error = ""
	var saved: Variant = RealityState.data.get("campaign_clock", {})
	if saved is not Dictionary:
		return _invalid("The saved campaign clock is not a record.")
	var value: Dictionary = saved
	if value.is_empty():
		return true
	if not _integer_between(value.get("start_minute_of_day"), 0, 1439) \
			or not _finite_number(value.get("elapsed_minutes")) \
			or float(value.elapsed_minutes) < 0.0:
		return _invalid("The saved start time or elapsed duration is invalid.")
	if not value.has("schema_version"):
		var last_key := 365 if str(value.get("epoch_date", "")) == "TEST_INJECTED" else 366
		if str(value.get("start_weekday", "")) not in DAY_NAMES \
				or not _integer_between(value.get("start_doy"), 1, last_key) \
				or float(value.elapsed_minutes) > 4000000000.0:
			return _invalid("The legacy campaign clock is incomplete or outside the calendar range.")
		return true
	if not _integer_between(value.get("schema_version"), SCHEMA_VERSION, SCHEMA_VERSION):
		return _invalid("This campaign clock version is not supported.")
	var mode := str(value.get("calendar_mode", ""))
	if mode == "test_schedule_365":
		if str(value.get("start_weekday", "")) not in DAY_NAMES \
				or not _integer_between(value.get("start_doy"), 1, 365) \
				or float(value.elapsed_minutes) > 4000000000.0:
			return _invalid("The injected schedule clock is invalid.")
		return true
	if mode != "gregorian" or not _valid_date_values(value):
		return _invalid("The saved campaign date is invalid.")
	if str(value.get("timezone", "")) != "America/New_York" \
			or not _integer_between(value.get("utc_offset_minutes"), -300, -300):
		return _invalid("The saved campaign time zone is invalid.")
	var ordinal := _ordinal(int(value.year), int(value.month), int(value.day_of_month))
	if float(value.elapsed_minutes) >= float(LAST_ORDINAL - ordinal + 1) * MINUTES_PER_DAY \
			- float(value.start_minute_of_day):
		return _invalid("The saved campaign duration exceeds the calendar range.")
	if str(value.get("epoch_date", "")) != _date_string(value) \
			or str(value.get("start_weekday", "")) != DAY_NAMES[ordinal % 7] \
			or not _integer_between(value.get("start_doy"), _schedule_doy(value), _schedule_doy(value)):
		return _invalid("The saved campaign date fields disagree.")
	return true


func _invalid(reason: String) -> bool:
	validation_error = reason
	RealityState.block_invalid_campaign_clock(reason)
	return false


func _authored_date() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CALENDAR_PATH))
	if parsed is not Dictionary:
		return {}
	var calendar: Dictionary = parsed
	var date := {"year": calendar.get("year"), "month": calendar.get("month"),
			"day_of_month": calendar.get("day")}
	if not _integer_between(calendar.get("schema_version"), 1, 1) \
			or not _valid_date_values(date) \
			or str(calendar.get("timezone", "")) != "America/New_York" \
			or not _integer_between(calendar.get("utc_offset_minutes"), -300, -300):
		return {}
	return date


func _initialize_authored_epoch() -> bool:
	var date := _authored_date()
	if date.is_empty():
		return _invalid("The authored campaign calendar is invalid.")
	var sample: Variant = creation_time_provider.call() if creation_time_provider.is_valid() \
			else _sample_local_minute_of_day()
	if sample is not Dictionary:
		return _invalid("The campaign creation time could not be sampled.")
	if not _integer_between(sample.get("hour"), 0, 23) \
			or not _integer_between(sample.get("minute"), 0, 59):
		return _invalid("The campaign creation time could not be sampled.")
	_state = _civil_record(date, int(sample.hour) * 60 + int(sample.minute))
	RealityState.data.campaign_clock = _state
	RealityState.commit()
	return true


## Sole world-calendar host read; no host date, seconds, zone or DST authority.
func _sample_local_minute_of_day() -> Dictionary:
	var time := Time.get_time_dict_from_system()
	return {"hour": int(time.hour), "minute": int(time.minute)}


func _migrate_legacy() -> bool:
	var old := _state.duplicate(true)
	if str(old.get("epoch_date", "")) == "TEST_INJECTED":
		_state.schema_version = SCHEMA_VERSION
		_state.calendar_mode = "test_schedule_365"
	else:
		var date := _authored_date()
		if date.is_empty():
			return _invalid("The authored campaign calendar is invalid.")
		_state = _civil_record(date, int(old.start_minute_of_day))
		_state.elapsed_minutes = float(old.elapsed_minutes)
		_state.migration = "host_date_rebased_to_authored_date; start_time_and_elapsed_preserved"
	RealityState.data.campaign_clock = _state
	RealityState.commit()
	return true


static func _civil_record(date: Dictionary, minute: int) -> Dictionary:
	var ordinal := _ordinal(int(date.year), int(date.month), int(date.day_of_month))
	return {"schema_version": SCHEMA_VERSION, "calendar_mode": "gregorian",
			"year": int(date.year), "month": int(date.month), "day_of_month": int(date.day_of_month),
			"timezone": "America/New_York", "utc_offset_minutes": -300,
			"epoch_date": _date_string(date), "start_weekday": DAY_NAMES[ordinal % 7],
			"start_doy": _schedule_doy(date), "start_minute_of_day": minute,
			"elapsed_minutes": 0.0}


## Explicit civil fixture seam. Production creates from CALENDAR_PATH.
func configure_date(year: int, month: int, day_of_month: int, minute := 0) -> bool:
	var date := {"year": year, "month": month, "day_of_month": day_of_month}
	if not _valid_date_values(date) or minute < 0 or minute >= MINUTES_PER_DAY:
		return false
	_state = _civil_record(date, minute)
	RealityState.data.campaign_clock = _state
	RealityState.commit()
	return true


## Legacy fixtures combine arbitrary weekdays and 365-key dates. Their abstract
## calendar remains explicit and cannot claim a Gregorian civil date.
func configure_start(day: String, doy := 1, minute_of_day := 0) -> bool:
	if day not in DAY_NAMES or doy < 1 or doy > 365 \
			or minute_of_day < 0 or minute_of_day >= MINUTES_PER_DAY:
		return false
	_state = {"schema_version": SCHEMA_VERSION, "calendar_mode": "test_schedule_365",
			"start_weekday": day, "start_doy": doy, "start_minute_of_day": minute_of_day,
			"elapsed_minutes": 0.0, "epoch_date": "TEST_INJECTED"}
	RealityState.data.campaign_clock = _state
	RealityState.commit()
	return true


func elapsed_minutes() -> float:
	return float(_state.elapsed_minutes) if bind_state() else 0.0


func absolute_minutes() -> float:
	if not bind_state():
		return NAN
	var ordinal := _ordinal(int(_state.year), int(_state.month), int(_state.day_of_month)) \
			if str(_state.calendar_mode) == "gregorian" else int(_state.start_doy) - 1
	return float(ordinal) * MINUTES_PER_DAY + float(_state.start_minute_of_day) \
			+ float(_state.elapsed_minutes)


func advance_to(target_minute: float) -> bool:
	if not is_finite(target_minute) or not bind_state() \
			or target_minute < float(_state.elapsed_minutes) or not _within_range(target_minute):
		return false
	_state.elapsed_minutes = target_minute
	RealityState.commit()
	return true


func advance_seconds(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or not bind_state():
		return
	var target := float(_state.elapsed_minutes) + delta / 60.0
	if _within_range(target):
		_state.elapsed_minutes = target


func _within_range(elapsed: float) -> bool:
	if str(_state.calendar_mode) == "test_schedule_365":
		return elapsed <= 4000000000.0
	var ordinal := _ordinal(int(_state.year), int(_state.month), int(_state.day_of_month))
	return elapsed < float(LAST_ORDINAL - ordinal + 1) * MINUTES_PER_DAY \
			- float(_state.start_minute_of_day)


func minute_of_day() -> float:
	return fposmod(float(_state.start_minute_of_day) + float(_state.elapsed_minutes),
			float(MINUTES_PER_DAY)) if bind_state() else 0.0


func start_weekday() -> String:
	return str(_state.get("start_weekday", ""))


func day_info() -> Dictionary:
	return day_info_at(elapsed_minutes())


func day_info_at(elapsed_minute: float) -> Dictionary:
	if not bind_state() or not is_finite(elapsed_minute) or elapsed_minute < 0.0 \
			or not _within_range(elapsed_minute):
		return {"valid": false, "reason": validation_error if not validation_error.is_empty()
				else "campaign time is outside the supported range"}
	var total := float(_state.start_minute_of_day) + elapsed_minute
	var offset := int(total / MINUTES_PER_DAY)
	var info: Dictionary
	if str(_state.calendar_mode) == "test_schedule_365":
		var doy := ((int(_state.start_doy) - 1 + offset) % 365) + 1
		var date := _date_from_schedule_doy(doy)
		info = {"day": DAY_NAMES[(DAY_NAMES.find(start_weekday()) + offset) % 7],
				"doy": doy, "month": date.month, "day_of_month": date.day_of_month,
				"civil_date_valid": false}
	else:
		var ordinal := _ordinal(int(_state.year), int(_state.month), int(_state.day_of_month)) + offset
		info = _date_from_ordinal(ordinal)
		info.day = DAY_NAMES[ordinal % 7]
		info.doy = _schedule_doy(info)
		info.civil_doy = _doy_of(int(info.year), int(info.month), int(info.day_of_month))
		info.civil_date_valid = true
		info.timezone = _state.timezone
		info.utc_offset_minutes = _state.utc_offset_minutes
	info.valid = true
	info.first_sat = info.day == "sat" and int(info.day_of_month) <= 7
	info.minute_of_day = fposmod(total, float(MINUTES_PER_DAY))
	return info


func local_datetime() -> Dictionary:
	var info := day_info()
	if not bool(info.get("valid", false)) or not bool(info.get("civil_date_valid", false)):
		return {}
	return _datetime_from_minutes(absolute_minutes())


func utc_datetime() -> Dictionary:
	if not bind_state() or str(_state.calendar_mode) != "gregorian":
		return {}
	return _datetime_from_minutes(absolute_minutes() - float(_state.utc_offset_minutes))


func datetime_string() -> String:
	var date := local_datetime()
	if date.is_empty():
		return "TIME UNAVAILABLE"
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [date.year, date.month, date.day,
			date.hour, date.minute, date.second]


static func _datetime_from_minutes(total: float) -> Dictionary:
	var ordinal := int(floor(total / MINUTES_PER_DAY))
	if ordinal < 0 or ordinal > LAST_ORDINAL:
		return {}
	var date := _date_from_ordinal(ordinal)
	var seconds := mini(86399,
			int(floor(fposmod(total, float(MINUTES_PER_DAY)) * 60.0 + 0.00001)))
	return {"year": date.year, "month": date.month, "day": date.day_of_month,
			"weekday": (ordinal + 1) % 7, "hour": seconds / 3600,
			"minute": (seconds / 60) % 60, "second": seconds % 60, "dst": false}


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _integer_between(value: Variant, low: int, high: int) -> bool:
	return _finite_number(value) and float(value) == floor(float(value)) \
			and float(value) >= low and float(value) <= high


static func _valid_date_values(date: Dictionary) -> bool:
	if not _integer_between(date.get("year"), 1, 9999) \
			or not _integer_between(date.get("month"), 1, 12):
		return false
	return _integer_between(date.get("day_of_month"), 1,
			_days_in_month(int(date.year), int(date.month)))


static func _days_in_month(year: int, month: int) -> int:
	return 29 if month == 2 and _is_leap(year) else MONTH_DAYS[month - 1]


static func _is_leap(year: int) -> bool:
	return year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)


static func _doy_of(year: int, month: int, day: int) -> int:
	var total := day
	for index in range(1, month):
		total += _days_in_month(year, index)
	return total


static func _schedule_doy(date: Dictionary) -> int:
	if int(date.month) == 2 and int(date.day_of_month) == 29:
		return 0 # No recurring anniversary in the authored 365-key table.
	return _doy_of(1927, int(date.month), int(date.day_of_month))


static func _ordinal(year: int, month: int, day: int) -> int:
	var previous := year - 1
	return 365 * previous + previous / 4 - previous / 100 + previous / 400 \
			+ _doy_of(year, month, day) - 1


static func _date_from_ordinal(ordinal: int) -> Dictionary:
	var low := 1
	var high := 9999
	while low < high:
		var middle := (low + high + 1) / 2
		if _ordinal(middle, 1, 1) <= ordinal:
			low = middle
		else:
			high = middle - 1
	var remaining := ordinal - _ordinal(low, 1, 1) + 1
	var month := 1
	while remaining > _days_in_month(low, month):
		remaining -= _days_in_month(low, month)
		month += 1
	return {"year": low, "month": month, "day_of_month": remaining}


static func _date_from_schedule_doy(doy: int) -> Dictionary:
	var month := 1
	while doy > int(MONTH_DAYS[month - 1]):
		doy -= int(MONTH_DAYS[month - 1])
		month += 1
	return {"month": month, "day_of_month": doy}


static func _date_string(date: Dictionary) -> String:
	return "%04d-%02d-%02d" % [date.year, date.month, date.day_of_month]
