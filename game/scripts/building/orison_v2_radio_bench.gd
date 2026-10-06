extends RefCounted
## Source-owned supported alignment bench and passive side leaf.
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_radio_service":return true
	return Seating.mount_radio_bench(cell,layout)
