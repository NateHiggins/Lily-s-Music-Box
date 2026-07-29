class_name WaveformView
extends Control
## Stylized loop timeline on the monitor. Not scientifically accurate — its
## job is to make the rhythm legible without solving it for the player:
## solid bars for heard events, a dashed hollow slot where the fifth event
## *should* be. Doubles as the visual rhythm track for players without audio.

enum Mode { IDLE, LIVE, CAPTURED }

const COL_BG := Color(0.04, 0.06, 0.08)
const COL_LINE := Color(0.16, 0.24, 0.28)
const COL_EVENT := Color(0.34, 0.9, 0.83)
const COL_GHOST := Color(0.95, 0.65, 0.35)

var mode: Mode = Mode.IDLE
var motif: MotifDefinition = null
var show_markers := true
var ghost_emphasis := 0.0  # 0..1, ramps up when the missing beat matters

var _playhead := -1.0      # normalized 0..1, -1 = hidden
var _pulses: Array = []    # transient flashes: {x: norm pos, age, accent, ghost}
var _blink_t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(300, 90)


func set_motif(m: MotifDefinition) -> void:
	motif = m
	queue_redraw()


func set_mode(m: Mode) -> void:
	mode = m
	if m != Mode.CAPTURED:
		_playhead = -1.0
	queue_redraw()


func set_playhead(norm: float) -> void:
	_playhead = norm


## Flash a transient at an event position (LIVE mode: rolling pulses).
func notify_event(index: int, accent: float) -> void:
	var x := 0.5
	if motif and motif.loop_duration > 0.0 and index < motif.event_count():
		x = motif.event_times[index] / motif.loop_duration
	_pulses.append({"x": x, "age": 0.0, "accent": accent, "ghost": motif and motif.is_missing(index)})


func _process(delta: float) -> void:
	_blink_t += delta
	for p in _pulses:
		p.age += delta
	_pulses = _pulses.filter(func(p): return p.age < 0.8)
	if mode != Mode.IDLE:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, COL_BG)
	draw_rect(r, COL_LINE, false, 1.0)
	var midy := size.y * 0.55
	draw_line(Vector2(4, midy), Vector2(size.x - 4, midy), COL_LINE, 1.0)

	if mode == Mode.IDLE:
		draw_string(get_theme_default_font(), Vector2(10, 20), "NO SIGNAL",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.36, 0.4))
		return

	if mode == Mode.CAPTURED and motif and show_markers:
		_draw_markers(midy)
	if _playhead >= 0.0:
		var px: float = 6.0 + _playhead * (size.x - 12.0)
		draw_line(Vector2(px, 6), Vector2(px, size.y - 6), Color(0.9, 0.95, 1.0, 0.5), 1.0)
	for p in _pulses:
		var px: float = 6.0 + p.x * (size.x - 12.0)
		var a: float = (1.0 - p.age / 0.8) * 0.9
		var col := COL_GHOST if p.ghost else COL_EVENT
		draw_circle(Vector2(px, midy), 4.0 + p.age * 14.0, Color(col.r, col.g, col.b, a * 0.4))
		draw_circle(Vector2(px, midy), 3.0, Color(col.r, col.g, col.b, a))


func _draw_markers(midy: float) -> void:
	for i in motif.event_count():
		var x := 6.0 + (motif.event_times[i] / motif.loop_duration) * (size.x - 12.0)
		var h := motif.accent_at(i) * (size.y * 0.38)
		if motif.is_missing(i):
			# Dashed hollow slot: the shape of the absent answer.
			var blink := 0.5 + 0.5 * sin(_blink_t * 3.0)
			var a := lerpf(0.25, 0.95, ghost_emphasis * blink)
			var col := Color(COL_GHOST.r, COL_GHOST.g, COL_GHOST.b, a)
			var y := midy - h
			while y < midy + h:
				draw_line(Vector2(x, y), Vector2(x, minf(y + 4, midy + h)), col, 2.0)
				y += 8.0
			draw_string(get_theme_default_font(), Vector2(x - 4, midy + h + 14), "?",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		else:
			draw_rect(Rect2(x - 2, midy - h, 4, h * 2.0), COL_EVENT)
