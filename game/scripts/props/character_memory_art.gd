class_name CharacterMemoryArt
extends Node3D
## Framed apartment memory using one quadrant of a shared generated atlas.

var art_id := ""
var atlas_name := ""
var atlas_col := 0
var atlas_row := 0
var medium := "photo"
var tabletop := false
var collection := "character_memories"
var texture_root := "res://assets/building/textures/character_memories/"


func setup(spec: Dictionary) -> void:
	art_id = spec.id
	atlas_name = spec.atlas
	atlas_col = int(spec.col)
	atlas_row = int(spec.row)
	medium = spec.get("medium", "photo")
	tabletop = spec.get("placement", "wall") == "tabletop"
	collection = spec.get("collection", "character_memories")
	texture_root = "res://assets/building/textures/%s/" % collection


func _ready() -> void:
	name = ("WallArt_" if collection == "character_wall_art"
			else "MemoryArt_") + art_id
	add_to_group(collection)
	var source := load(texture_root + atlas_name) as Texture2D
	if source == null:
		push_warning("Character art atlas missing: " + atlas_name)
		return
	var isolated := _isolate_atlas_tile(source)
	var size := Vector2(0.34, 0.34) if tabletop else Vector2(0.72, 0.72)
	var art_mesh := QuadMesh.new()
	art_mesh.size = size
	var art_material := StandardMaterial3D.new()
	art_material.albedo_texture = isolated
	art_material.roughness = 0.76 if medium != "photo" else 0.48
	art_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var art := MeshInstance3D.new()
	art.mesh = art_mesh
	art.material_override = art_material
	art.position.z = 0.018
	art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(art)
	_build_frame(size)
	if tabletop:
		_build_stand(size)


## Copies one panel into its own GPU texture. A small inset removes the atlas
## divider and prevents mip/filter sampling from ever revealing another panel.
func _isolate_atlas_tile(source: Texture2D) -> Texture2D:
	var image := source.get_image()
	if image == null or image.is_empty():
		var fallback := AtlasTexture.new()
		var half := source.get_size() / 2
		fallback.atlas = source
		fallback.region = Rect2(Vector2(atlas_col, atlas_row) * half, half)
		return fallback
	var half_size := Vector2i(image.get_width() / 2, image.get_height() / 2)
	var inset := maxi(4, mini(half_size.x, half_size.y) / 96)
	var origin := Vector2i(atlas_col * half_size.x, atlas_row * half_size.y)
	origin += Vector2i(inset, inset)
	var crop_size := half_size - Vector2i(inset * 2, inset * 2)
	var tile := image.get_region(Rect2i(origin, crop_size))
	tile.generate_mipmaps()
	return ImageTexture.create_from_image(tile)


func _build_frame(size: Vector2) -> void:
	var frame_color := Color(0.18, 0.105, 0.055)
	if medium == "painting":
		frame_color = Color(0.25, 0.17, 0.055)
	elif medium == "polaroid":
		frame_color = Color(0.10, 0.075, 0.055)
	elif medium == "sign":
		frame_color = Color(0.20, 0.22, 0.21)
	elif medium == "poster":
		frame_color = Color(0.055, 0.05, 0.045)
	elif medium == "textile":
		frame_color = Color(0.26, 0.12, 0.045)
	var material := StandardMaterial3D.new()
	material.albedo_color = frame_color
	material.roughness = 0.68
	var border := 0.045 if not tabletop else 0.025
	_frame_bar(Vector3(size.x + border * 2, border, 0.045),
			Vector3(0, size.y * 0.5 + border * 0.5, 0), material)
	_frame_bar(Vector3(size.x + border * 2, border, 0.045),
			Vector3(0, -size.y * 0.5 - border * 0.5, 0), material)
	_frame_bar(Vector3(border, size.y, 0.045),
			Vector3(size.x * 0.5 + border * 0.5, 0, 0), material)
	_frame_bar(Vector3(border, size.y, 0.045),
			Vector3(-size.x * 0.5 - border * 0.5, 0, 0), material)


func _build_stand(size: Vector2) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.14, 0.09, 0.05)
	material.roughness = 0.72
	_frame_bar(Vector3(size.x * 0.72, 0.035, 0.16),
			Vector3(0, -size.y * 0.5 - 0.035, -0.04), material)
	position.y += size.y * 0.5 + 0.04


func _frame_bar(size: Vector3, at: Vector3,
		material: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	add_child(instance)
