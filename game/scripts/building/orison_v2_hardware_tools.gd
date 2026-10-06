extends RefCounted
## Original passive glass/tool/ladder identities retain their nonvisual authority.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return preload("res://scripts/building/orison_v2_shop_seating.gd").mount_hardware_tools(cell,layout)
