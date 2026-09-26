extends Node3D
## Physical paper and mechanism only. Gameplay supplies the complete message.
const MODEL := preload("res://assets/device/service_teletype/service_teletype.glb")
const COLUMNS := 30
const ROWS := 13
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
	heading.text="SERVICE WIRE / %04d" % serial
	page=0; _begin_page()

func turn_page(direction: int) -> void:
	if not powered or pages.is_empty(): return
	page=posmod(page+direction,pages.size()); _begin_page()

func _begin_page() -> void:
	if _return_motion: _return_motion.kill()
	if _paper_motion: _paper_motion.kill()
	_paper.position=_paper_home-Vector3.UP*.012
	_paper_motion=create_tween()
	_paper_motion.tween_property(_paper,"position",_paper_home,.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	printed_characters=0; _advance=0; ink.text=""; printing=true
	footer.text="%d / %d   T: READ   [ ]: FEED" % [page+1,pages.size()]
	if _feed.stream: _feed.play()

func _process(delta: float) -> void:
	if not powered or not printing: return
	_clock+=delta; _advance+=delta*48.0
	var count := mini(int(_advance),pages[page].length())
	if count!=printed_characters:
		printed_characters=count; ink.text=pages[page].left(count)
		if _tick.stream and not _tick.playing: _tick.play()
		var last_line := ink.text.get_slice("\n",ink.text.count("\n"))
		carriage.position.x=lerpf(-.076,.076,float(last_line.length())/COLUMNS)
		platen.rotate_x(.08)
		for spool in spools: spool.rotate_z(.035)
	hammer.position=_hammer_home+Vector3(0,0,sin(_clock*TAU*24)*.002)
	if count==pages[page].length():
		printing=false; hammer.position=_hammer_home
		_return_motion = create_tween()
		_return_motion.tween_property(carriage,"position",_carriage_home,.18)
