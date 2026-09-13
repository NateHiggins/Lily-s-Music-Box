extends RefCounted
## All six household receivers use the existing radio profiles and behavior.
## Furniture supports own their transforms and destruction.
const PATH := "res://data/orison_v2/domestic_radios.json"
const PROFILES := "res://data/domestic_radios.json"
const Radio := preload("res://scripts/building/orison_v2_radio_prop.gd")
const UNITS := ["2A", "2B", "3A", "3B", "4A", "4B"]
const PLACED_PROFILES := {
	"2A": ["atwater_kent_44", "cone"], "2B": ["three_dial_battery", "cone"],
	"3A": ["crystal_set", "headphones"], "3B": ["three_dial_battery", "horn"],
	"4A": ["atwater_kent_44", "cone"], "4B": ["three_dial_battery", "cone"]
}
var errors: Array[String] = []

func mount(adapter: Variant) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILES))
	if not validate(source, catalog, adapter): return false
	for record: Dictionary in source.receivers:
		var profile: Dictionary = {}
		for candidate: Dictionary in catalog.profiles:
			if candidate.unit == record.unit: profile = candidate.duplicate(true)
		profile.anchor = record.support
		profile.surface_y = record.position[1]
		var radio := Radio.new()
		radio.configure(profile)
		radio.name = record.id
		radio.position = Vector3(record.position[0],record.position[1],record.position[2])
		radio.rotation.y = float(record.yaw)
		radio.set_meta("v2_radio_support", str(record.support))
		(adapter.resolve(record.support) as Node3D).add_child(radio)
	return true

func validate(source: Variant, catalog: Variant, adapter: Variant) -> bool:
	errors.clear()
	if source is not Dictionary or source.get("schema_version") != 1 \
			or source.get("receivers") is not Array or catalog is not Dictionary \
			or catalog.get("profiles") is not Array or adapter == null:
		errors.append("malformed household radio source or missing adapter")
		return false
	var profiles := {}
	for profile: Variant in catalog.profiles:
		if profile is not Dictionary or profile.get("unit") is not String: continue
		if profiles.has(profile.unit):
			errors.append("duplicate household radio profile")
		profiles[profile.unit] = profile
	var units := {}
	var ids := {}
	for record: Variant in source.receivers:
		if record is not Dictionary or record.get("unit") not in UNITS \
				or record.get("id") is not String or record.id.is_empty() \
				or record.get("support") is not String:
			errors.append("invalid household radio identity")
			continue
		if units.has(record.unit) or ids.has(record.id) or not profiles.has(record.unit):
			errors.append("duplicate or missing household radio profile")
		if profiles.has(record.unit):
			var profile: Dictionary = profiles[record.unit]
			if [profile.get("family"), profile.get("speaker")] != PLACED_PROFILES[record.unit]:
				errors.append("household receiver family needs a supported V2 placement")
		units[record.unit] = true
		ids[record.id] = true
		if not adapter.resolve(record.support) is StaticBody3D or adapter.resolve(record.id) != null:
			errors.append("missing radio support or occupied identity: " + str(record.id))
		var position: Variant = record.get("position")
		if position is not Array or position.size() != 3:
			errors.append("invalid radio position")
		else:
			for value: Variant in position:
				if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):
					errors.append("nonfinite radio position")
		var yaw: Variant = record.get("yaw")
		if typeof(yaw) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(yaw)):
			errors.append("invalid radio yaw")
	if units.size() != UNITS.size(): errors.append("incomplete detailed-apartment receiver roster")
	return errors.is_empty()
