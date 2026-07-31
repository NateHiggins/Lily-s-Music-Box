class_name ExteriorGroundDecal
extends Node3D
## One isolated quadrant from the shared exterior damage atlas.

const ATLAS := \
		"res://assets/building/textures/exterior_details/exterior_damage_atlas.png"
static var _cache: Dictionary = {}


func setup(panel: int, size: Vector2, tint := Color.WHITE) -> void:
	var texture: Texture2D = _cache.get(panel)
	if texture == null:
		var atlas := load(ATLAS) as Texture2D
		if atlas == null:
			push_warning("Exterior damage atlas missing")
			return
		var source := atlas.get_image()
		var half := Vector2i(source.get_width() / 2, source.get_height() / 2)
		var inset := 4
		var origin := Vector2i(
				(panel % 2) * half.x, int(panel / 2) * half.y)
		origin += Vector2i(inset, inset)
		var tile := source.get_region(Rect2i(
				origin, half - Vector2i(inset * 2, inset * 2)))
		tile.generate_mipmaps()
		texture = ImageTexture.create_from_image(tile)
		_cache[panel] = texture
	var quad := QuadMesh.new()
	quad.size = size
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.roughness = 0.78
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var visual := MeshInstance3D.new()
	visual.mesh = quad
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
