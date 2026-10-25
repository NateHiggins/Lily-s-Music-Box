extends Node3D
## Physical paper and mechanism only. Gameplay supplies the complete message.
const MODEL := preload("res://assets/props/service_radiophone_v2.glb")
var model_scene: PackedScene = MODEL
var stock_applier: Callable = preload("res://scripts/device/service_radiophone_stock.gd").apply
var model: Node3D
var model_ready := false
const COLUMNS := 30
const ROWS := 10
const HISTORY_LIMIT := 24
const CHARACTER_SECONDS := 1.0/48.0
const RETURN_SECONDS := .09
var reports: Array[Dictionary]=[]
var report_index := -1
var pages: Array[String]=[]
var page := 0
var ink: Label3D
var heading: Label3D
var footer: Label3D
var carriage: Node3D
var hammer: Node3D
var platen: Node3D
var spools: Array[Node3D]=[]
var feed_wheels: Array[Node]=[]
var powered := true
var printing := false
var printed_characters := 0
var _clock := 0.0
var _advance := 0.0
var _carriage_home := Vector3.ZERO
var _hammer_home := Vector3.ZERO
var _tick: AudioStreamPlayer
var _feed: AudioStreamPlayer
var _return_motion: Tween
var _paper_motion: Tween
var _paper: Node3D
var _paper_home := Vector3.ZERO
var _return_left := 0.0
var _column := 0
var _serial := 0
var _reviewing := false
var _return_from := 0.0
var _action_hint := ""
var service_open := false
var service_cover: Node3D
var focus_wheel: Node3D
var torch_lens: MeshInstance3D
var lamp_switch: Node3D
var radio_switch: Node3D
var hand_control: Node3D
var _gears: Array[Node]=[]
var _jewels: Array[MeshInstance3D]=[]
var _control_state: Array=[]
var _controls_motion: Tween
var _cover_motion: Tween
var _focus_motion: Tween
var _hot_writer: Node3D
var _aerial: Node3D
var _carriage_left := -.05832
var _character_pitch := .003888
var _ink_home := Vector3.ZERO
var _line_pitch := .007
const DELIVERY_FEED := .020

