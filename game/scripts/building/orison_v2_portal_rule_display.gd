extends "res://scripts/cases/portal_rule_display.gd"
## The storage-room rule board in V2. V1's script still writes the header and
## the accepted rules and listens to the campaign state; its slab is retired
## the moment it is made, and the Blender board (ground, mitred frame, ledge,
## battens and hanger straps) is hung in its place.
const Stock := preload("res://scripts/building/orison_v2_case_prop_stock.gd")
## The board's battens and straps bear on a wall this far behind its origin.
const WALL_OFFSET := 0.040

var stock: Stock


func _ready() -> void:
	super._ready()
	for child in get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is PrimitiveMesh:
			remove_child(child)
			child.free()
		elif child is Label3D:
			# Lettering faces the room only; nothing reads through the wall.
			(child as Label3D).double_sided = false
	if stock == null or stock.mount_on(self, "rule_board").is_empty():
		push_error("V2 rule board has no library object")


func rules_text() -> String:
	return _rules.text if _rules != null else ""
