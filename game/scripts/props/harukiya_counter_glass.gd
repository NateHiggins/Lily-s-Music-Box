extends Node3D
## The Harukiya's counter. An empty glass waits at the east end of the bar; the
## player's hand slides it across toward the back bar, which is how a customer asks
## for the bartender here. When the staff clock has Stacy behind the bar she comes
## over and her conversation opens; otherwise the glass only crosses the wood.
## Released, it slides back to the customer's side by itself.
## Attendance stays with the staff clock, the lines with her authored tree.

const STAFF := "stacy"
const PLACE := "harukiya_bar"
const STOCK := "3D_glass"
## Source metres: past the last stool at the east end of the counter, on the
## customer's edge of the top, and how far across the top it travels.
const HOME := [0.95, -30.22]
const TOP_Z := -1.72
const SLIDE := 0.5
const ACROSS_AT := 0.9
const SLIDE_PIXELS := 200.0
const RETURN_SPEED := 0.8
const NOTICE_SECONDS := 3.5
const NOBODY := "Nobody is behind the bar."

var world: Node3D
var conversations: ResidentConversations
var glass: Node3D
var notice: Label
var _held := false
var _slide := 0.0
var _called := false
var _notice_left := 0.0
var cast: Node3D
var _clink: AudioStreamPlayer3D


func configure(runtime: Node3D, region: Node3D, talk: ResidentConversations) -> bool:
	world = runtime
	conversations = talk
	if region == null or talk == null:
		return false
	region.get("actors").add_child(self)
	position = GameBoot.b2g([HOME[0], HOME[1], TOP_Z])
	var stock := preload("res://scripts/building/orison_v2_surface_stock.gd").new()
	if not stock.prepare():
		return false
	glass = Node3D.new()
	glass.name = "CounterGlass"
	add_child(glass)
	var mounted: bool = stock.mount_on(glass, STOCK)
	stock.finish()
	if not mounted:
		return false
	preload("res://scripts/props/manipulation_area.gd").install(glass, _grip)
	_clink = AudioStreamPlayer3D.new()
	_clink.stream = PropAudio.get_stream("tick")
	_clink.unit_size = 2.0
	add_child(_clink)
	var layer := CanvasLayer.new()
	layer.layer = 59
	add_child(layer)
	notice = Label.new()
	notice.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	notice.offset_left = 160.0
	notice.offset_right = -160.0
	notice.offset_top = -170.0
	notice.offset_bottom = -70.0
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	notice.add_theme_color_override("font_color", Color(0.93, 0.92, 0.88))
	notice.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	notice.add_theme_constant_override("outline_size", 6)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(notice)
	cast = preload("res://scripts/characters/harukiya_cast.gd").new()
	if not cast.configure(runtime, region, self, talk):
		push_error("Harukiya cast presentation refused")
		return false
	return true


## Across the top, away from the customer: source north, the back bar's side.
func across() -> Vector3:
	return (GameBoot.b2g([0.0, 1.0, 0.0]) - GameBoot.b2g([0.0, 0.0, 0.0])).normalized()


func on_shift() -> bool:
	return str(world.resident_whereabouts(STAFF).get("place", "")) == PLACE


func _grip() -> Dictionary:
	return {"owner": self, "part": glass, "frame": self, "kind": "slide", "axis": across(),
		"minimum": 0.0, "maximum": SLIDE, "gesture_travel_px": SLIDE_PIXELS,
		"gesture_screen_axis": Vector2.UP,
		"read": func(): return _slide,
		"write": func(value: float):
			if _held:
				_slide = value
				_pose()
				if _slide >= SLIDE * ACROSS_AT and not _called:
					_called = true
					_arrive(),
		"owns": func(): return _held,
		"begin": func():
			if _held:
				return false
			_held = true
			_called = false
			return true,
		"end": func():
			_held = false}


func _pose() -> void:
	glass.position = across() * _slide


## The glass has reached the far side of the top.
func _arrive() -> void:
	_clink.play()
	if on_shift() and conversations.start(STAFF):
		# She takes the glass: the hand lets go, so no grip outlasts the conversation.
		var player := get_tree().get_first_node_in_group("player_controller")
		if player != null and player.has_method("cancel_manipulation"):
			player.cancel_manipulation()
		_held = false
		return
	notice.text = NOBODY
	_notice_left = NOTICE_SECONDS


func _process(delta: float) -> void:
	if not _held and _slide > 0.0:
		_slide = maxf(_slide - RETURN_SPEED * delta, 0.0)
		_pose()
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			notice.text = ""
