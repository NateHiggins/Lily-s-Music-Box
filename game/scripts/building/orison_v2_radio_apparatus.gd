extends RefCounted
## Original passive test instruments and set with its back off.
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_radio_service":return true
	return Seating.mount_radio_apparatus(cell,layout)
