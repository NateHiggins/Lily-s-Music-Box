class_name PantryDisplay
extends Node3D
## A household's dry goods along the back edge of its kitchen work table
## (design/ORISON_KITCHENS_2026-10-24.md): sacks, tins, jars, packets, a loaf
## and paper bags of produce, each named on a Label3D tag, restocked from
## KitchenLarder.pantry_rows. Shapes and finishes come from the groceries'
## `pantry_looks`; every surface is catalogue PBR on metre-charted UVs.

const MetreUV := preload("res://scripts/building/v2_metre_box_uv.gd")

var looks: Dictionary = {}
var _span := Vector2(-0.5, 0.5)
var _skip := Vector2(INF, INF)
var _shown: Array = []


## The row runs along local X between `span`, at this node's origin; `skip`
## is an X interval already taken (a bowl).
func setup(pantry_looks: Dictionary, span: Vector2, skip := Vector2(INF, INF)) -> void:
	looks = pantry_looks
	_span = span
	_skip = skip


func show_rows(rows: Array) -> void:
	if rows == _shown:
		return
	_shown = rows.duplicate(true)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var x := _span.x
	for row: Array in rows:
		var look: Dictionary = looks.get(str(row[1]), {})
		if look.is_empty():
			continue
		var size := Vector3(float(look.size[0]), float(look.size[1]), float(look.size[2]))
		if x + size.x * 0.5 > _skip.x - 0.01 and x - size.x * 0.5 < _skip.y + 0.01:
			x = _skip.y + 0.02 + size.x * 0.5
		if x + size.x * 0.5 > _span.y:
			break
		var item := Node3D.new()
		item.name = "Pantry_" + str(row[0]).validate_node_name()
		item.position = Vector3(x + size.x * 0.5, 0.0, 0.0)
		add_child(item)
		_body(item, str(look.shape), size, str(look.material), look.tint)
		var tag := Label3D.new()
		tag.name = "Tag"
		tag.text = str(row[2])
		tag.font_size = 22
		tag.pixel_size = 0.00028
		tag.width = size.x / 0.00028
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tag.modulate = Color(0.12, 0.10, 0.08)
		tag.outline_size = 0
		tag.position = Vector3(0.0, size.y * 0.55, -size.z * 0.5 - 0.002)
		tag.rotation.y = PI
		item.add_child(tag)
		x += size.x + 0.025


func _body(item: Node3D, shape: String, size: Vector3, material: String, tint: Array) -> void:
	var mesh: PrimitiveMesh
	if shape == "cylinder":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x * 0.5
		cylinder.bottom_radius = size.x * 0.5
		cylinder.height = size.y
		cylinder.radial_segments = 12
		mesh = cylinder
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh = box
	var finish := MatLib.get_mat(material).duplicate() as StandardMaterial3D
	finish.uv1_triplanar = false
	finish.uv1_scale = Vector3.ONE / float(MatLib.SETS[material][3])
	finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	finish.albedo_color = Color(float(tint[0]), float(tint[1]), float(tint[2]))
	mesh.material = finish
	var draw := MeshInstance3D.new()
	draw.name = "Body"
	draw.mesh = MetreUV.chart(mesh)
	draw.position = Vector3(0.0, size.y * 0.5, 0.0)
	item.add_child(draw)
