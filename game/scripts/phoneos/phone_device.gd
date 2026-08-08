class_name PhoneDevice
extends Control
## The NOCTURNE 900 — the handset itself, as opposed to what runs on it.
##
## Deliberately split from PhoneOS. The OS renders 60x24 characters into
## a SubViewport at exactly 480x384 and knows nothing about bezels; this
## draws the physical object around that texture. Two consequences worth
## having: the same OS can later be pasted onto a phone held in a 3D
## hand without changing a line of it, and the screen is genuinely a
## low-resolution display being magnified rather than large text.
##
## The body is a 2011 enterprise handset: squared shoulders, a real
## QWERTY under the screen, a trackpad flanked by call / menu / back /
## end, and a notification LED that has never once been reassuring.

const SCREEN_W := TermGrid.COLS * TermGrid.CW    # 480
const SCREEN_H := TermGrid.ROWS * TermGrid.CH    # 384
const SCALE := 2
const BEZEL := 26
const BODY := Color("17131a")
const BODY_HI := Color("241d28")
const CHROME := Color("6a6472")
const KEYCAP := Color("1d1822")
const KEYTEXT := Color("8d8496")

const ROWS_QWERTY := ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]

var os_sim := PhoneOS.new()
var _font: Font
var _screen: SubViewport
var _canvas: Control
var _led := Color("5cf07a")


func _ready() -> void:
	_font = TermGrid.make_font()
	os_sim.boot()
	# The screen is a real viewport at the panel's real resolution. Its
	# texture is then magnified with nearest-neighbour, which is what
	# makes the pixels hard instead of soft.
	_screen = SubViewport.new()
	_screen.size = Vector2i(SCREEN_W, SCREEN_H)
	_screen.transparent_bg = false
	_screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_screen)
	_canvas = Control.new()
	_canvas.size = Vector2(SCREEN_W, SCREEN_H)
	_canvas.draw.connect(_draw_screen)
	_screen.add_child(_canvas)
	custom_minimum_size = device_size()
	set_process(true)
	set_process_unhandled_input(true)


static func device_size() -> Vector2:
	# body = screen + bezel both sides + nav cluster + three key rows
	return Vector2(SCREEN_W * SCALE + BEZEL * 2,
			SCREEN_H * SCALE + BEZEL * 2 + 250)


## Scale the whole handset to fit a viewport and centre it.
##
## The device is 1070 px tall at SCALE 2, which is taller than a 720p
## window - so without this the keyboard simply is not on screen, which
## is how the first framegrab came out. Scaling the Control rather than
## dropping SCALE keeps the panel's own pixels square and hard; the
## magnification just ends up non-integer, which for a photograph of a
## phone is fine.
func fit_into(view: Vector2) -> void:
	var size := device_size()
	var f: float = minf(1.0, minf(view.x / size.x, view.y / size.y))
	scale = Vector2(f, f)
	position = (view - size * f) * 0.5


func _process(delta: float) -> void:
	os_sim.advance(delta)
	_canvas.queue_redraw()
	queue_redraw()


func _draw_screen() -> void:
	var grid := os_sim.render()
	_canvas.draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), TermGrid.BG)
	grid.draw(_canvas, _font)
	# Scanlines. One dark row every second line, at the PANEL's
	# resolution - drawn here rather than as a post effect so it
	# magnifies with everything else and stays crisp.
	for y in range(0, SCREEN_H, 2):
		_canvas.draw_rect(Rect2(0, y, SCREEN_W, 1),
				Color(0, 0, 0, 0.22))


func _draw() -> void:
	var w := SCREEN_W * SCALE
	var h := SCREEN_H * SCALE
	var ox := BEZEL
	var oy := BEZEL
	# body
	draw_rect(Rect2(0, 0, w + BEZEL * 2, h + BEZEL * 2 + 250), BODY)
	draw_rect(Rect2(4, 4, w + BEZEL * 2 - 8, h + BEZEL * 2 + 242),
			BODY_HI)
	# a chrome band down each side, the one flourish the hardware had
	draw_rect(Rect2(0, 60, 4, h + 120), CHROME)
	draw_rect(Rect2(w + BEZEL * 2 - 4, 60, 4, h + 120), CHROME)
	# screen well and the panel itself
	draw_rect(Rect2(ox - 6, oy - 6, w + 12, h + 12), Color("0b070d"))
	var tex := _screen.get_texture()
	if tex:
		tex.draw_rect(get_canvas_item(), Rect2(ox, oy, w, h), false)
	# maker's mark and the notification LED
	draw_string(_font, Vector2(ox + 8, oy - 10), "NOCTURNE 900",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, KEYTEXT)
	var pulse: float = 0.35 + 0.65 * absf(sin(os_sim.led_pulse * 1.7))
	draw_circle(Vector2(ox + w - 12, oy - 14), 5.0,
			Color(_led.r, _led.g, _led.b, pulse))
	_draw_navcluster(ox, oy + h + 18, w)
	_draw_keyboard(ox, oy + h + 92, w)


## Call / menu / trackpad / back / end, in the order the hardware had
## them. The trackpad is the thing your thumb lives on.
func _draw_navcluster(x: int, y: int, w: int) -> void:
	var labels := ["CALL", "MENU", "", "BACK", "END"]
	var cw := w / 5
	for i in 5:
		var r := Rect2(x + i * cw + 4, y, cw - 8, 54)
		if i == 2:
			draw_rect(r, Color("2c2532"))
			draw_rect(Rect2(r.position + Vector2(10, 10),
					r.size - Vector2(20, 20)), Color("3a3242"))
			continue
		draw_rect(r, KEYCAP)
		var col: Color = KEYTEXT
		if i == 0:
			col = Color("5cf07a")
		elif i == 4:
			col = Color("c4788a")
		draw_string(_font, r.position + Vector2(12, 34), labels[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)


## The reason anyone kept these phones. Three staggered rows, frets
## between the columns, keys wider than they are tall.
func _draw_keyboard(x: int, y: int, w: int) -> void:
	for r in ROWS_QWERTY.size():
		var row: String = ROWS_QWERTY[r]
		var kw := float(w) / 10.0
		var inset := (w - row.length() * kw) * 0.5
		for c in row.length():
			var kr := Rect2(x + inset + c * kw + 2, y + r * 44, kw - 4, 40)
			draw_rect(kr, KEYCAP)
			draw_rect(Rect2(kr.position, Vector2(kr.size.x, 2)),
					Color("312a38"))
			draw_string(_font, kr.position + Vector2(kw * 0.36, 26),
					row[c], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, KEYTEXT)
	# space bar
	var sr := Rect2(x + w * 0.28, y + 3 * 44, w * 0.44, 34)
	draw_rect(sr, KEYCAP)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_LEFT: os_sim.key("left")
		KEY_RIGHT: os_sim.key("right")
		KEY_UP: os_sim.key("up")
		KEY_DOWN: os_sim.key("down")
		KEY_ENTER, KEY_KP_ENTER: os_sim.key("ok")
		KEY_ESCAPE, KEY_BACKSPACE:
			if k.keycode == KEY_BACKSPACE:
				os_sim.key("backspace")
			else:
				os_sim.key("back")
		_:
			var ch := char(k.unicode)
			if ch.strip_edges() != "" or ch == " ":
				os_sim.key("type", ch)
