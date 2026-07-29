extends RoomBase
class_name LaundryOrbitRoom

var orbit_tiles: Array[Vector2i] = []
var cycle := 5.0
var elapsed := 0.0

func _ready() -> void:
	for x in range(3, 13):
		orbit_tiles.append(Vector2i(x, 10))
	for y in range(11, 17):
		orbit_tiles.append(Vector2i(12, y))
	for x in range(11, 2, -1):
		orbit_tiles.append(Vector2i(x, 16))
	for y in range(15, 10, -1):
		orbit_tiles.append(Vector2i(3, y))
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	var idx := _player_orbit_index()
	if idx != -1 and not _is_safe(idx):
		player_died.emit(player.global_position)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(grid_size * tile_size)), Color(0.9, 0.91, 0.98))
	for i in orbit_tiles.size():
		var t := orbit_tiles[i]
		var color := Color(0.6, 0.82, 0.95) if _is_safe(i) else Color(0.86, 0.63, 0.7)
		draw_rect(Rect2(Vector2(t) * tile_size, Vector2(tile_size, tile_size)), color)
	draw_rect(Rect2(Vector2(7, 3) * tile_size, Vector2(2, 2) * tile_size), Color(0.95, 0.95, 0.75, 0.85), true)

func on_player_interact() -> void:
	var exit_rect := Rect2(Vector2(7, 3) * tile_size, Vector2(2, 2) * tile_size)
	if exit_rect.has_point(player.global_position):
		room_cleared.emit()

func get_debug_timer() -> float:
	return fmod(elapsed, cycle)

func _is_safe(index: int) -> bool:
	var center := int(floor((fmod(elapsed, cycle) / cycle) * orbit_tiles.size()))
	var diff := abs(index - center)
	return diff <= 2 or diff >= orbit_tiles.size() - 2

func _player_orbit_index() -> int:
	for i in orbit_tiles.size():
		var rect := Rect2(Vector2(orbit_tiles[i]) * tile_size, Vector2(tile_size, tile_size))
		if rect.has_point(player.global_position):
			return i
	return -1
