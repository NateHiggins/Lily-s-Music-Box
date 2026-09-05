class_name MaintenanceShopService
extends Node
## Owns shop stock provenance and the maintenance acquisition transaction.
##
## Stock is authored in `data/shop_inventory.json` and validated on load —
## the same narrow-boundary discipline as MaintenanceJobLibrary. The
## transaction is the one gate: the right shop, an open job awaiting exactly
## this part, and an inventory that does not already hold it. On success the
## inventory records the fact (and emits `part_acquired`) and the job is
## advanced through WorkOrders' public contract — lifecycle legality stays
## WorkOrders' own; item facts stay MaintenanceInventory's own; this service
## never stores either.
##
## The counter interaction point is spawned from the shop's authored
## furniture anchor in the generated layout. Runtime selects among authored
## anchors; it invents no placement.

const STOCK_PATH := "res://data/shop_inventory.json"
const SCHEMA_VERSION := 1
const KINDS: Array[String] = ["part", "tool"]
## The plan's procurement vocabulary. K3 authors exactly one: buy.
const VERBS: Array[String] = ["buy", "identify", "borrow", "repair",
		"trade", "recover", "improvise"]
## How far above the counter top the interaction volume reaches.
const REACH_H := 0.5

var stock: Dictionary = {}
var errors: Array[String] = []
var inventory: MaintenanceInventory
var work_orders: WorkOrders
var _counters: Dictionary = {}
var _semantic_mounts: Dictionary = {}


func setup(items: MaintenanceInventory, orders: WorkOrders,
		path := STOCK_PATH) -> void:
	inventory = items
	work_orders = orders
	_load_stock(path)


func is_valid() -> bool:
	return errors.is_empty()


func stock_record(item_id: String) -> Dictionary:
	return stock.get(item_id, {}).duplicate(true)


func stock_ids() -> Array[String]:
	var ids: Array[String] = []
	for item_id in stock:
		ids.append(str(item_id))
	ids.sort()
	return ids


## The one item this shop could hand over right now: stocked here, an open
## job awaiting it, not already acquired. Empty string means the counter has
## nothing for the player.
func pending_item(shop_id: String) -> String:
	if inventory == null or work_orders == null:
		return ""
	for item_id in stock_ids():
		if str(stock[item_id].shop_id) != shop_id:
			continue
		if work_orders.jobs_awaiting_part(item_id).is_empty():
			continue
		if inventory.item_state(item_id).is_empty():
			return item_id
	return ""


func counter_prompt(shop_id: String) -> String:
	var item_id := pending_item(shop_id)
	if item_id.is_empty():
		return ""
	var record: Dictionary = stock[item_id]
	return "[E]  %s: %s" % [str(record.acquisition_verb).capitalize(),
			str(record.display_name)]


## The acquisition transaction. All-or-nothing and idempotent: a repeat call
## fails on the inventory fact and mutates nothing.
func acquire(item_id: String, shop_id: String) -> bool:
	var record: Dictionary = stock.get(item_id, {})
	if record.is_empty() or str(record.shop_id) != shop_id:
		return false
	if inventory == null or work_orders == null:
		return false
	var waiting := work_orders.jobs_awaiting_part(item_id)
	if waiting.is_empty():
		return false
	if not inventory.grant(item_id, shop_id):
		return false
	for job_id in waiting:
		work_orders.mark_job_repairable(job_id)
	return true


func acquire_pending(shop_id: String) -> bool:
	var item_id := pending_item(shop_id)
	return not item_id.is_empty() and acquire(item_id, shop_id)


## Spawn one interaction point per stocked shop, anchored on the authored
## counter furniture record. Call after this service is in the tree.
func build_counters(layout: Dictionary) -> int:
	for item_id in stock_ids():
		var record: Dictionary = stock[item_id]
		var shop_id := str(record.shop_id)
		if _counters.has(shop_id):
			continue
		var anchor := _find_furniture(layout, str(record.counter_anchor_id))
		if anchor.is_empty():
			push_warning("shop counter anchor missing: %s"
					% record.counter_anchor_id)
			continue
		_counters[shop_id] = _build_counter(shop_id, anchor)
	return _counters.size()


## Mount the existing production counter adapter at a placement resolved by
## another public spatial authority. The transform is the interaction volume's
## world transform; this service neither knows nor reconstructs layout/world
## coordinates. Repeating the same identity is idempotent and cannot create a
## second transaction surface.
func mount_counter(shop_id: String, world_transform: Transform3D,
		interaction_size := Vector3(1.2, REACH_H, 0.8),
		physical_label := "counter") -> Area3D:
	if shop_id.is_empty() or shop_id != shop_id.strip_edges() \
			or not _valid_mount(world_transform, interaction_size):
		push_warning("shop counter semantic mount refused: %s" % shop_id)
		return null
	var existing := _counters.get(shop_id) as Area3D
	if is_instance_valid(existing):
		var prior: Dictionary = _semantic_mounts.get(shop_id, {})
		if not prior.is_empty() \
				and (prior.get("transform") as Transform3D).is_equal_approx(
						world_transform) \
				and (prior.get("size") as Vector3).is_equal_approx(
						interaction_size) \
				and str(prior.get("physical_label", "")) == physical_label:
			return existing
		push_warning("shop counter duplicate identity refused: %s" % shop_id)
		return null
	_counters.erase(shop_id)
	_semantic_mounts.erase(shop_id)
	var point := _new_semantic_counter(shop_id, physical_label)
	add_child(point)
	point.global_transform = world_transform
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = interaction_size
	shape.shape = box
	point.add_child(shape)
	_counters[shop_id] = point
	_semantic_mounts[shop_id] = {"transform":world_transform,
			"size":interaction_size, "physical_label":physical_label}
	return point


