extends RefCounted
## Source-owned unused soda fountain; this fitting adds no dispensing or utility owner.
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_otis_son":return true
	return Seating.mount_druggist_fountain(cell,layout)
