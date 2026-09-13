extends RefCounted
## Validate the whole batch before any construction. Existing sinks/cabinets
## own these children, so transforms and retirement follow their real support.
const PATH := "res://data/orison_v2/household_accessories.json"
const UNITS := ["2A", "2B", "3A", "3B", "4A", "4B"]
const Toaster := preload("res://scripts/building/orison_v2_toaster.gd")
const Cabinet := preload("res://scripts/building/orison_v2_medicine_cabinet.gd")
var errors: Array[String] = []

func mount(adapter: Variant) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not validate(source, adapter): return false
	var acoustic_ids: Array[String] = []
	for record: Dictionary in source.accessories:
		var prop: FunctionalProp
		if record.kind == "toaster":
			var toaster := Toaster.new()
			toaster.tray_axis = Vector3.LEFT if record.unit == "4B" else Vector3.FORWARD
			prop = toaster
		else:
			var cabinet := Cabinet.new()
			cabinet.hinge_side = str(record.hinge_side)
			prop = cabinet
		prop.prop_type = str(record.kind)
		prop.set("unit", str(record.unit))
		prop.name = str(record.id)
		prop.position = Vector3(record.position[0], record.position[1], record.position[2])
		prop.rotation.y = float(record.yaw)
		prop.set_meta("v2_accessory_support", str(record.support))
		if AcousticGraphData.nodes.has(record.id):
			prop.graph_node_id = str(record.id)
			acoustic_ids.append(str(record.id))
		adapter.resolve(str(record.support)).add_child(prop)
	if not acoustic_ids.is_empty() and not adapter.install_acoustic_overrides(acoustic_ids):
		errors.append("accessory acoustic positions could not be rebound")
		return false
	return true

func validate(source: Variant, adapter: Variant) -> bool:
	errors.clear()
	if source is not Dictionary or source.get("schema_version") != 1 \
			or source.get("accessories") is not Array or adapter == null:
		errors.append("malformed household accessory source")
		return false
	var seen := {}
	for record: Variant in source.accessories:
		if record is not Dictionary or record.get("unit") not in UNITS \
				or record.get("kind") not in ["toaster", "mirror"]:
			errors.append("invalid accessory household or kind")
			continue
		var unit_id := str(record.unit)
		var is_toaster: bool = record.kind == "toaster"
		var identity := "F0" + unit_id[0] + "_" + unit_id + ("_TOASTER_01" if is_toaster else "_MIRROR_01")
		if unit_id == "4B" and is_toaster: identity = "F04_B_TOASTER_01"
		var support := unit_id + "_prep_cabinet" if is_toaster else "F0" + unit_id[0] + "_" + unit_id + "_SINK_01"
		if seen.has(identity) or record.get("id") != identity or record.get("support") != support:
			errors.append("duplicate or incorrect accessory identity/support")
		seen[identity] = true
		var owner: Node = adapter.resolve(support)
		if (is_toaster and not owner is StaticBody3D) \
				or (not is_toaster and (not owner is TapProp or owner.get("fixture") != "bath_sink")) \
				or adapter.resolve(identity) != null:
			errors.append("missing accessory support or occupied identity")
		var expected := [0.0, .9, 0.0] if is_toaster else [0.0, .04,
				{"2A":.242, "2B":.202, "3A":.242, "3B":.392, "4A":.202, "4B":.222}[unit_id]]
		var at: Variant = record.get("position")
		if at is not Array or at.size() != 3:
			errors.append("invalid accessory position")
		else:
			for i in 3:
				if typeof(at[i]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(at[i])) \
						or not is_equal_approx(float(at[i]), float(expected[i])):
					errors.append("accessory must use its validated support contact")
		if typeof(record.get("yaw")) not in [TYPE_INT, TYPE_FLOAT] or record.yaw != 0:
			errors.append("accessory must face its validated clearance")
		if not is_toaster and record.get("hinge_side") != ("left" if unit_id == "4B" else "right"):
			errors.append("cabinet must retain its authored hinge")
		if is_toaster and record.get("tray_axis") != ("-x" if unit_id == "4B" else "-z"):
			errors.append("toaster must retain its authored tray exit")
	if seen.size() != 12 or source.accessories.size() != 12:
		errors.append("incomplete six-home accessory roster")
	return errors.is_empty()
