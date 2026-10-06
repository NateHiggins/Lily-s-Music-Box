extends RefCounted
const ShopSeating := preload("res://scripts/building/orison_v2_shop_seating.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return ShopSeating.mount_photo_process(cell,layout)
