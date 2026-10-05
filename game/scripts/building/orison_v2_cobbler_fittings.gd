extends RefCounted
## Source-owned cobbler frames and paired shoes; service state retains its owner.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return preload("res://scripts/building/orison_v2_shop_seating.gd").mount_cobbler(cell,layout)
