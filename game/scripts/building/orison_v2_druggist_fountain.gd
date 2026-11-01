extends RefCounted
## Source-owned soda fountain. Dispensing belongs to scripts/props/otis_fountain.gd.
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_otis_son":return true
	return Seating.mount_druggist_fountain(cell,layout)
