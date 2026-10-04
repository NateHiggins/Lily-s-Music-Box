extends RefCounted
## Native laundry appearance shares the exact source-boundary fitter.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return preload("res://scripts/building/orison_v2_shop_seating.gd").mount_laundry(cell,layout)
