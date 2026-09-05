extends Node

var checks := 0
var failures := 0
var samples := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_test_creation()
	_test_calendar()
	_test_calendar_against_engine()
	_test_save_reload()
	_test_invalid_saved_clocks()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	print("CAMPAIGN CALENDAR: %s %d/%d" % ["PASS" if failures == 0 else "FAIL",
			checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


func _sample() -> Dictionary:
	samples += 1
	return {"hour": 23, "minute": 59, "year": 2099, "month": 2, "day": 3, "weekday": 1}


func _test_creation() -> void:
	var clock := CampaignClock.new()
	clock.creation_time_provider = _sample
	_check("new campaign binds", clock.bind_state())
	_check("creation samples hour/minute once", samples == 1 and clock.minute_of_day() == 1439)
	var info := clock.day_info()
	_check("sample date fields cannot override authored November 10", info.year == 1928
			and info.month == 11 and info.day_of_month == 10 and info.day == "sat")
	_check("leap-aware civil day preserves authored schedule key", info.civil_doy == 315 and info.doy == 314)
	_check("November 10 is not the first Saturday", not info.first_sat)
	clock.bind_state()
	clock.minute_of_day()
	clock.day_info()
	_check("readers do not resample", samples == 1)
	_check("advance through midnight", clock.advance_to(2.0))
	info = clock.day_info()
	_check("Sunday November 11 at 00:01", info.year == 1928 and info.month == 11
			and info.day_of_month == 11 and info.day == "sun" and info.minute_of_day == 1)
	_check("civil datetime string", clock.datetime_string() == "1928-11-11T00:01:00")
	var near_midnight := CampaignClock._datetime_from_minutes(1013955839.9999999)
	print("MIDNIGHT PRECISION INPUT %.12f RESULT %s" % [1013955839.9999999, near_midnight])
	_check("fraction before midnight cannot print hour24 on prior date",
			near_midnight.day == 10 and near_midnight.hour == 23
			and near_midnight.minute == 59 and near_midnight.second == 59)
	var utc := clock.utc_datetime()
	_check("authored EST converts to UTC", utc.day == 11 and utc.hour == 5 and utc.minute == 1)
	var absolute := clock.absolute_minutes()
	_check("advance preserves whole days", clock.advance_to(2887.0)
			and clock.absolute_minutes() - absolute == 2885.0)
	_check("backward and nonfinite advance rejected", not clock.advance_to(1.0)
			and not clock.advance_to(NAN) and not clock.advance_to(INF)
			and not clock.advance_to(1e308))
	var before := clock.elapsed_minutes()
	clock.advance_seconds(NAN)
	clock.advance_seconds(-1.0)
	_check("invalid delta leaves clock unchanged", clock.elapsed_minutes() == before)
	clock.advance_seconds(30.0)
	_check("simulation delta preserves fractional minutes", clock.elapsed_minutes() == before + 0.5)


func _test_calendar() -> void:
	var clock := CampaignClock.new()
	_check("valid leap date accepted", clock.configure_date(1928, 2, 28, 1439))
	clock.advance_to(1)
	var info := clock.day_info()
	_check("February 29 exists without duplicate anniversary key", info.month == 2
			and info.day_of_month == 29 and info.civil_doy == 60 and info.doy == 0)
	clock.advance_to(1441)
	info = clock.day_info()
	_check("March 1 retains legacy key60", info.month == 3 and info.day_of_month == 1
			and info.civil_doy == 61 and info.doy == 60)
	clock.configure_date(1928, 12, 31, 1439)
	clock.advance_to(1)
	info = clock.day_info()
	_check("year rollover is Gregorian", info.year == 1929 and info.month == 1
			and info.day_of_month == 1 and info.day == "tue" and info.doy == 1)
	clock.configure_date(1928, 12, 1, 0)
	_check("first Saturday is monthly", clock.day_info().first_sat)
	clock.advance_to(7 * 1440)
	_check("second Saturday is not first Saturday", not clock.day_info().first_sat)
	_check("invalid dates rejected", not clock.configure_date(1929, 2, 29)
			and not clock.configure_date(1900, 2, 29) and not clock.configure_date(1928, 13, 1))
	_check("400-year leap rule", clock.configure_date(2000, 2, 29))
	clock.configure_date(9999, 12, 31, 1439)
	_check("range exhaustion cannot overflow calendar", not clock.advance_to(1))
	clock.configure_start("fri", 100, 1439)
	clock.advance_to(2)
	info = clock.day_info()
	_check("legacy schedule fixtures retain arbitrary weekday relation", info.day == "sat"
			and info.doy == 101 and info.minute_of_day == 1 and not info.civil_date_valid)
	_check("abstract fixtures do not invent civil dates", clock.local_datetime().is_empty())


func _test_calendar_against_engine() -> void:
	# Independent engine conversion of supplied dates, never a host-clock read.
	var unix_epoch := CampaignClock._ordinal(1970, 1, 1)
	var first := CampaignClock._ordinal(1928, 1, 1)
	var end := CampaignClock._ordinal(1930, 1, 1)
	var all_match := true
	for ordinal in range(first, end):
		var expected := Time.get_datetime_dict_from_unix_time((ordinal - unix_epoch) * 86400)
		var actual := CampaignClock._date_from_ordinal(ordinal)
		if actual.year != expected.year or actual.month != expected.month \
				or actual.day_of_month != expected.day \
				or CampaignClock._ordinal(actual.year, actual.month, actual.day_of_month) != ordinal \
				or (ordinal + 1) % 7 != expected.weekday:
			all_match = false
			break
	_check("all 731 days of 1928/1929 agree with independent engine date conversion", all_match)


func _test_save_reload() -> void:
	var directory := "user://tests/campaign_calendar"
	_check("isolated save directory created", DirAccess.make_dir_recursive_absolute(directory) == OK)
	RealityState.save_path = directory + "/save.json"
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.creation_time_provider = _sample
	clock.bind_state()
	clock.advance_to(1621.5)
	RealityState.data.discovered_documents = ["calendar_reload_witness"]
	RealityState.persistence_enabled = true
	_check("real save writes", RealityState.save_game())
	var expected := clock.datetime_string()
	var calls := samples
	RealityState.load_game()
	var loaded := CampaignClock.new()
	loaded.creation_time_provider = _sample
	_check("real reload preserves epoch and elapsed", loaded.datetime_string() == expected)
	_check("an existing reader rebinds after load replaces the state dictionary",
			clock.datetime_string() == expected)
	_check("real reload preserves other facts and never samples host", samples == calls
			and "calendar_reload_witness" in RealityState.data.discovered_documents)
	RealityState.persistence_enabled = false
	RealityState.data.campaign_clock = {"start_weekday": "fri", "start_doy": 247,
			"start_minute_of_day": 1201, "elapsed_minutes": 2900.5, "epoch_date": "2026-09-04"}
	loaded.creation_time_provider = _sample
	_check("legacy clock migrates", loaded.bind_state())
	_check("legacy migration preserves minute and duration without resampling",
			RealityState.data.campaign_clock.epoch_date == "1928-11-10"
			and RealityState.data.campaign_clock.start_minute_of_day == 1201
			and loaded.elapsed_minutes() == 2900.5 and samples == calls)


func _test_invalid_saved_clocks() -> void:
	var clock := CampaignClock.new()
	clock.configure_date(1928, 11, 10, 600)
	var good: Dictionary = RealityState.data.campaign_clock.duplicate(true)
	for mutation in [
			["elapsed_minutes", -1], ["elapsed_minutes", INF], ["elapsed_minutes", "5"],
			["elapsed_minutes", 1e308],
			["start_minute_of_day", 1440], ["start_minute_of_day", 0.5],
			["year", 1928.5], ["month", 13], ["day_of_month", 0],
			["schema_version", 3], ["start_weekday", "mon"], ["start_doy", 315],
			["epoch_date", "2026-09-04"], ["utc_offset_minutes", -240]]:
		RealityState.reset_campaign_for_tests()
		var broken := good.duplicate(true)
		broken[mutation[0]] = mutation[1]
		RealityState.data.campaign_clock = broken
		var saved := JSON.stringify(broken)
		_check("invalid %s=%s blocks without replacing state" % [mutation[0], mutation[1]],
				not clock.bind_state() and RealityState.save_write_blocked
				and JSON.stringify(RealityState.data.campaign_clock) == saved)
	RealityState.reset_campaign_for_tests()
	RealityState.data.campaign_clock = {"start_weekday": "fri", "start_doy": 366,
			"start_minute_of_day": 0, "elapsed_minutes": 0.0, "epoch_date": "TEST_INJECTED"}
	var legacy_bad := JSON.stringify(RealityState.data.campaign_clock)
	_check("legacy fixture day366 is rejected before migration writes", not clock.bind_state()
			and JSON.stringify(RealityState.data.campaign_clock) == legacy_bad)
	RealityState.reset_campaign_for_tests()
	var malformed := good.duplicate(true)
	malformed.month = 13
	RealityState.data.campaign_clock = malformed
	var file := FileAccess.open(RealityState.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(RealityState.data))
	file.close()
	var bytes := FileAccess.get_file_as_bytes(RealityState.save_path)
	RealityState.load_game()
	RealityState.commit()
	_check("malformed clock survives real load/commit byte-identically",
			RealityState.save_write_blocked and not RealityState.save_game()
			and FileAccess.get_file_as_bytes(RealityState.save_path) == bytes
			and RealityState.player_notice().code == "campaign_clock_read_only")


func _check(label: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("  %s: %s" % ["PASS" if condition else "FAIL", label])
