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
	if str(clock.get("epoch", "")) != "campaign_start" \
			or bool(clock.get("host_clock_allowed", true)):
		errors.append("simulation clock must use the campaign epoch, never host time")
	return errors.is_empty()


func shop_id(value: String) -> String:
	var normalized := value.strip_edges().to_upper().replace("-", "_").replace(" ", "_")
	if normalized == "BODEGA":
		return str(data.get("shop_namespace", {}).get("canonical_bodega_id", ""))
	return normalized if normalized.begins_with("SHOP_") else ""


func exterior_home() -> String:
	return str(data.get("exterior_output", {}).get("authoritative_data_home", ""))
