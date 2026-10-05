extends RefCounted
## Source-owned News/Cigars fittings; existing transactions and locks retain authority.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return preload("res://scripts/building/orison_v2_shop_seating.gd").mount_news(cell,layout)
