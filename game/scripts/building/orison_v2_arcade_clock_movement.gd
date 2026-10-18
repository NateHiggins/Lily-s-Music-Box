extends Node
## Presentation only. CampaignClock retains all calendar, elapsed-time and save authority.
var errors: Array[String]=[]
var displayed_minute := 0.0
var _clock := CampaignClock.new()
var _hands: Dictionary={}
var _rest: Dictionary={}
var _elapsed := 0.0
var _interval := .2

func configure(model: Node3D) -> bool:
	if not _hands.is_empty() or model==null or not _clock.bind_state():return false
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/arcade_clock.json"))
	var presentation: Dictionary=data.presentation
	if str(presentation.time_owner)!="CampaignClock.minute_of_day":return false
	_interval=float(presentation.update_interval_s)
	if not is_finite(_interval) or _interval<=0.:return false
	var origin:=_v(data.origin)
	var parts: Dictionary={}
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var identity:=str(draw.get_meta("arcade_clock_part",""))
		if identity.is_empty() or parts.has(identity):return false
		parts[identity]=draw
	var letters:=Node3D.new();letters.name="ClockNumerals"
	for face: Dictionary in data.faces:
		var identity:=str(face.id);var u:=_v(face.u);var up:=_v(face.v);var normal:=_v(face.normal)
		if not u.cross(up).is_equal_approx(normal) or not is_equal_approx(u.length(),1.) or not is_equal_approx(up.length(),1.) or not is_equal_approx(normal.length(),1.):letters.free();return false
		for kind: String in ["hour","minute"]:
			var key:=identity+"_"+kind+"_hand";var hand:=parts.get(key) as MeshInstance3D
			if hand==null:letters.free();return false
			_hands[key]=hand;_rest[key]=hand.transform
		var center:=origin+_v(face.center)+normal*float(presentation.letter_depth_m)
		for hour in range(1,13):
			var angle:=TAU*float(hour)/12.;var label:=Label3D.new()
			label.name=identity+"_Numeral_%02d"%hour;label.text=str(hour)
			label.font_size=int(presentation.font_size);label.pixel_size=float(presentation.pixel_size_m)
			label.modulate=Color(.035,.028,.022,1.);label.outline_size=0
			label.shaded=true;label.double_sided=false;label.no_depth_test=false
			label.alpha_cut=Label3D.ALPHA_CUT_DISCARD
			label.transform=Transform3D(Basis(u,up,normal),center+(u*sin(angle)+up*cos(angle))*float(presentation.numeral_radius_m))
			letters.add_child(label)
	if _hands.size()!=8:letters.free();return false
	model.add_child(letters)
	return refresh_from_campaign()

func _process(delta: float) -> void:
	_elapsed+=delta
	if _elapsed<_interval:return
	_elapsed=fmod(_elapsed,_interval);refresh_from_campaign()

func refresh_from_campaign() -> bool:
	if not _clock.bind_state():return false
	displayed_minute=_clock.minute_of_day()
	for key: String in _hands:
		var period:=720. if "_hour_" in key else 60.
		var rotation:=Basis(Vector3.BACK,-TAU*fposmod(displayed_minute,period)/period)
		_hands[key].transform=(_rest[key] as Transform3D)*Transform3D(rotation,Vector3.ZERO)
	return true

static func _v(value: Array) -> Vector3:return Vector3(value[0],value[1],value[2])
