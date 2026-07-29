extends Node2D

@onready var room_root: Node2D = %RoomRoot
@onready var player: Player = %Player
@onready var hud: CanvasLayer = %TouchHUD
@onready var status_label: Label = %StatusLabel
@onready var debug_label: Label = %DebugLabel
@onready var vignette: ColorRect = %Vignette

var run_rooms: Array[Dictionary] = []
var room_scene_map := {
	"cup_choir": preload("res://scenes/rooms/CupChoirRoom.tscn"),
	"laundry_orbit": preload("res://scenes/rooms/LaundryOrbitRoom.tscn"),
}
var current_room: RoomBase
var tap_to_move := false
var show_debug := true

func _ready() -> void:
	ServerAPI.run_failed.connect(_on_run_failed)
	ServerAPI.run_completed.connect(_on_run_complete)
	run_rooms = ServerAPI.create_run(5)
	_load_current_room()
	hud.move_input.connect(_on_move_input)
	hud.interact_pressed.connect(func(): player.interact())
	hud.inspect_pressed.connect(func(): player.inspect())
	hud.emote_pressed.connect(func(): player.emote())
	hud.tap_move.connect(_on_tap_move)
	player.request_inspect.connect(_on_inspect)
	player.request_interact.connect(_on_interact)

func _process(_delta: float) -> void:
	if show_debug:
		var trap_timer := current_room.get_debug_timer() if current_room != null and current_room.has_method("get_debug_timer") else 0.0
		var room_info := ServerAPI.get_current_room()
		debug_label.text = "FPS:%s\nRoom:%s\nSeed:%s\nTrap:%.2f" % [Engine.get_frames_per_second(), room_info.get("room_id", "-"), room_info.get("seed", 0), trap_timer]
	else:
		debug_label.text = ""

func _load_current_room() -> void:
	for child in room_root.get_children():
		child.queue_free()
	var room_data := ServerAPI.get_current_room()
	if room_data.is_empty():
		return
	status_label.text = "Room %d / %d" % [ServerAPI.current_index + 1, run_rooms.size()]
	current_room = room_scene_map[room_data["room_id"]].instantiate()
	room_root.add_child(current_room)
	current_room.setup(int(room_data["seed"]), room_data["room_id"], player)
	current_room.player_died.connect(_on_player_died)
	current_room.room_cleared.connect(_on_room_cleared)
	player.global_position = Vector2(64, 64)
	_spawn_remnants(room_data)

func _spawn_remnants(room_data: Dictionary) -> void:
	for rem in DeathRemnantStore.list_for_room(room_data["room_id"], int(room_data["seed"])):
		var r := preload("res://scenes/DeathRemnant.tscn").instantiate()
		room_root.add_child(r)
		r.setup(rem)

func _on_move_input(vec: Vector2) -> void:
	player.tap_to_move = false
	player.set_move_input(vec)

func _on_tap_move(world_pos: Vector2) -> void:
	if not tap_to_move:
		return
	player.tap_to_move = true
	player.set_path([world_pos])

func _on_inspect() -> void:
	current_room.on_player_inspect()

func _on_interact() -> void:
	current_room.on_player_interact()

func _on_player_died(position: Vector2) -> void:
	vignette.visible = true
	await get_tree().create_timer(0.45).timeout
	ServerAPI.fail_run(ServerAPI.get_current_room(), position)

func _on_room_cleared() -> void:
	if ServerAPI.advance_room():
		_load_current_room()

func _on_run_failed(_reason: String) -> void:
	get_tree().change_scene_to_file("res://scenes/Hub.tscn")

func _on_run_complete() -> void:
	MansionStateStore.apply_rewire()
	get_tree().change_scene_to_file("res://scenes/Hub.tscn")

func _on_settings_pressed() -> void:
	tap_to_move = not tap_to_move

func _on_debug_toggled() -> void:
	show_debug = not show_debug

func _on_decay_debug_pressed() -> void:
	DeathRemnantStore.set_debug_decay(0.1)