## Remove one mounted counter without reaching into its node tree. The service
## drops its strong reference synchronously; Godot performs safe node disposal
## at the ordinary end-of-frame boundary.
func unmount_counter(shop_id: String) -> bool:
	if not _counters.has(shop_id):
		return false
	var point := _counters.get(shop_id) as Area3D
	_counters.erase(shop_id)
	_semantic_mounts.erase(shop_id)
	if is_instance_valid(point):
		if point.get_parent() == self:
			remove_child(point)
		point.queue_free()
	return true


func unmount_all_counters() -> int:
	var removed := 0
	for shop_id: Variant in _counters.keys():
		if unmount_counter(str(shop_id)):
			removed += 1
	return removed


func counter(shop_id: String) -> Area3D:
	return _counters.get(shop_id)


func _build_counter(shop_id: String, anchor: Dictionary) -> Area3D:
	# Preserve the established v1 scene-name contract. Semantic mounts below
	# expose shop identity through metadata instead of generated node names.
	var point := MaintenanceShopCounter.new()
	point.name = "ShopCounter_%s" % shop_id
	point.setup(self, shop_id, "hardware counter")
	add_child(point)
	var rect: Array = anchor.rect
	var top := float(anchor.get("z0", 0.0)) + float(anchor.get("h", 0.0))
	point.global_position = GameBoot.b2g([
		(float(rect[0]) + float(rect[2])) * 0.5,
		(float(rect[1]) + float(rect[3])) * 0.5,
		top + REACH_H * 0.5])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(absf(float(rect[2]) - float(rect[0])),
			REACH_H, absf(float(rect[3]) - float(rect[1])))
	shape.shape = box
	point.add_child(shape)
	return point


func _new_semantic_counter(shop_id: String, physical_label: String) \
		-> MaintenanceShopCounter:
	var point := MaintenanceShopCounter.new()
	point.name = "SemanticShopCounter"
	point.set_meta("semantic_shop_id", shop_id)
	point.setup(self, shop_id, physical_label)
	return point


func _valid_mount(world_transform: Transform3D, size: Vector3) -> bool:
	return world_transform.origin.is_finite() \
			and world_transform.basis.x.is_finite() \
			and world_transform.basis.y.is_finite() \
			and world_transform.basis.z.is_finite() \
			and absf(world_transform.basis.determinant()) > 0.000001 \
			and size.is_finite() and size.x > 0.0 \
			and size.y > 0.0 and size.z > 0.0


func _find_furniture(layout: Dictionary, furniture_id: String) -> Dictionary:
	for floor in layout.get("floors", []):
		for record in floor.get("furniture", []):
			if str(record.get("id", "")) == furniture_id:
				return record
	return {}


func _load_stock(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("shop stock file missing: %s" % path)
	else:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is not Dictionary:
			errors.append("shop stock root is not a dictionary")
		else:
			_validate(parsed)
	for err in errors:
		push_warning("shop_inventory.json: %s" % err)


func _validate(parsed: Dictionary) -> void:
	if int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("schema_version must be %d" % SCHEMA_VERSION)
		return
	var authored: Variant = parsed.get("stock")
	if authored is not Dictionary or (authored as Dictionary).is_empty():
		errors.append("stock must be a non-empty dictionary keyed by item id")
		return
	for item_id in authored:
		var record: Variant = authored[item_id]
		if str(item_id).is_empty() or record is not Dictionary:
			errors.append("stock record '%s' is malformed" % item_id)
			continue
		_validate_record(str(item_id), record)
	if not errors.is_empty():
		return
	for item_id in authored:
		stock[str(item_id)] = (authored[item_id] as Dictionary).duplicate(true)


func _validate_record(item_id: String, record: Dictionary) -> void:
	for field in ["shop_id", "display_name", "counter_anchor_id", "provenance"]:
		if str(record.get(field, "")).is_empty():
			errors.append("%s: %s must be a non-empty string" % [item_id, field])
	if str(record.get("kind", "")) not in KINDS:
		errors.append("%s: kind must be one of %s" % [item_id, KINDS])
	if str(record.get("acquisition_verb", "")) not in VERBS:
		errors.append("%s: acquisition_verb must be one of %s" % [item_id, VERBS])
