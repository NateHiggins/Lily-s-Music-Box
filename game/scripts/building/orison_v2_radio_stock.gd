extends RefCounted
## Four original shelves and fourteen seated stored radio valves.
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_radio_service":return true
	return Seating.mount_radio_stock(cell,layout)
