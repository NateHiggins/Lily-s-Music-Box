extends RefCounted
## Existing laundry owners retain every non-visual authority.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return preload("res://scripts/building/orison_v2_shop_seating.gd").mount_laundry_trade(cell,layout)
