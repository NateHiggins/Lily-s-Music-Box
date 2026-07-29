class_name KettleProp
extends FunctionalProp
## Electric kettle on the 4B counter. Interact to switch on: the element
## hums, water works up to the boil, the whistle rises. Infected, the
## whistle's ONSET quantizes to the conductor's next event — the kettle
## still makes tea, it just announces it in time. Case 05's "the kettle
## whistles before one of them raises their voice" starts here.

var heat_time := 22.0  # seconds to boil (tests shorten this)
var cycles_completed := 0

var _hum: AudioStreamPlayer3D
var _whistle: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D
var _body: MeshInstance3D
var _whistle_on_next := false


func _build_visual() -> void:
	_body = make_box(Vector3(0.16, 0.20, 0.16), Vector3(0, 0.10, 0),
			Color(0.75, 0.76, 0.78))
	var bm := _body.material_override as StandardMaterial3D
	bm.metallic = 0.85
	bm.roughness = 0.25
	make_box(Vector3(0.03, 0.10, 0.03), Vector3(0.10, 0.16, 0),
			Color(0.12, 0.12, 0.13))  # handle
	make_box(Vector3(0.04, 0.05, 0.04), Vector3(-0.09, 0.15, 0),
			Color(0.65, 0.66, 0.68))  # spout
	_hum = make_emitter("hum_loop", -60.0, true)
	_hum.pitch_scale = 1.3
	_whistle = make_emitter("whistle_loop", -60.0)
	_whistle.max_distance = 30.0
	_click = make_emitter("tick", -12.0)


func interact_prompt() -> String:
	if state == PState.IDLE:
		return "[E]  Put the kettle on"
	if state == PState.OPERATING or _whistle.playing:
		return "[E]  Take it off the boil"
	return ""


func interact(_player: Node) -> void:
	if state == PState.IDLE:
		_switch_on()
	elif state in [PState.OPERATING, PState.COMPLETING]:
		_switch_off()


func _switch_on() -> void:
	state = PState.OPERATING
	_click.play()
	print("[KETTLE] on")
	create_tween().tween_property(_hum, "volume_db", -22.0, 2.0)
	var boil := get_tree().create_timer(heat_time, false)
	boil.timeout.connect(_request_whistle)


func _request_whistle() -> void:
	if state != PState.OPERATING:
		return
	if Conductor.infection > 0.4:
		_whistle_on_next = true  # the boil waits for the beat
	else:
		_begin_whistle()


func _begin_whistle() -> void:
	if state != PState.OPERATING:
		return
	state = PState.COMPLETING
	_whistle_on_next = false
	_whistle.volume_db = -30.0
	_whistle.play()
	create_tween().tween_property(_whistle, "volume_db", -10.0, 3.0)
	print("[KETTLE] whistling")


func _switch_off() -> void:
	state = PState.IDLE
	cycles_completed += 1
	_click.play()
	create_tween().tween_property(_hum, "volume_db", -60.0, 1.0)
	var tw := create_tween()
	tw.tween_property(_whistle, "volume_db", -60.0, 1.4)
	tw.tween_callback(_whistle.stop)
	print("[KETTLE] off (%d boils)" % cycles_completed)


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	if _whistle_on_next:
		_begin_whistle()
		return
	if state == PState.OPERATING:
		# element relay ticks riding the motif while heating
		_click.volume_db = -16.0 + linear_to_db(clampf(accent, 0.2, 1.0))
		_click.play()
