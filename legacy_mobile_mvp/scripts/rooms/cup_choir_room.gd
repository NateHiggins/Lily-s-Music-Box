extends RoomBase
class_name CupChoirRoom

var cups: Array[Vector2i] = []
var pure_index := 0
var selected_index := -1

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = room_seed
	for i in 8:
		cups.append(Vector2i(4 + (i % 4) * 2, 8 + (i / 4) * 4))
	pure_index = rng.randi_range(0, cups.size() - 1)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(grid_size * tile_size)), Color(0.94, 0.88, 0.93))
	for i in cups.size():
		var world := Vector2(cups[i]) * tile_size + Vector2(tile_size / 2, tile_size / 2)
		var c := Color(0.73, 0.8, 0.95) if i == selected_index else Color(0.95, 0.94, 0.88)
		draw_circle(world, 12, c)
		draw_arc(world, 14, 0, TAU, 18, Color(0.2, 0.15, 0.2), 2)
	draw_rect(Rect2(Vector2(13, 2) * tile_size, Vector2(2, 2) * tile_size), Color(0.75, 0.95, 0.78, 0.7), true)

func on_player_inspect() -> void:
	selected_index = _nearest_cup()
	if selected_index == -1:
		return
	var base_hz := 440.0
	var hz := base_hz if selected_index == pure_index else base_hz + randf_range(-22.0, 22.0)
	_play_tone(hz)
	queue_redraw()

func on_player_interact() -> void:
	var idx := _nearest_cup()
	if idx == -1:
		return
	if idx == pure_index:
		room_cleared.emit()
	else:
		player_died.emit(player.global_position)

func _nearest_cup() -> int:
	var best := -1
	var dist := 28.0
	for i in cups.size():
		var world := Vector2(cups[i]) * tile_size + Vector2(tile_size / 2, tile_size / 2)
		var d := player.global_position.distance_to(world)
		if d < dist:
			dist = d
			best = i
	return best

func _play_tone(_hz: float) -> void:
	# Placeholder: use short beep through AudioStreamGenerator in a fuller build.
	pass
