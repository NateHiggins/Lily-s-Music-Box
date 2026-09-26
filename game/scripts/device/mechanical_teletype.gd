extends Node3D
## Physical paper and mechanism only. Gameplay supplies the complete message.
const MODEL := preload("res://assets/device/service_teletype/service_teletype.glb")
const COLUMNS := 30
const ROWS := 13
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

func _ready() -> void:
	var model := MODEL.instantiate(); add_child(model)
	_paper=model.find_child("Paper",true,false)
	_paper_home=_paper.position
	var stock := (_paper as MeshInstance3D).get_active_material(0).duplicate() as StandardMaterial3D
	stock.albedo_texture=TelegramStyle.PAPER
	stock.albedo_color=Color.WHITE
	(_paper as MeshInstance3D).material_override=stock
	carriage=model.find_child("Carriage",true,false)
	hammer=model.find_child("Type_hammer",true,false)
	if hammer==null: hammer=model.find_child("Type hammer",true,false)
	platen=model.find_child("Platen",true,false)
	for key in ["SupplySpool","TakeupSpool"]: spools.append(model.find_child(key,true,false))
	_carriage_home=carriage.position; _hammer_home=hammer.position
	heading=_label(Vector3(0,.096,.0812),.00014)
	heading.font=TelegramStyle.BOLD_FONT
	ink=_label(Vector3(-.076,.079,.0814),.000175)
	ink.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	ink.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	footer=_label(Vector3(0,-.034,.0814),.000105)
	for label in [heading,ink,footer]: label.reparent(_paper,true)
	for spec in [["tick",-23.0],["pop",-24.0]]:
		var sound := AudioStreamPlayer.new(); add_child(sound)
		sound.bus="UI"; sound.stream=PropAudio.get_stream(spec[0]); sound.volume_db=spec[1]
		if spec[0]=="tick": _tick=sound
		else: _feed=sound
	present({"title":"ORISON SERVICE WIRE","body":"Receiver ready.\n\nOperate a fixture to receive its field report.\n\nT: raise paper\n[ / ]: previous / next page"},0)

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
	ink.text=pages[page]; _column=0; _return_left=0
	carriage.position=_carriage_home; hammer.position=_hammer_home
	_update_footer()

func _update_footer() -> void:
	footer.text="PAGE %d/%d  FILE %d/%d  SHIFT [ ]" % [page+1,pages.size(),maxi(1,report_index+1),maxi(1,reports.size())]

func turn_page(direction: int) -> void:
	if pages.is_empty() or (not powered and not _reviewing): return
	page=posmod(page+direction,pages.size())
	if _reviewing: _show_copy()
	else: _begin_page()

func _begin_page() -> void:
	if _return_motion: _return_motion.kill()
	if _paper_motion: _paper_motion.kill()
	_paper.position=_paper_home-Vector3.UP*.012
	_paper_motion=create_tween()
	_paper_motion.tween_property(_paper,"position",_paper_home,.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	printed_characters=0; _advance=0; ink.text=""; printing=true
	_column=0; _return_left=0
	carriage.position.x=-.076
	_update_footer()
	if _feed.stream: _feed.play()

func _process(delta: float) -> void:
	if not powered or not printing: return
	_clock+=delta; _advance+=delta
	# Account for every character, including low-frame-rate catch-up. Feed belongs
	# to line endings, not to render frames; return travel has its own dwell.
	while _advance>=CHARACTER_SECONDS and printed_characters<pages[page].length():
		if _return_left>0:
			var consumed := minf(_advance,_return_left)
			_advance-=consumed; _return_left-=consumed
			carriage.position.x=lerpf(_return_from,-.076,1.0-_return_left/RETURN_SECONDS)
			if _return_left>0: break
			carriage.position.x=-.076
			continue
		_advance-=CHARACTER_SECONDS
		var character: String=pages[page][printed_characters]
		printed_characters+=1
		if character=="\n":
			_return_from=carriage.position.x
			_column=0; _return_left=RETURN_SECONDS
			platen.rotate_x(.42)
			if _feed.stream: _feed.play()
		else:
			_column+=1
			carriage.position.x=lerpf(-.076,.076,float(_column)/COLUMNS)
			for spool in spools: spool.rotate_z(.035)
			if _tick.stream and not _tick.playing: _tick.play()
	ink.text=pages[page].left(printed_characters)
	hammer.position=_hammer_home
	if _return_left<=0: hammer.position.z+=sin(_clock*TAU*24)*.002
	if printed_characters==pages[page].length():
		printing=false; hammer.position=_hammer_home
		_return_motion = create_tween()
		_return_motion.tween_property(carriage,"position",_carriage_home,.18)
