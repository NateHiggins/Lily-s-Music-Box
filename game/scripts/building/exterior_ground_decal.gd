class_name ExteriorGroundDecal
extends Node3D
## One isolated quadrant from the shared exterior damage atlas.

const ATLAS := \
		"res://assets/building/textures/exterior_details/exterior_damage_atlas.png"
static var _cache: Dictionary = {}
static var _shader: Shader


static func _feathered() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
render_mode cull_disabled, shadows_disabled, depth_draw_never;
uniform sampler2D tile : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec4 c = texture(tile, UV) * tint;
	vec2 d = min(UV, 1.0 - UV);
	ALBEDO = c.rgb;
	ALPHA = c.a * smoothstep(0.0, 0.22, min(d.x, d.y));
	ROUGHNESS = 0.78;
}
"""
	return _shader


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
	# Dossier slice 65 (CITY_STREET-005): the mark feathers out toward its quad's edges, so a stain never ends in
	# a hard dark rectangle on the pavement. Same atlas tile, tint and roughness.
	var material := ShaderMaterial.new()
	material.shader = _feathered()
	material.set_shader_parameter("tile", texture)
	material.set_shader_parameter("tint", tint)
	var visual := MeshInstance3D.new()
	visual.mesh = quad
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
