extends Node3D
## Optional street play. Transient bodies and scores have no save authority.

const Stone := preload("res://scripts/game/street_rock.gd")
const KICK_ACTION := &"street_rock_kick"
const COMBO_SECONDS := 2.35
const REACH := 1.55
const WORLD_LAYER := 1
const ROCK_LAYER := 1 << 24
const MAX_LINKS := 24
const DRIVE_SPEED := 3.7
const HUD_COLOR := Color("#dfcf9e")
const CONTROL_PAD := "B"
const CONTROL_KEYS := "G"
# Front pavement, the side of the public crossing and the far curb.
# Sites stay clear of door swings in the front threshold world frame.
const SITES: Array[Vector3] = [
	Vector3(-1.8, 0.0, 3.6), Vector3(-0.9, 0.0, 3.8),
	Vector3(1.6, 0.0, 3.6), Vector3(3.1, 0.0, 3.9),
	Vector3(10.5, 0.0, 3.9), Vector3(12.6, 0.0, 4.9),
	Vector3(12.9, -0.1, 7.6), Vector3(15.1, -0.1, 8.8),
	Vector3(12.9, 0.0, 15.7), Vector3(14.9, 0.0, 16.5),
	Vector3(12.8, 0.0, 19.1), Vector3(14.9, 0.0, 19.8),
]

var total := 0
var pending := 0
var links := 0
var _combo_left := 0.0
var _show_left := 0.0
var _last_trick := ""
var _last_award := 0
var _variety := {}
var _player: PlayerController
var _stones: Array[Stone] = []
var _hud: Label
var _last_device_pad := false
var _kick_requested := false
var _target: Stone
var _aim_refresh := 0.0
var _touch: TouchControls


func setup(player: PlayerController) -> void:
	_player = player
	_make_hud()


func bind_touch(touch: TouchControls) -> void:
	_touch = touch
	touch.street_kick_requested.connect(_request_touch_kick)


func _request_touch_kick() -> void:
	if _can_play():
		_kick_requested = true


func populate(sites: Array[Vector3] = SITES) -> void:
	# The next physics sync registers the composed pavement and walls.
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	for index in sites.size():
		var p := sites[index]
		var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.85, p - Vector3.UP * 0.55, WORLD_LAYER)
		ray.exclude = [_player.get_rid()]
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or not hit.collider is StaticBody3D or hit.normal.y < 0.82:
			continue
		var size: float = [0.87, 1.0, 1.22][index % 3]
		add_stone(hit.position + Vector3.UP * size * 0.034, size, index * 1.67)


func add_stone(at: Vector3, size: float, yaw: float) -> Stone:
	var stone := Stone.new()
	stone.name = "StreetStone%02d" % _stones.size()
	stone.collision_layer = ROCK_LAYER
	stone.collision_mask = WORLD_LAYER | ROCK_LAYER
	stone.build(size, yaw)
	stone.position = to_local(at)
	stone.sleeping = true
	add_child(stone)
	stone.add_collision_exception_with(_player)
	stone.trick_scored.connect(_physical_trick)
	_stones.append(stone)
	return stone


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_last_device_pad = false
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.35):
		_last_device_pad = true
	if not event.is_action_pressed(KICK_ACTION) or not _can_play() or _aimed_stone() == null:
		return
	_kick_requested = true
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_aim_refresh -= delta
	if not _kick_requested and _aim_refresh > 0.0:
		return
	_aim_refresh = 0.12
	var requested := _kick_requested
	_kick_requested = false
	_target = _reachable_stone() if _can_play() and _player.is_on_floor() else null
	if is_instance_valid(_touch):
		_touch.set_street_kick_available(_target != null)
	if requested and _target != null:
		_kick(_target)


func _reachable_stone() -> Stone:
	var stone := _aimed_stone()
	if stone == null:
		return null
	var origin := _player.global_position + Vector3.UP * 0.3
	var target := stone.global_position + Vector3.UP * 0.02
	var ray := PhysicsRayQueryParameters3D.create(origin, target, WORLD_LAYER, [_player.get_rid()])
	return stone if get_world_3d().direct_space_state.intersect_ray(ray).is_empty() else null


func _kick(stone: Stone) -> void:
	var direction := stone.global_position - _player.global_position
	direction.y = 0.0
	direction = direction.normalized()
	if _player.crouched:
		stone.kick(direction, 2.6, 3.25, 0.024)
		_score("Pop Kick", 50, true)
	elif _player.planar_speed() >= DRIVE_SPEED:
		stone.kick(direction, 5.6, 0.6, 0.014)
		_score("Drive Kick", 35, true)
	else:
		stone.kick(direction, 3.5, 0.22, 0.009)
		_score("Ground Kick", 20, true)


func _can_play() -> bool:
	return is_instance_valid(_player) and is_instance_valid(_player.camera) \
		and _player.camera.is_current() and not _player.call_locked \
		and not _player.mouse_released and not _player.protected_input_active() \
		and not _player.noclip and not is_instance_valid(_player.seated_on) \
		and not _player.inspecting() and not is_instance_valid(_player.text_input_owner) \
		and (_player.touch_input or _player.pointer_captured())


func _aimed_stone() -> Stone:
	var forward := -_player.camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best := -INF
	var target: Stone
	for stone in _stones:
		var offset := stone.global_position - _player.global_position
		if absf(offset.y) > 0.62:
			continue
		offset.y = 0.0
		var distance := offset.length()
		if distance < 0.10 or distance > REACH:
			continue
		var facing := forward.dot(offset / distance)
		var rank := facing - distance * 0.33
		if facing >= 0.76 and rank > best:
			target = stone
			best = rank
	return target


func _physical_trick(trick: String, points: int) -> void:
	if links > 0:
		_score(trick, points, false)


func _score(trick: String, points: int, kick: bool) -> void:
	if links >= MAX_LINKS:
		return
	var prior: int = _variety.get(trick, 0)
	_variety[trick] = prior + 1
	pending += maxi(1, floori(float(points) / (prior + 1)))
	links += 1
	_last_trick = trick
	if kick:
		_combo_left = COMBO_SECONDS


func _multiplier() -> int:
	return mini(_variety.size() + floori(float(links - 1) / 4.0), 8)


func _process(delta: float) -> void:
	if not is_instance_valid(_hud):
		return
	if links > 0:
		_combo_left -= delta
		if _combo_left <= 0.0:
			_last_award = pending * _multiplier()
			total += _last_award
			_show_left = 2.0
			links = 0
			pending = 0
			_variety.clear()
	_show_left -= delta
	if not _can_play():
		_hud.hide()
		return
	if links > 0:
		_hud.text = "%s   %d × %d   ·   %d links" % [_last_trick, pending, _multiplier(), links]
	elif _show_left > 0.0:
		_hud.text = "+%d banked   ·   Street score %d" % [_last_award, total]
	elif is_instance_valid(_target):
		var button := CONTROL_PAD if _last_device_pad else CONTROL_KEYS
		var hint := "Tap Kick" if _player.touch_input else button + "  Kick"
		_hud.text = "%s   ·   Crouch to pop" % hint
	else:
		_hud.hide()
		return
	_hud.show()


func _make_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud = Label.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_theme_color_override("font_color", HUD_COLOR)
	_hud.add_theme_color_override("font_outline_color", Color("#1a160f"))
	_hud.add_theme_constant_override("outline_size", 5)
	_hud.add_theme_font_size_override("font_size", 17)
	root.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hud.offset_top = -84
	_hud.offset_bottom = -57
	_hud.hide()
