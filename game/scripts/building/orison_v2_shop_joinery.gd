extends RefCounted
## Original closed doors remain non-interactive representations of unmodelled backs.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return preload("res://scripts/building/orison_v2_shop_seating.gd").mount_shop_joinery(cell,layout)
