extends CanvasLayer
## Her plate camera (Lily's ruling wall_photos_how_20261120: "hold the camera up anywhere, frame, press; that view is
## what the print shows"). One key raises it and, pressed again, takes the picture; another lowers it unused. Raised,
## the view is masked to the plate's frame and nothing else is drawn over it. A picture needs a blank plate in the
## case. What the lens saw is written once, small and without colour, to PhotoSales.picture_path(number); the photo
## bench (PhotoSales) keeps which plate holds which picture. It reads the world and writes that one file and the
## bench's own record: no clock, route, case or loop state. It never reads the computer's clock.
const RAISE := "plate_camera"
const LOWER := "plate_camera_lower"
const KEYS := {RAISE: KEY_O, LOWER: KEY_X}
## The plate's proportions and the picture kept from it.
const PLATE_SHAPE := 4.0 / 3.0
const PICTURE := Vector2i(640, 480)
## How much of the view's height the frame takes.
const FRAME_HEIGHT := 0.78

signal exposed(number: int)

var world: Node
var raised := false
var _mask: Control
var _bars: Array[ColorRect] = []
var _busy := false
var _told := false


func setup(root: Node) -> void:
	world = root


func _ready() -> void:
	layer = 40
	for action: String in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = KEYS[action]
			InputMap.action_add_event(action, key)
	_mask = Control.new()
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.visible = false
	add_child(_mask)
	for _index in 8:
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mask.add_child(bar)
		_bars.append(bar)
	_mask.resized.connect(_lay_out)
	_lay_out()


## The part of the view the plate takes, in viewport pixels.
func frame_rect() -> Rect2:
	var view := get_viewport().get_visible_rect().size
	var tall := view.y * FRAME_HEIGHT
	var wide := minf(tall * PLATE_SHAPE, view.x * 0.94)
	tall = wide / PLATE_SHAPE
	return Rect2((view - Vector2(wide, tall)) * 0.5, Vector2(wide, tall))


func _lay_out() -> void:
	if _bars.size() < 8:
		return
	var view := get_viewport().get_visible_rect().size
	var frame := frame_rect()
	var dark := Color(0.0, 0.0, 0.0, 0.86)
	var edges := [Rect2(Vector2.ZERO, Vector2(view.x, frame.position.y)), Rect2(Vector2(0, frame.end.y), Vector2(view.x, view.y - frame.end.y)),
		Rect2(Vector2(0, frame.position.y), Vector2(frame.position.x, frame.size.y)), Rect2(Vector2(frame.end.x, frame.position.y), Vector2(view.x - frame.end.x, frame.size.y))]
	for index in 4:
		_bars[index].position = (edges[index] as Rect2).position
		_bars[index].size = (edges[index] as Rect2).size
		_bars[index].color = dark
	# A hairline round the ground glass.
	var line := Color(0.92, 0.9, 0.82, 0.55)
	var hair := [Rect2(frame.position, Vector2(frame.size.x, 1)), Rect2(Vector2(frame.position.x, frame.end.y - 1), Vector2(frame.size.x, 1)),
		Rect2(frame.position, Vector2(1, frame.size.y)), Rect2(Vector2(frame.end.x - 1, frame.position.y), Vector2(1, frame.size.y))]
	for index in 4:
		_bars[4 + index].position = (hair[index] as Rect2).position
		_bars[4 + index].size = (hair[index] as Rect2).size
		_bars[4 + index].color = line


func _player() -> PlayerController:
	return world.get("player") as PlayerController if world != null else null


func _typing() -> bool:
	var player := _player()
	return player != null and is_instance_valid(player.text_input_owner)


func _unhandled_key_input(event: InputEvent) -> void:
	if _busy or _typing() or get_tree().paused:
		return
	if event.is_action_pressed(RAISE) and not event.is_echo():
		get_viewport().set_input_as_handled()
		if raised:
			take_picture()
		else:
			raise_camera()
	elif raised and event.is_action_pressed(LOWER) and not event.is_echo():
		get_viewport().set_input_as_handled()
		lower_camera()


## True when the camera came up. It stays down, with a slip, when there is no blank plate.
func raise_camera() -> bool:
	if raised:
		return true
	if PhotoSales.blank_plates() <= 0:
		_slip("NO BLANK PLATE", "The camera stays in the case.", "EMPTY")
		return false
	raised = true
	_lay_out()
	_mask.visible = true
	if not _told:
		# Once a sitting, on the slip printer, as every instruction is (RUL-013).
		_told = true
		_slip("THE CAMERA IS UP", "O again takes the picture. X puts it away.", "READY")
	return true


func lower_camera() -> void:
	raised = false
	_mask.visible = false


## Take the picture in the frame. Returns its number, or 0 when none was taken.
func take_picture() -> int:
	if not raised or _busy:
		return 0
	if PhotoSales.blank_plates() <= 0:
		lower_camera()
		return 0
	_busy = true
	var frame := frame_rect()
	_mask.visible = false
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var view := get_viewport().get_visible_rect().size
	var scale := Vector2(float(image.get_width()) / view.x, float(image.get_height()) / view.y)
	var region := Rect2i(Vector2i((frame.position * scale).round()), Vector2i((frame.size * scale).round())).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var number := 0
	if region.size.x > 8 and region.size.y > 8:
		var plate := image.get_region(region)
		plate.resize(PICTURE.x, PICTURE.y, Image.INTERPOLATE_LANCZOS)
		plate.convert(Image.FORMAT_L8)
		plate.convert(Image.FORMAT_RGB8)
		PhotoSales.ready_roll()
		if plate.save_webp(PhotoSales.picture_path(PhotoSales.next_picture()), true, 0.86) == OK:
			var eye := get_viewport().get_camera_3d()
			var room := str(world.call("room_at_world", eye.global_position)) if world != null and eye != null and world.has_method("room_at_world") else ""
			var taken := CampaignClock.new().datetime_string() if RealityState.data.has("campaign_clock") else ""
			number = PhotoSales.expose(room, taken)
			if number > 0:
				RealityState.commit()
	_busy = false
	lower_camera()
	if number > 0:
		_slip("PLATE %d EXPOSED" % number, "%d blank left. Print it at Photo Supplies, at the counter or in the tray." % PhotoSales.blank_plates(), "EXPOSED")
		exposed.emit(number)
	return number


func _slip(title: String, body: String, condition: String) -> void:
	var player := _player()
	if player != null:
		player.present_service_note(self, {"title": title, "body": body, "condition": condition, "stamp": "THE CAMERA"})
