extends RefCounted
## Full authored demand roster; only spatially migrated emitters are mounted.
const PATH := "res://data/orison_v2/heating.json"
const Household := preload("res://scripts/building/orison_v2_household_radiator.gd")
const UNITS := ["1A", "1D", "2C", "3D", "4C", "4D", "2A", "2B", "3A", "3B", "4A", "4B", "5A", "5B", "5C", "6A", "6B", "6C"]
var errors: Array[String] = []
var balance: HeatBalance

func mount(adapter: Variant, inventory: MaintenanceInventory) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not validate(source,adapter): return false
	var acoustic_ids: Array[String] = []
	for record: Dictionary in source.installed: acoustic_ids.append(str(record.id))
	if not adapter.install_acoustic_overrides(acoustic_ids):
		errors.append("installed radiator acoustic anchors could not be rebound")
		return false
	balance = HeatBalance.new()
	balance.configure({"floors":[{"markers":source.network}]})
	for record: Dictionary in source.installed:
		var radiator: RadiatorProp = RadiatorProp.new() if record.unit == "2B" else Household.new()
		radiator.unit = record.unit
		radiator.riser = record.riser
		radiator.section_count = int(record.sections)
		radiator.installation_drop = .75
		radiator.graph_node_id = record.id
		if record.unit == "2B": radiator.bind_inventory(inventory)
		radiator.bind_heat_balance(balance)
		_add_collision(radiator)
		if not adapter.mount_consumer(record.id,radiator):
			radiator.free()
			errors.append("radiator mount refused: "+str(record.id))
			return false
	return true

func _add_collision(radiator: RadiatorProp) -> void:
	var body := StaticBody3D.new()
	body.name = "InstalledRadiatorCollision"
	var half_width := float(radiator.section_count-1)*RadiatorProp.SECTION_PITCH*.5
	# The case blocks walking; the narrower supply hull leaves the physical
	# handwheel target exposed in front of the pipe instead of burying it.
	for bounds: Array in [
		[Vector3(-half_width-.06,.07,-.10),Vector3(half_width+.06,.81,.12)],
		[Vector3(-.715,0,-.055),Vector3(-.38,.33,.055)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bounds[1]-bounds[0]
		shape.shape = box
		shape.position = (bounds[1]+bounds[0])*.5-Vector3.UP*.75
		body.add_child(shape)
	radiator.add_child(body)

func validate(source: Variant, adapter: Variant) -> bool:
	errors.clear()
	if source is not Dictionary or source.get("schema_version") != 1 or source.get("network") is not Array or source.get("installed") is not Array or adapter == null:
		errors.append("invalid heating source")
		return false
	var network := {}
	for record: Variant in source.network:
		if record is not Dictionary or record.get("kind") != "radiator" or record.get("id") is not String or record.get("unit") is not String or record.get("riser") not in ["H-A","H-B","H-C","H-D"]:
			errors.append("invalid heating demand record")
			continue
		if network.has(record.id): errors.append("duplicate heating demand")
		network[record.id] = record
		if record.get("pos") is not Array or record.pos.size() != 3:
			errors.append("invalid heating demand position")
		else:
			for value: Variant in record.pos:
				if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): errors.append("nonfinite heating demand position")
	if network.size() != 23: errors.append("incomplete full-building heat budget")
	var units := {}
	for record: Variant in source.installed:
		if record is not Dictionary or record.get("unit") not in UNITS or record.get("id") not in network:
			errors.append("unknown installed radiator")
			continue
		if units.has(record.unit): errors.append("duplicate installed household")
		units[record.unit] = true
		if network[record.id].unit != record.unit or network[record.id].riser != record.get("riser"):
			errors.append("installed radiator disagrees with authored demand")
		var sections: Variant = record.get("sections")
		if typeof(sections) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(sections)) or float(sections) != floorf(float(sections)) or float(sections) < 7 or float(sections) > 10:
			errors.append("invalid radiator section count")
		var anchor := adapter.resolve(str(record.id)) as Node3D
		if anchor == null or anchor is RadiatorProp: errors.append("missing or occupied radiator anchor")
	if units.size() != UNITS.size(): errors.append("incomplete installed radiator category")
	return errors.is_empty()
