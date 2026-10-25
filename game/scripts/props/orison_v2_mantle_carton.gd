class_name OrisonV2MantleCarton
extends Node3D
## The workroom's carton of a dozen spare gas mantles.
## Design: design/V2_ENTRY_VESTIBULE_2026-10-24.md §1.
##
## Each mantle is a single-use MaintenanceInventory id (`gas_mantle_01` to
## `gas_mantle_12`); the inventory alone holds which are taken and which are
## spent, and the packets left in the carton are read back from it. Lift the
## lid (RUL-013: grab it, raise it, release) with no spare already in hand,
## and the next mantle is yours. One in hand at a time.
##
## When the dozen is gone, Management posts a second carton to box 4B (a mail
## delivery carrying the single-use part `gas_mantle_carton_2`). Lift the
## empty carton's lid with it in hand and it refills: `gas_mantle_13` to
## `gas_mantle_24`. There is no third.
##
## State is the lid's angle alone, the household save's mechanism record
## under this node's semantic name.

signal manipulation_changed

const SHOP_ID := "front_workroom_mantle_carton"
const LID_TRAVEL := 1.9

var inventory: Node
var prefix := "gas_mantle_"
## Mantles to a carton; the refill doubles the run once.
var count := 12
var refill_item := ""
## Lid angle, radians, at which a hand can reach in for a mantle.
var takes_at := 1.0
var lid := 0.0
var lid_part: Node3D
var packets: Array[Node3D] = []
var _held := false


func configure(lid_node: Node3D, packet_nodes: Array[Node3D]) -> void:
	lid_part = lid_node
	packets = packet_nodes
	preload("res://scripts/props/manipulation_area.gd").install(lid_part, lid_grip)
	_show()


## Every mantle id this carton can ever hold: the first dozen, and the
## second once its refill has been spent into it.
func ids() -> Array[String]:
	var result: Array[String] = []
	var total := count * (2 if refilled() else 1)
	for i in total:
		result.append("%s%02d" % [prefix, i + 1])
	return result


func refilled() -> bool:
	return inventory != null and not refill_item.is_empty() and inventory.is_consumed(refill_item)


## The spare the player carries, or "".
func carried() -> String:
	if inventory == null:
		return ""
	for id in ids():
		if inventory.has_item(id):
			return id
	return ""


## Mantles still in the carton: never taken, by the inventory's own record.
func remaining() -> int:
	var left := 0
	for id in ids():
		if inventory == null or inventory.item_state(id).is_empty():
			left += 1
	return left


func lid_grip() -> Dictionary:
	return {"owner": self, "part": lid_part, "frame": self, "kind": "hinge",
		"axis": Vector3.LEFT, "minimum": 0.0, "maximum": LID_TRAVEL,
		"read": func(): return lid,
		"write": func(angle: float):
			if _held: set_lid(angle),
		"owns": func(): return _held,
		"begin": func():
			if _held: return false
			_held = true
			return true,
		"end": func(): _held = false; manipulation_changed.emit()}


func set_lid(angle: float) -> void:
	var before := lid
	lid = clampf(angle, 0.0, LID_TRAVEL)
	if before < takes_at and lid >= takes_at:
		_take()
	_show()


func _take() -> void:
	if inventory == null or not carried().is_empty():
		return
	# The empty carton takes the posted refill first.
	if remaining() == 0 and not refill_item.is_empty() and inventory.has_item(refill_item):
		inventory.consume(refill_item)
	for id in ids():
		if inventory.item_state(id).is_empty():
			inventory.grant(id, SHOP_ID)
			return


func _show() -> void:
	if lid_part != null:
		lid_part.rotation.x = -lid
	var left := remaining()
	for i in packets.size():
		packets[i].visible = i < left


func mechanism_snapshot() -> Dictionary:
	return {"lid": lid}


func valid_mechanism(value: Variant) -> bool:
	return value is Dictionary and value.size() == 1 \
			and typeof(value.get("lid")) in [TYPE_FLOAT, TYPE_INT] \
			and is_finite(float(value.lid)) and float(value.lid) >= 0.0 and float(value.lid) <= LID_TRAVEL


func restore_mechanism(value: Dictionary) -> void:
	if not valid_mechanism(value): return
	_held = false
	# A restored lid is a position, never a fresh reach into the carton.
	lid = float(value.lid)
	_show()
