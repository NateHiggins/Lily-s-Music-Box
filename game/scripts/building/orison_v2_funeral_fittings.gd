extends RefCounted
## Source-owned lectern and deliberately empty bier; passive room fittings.
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_funeral_parlour":return true
	return Seating.mount_funeral(cell,layout)
