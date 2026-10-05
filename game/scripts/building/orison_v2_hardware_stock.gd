extends RefCounted
## Source-owned passive stock; original purchasing, plot and saved-state authority remain.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return preload("res://scripts/building/orison_v2_shop_seating.gd").mount_hardware_stock(cell,layout)
