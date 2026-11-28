extends Node3D
## Event-driven world lettering. No HUD, collision, light or gameplay state.
signal transcription_changed(text: String)
signal revealed(text: String)
const FONT := preload("res://assets/fonts/eb_garamond/EBGaramond-Italic[wght].ttf")
const INK := Color(0.68,1.65,0.89,1.0)
var current_text := ""
var _words: Array[Dictionary]=[]
var _elapsed := 0.0
var _reveal_seconds := 1.5
var _hold_seconds := -1.0
var _characters := 0
var _announced := false
# Haunted typing (Lily 2026-11-28, the wake-up line): each letter typed leaves
# faint copies of the whole message strewn across the wall, as if she has been
# woken to this reminder many times before. Fixed seed, bounded count.
const ECHO_LIMIT := 72
# Strewn over the wall around the live line, with a clear band kept around it
# so the line itself always reads.
const ECHO_SPREAD := Vector2(1.05,.72)
const ECHO_CLEAR := Vector2(.62,.13)
var _echoes_per_letter := 0
var _echoes: Array[Dictionary]=[]
var _echo_rng := RandomNumberGenerator.new()
var _shown_characters := 0
var _quiet := false
var _font_size := 52
var _pixel_size := .0024

func _ready() -> void:
	set_process(false)

func show_message(text: String, reveal_seconds := 1.5, hold_seconds := -1.0,
		width_metres := 1.25, echoes_per_letter := 0) -> bool:
	if text.is_empty() or text.length()>160 or text.split("\n").size()>3: return false
	if not is_finite(reveal_seconds) or reveal_seconds<0.0 or reveal_seconds>8.0: return false
	if not is_finite(hold_seconds) or hold_seconds< -1.0: return false
	if not is_finite(width_metres) or width_metres<=0.1 or width_metres>2.0: return false
	var word_count := 0
	for line: String in text.split("\n"): word_count+=line.split(" ",false).size()
	if word_count>24: return false
	clear()
	current_text=text
	_reveal_seconds=reveal_seconds;_hold_seconds=hold_seconds
	_echoes_per_letter=clampi(echoes_per_letter,0,6)
	_echo_rng.seed=hash(text)
	_quiet=bool(GameBoot.settings.get("reduce_flashing",false))
	var pixel_size := 0.0024
	var font_size := 52
	var widest := 1.0
	for line: String in text.split("\n"):
		widest=maxf(widest,FONT.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
	pixel_size=minf(pixel_size,width_metres/widest)
	_font_size=font_size;_pixel_size=pixel_size
	var space_width := FONT.get_string_size(" ",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*pixel_size
	var row := 0
	for line: String in text.split("\n"):
		var x := -FONT.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*pixel_size*0.5
		for word: String in line.split(" ",false):
			var size := FONT.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)*pixel_size
			var label := Label3D.new()
			label.name="SignalWord%d" % _words.size()
			label.font=FONT;label.font_size=font_size;label.pixel_size=pixel_size
			label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
			label.outline_size=3;label.outline_modulate=Color(.015,.045,.025,.95)
			label.shaded=false;label.no_depth_test=false;label.billboard=BaseMaterial3D.BILLBOARD_DISABLED
			label.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Fixed word-level irregularity; no perpetual jitter or processing.
			var seed_value := float(_words.size()+1)
			label.position=Vector3(x,-row*font_size*pixel_size*1.35+sin(seed_value*2.71)*.0015,0)
			label.rotation.z=sin(seed_value*4.13)*.009
			label.modulate=Color(INK,0)
			label.text=word # Warm the final glyphs before incremental reveal.
			add_child(label)
			_words.append({"label":label,"text":word,"start":_characters,"count":0})
			_characters+=word.length();x+=size.x+space_width
			label.text=""
		row+=1
	transcription_changed.emit(current_text)
	set_process(true)
	_process(0.0)
	return true

func clear() -> void:
	set_process(false)
	for word: Dictionary in _words:
		var label: Label3D=word.label
		if is_instance_valid(label):
			remove_child(label);label.queue_free()
	_words.clear();current_text="";_elapsed=0;_characters=0;_announced=false
	for echo: Dictionary in _echoes:
		var ghost: Label3D=echo.label
		if is_instance_valid(ghost):
			remove_child(ghost);ghost.queue_free()
	_echoes.clear();_shown_characters=0;_echoes_per_letter=0
	transcription_changed.emit("")


## One faint, displaced copy of the whole message. It flares as it is written
## (a still flare under reduced flashing) and settles to a residue.
func _spawn_echo() -> void:
	if _echoes.size()>=ECHO_LIMIT:return
	var ghost := Label3D.new()
	ghost.name="SignalEcho%d" % _echoes.size()
	ghost.font=FONT;ghost.font_size=_font_size
	ghost.pixel_size=_pixel_size*_echo_rng.randf_range(.55,1.25)
	ghost.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	ghost.outline_size=0
	ghost.shaded=false;ghost.no_depth_test=false;ghost.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	ghost.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.render_priority=-1
	ghost.text=current_text
	# Behind the live line (which floats 6 mm off the wall), never through it.
	var spot := Vector2.ZERO
	for attempt in 12:
		spot=Vector2(_echo_rng.randf_range(-ECHO_SPREAD.x,ECHO_SPREAD.x),_echo_rng.randf_range(-ECHO_SPREAD.y,ECHO_SPREAD.y*.85))
		if absf(spot.x)>ECHO_CLEAR.x or absf(spot.y)>ECHO_CLEAR.y:break
	ghost.position=Vector3(spot.x,spot.y,-.002-.0002*float(_echoes.size()%6))
	ghost.rotation.z=_echo_rng.randf_range(-.14,.14)
	ghost.modulate=Color(INK,0)
	add_child(ghost)
	_echoes.append({"label":ghost,"born":_elapsed,"rest":_echo_rng.randf_range(.035,.12)})


func _update_echoes() -> void:
	for echo: Dictionary in _echoes:
		var ghost: Label3D=echo.label
		if not is_instance_valid(ghost):continue
		var age: float=_elapsed-float(echo.born)
		var flare := 0.0 if _quiet else .34*exp(-age/.16)
		var arrive := clampf(age/(.35 if _quiet else .08),0,1)
		ghost.modulate=Color(INK,clampf(float(echo.rest)*arrive+flare,0,1))

func _process(delta: float) -> void:
	_elapsed+=maxf(0.0,delta)
	var fraction := 1.0 if _reveal_seconds<=0.0 else clampf(_elapsed/_reveal_seconds,0.0,1.0)
	var visible_characters := int(ceil(fraction*_characters))
	var opacity := 1.0
	if _hold_seconds>=0.0 and _elapsed>_reveal_seconds+_hold_seconds:
		opacity=clampf(1.0-(_elapsed-_reveal_seconds-_hold_seconds)/0.5,0,1)
	if _echoes_per_letter>0:
		while _shown_characters<visible_characters:
			_shown_characters+=1
			for i in _echoes_per_letter:_spawn_echo()
		_update_echoes()
	for word: Dictionary in _words:
		var label: Label3D=word.label
		var count := clampi(visible_characters-int(word.start),0,str(word.text).length())
		if count!=int(word.count):
			label.text=str(word.text).left(count);word.count=count
		label.modulate=Color(INK,opacity if count>0 else 0.0)
	if fraction>=1.0 and not _announced:
		_announced=true;revealed.emit(current_text)
	if opacity<=0.0: clear()
	elif fraction>=1.0 and _hold_seconds<0.0 and (_echoes.is_empty() or _elapsed-float(_echoes[-1].born)>1.2):
		set_process(false)