func _ready() -> void:
	model = model_scene.instantiate()
	var supplied: Variant = stock_applier.call(model)
	if supplied is not Dictionary or supplied.is_empty():
		push_error("Native printer stock provider refused its paper datum")
		return
	var paper: Dictionary = supplied
	add_child(model)
	_aerial=model.find_child("Aerial",true,false)
	if model.find_child("TypeSelector",true,false)!=null:
		_hot_writer=preload("res://scripts/device/hot_type_writer.gd").new();add_child(_hot_writer)
		if not _hot_writer.bind_model(model):_hot_writer.queue_free();_hot_writer=null
	service_cover=model.find_child("ServiceCover",true,false)
	focus_wheel=model.find_child("FocusWheel",true,false)
	torch_lens=model.find_child("TorchLens",true,false)
	torch_lens.set_surface_override_material(0,torch_lens.get_active_material(0).duplicate())
	lamp_switch=model.find_child("LampSwitch",true,false)
	radio_switch=model.find_child("RadioSwitch",true,false)
	for gear: Node3D in model.find_children("FeedGear*","Node3D",true,false):
		if gear is not MeshInstance3D:_gears.append(gear)
	# The importer names material meshes FeedWheel0__Brass beneath FeedWheel0.
	# Rotating both doubled shaft travel and created overlapping hand targets.
	for key in ["FeedWheel0","FeedWheel1"]:feed_wheels.append(model.find_child(key,true,false))
	for key in ["OrderJewel","NetJewel","LampJewel"]:
		var jewel := model.find_child(key,true,false) as MeshInstance3D
		jewel.set_surface_override_material(0,jewel.get_active_material(0).duplicate())
		_jewels.append(jewel)
	_paper=model.find_child("Paper",true,false)
	_paper_home=_paper.position
	var stock := (_paper as MeshInstance3D).get_active_material(0).duplicate() as StandardMaterial3D
	stock.albedo_texture=TelegramStyle.PAPER
	stock.albedo_color=Color.WHITE
	(_paper as MeshInstance3D).set_surface_override_material(0,stock)
	carriage=model.find_child("Carriage",true,false)
	hammer=model.find_child("Type_hammer",true,false)
	if hammer==null: hammer=model.find_child("Type hammer",true,false)
	platen=model.find_child("Platen",true,false)
	for key in ["SupplySpool","TakeupSpool"]:
		var spool:=model.find_child(key,true,false)
		if spool!=null:spools.append(spool)
	_carriage_home=carriage.position; _hammer_home=hammer.position
	var center:=Vector3(paper["center"][0],paper["center"][1],paper["center"][2])
	var top: float=center.y+float(paper["height"])*.5
	var bottom: float=center.y-float(paper["height"])*.5
	heading=_label(Vector3(center.x,top-.008,center.z+.0003),.00012)
	heading.font=TelegramStyle.BOLD_FONT
	ink=_label(Vector3(center.x-float(paper["width"])*.5+.01168,bottom+.002,center.z+.0004),.000135)
	ink.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	# Current line stays beside the impression datum. Completed lines rise
	# through the copy window when a new line is fed, rather than appearing
	# at the top while a detached head writes at the bottom.
	ink.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
	_carriage_left=ink.position.x
	_character_pitch=ink.font.get_string_size("M",HORIZONTAL_ALIGNMENT_LEFT,-1,ink.font_size).x*ink.pixel_size
	footer=_label(Vector3(center.x,top-.015,center.z+.0004),.000075)
	for label in [heading,ink,footer]: label.reparent(_paper,true)
	_ink_home=ink.position
	_line_pitch=ink.font.get_height(ink.font_size)*ink.pixel_size
	var plate := _label(Vector3(0,-.079,.0413),.000075)
	plate.text="VANTRY / TYPE 28-R"
	plate.modulate=Color("d9c69b")
	plate.reparent(service_cover,true)
	for spec in [[-.094,"L"],[.094,"R"]]:
		var legend := _label(Vector3(spec[0],-.089,.042),.00010)
		legend.text=spec[1]; legend.modulate=Color("d9c69b")
	for spec in [["tick",-23.0],["pop",-24.0]]:
		var sound := AudioStreamPlayer.new(); add_child(sound)
		sound.bus="UI"; sound.stream=PropAudio.get_stream(spec[0]); sound.volume_db=spec[1]
		if spec[0]=="tick": _tick=sound
		else: _feed=sound
	present({"title":"ORISON SERVICE WIRE","body":"THE LINE IS CLEAR.\n\nA hinge remembers its arc.\nA hand can pause there.\n\n o----)   (----o\n   [ ] -> [___]\n\nThere is more under the lid."},0)

	model_ready = true

func _label(at: Vector3, pixel: float) -> Label3D:
	var label := Label3D.new(); add_child(label)
	label.font=TelegramStyle.BODY_FONT; label.font_size=48
	label.pixel_size=pixel; label.position=at
	label.modulate=TelegramStyle.CARBON; label.outline_size=0
	label.no_depth_test=false; label.shaded=false
	return label

func present(card: Dictionary, serial: int) -> void:
	var text := str(card.get("title","FIELD COPY"))+"\n\n"+str(card.get("body",""))
	var condition := str(card.get("condition",""))
	if not condition.is_empty(): text+="\n\n"+condition
	var lines: Array[String]=[]
	for paragraph in text.replace("\r","").split("\n"):
		var remaining: String=paragraph
		while remaining.length()>COLUMNS:
			var cut := remaining.rfind(" ",COLUMNS)
			if cut<1: cut=COLUMNS
			lines.append(remaining.left(cut))
			remaining=remaining.substr(cut).trim_prefix(" ")
		lines.append(remaining)
	pages.clear()
	for start in range(0,lines.size(),ROWS):
		pages.append("\n".join(lines.slice(start,mini(start+ROWS,lines.size()))))
	_serial=serial; _reviewing=false
	if serial>0:
		reports.append({"serial":serial,"pages":pages.duplicate()})
		if reports.size()>HISTORY_LIMIT: reports.pop_front()
		report_index=reports.size()-1
	heading.text="SERVICE WIRE / %04d" % _serial
	page=0; _begin_page()

