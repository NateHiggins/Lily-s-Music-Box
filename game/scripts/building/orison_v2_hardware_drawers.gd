extends RefCounted
## Source-owned hardware drawer wall; original shop and plot-device ladder keep authority.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return preload("res://scripts/building/orison_v2_shop_seating.gd").mount_hardware_drawers(cell,layout)
