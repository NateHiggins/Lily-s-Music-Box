class_name CookbookProp
extends Node3D
## The house cookbook, lying shut on a kitchen work surface
## (design/ORISON_KITCHENS_2026-10-24.md). Cloth boards over a page block;
## the title is a Label3D on the cover, never painted into a texture. Its one
## control, `cookbook`, opens CookbookPanel. The larder owns every receipt.

const SIZE := Vector3(0.19, 0.034, 0.25)
const BOARD := 0.003
const MetreUV := preload("res://scripts/building/v2_metre_box_uv.gd")

var larder: KitchenLarder
var _panel: CookbookPanel


func setup(source: KitchenLarder) -> void:
	larder = source


func _ready() -> void:
	add_to_group("cookbooks")
	_box("BackBoard", Vector3(SIZE.x, BOARD, SIZE.z), Vector3(0, BOARD * 0.5, 0), "book_burgundy")
	_box("FrontBoard", Vector3(SIZE.x, BOARD, SIZE.z), Vector3(0, SIZE.y - BOARD * 0.5, 0), "book_burgundy")
	_box("Spine", Vector3(BOARD * 2.0, SIZE.y, SIZE.z), Vector3(-SIZE.x * 0.5 + BOARD, SIZE.y * 0.5, 0), "book_burgundy")
	_box("Leaves", Vector3(SIZE.x - 0.008, SIZE.y - BOARD * 2.0, SIZE.z - 0.008),
			Vector3(0.002, SIZE.y * 0.5, 0), "paper")
	var title := Label3D.new()
	title.name = "CoverTitle"
	title.text = "THE ORISON TABLE"
	title.font_size = 30
	title.pixel_size = 0.0004
	title.modulate = Color(0.83, 0.70, 0.40)
	title.outline_size = 0
	title.rotation_degrees = Vector3(-90, 0, 0)
	title.position = Vector3(0.006, SIZE.y + 0.0006, -0.035)
	add_child(title)
	var by := Label3D.new()
	by.name = "CoverImprint"
	by.text = "Receipts of the House"
	by.font_size = 18
	by.pixel_size = 0.0004
	by.modulate = Color(0.83, 0.70, 0.40)
	by.outline_size = 0
	by.rotation_degrees = Vector3(-90, 0, 0)
	by.position = Vector3(0.006, SIZE.y + 0.0006, 0.0)
	add_child(by)
	var control := PropControlArea.new()
	control.name = "CookbookControl"
	control.configure("cookbook")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE.x + 0.06, SIZE.y + 0.06, SIZE.z + 0.06)
	shape.shape = box
	shape.position = Vector3(0, SIZE.y * 0.5, 0)
	control.add_child(shape)
	add_child(control)


func _box(id: String, size: Vector3, at: Vector3, material: String) -> void:
	var box := BoxMesh.new()
	box.size = size
	# Catalogue PBR at its metre scale on metre-charted UVs (RUL-012).
	var finish := MatLib.get_mat(material).duplicate() as StandardMaterial3D
	finish.uv1_triplanar = false
	finish.uv1_scale = Vector3.ONE / float(MatLib.SETS[material][3])
	finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	box.material = finish
	var draw := MeshInstance3D.new()
	draw.name = id
	draw.mesh = MetreUV.chart(box)
	draw.position = at
	add_child(draw)


func control_prompt(control_id: String) -> String:
	if control_id != "cookbook" or larder == null or _reading():
		return ""
	return "The Orison Table"


func interact_control(control_id: String, player: Node) -> Variant:
	if control_id != "cookbook" or larder == null or _reading():
		return {}
	_panel = CookbookPanel.new()
	_panel.name = "CookbookPanel"
	get_tree().current_scene.add_child(_panel)
	_panel.open(player, larder, "", func(): _panel = null)
	return {}


func _reading() -> bool:
	return _panel != null and is_instance_valid(_panel)