## Revisit a retained physical copy; this neither receives nor prints a new report.
func browse_report(direction: int) -> void:
	if reports.is_empty(): return
	report_index=posmod(report_index+direction,reports.size())
	var record: Dictionary=reports[report_index]
	pages.assign(record.pages)
	_serial=int(record.serial)
	heading.text="SERVICE WIRE / %04d" % _serial
	page=0; _reviewing=true
	_show_copy()

func _show_copy() -> void:
	if _return_motion: _return_motion.kill()
	if _paper_motion: _paper_motion.kill()
	_paper.position=_paper_home
	printing=false; printed_characters=pages[page].length()
	if _hot_writer:_hot_writer.stop()
	ink.text=pages[page]; _column=0; _return_left=0
	ink.position=_ink_home+Vector3.UP*DELIVERY_FEED
	carriage.position=_carriage_home; hammer.position=_hammer_home
	_update_footer()

func _update_footer() -> void:
	footer.text=_action_hint+"\nPAGE %d/%d  FILE %d/%d" % [page+1,pages.size(),maxi(1,report_index+1),maxi(1,reports.size())]

func set_action_hint(value: String) -> void:
	if value==_action_hint: return
	_action_hint=value
	_update_footer()

func set_controls(radio: bool, lamp: bool, order: bool, animate := true) -> void:
	var state := [radio,lamp,order]
	if state==_control_state: return
	var old:=_control_state
	_control_state=state
	if _controls_motion: _controls_motion.kill()
	var move_lamp: bool=hand_control!=lamp_switch and (old.is_empty() or old[1]!=lamp)
	var move_radio: bool=old.is_empty() or old[0]!=radio
	if animate and (move_lamp or move_radio):
		_controls_motion=create_tween().set_parallel(true)
		if move_lamp:_controls_motion.tween_property(lamp_switch,"rotation:z",-.4 if lamp else .4,.18)
		if move_radio:
			if hand_control!=radio_switch:_controls_motion.tween_property(radio_switch,"rotation:z",-.4 if radio else .4,.18)
			_controls_motion.tween_property(_aerial,"scale:y",1. if radio else .14,.28)
	else:
		if move_lamp:lamp_switch.rotation.z=-.4 if lamp else .4
		if move_radio:
			if hand_control!=radio_switch:radio_switch.rotation.z=-.4 if radio else .4
			_aerial.scale.y=1. if radio else .14
	var lens := torch_lens.get_active_material(0) as StandardMaterial3D
	lens.emission=Color("ffd08a"); lens.emission_enabled=lamp
	lens.emission_energy_multiplier=.65
	var colors := [Color("ff9d24"),Color("65d07d"),Color("e35a42")]
	var enabled := [order and radio,radio,lamp]
	for index in range(3):
		var material := _jewels[index].get_active_material(0) as StandardMaterial3D
		material.albedo_color=colors[index] if enabled[index] else colors[index]*.15
		material.emission=colors[index]; material.emission_enabled=enabled[index]
		material.emission_energy_multiplier=.65

func set_optical_output(color: Color, emission: float) -> void:
	var lens:=torch_lens.get_active_material(0) as StandardMaterial3D
	lens.emission=color;lens.emission_enabled=emission>.001;lens.emission_energy_multiplier=maxf(0.,emission)

