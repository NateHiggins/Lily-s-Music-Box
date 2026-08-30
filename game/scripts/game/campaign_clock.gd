class_name CampaignClock
extends RefCounted
## Durable campaign time. The host supplies one creation-time epoch only;
## elapsed campaign time is subsequently simulation-owned.

const MINUTES_PER_DAY := 1440
const DAY_NAMES := ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

var _state: Dictionary


func bind_state() -> bool:
	if not RealityState.data.has("campaign_clock") \
			or RealityState.data.campaign_clock is not Dictionary:
		RealityState.data.campaign_clock = {}
	_state = RealityState.data.campaign_clock
	_state.merge({"elapsed_minutes": 0.0, "start_minute_of_day": -1,
			"start_weekday": "", "start_doy": 0, "epoch_date": ""}, false)
	if start_weekday() not in DAY_NAMES:
		_initialize_epoch_from_host()
	return start_weekday() in DAY_NAMES


## The one authorized host-clock read: a campaign starts at the real local
## date/time, captures that epoch durably, then never consults the host again.
func _initialize_epoch_from_host() -> void:
	var date := Time.get_date_dict_from_system()
	var time := Time.get_time_dict_from_system()
	var weekday: String = DAY_NAMES[(int(date.weekday) + 6) % 7]
	_state.start_weekday = weekday
	_state.start_doy = _doy_of(int(date.year), int(date.month), int(date.day))
	_state.start_minute_of_day = int(time.hour) * 60 + int(time.minute)
	_state.elapsed_minutes = 0.0
	_state.epoch_date = "%04d-%02d-%02d" % [date.year, date.month, date.day]
	RealityState.commit()


func configure_start(day: String, doy := 1, minute_of_day := 0) -> bool:
	if day not in DAY_NAMES or doy < 1 or doy > 365:
		return false
	if minute_of_day < 0 or minute_of_day >= MINUTES_PER_DAY:
		return false
	bind_state()
	_state.start_weekday = day
	_state.start_doy = doy
	_state.start_minute_of_day = minute_of_day
	_state.elapsed_minutes = 0.0
	_state.epoch_date = "TEST_INJECTED"
	RealityState.commit()
	return true


func elapsed_minutes() -> float:
	bind_state()
	return maxf(0.0, float(_state.elapsed_minutes))


func advance_to(target_minute: float) -> bool:
	bind_state()
	if target_minute < float(_state.elapsed_minutes):
		return false
	_state.elapsed_minutes = target_minute
	RealityState.commit()
	return true


func advance_seconds(delta: float) -> void:
	if delta <= 0.0:
		return
	bind_state()
	_state.elapsed_minutes = float(_state.elapsed_minutes) + delta / 60.0


func minute_of_day() -> float:
	bind_state()
	return fposmod(float(_state.start_minute_of_day) + elapsed_minutes(),
			float(MINUTES_PER_DAY))


func start_weekday() -> String:
	return str(_state.get("start_weekday", "")) if _state != null else ""


static func _doy_of(year: int, month: int, day: int) -> int:
	var month_days := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if year % 400 == 0 or (year % 4 == 0 and year % 100 != 0):
		month_days[1] = 29
	var total := day
	for index in range(maxi(0, month - 1)):
		total += month_days[index]
	return total


func day_info() -> Dictionary:
	return day_info_at(elapsed_minutes())


func day_info_at(elapsed_minute: float) -> Dictionary:
	bind_state()
	var start := start_weekday()
	if start not in DAY_NAMES:
		return {"valid": false, "reason": "campaign start weekday is owner-required"}
	var total := maxi(0, int(_state.start_minute_of_day)) + maxf(0.0, elapsed_minute)
	var day_offset := int(total / MINUTES_PER_DAY)
	var day_index := (DAY_NAMES.find(start) + day_offset) % DAY_NAMES.size()
	var doy := ((int(_state.start_doy) - 1 + day_offset) % 365) + 1
	return {"valid": true, "day": DAY_NAMES[day_index], "doy": doy,
			"first_sat": DAY_NAMES[day_index] == "sat" and doy <= 7,
			"minute_of_day": fposmod(total, float(MINUTES_PER_DAY))}
