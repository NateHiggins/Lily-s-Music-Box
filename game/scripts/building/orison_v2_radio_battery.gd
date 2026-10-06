extends RefCounted
## Source-owned passive wet-cell charging display with a fitted rack.
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_radio_service":return true
	return Seating.mount_radio_battery(cell,layout)
