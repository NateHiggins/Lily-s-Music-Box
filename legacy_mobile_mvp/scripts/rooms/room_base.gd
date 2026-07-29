extends Node2D
class_name RoomBase

signal player_died(position: Vector2)
signal room_cleared

var room_seed: int
var room_id: String
var tile_size := 32
var grid_size := Vector2i(16, 24)
var player: Player
var tile_map: TileMap

func _ready() -> void:
	tile_map = TileMap.new()
	add_child(tile_map)
	tile_map.tile_set = _make_tileset()
	for x in grid_size.x:
		for y in grid_size.y:
			tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i.ZERO)

func setup(seed: int, id: String, actor: Player) -> void:
	room_seed = seed
	room_id = id
	player = actor

func on_player_inspect() -> void:
	pass

func on_player_interact() -> void:
	pass

func _make_tileset() -> TileSet:
	var image := Image.create(tile_size, tile_size, false, Image.FORMAT_RGBA8)
	for x in tile_size:
		for y in tile_size:
			var noise := 0.9 + sin(float(x + y) * 0.2) * 0.04
			image.set_pixel(x, y, Color(0.96 * noise, 0.93 * noise, 0.97 * noise))
	var texture := ImageTexture.create_from_image(image)
	var ts := TileSet.new()
	var src := TileSetAtlasSource.new()
	src.texture = texture
	src.create_tile(Vector2i.ZERO, Vector2i(tile_size, tile_size))
	ts.add_source(src, 0)
	ts.tile_size = Vector2i(tile_size, tile_size)
	return ts
