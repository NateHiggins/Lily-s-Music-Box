extends RefCounted
## Build the replacement cells off-tree. The caller owns the detached donors,
## registered region transform, actor/save lifetime, and final publication.
const Shell := preload("res://scripts/building/orison_v2_arcade_plaza_shell.gd")
const Frame := preload("res://scripts/building/orison_v2_arcade_native_carrier.gd")
const Public := preload("res://scripts/building/orison_v2_arcade_public_fittings.gd")
const Threshold := preload("res://scripts/building/orison_v2_arcade_entry_threshold.gd")
const Millwork := preload("res://scripts/building/orison_v2_shop_millwork.gd")
const Cobbler := preload("res://scripts/building/orison_v2_arcade_cobbler_field.gd")
const Finishes := preload("res://scripts/building/orison_v2_owner_finishes.gd")

var errors: Array[String] = []

func _declaration(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _refuse(message: String, root: Node3D = null) -> Node3D:
	errors.append(message)
	if root != null:
		root.free()
	return null

func prepare(shell_contract: Dictionary, frames: Array) -> Node3D:
	errors.clear()
	var shell_loader := Shell.new()
	var root := shell_loader.prepare(_declaration(Shell.DATA))
	if root == null:
		return _refuse("Prepared shell: " + str(shell_loader.errors))
	root.name = "ResidentGeometry"
	if not Millwork.mount_prepared(root,shell_contract,frames):
		return _refuse("Prepared shell millwork",root)
	var frontage := shell_loader.prepare_storefront(_declaration(Shell.STOREFRONT_DATA))
	if frontage == null:
		return _refuse("Prepared storefront: " + str(shell_loader.errors),root)
	for shop: Node3D in frontage.get_children():
		var receiver := root.get_node_or_null(NodePath(str(shop.name))) as Node3D
		if receiver == null:
			frontage.free()
			return _refuse("Unregistered storefront cell",root)
		for draw: Node3D in shop.get_children():
			shop.remove_child(draw)
			receiver.add_child(draw)
	frontage.free()
	var passage := root.get_node("passage") as Node3D
	var public_fittings := Public.new()
	var hatches := public_fittings.prepare_hatches(_declaration(Public.DATA))
	if hatches == null:
		return _refuse("Prepared pavement hatches: " + str(public_fittings.errors),root)
	passage.add_child(hatches)
	var entry := Threshold.prepare()
	if entry == null:
		return _refuse("Prepared entrance threshold",root)
	passage.add_child(entry)
	return root

func admit_clock(root: Node3D, donor: Node3D) -> bool:
	errors.clear()
	var passage := root.get_node_or_null("passage") as Node3D
	if root.is_inside_tree() or passage == null or passage.has_node("ArcadePublicClock"):
		errors.append("Clock requires a detached replacement passage without a clock")
		return false
	var helper := Public.new()
	var clock := helper.extract_clock(donor,_declaration(Public.DATA))
	if clock == null:
		errors.append_array(helper.errors)
		return false
	passage.add_child(clock)
	return true

func admit_shop(root: Node3D, donor: Node3D, native_spec: Dictionary, raw_spec: Dictionary) -> bool:
	errors.clear()
	var cell := root.get_node_or_null(NodePath(str(native_spec.get("cell","")))) as Node3D
	if root.is_inside_tree() or donor.is_inside_tree() or cell == null \
		or cell.name != donor.name or cell.has_meta("arcade_retained_shop_admitted") \
		or native_spec.get("cell") != raw_spec.get("cell"):
		errors.append("Shop carrier requires matching detached cells and fresh custody")
		return false
	var helper := Frame.new()
	var cobbler: Node3D
	if cell.name == "shop_shoe_rebuilding":
		var field := Cobbler.new()
		cobbler = field.prepare(_declaration(Cobbler.DATA),donor,native_spec)
		if cobbler == null:
			errors.append_array(field.errors)
			return false
	var native := helper.extract_native(donor,native_spec)
	if native == null:
		if cobbler != null:
			cobbler.free()
		errors.append_array(helper.errors)
		return false
	var raw := helper.extract_raw(donor,raw_spec)
	if raw == null:
		# Keep the extracted native parts in detached donor custody. Leave
		# the receiving cell untouched so no partial shop can be published.
		donor.add_child(native)
		if cobbler != null:
			cobbler.free()
		errors.append_array(helper.errors)
		return false
	Finishes.new().apply_shop_cell(native)
	cell.add_child(native)
	cell.add_child(raw)
	if cobbler != null:
		cell.add_child(cobbler)
	cell.set_meta("arcade_retained_shop_admitted", true)
	return true