func set_focus_position(value: float) -> void:
	if _focus_motion: _focus_motion.kill()
	_focus_motion=create_tween()
	_focus_motion.tween_property(focus_wheel,"rotation:x",value*TAU,.18)

func toggle_service_cover() -> void:
	service_open=not service_open
	if _cover_motion: _cover_motion.kill()
	_cover_motion=create_tween()
	_cover_motion.tween_property(service_cover,"rotation:x",1.85 if service_open else 0.0,.3).set_trans(Tween.TRANS_CUBIC)

func turn_page(direction: int) -> void:
	if pages.is_empty() or (not powered and not _reviewing): return
	page=posmod(page+direction,pages.size())
	if _reviewing: _show_copy()
	else: _begin_page()

func _begin_page() -> void:
	if _return_motion: _return_motion.kill()
	if _paper_motion: _paper_motion.kill()
	_paper.position=_paper_home
	ink.position=_ink_home
	if _hot_writer:_hot_writer.stop()
	printed_characters=0; _advance=0; ink.text=""; printing=true
	_column=0; _return_left=0
	carriage.position.x=_carriage_left+_character_pitch*.5
	_update_footer()
	if _feed.stream: _feed.play()

func _process(delta: float) -> void:
	if not powered or not printing:
		if not powered and _hot_writer:_hot_writer.stop()
		return
	_clock+=delta; _advance+=delta
	# Account for every character, including low-frame-rate catch-up. Feed belongs
	# to line endings, not to render frames; return travel has its own dwell.
	while _advance>=CHARACTER_SECONDS and printed_characters<pages[page].length():
		if _return_left>0:
			var consumed := minf(_advance,_return_left)
			_advance-=consumed; _return_left-=consumed
			carriage.position.x=lerpf(_return_from,_carriage_left+_character_pitch*.5,1.0-_return_left/RETURN_SECONDS)
			if _return_left>0: break
			carriage.position.x=_carriage_left+_character_pitch*.5
			continue
		_advance-=CHARACTER_SECONDS
		var character: String=pages[page][printed_characters]
		printed_characters+=1
		if character=="\n":
			_return_from=carriage.position.x
			_column=0; _return_left=RETURN_SECONDS
			platen.rotate_x(_line_pitch/.008)
			for wheel in feed_wheels: (wheel as Node3D).rotate_x(_line_pitch/.008)
			if _feed.stream: _feed.play()
		else:
			_column+=1
			if _hot_writer:_hot_writer.strike(character)
			carriage.position.x=_carriage_left+_character_pitch*(float(_column)-.5)
			for spool in spools: spool.rotate_z(.035)
			for index in range(_gears.size()): (_gears[index] as Node3D).rotate_z(.045 if index%2==0 else -.045)
			if _tick.stream and not _tick.playing: _tick.play()
	if _hot_writer:_hot_writer.sync_phase(_advance if _return_left<=0 else 1.)
	ink.text=pages[page].left(printed_characters)
	if _hot_writer==null:
		hammer.position=_hammer_home
		if _return_left<=0: hammer.position.z+=sin(_clock*TAU*24)*.002
	if printed_characters==pages[page].length():
		printing=false
		if _hot_writer==null:hammer.position=_hammer_home
		_return_motion = create_tween()
		_return_motion.tween_property(carriage,"position",_carriage_home,.18)
		# Feed finished copy above the head. Keep the continuous web seated;
		# only the ink advances through the fixed viewing window.
		_paper_motion=create_tween().set_parallel(true)
		_paper_motion.tween_property(ink,"position",_ink_home+Vector3.UP*DELIVERY_FEED,.24)
		_paper_motion.tween_property(platen,"rotation:x",platen.rotation.x+DELIVERY_FEED/.008,.24)
		for wheel in feed_wheels:_paper_motion.tween_property(wheel,"rotation:x",wheel.rotation.x+DELIVERY_FEED/.008,.24)
		if _feed.stream:_feed.play()
