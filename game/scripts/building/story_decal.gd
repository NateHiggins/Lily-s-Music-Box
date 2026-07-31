class_name StoryDecal
extends Node3D
## Cheap story texture: one quad, cached isolated atlas quadrant, no physics.

static var _texture_cache: Dictionary = {}


func setup(atlas_path: String, col: int, row: int,
		size := Vector2(0.58, 0.58)) -> void:
	var key := "%s:%d:%d" % [atlas_path, col, row]
	var texture: Texture2D = _texture_cache.get(key)
	if texture == null:
		var atlas := load(atlas_path) as Texture2D
		if atlas == null:
			push_warning("Story decal atlas missing: " + atlas_path)
			return
		var image := atlas.get_image()
		var half := Vector2i(image.get_width() / 2, image.get_height() / 2)
		var inset := maxi(5, mini(half.x, half.y) / 96)
		var origin := Vector2i(col * half.x + inset, row * half.y + inset)
		var tile := image.get_region(Rect2i(
				origin, half - Vector2i(inset * 2, inset * 2)))
		tile.generate_mipmaps()
		texture = ImageTexture.create_from_image(tile)
		_texture_cache[key] = texture
	var quad := QuadMesh.new()
	quad.size = size
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.84
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var visual := MeshInstance3D.new()
	visual.mesh = quad
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
