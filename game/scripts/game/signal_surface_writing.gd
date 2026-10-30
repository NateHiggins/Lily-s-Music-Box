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

func _ready() -> void:
	set_process(false)

func show_message(text: String, reveal_seconds := 1.5, hold_seconds := -1.0,
		width_metres := 1.25) -> bool:
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
	var pixel_size := 0.0024
	var font_size := 52
	var widest := 1.0
	for line: String in text.split("\n"):
		widest=maxf(widest,FONT.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
	pixel_size=minf(pixel_size,width_metres/widest)
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
	transcription_changed.emit("")

func _process(delta: float) -> void:
	_elapsed+=maxf(0.0,delta)
	var fraction := 1.0 if _reveal_seconds<=0.0 else clampf(_elapsed/_reveal_seconds,0.0,1.0)
	var visible_characters := int(ceil(fraction*_characters))
	var opacity := 1.0
	if _hold_seconds>=0.0 and _elapsed>_reveal_seconds+_hold_seconds:
		opacity=clampf(1.0-(_elapsed-_reveal_seconds-_hold_seconds)/0.5,0,1)
	for word: Dictionary in _words:
		var label: Label3D=word.label
		var count := clampi(visible_characters-int(word.start),0,str(word.text).length())
		if count!=int(word.count):
			label.text=str(word.text).left(count);word.count=count
		label.modulate=Color(INK,opacity if count>0 else 0.0)
	if fraction>=1.0 and not _announced:
		_announced=true;revealed.emit(current_text)
	if opacity<=0.0: clear()
	elif fraction>=1.0 and _hold_seconds<0.0: set_process(false)
