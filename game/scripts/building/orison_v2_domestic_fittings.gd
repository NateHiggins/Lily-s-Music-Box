extends RefCounted
## Existing appliance implementations mounted through semantic anchors.
## Validate every record before mounting any consumer. The adapter owns teardown.
const PATH := "res://data/orison_v2/domestic_fittings.json"
const SCRIPTS := {
	"sink": preload("res://scripts/props/tap_prop.gd"),
	"shower": preload("res://scripts/props/tap_prop.gd"),
	"stove": preload("res://scripts/props/stove_prop.gd"),
	"fridge": preload("res://scripts/props/fridge_prop.gd")}
const PROPERTY_TYPES := {
	"sink": {"fixture": TYPE_STRING, "drain_side": TYPE_INT,
		"compact_kitchen": TYPE_BOOL, "has_drainboard": TYPE_BOOL},
	"shower": {"fixture": TYPE_STRING},
	"stove": {"ambient_lit": TYPE_BOOL},
	"fridge": {"monitor_top": TYPE_BOOL}}
var errors: Array[String] = []

func mount(adapter: Variant) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not validate(parsed, adapter):
		return false
	var acoustic_ids: Array[String] = []
	for record: Dictionary in parsed.fittings:
		if AcousticGraphData.nodes.has(record.id):
			acoustic_ids.append(str(record.id))
	if not acoustic_ids.is_empty() and not adapter.install_acoustic_overrides(acoustic_ids):
		errors.append("domestic fitting acoustic anchors could not be rebound")
		return false
	for record: Dictionary in parsed.fittings:
		var consumer: FunctionalProp = SCRIPTS[record.kind].new()
		consumer.prop_type = str(record.kind)
		consumer.set("unit", str(record.unit))
		for property: String in record.properties:
			var value: Variant = record.properties[property]
			consumer.set(property, int(value) if PROPERTY_TYPES[record.kind][property] == TYPE_INT else value)
		if AcousticGraphData.nodes.has(record.id):
			consumer.graph_node_id = str(record.id)
		if not adapter.mount_consumer(str(record.id), consumer):
			consumer.free()
			errors.append("domestic fitting mount failed: " + str(record.id))
			return false
	return true

func validate(source: Variant, adapter: Variant) -> bool:
	errors.clear()
	if source is not Dictionary or source.get("schema_version") != 1 \
			or source.get("fittings") is not Array or source.size() != 2:
		errors.append("domestic fitting source is malformed")
		return false
	if source.fittings.is_empty():
		errors.append("domestic fitting source is empty")
		return false
	var seen: Dictionary = {}
	for value: Variant in source.fittings:
		if value is not Dictionary:
			errors.append("domestic fitting record is not an object")
			continue
		var record: Dictionary = value
		var identity := str(record.get("id", ""))
		var kind := str(record.get("kind", ""))
		if record.size() != 4 or identity.is_empty() or seen.has(identity) or not SCRIPTS.has(kind) \
				or str(record.get("unit", "")).is_empty() or record.get("properties") is not Dictionary:
			errors.append("invalid or duplicate domestic fitting: " + identity)
			continue
		seen[identity] = true
		if adapter == null or adapter.resolve(identity) == null:
			errors.append("domestic fitting has no unique anchor: " + identity)
		for property: String in record.properties:
			var expected: int = PROPERTY_TYPES[kind].get(property, -1)
			var actual := typeof(record.properties[property])
			# JSON numbers decode as floats; integer settings must remain integral.
			var integer_json := expected == TYPE_INT and actual == TYPE_FLOAT \
					and is_finite(float(record.properties[property])) \
					and float(record.properties[property]) == floorf(float(record.properties[property]))
			if actual != expected and not integer_json:
				errors.append("invalid domestic fitting property: %s/%s" % [identity, property])
		if record.properties.has("drain_side") and (typeof(record.properties.drain_side) not in [TYPE_INT, TYPE_FLOAT] \
				or absf(float(record.properties.drain_side)) != 1.0):
			errors.append("domestic drainboard side must be left or right: " + identity)
		if kind in ["sink", "shower"]:
			var fixture := str(record.properties.get("fixture", ""))
			if (kind == "shower" and fixture != "shower") \
					or (kind == "sink" and fixture not in ["bath_sink", "kitchen_sink"]):
				errors.append("water fitting subtype disagrees with its kind: " + identity)
	return errors.is_empty()
