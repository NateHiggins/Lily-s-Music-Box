extends RefCounted
## Passive Manhattan stock behind the installed bridge, on its existing land.
const MetreUV := preload("res://scripts/building/v2_metre_box_uv.gd")

const SHORE_BOTTOM_M := -0.17
const BAY_SPACING_M := 56.0
const STREET_GRID_DEG := 29.708333
# First west/east coordinate, north/south coordinate, bay count, maximum height.
# Short rows leave gaps along the bank. Taller setbacks stay on the west flank.
const ROWS: Array[Vector4] = [
	Vector4(-1720, -775, 5, 30),
	Vector4(-1708, -855, 5, 38),
	Vector4(-1728, -945, 6, 33),
	Vector4(-1710, -1030, 5, 31),
	Vector4(-1406, -1046, 3, 23),
	Vector4(-1487, -1360, 5, 27),
	Vector4(-1476, -1441, 5, 29),
	Vector4(-1520, -1555, 5, 26),
	Vector4(-1500, -1650, 5, 23),
	Vector4(-1509, -1770, 5, 25),
	Vector4(-1470, -1885, 4, 21),
	Vector4(-1482, -1984, 4, 22),
]
const SETBACK_HEIGHTS_M := {
	Vector2i(1, 1): 53.0,
	Vector2i(2, 2): 68.0,
	Vector2i(3, 0): 58.0,
}


static func mount(city: Node3D, threshold_offset_m: float) -> void:
	var batch := SurfaceTool.new()
	batch.begin(Mesh.PRIMITIVE_TRIANGLES)
	var generator := RandomNumberGenerator.new()
	generator.seed = 19290223
	var grid := Basis(Vector3.UP, deg_to_rad(STREET_GRID_DEG))
	for row_index in ROWS.size():
		var row := ROWS[row_index]
		for bay in int(row.z):
			var footprint := Vector2(generator.randf_range(29.0, 39.0), generator.randf_range(27.0, 36.0))
			var position := Vector3(
				row.x + BAY_SPACING_M * bay + generator.randf_range(-1.0, 1.0),
				SHORE_BOTTOM_M, row.y + generator.randf_range(-5.0, 5.0))
			var height := generator.randf_range(14.0, row.w)
			var setback_height: float = SETBACK_HEIGHTS_M.get(Vector2i(row_index, bay), 0.0)
			if setback_height > 0.0:
				var body_height := setback_height * 0.72
				var upper_height := setback_height * 0.19
				_append_block(batch, grid, position, footprint, body_height)
				_append_block(batch, grid, position + Vector3.UP * body_height, footprint * 0.71, upper_height)
				_append_block(batch, grid, position + Vector3.UP * (body_height + upper_height),
					footprint * 0.43, setback_height * 0.09)
			else:
				_append_block(batch, grid, position, footprint, height)

	var masonry := MatLib.get_mat("arcade_brick_bond").duplicate() as StandardMaterial3D
	masonry.uv1_triplanar = false
	masonry.uv2_triplanar = false
	masonry.albedo_color = Color(0.70, 0.74, 0.80)
	masonry.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var skyline := MeshInstance3D.new()
	skyline.name = "FarShoreSkyline"
	skyline.mesh = batch.commit()
	skyline.material_override = masonry
	skyline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# CityShells is shifted by the source threshold. The shore rows use the
	# unshifted runtime axes shared with the bridge's installed survey.
	skyline.position.z = threshold_offset_m
	city.add_child(skyline)


static func _append_block(batch: SurfaceTool, grid: Basis, bottom: Vector3,
		footprint: Vector2, height: float) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(footprint.x, height, footprint.y)
	var center := bottom + Vector3.UP * height * 0.5
	batch.append_from(MetreUV.chart(box), 0, Transform3D(grid, center))
