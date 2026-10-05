extends RefCounted
## Fitted Keys Cut visuals retain the source shop and its permission service.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return preload("res://scripts/building/orison_v2_shop_seating.gd").mount_locksmith(cell,layout)
