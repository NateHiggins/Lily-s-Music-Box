extends RefCounted
## The 62 reality-affected props and the storage-room rule board in V2
## (Lily, v1r_case_presentation_20261109: "Import it into V2 case placement").
##
## V1's catalogue (res://data/reality_affected_props.json) still owns every
## id, name, kind and case. For each id the V2 placement table names either the
## object V2 already furnishes in that flat (bound in place, never rebuilt) or
## a Blender library object and the support it rests on. Each cluster prop is
## registered with its case's ApartmentRealityController exactly as V1 did,
## so a stabilised case restores it.
const CATALOGUE := "res://data/reality_affected_props.json"
const PLACEMENTS := "res://data/orison_v2/case_prop_placements.json"
const Stock := preload("res://scripts/building/orison_v2_case_prop_stock.gd")
const Prop := preload("res://scripts/building/orison_v2_reality_affected_prop.gd")
const Binding := preload("res://scripts/building/orison_v2_reality_affected_binding.gd")
const RuleBoard := preload("res://scripts/building/orison_v2_portal_rule_display.gd")


## Returns {"props": {id: node}, "rule_board": node, "drivers": {id: driver},
## "errors": [...]}. `props` holds the node registered for the id: the V2
## object itself where one is bound, the library prop otherwise. `drivers`
## holds the node carrying V1's affected-state behaviour for it.
static func mount(root: Node3D, blockout: Node3D, layout: Dictionary, adapter: Variant,
		controllers: Dictionary) -> Dictionary:
	var result := {"props": {}, "rule_board": null, "drivers": {}, "errors": []}
	var errors: Array = result.errors
	var catalogue: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE))
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACEMENTS))
	if catalogue is not Dictionary or table is not Dictionary or table.get("schema_version") != 1 \
			or table.get("props") is not Dictionary:
		errors.append("case prop catalogue or placement table malformed")
		return result
	var stock := Stock.new()
	if not stock.prepare():
		errors.append_array(stock.errors)
		return result
	var levels: Dictionary = {}
	for row: Dictionary in layout.get("levels", []):
		levels[str(row.id)] = float(row.y)
	var placements: Dictionary = table.props
	for cluster: Dictionary in catalogue.get("case_clusters", []):
		var case_id := str(cluster.case_id)
		var controller: ApartmentRealityController = controllers.get(case_id)
		if controller == null:
			errors.append("no reality controller for " + case_id)
		for spec: Dictionary in cluster.props:
			var node := _place(spec, case_id, placements, stock, blockout, levels, adapter, result)
			if node != null and controller != null:
				controller.register_node(node)
	for spec: Dictionary in catalogue.get("shared_props", []):
		_place(spec, "", placements, stock, blockout, levels, adapter, result)
	var expected := int(catalogue.get("expected_prop_count", 0))
	if result.props.size() != expected:
		errors.append("reality-affected prop placement mismatch: expected %d, placed %d" % [expected, result.props.size()])
	var board_row: Dictionary = table.get("rule_board", {})
	var board_parent := _parent(board_row, blockout, adapter)
	if board_parent == null:
		errors.append("rule board has no wall")
	else:
		var board := RuleBoard.new()
		board.stock = stock
		board.position = _position(board_row, levels)
		board.rotation.y = float(board_row.get("yaw", 0.0))
		board_parent.add_child(board)
		result.rule_board = board
	if not errors.is_empty():
		push_error("ORISON V2 case props: %s" % [errors])
	root.set_meta("v2_case_props", result)
	return result


static func _place(spec: Dictionary, case_id: String, placements: Dictionary, stock: Stock, blockout: Node3D,
		levels: Dictionary, adapter: Variant, result: Dictionary) -> Node3D:
	var id := str(spec.id)
	var errors: Array = result.errors
	if result.props.has(id):
		errors.append("duplicate reality-affected prop id: " + id)
		return null
	if not placements.has(id):
		errors.append("no V2 placement for " + id)
		return null
	var row: Dictionary = placements[id]
	if row.has("counterpart"):
		var target := adapter.resolve(str(row.counterpart)) as Node3D
		if target == null or target.has_meta("reality_affected_prop_id"):
			errors.append("counterpart missing or already bound: %s -> %s" % [id, row.counterpart])
			return null
		var binding := Binding.new()
		binding.setup(id, str(spec.name), str(spec.kind), case_id)
		binding.bind(target, bool(row.get("fixed", false)))
		target.get_parent().add_child(binding)
		result.props[id] = target
		result.drivers[id] = binding
		return target
	var asset := str(row.get("asset", ""))
	var parent := _parent(row, blockout, adapter)
	if not stock.has(asset) or parent == null:
		errors.append("library object or support missing: %s (%s on %s)" % [id, asset, row.get("support", "")])
		return null
	var prop := Prop.new()
	prop.setup(id, str(spec.name), str(spec.kind), case_id)
	prop.asset = asset
	prop.stock = stock
	prop.yaw = float(row.get("yaw", 0.0))
	prop.position = _position(row, levels)
	parent.add_child(prop)
	if row.has("collision"):
		var solid: Array = row.collision
		_collide(prop, AABB(Vector3(float(solid[0][0]), float(solid[0][1]), float(solid[0][2])),
			Vector3(float(solid[1][0]) - float(solid[0][0]), float(solid[1][1]) - float(solid[0][1]),
			float(solid[1][2]) - float(solid[0][2]))), prop.yaw)
	if bool(row.get("label", false)):
		_stencil(prop, str(spec.name), stock.bounds(asset), prop.yaw)
	result.props[id] = prop
	result.drivers[id] = prop
	return prop


## A support id resolves through the anchor adapter and the row's position is
## local to it; "plan" rows are blockout plan metres on a level's floor.
static func _parent(row: Dictionary, blockout: Node3D, adapter: Variant) -> Node3D:
	var support := str(row.get("support", ""))
	if support == "plan":
		return blockout
	if support == "":
		return null
	return adapter.resolve(support) as Node3D


static func _position(row: Dictionary, levels: Dictionary) -> Vector3:
	var p: Array = row.get("position", [0, 0, 0])
	var at := Vector3(float(p[0]), float(p[1]), float(p[2]))
	if str(row.get("support", "")) == "plan":
		at.y += float(levels.get(str(row.get("level", "")), 0.0))
	return at


## Floor-standing shared stock (crates, the cart) is solid, like V2's own:
## the row gives the solid box in the library object's own frame.
static func _collide(prop: Node3D, box: AABB, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = box.size
	shape.shape = solid
	shape.position = box.get_center()
	body.add_child(shape)
	prop.add_child(body)


## The catalogue's own name, stencilled on the crate's face: lettering is
## Label3D, never texture (RUL-008).
static func _stencil(prop: Node3D, text: String, box: AABB, yaw: float) -> void:
	var holder := Node3D.new()
	holder.name = "Stencil"
	holder.rotation.y = yaw
	prop.add_child(holder)
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.0011
	label.outline_size = 0
	label.modulate = Color(0.10, 0.09, 0.08, 0.92)
	label.double_sided = false
	label.width = (box.size.x - 0.12) / label.pixel_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector3(box.get_center().x, box.position.y + box.size.y * 0.52, box.end.z + 0.002)
	holder.add_child(label)
