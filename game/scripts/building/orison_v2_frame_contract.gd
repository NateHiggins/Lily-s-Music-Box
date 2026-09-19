class_name OrisonV2FrameContract
extends RefCounted

const PATH := "res://data/orison_v2_shared_frames.json"
const REQUIRED := ["neighbourhood", "shop_namespace", "simulation_clock",
		"anomaly_binding", "exterior_output"]

var data: Dictionary = {}
var errors: Array[String] = []


static func load_default() -> OrisonV2FrameContract:
	var contract := OrisonV2FrameContract.new()
	contract.load_path(PATH)
	return contract


func load_path(path: String) -> bool:
	errors.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		errors.append("shared-frame record is not a dictionary")
		return false
	data = (parsed as Dictionary).duplicate(true)
	for key: String in REQUIRED:
		if data.get(key) is not Dictionary:
			errors.append("missing shared-frame record: %s" % key)
	var expected_metric := "res://data/" + "building_" + "layout.json"
	if str(data.get("metric_authority", "")) != expected_metric:
		errors.append("production building layout must remain the metric authority")
	var clock: Dictionary = data.get("simulation_clock", {})
	validate_clock(clock)
	return errors.is_empty()


func validate_clock(clock: Dictionary) -> void:
	var expected := {
		"epoch": "campaign_start", "unit": "simulation_minute",
		"timezone": "America/New_York",
		"utc_offset_minutes": -300, "automatic_host_dst_allowed": false,
		"calendar_authority": "res://data/campaign_calendar.json",
		"calendar": "gregorian", "host_clock_allowed": false,
		"creation_time_sample_allowed": true,
		"creation_time_sampler": "CampaignClock._sample_local_minute_of_day",
		"host_calendar_fields_allowed": false,
		"start_weekday": "derived_from_authored_calendar",
		"start_time": "sample_local_time_of_day_once_at_campaign_creation",
		"subsequent_host_clock_reads_forbidden": true,
		"day_length_minutes": 1440,
		"elapsed_time": "absolute_simulation_minutes",
		"minute_of_day": "wrapped_presentation_and_schedule_value",
		"doy": "legacy_365_month_day_key",
		"leap_day_schedule_key": 0,
		"civil_doy": "gregorian_leap_aware",
		"first_sat": "first_saturday_of_current_month",
		"schedule_year_days": 365,
	}
	for field: String in expected:
		if clock.get(field) != expected[field]:
			errors.append("simulation clock field %s must be %s" % [field, expected[field]])
	if clock.has("calendar_year_days"):
		errors.append("a Gregorian civil year cannot be fixed at 365 days")


func shop_id(value: String) -> String:
	var normalized := value.strip_edges().to_upper().replace("-", "_").replace(" ", "_")
	if normalized == "BODEGA":
		return str(data.get("shop_namespace", {}).get("canonical_bodega_id", ""))
	return normalized if normalized.begins_with("SHOP_") else ""


func exterior_home() -> String:
	return str(data.get("exterior_output", {}).get("authoritative_data_home", ""))
