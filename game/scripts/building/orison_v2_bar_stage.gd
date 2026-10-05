extends RefCounted
## Fixed source-fitted curtains; the original stage signal actors keep state.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return preload("res://scripts/building/orison_v2_shop_seating.gd").mount_bar_stage(cell,layout)
