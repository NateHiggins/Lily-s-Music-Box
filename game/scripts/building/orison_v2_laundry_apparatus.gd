extends RefCounted
## Retained laundry source identities use the shared exact-boundary fitter.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return preload("res://scripts/building/orison_v2_shop_seating.gd").mount_laundry_apparatus(cell,layout)
