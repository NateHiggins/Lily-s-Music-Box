extends Node3D
## Two Harukiya presentations. The existing staff clock owns attendance and
## the counter glass owns Stacy's conversation. No resident/case/save rows.
const CastModel := preload("res://scripts/characters/cast_model_presentation.gd")
const Rules := preload("res://scripts/characters/wardrobe_rules.gd")
const PARTS: Array[String] = ["work_top", "work_bottom", "work_feet"]
var world: Node3D
var counter: Node3D
var conversations: ResidentConversations
var actors: Dictionary = {}
var ready_ok := false
var _accum := 0.0
var _speaker := ""
var _floor_y := 0.0
var _present: Variant = null
var _rules := Rules.new()
var _dressed_for := ""

func configure(runtime: Node3D, region: Node3D, glass: Node3D, talk: ResidentConversations) -> bool:
	if is_inside_tree() or runtime == null or region == null or glass == null or talk == null:
		return false
	var bar := region as OrisonV2BarRegion
	if bar == null or bar.actors == null:
		return false
	if bar.actors.get_node_or_null("HarukiyaCast") != null:
		return false
	world = runtime
	counter = glass
	conversations = talk
	var found_floor := false
	for storey: Dictionary in bar.source_layout.floors:
		if str(storey.id) != "F01": continue
		for row: Dictionary in storey.furniture:
			if str(row.id) == "retail_bar_floor":
				_floor_y = GameBoot.b2g([0.0,0.0,float(row.z0)+float(row.h)]).y
				found_floor = true
	if not found_floor: return false
	name = "HarukiyaCast"
	bar.actors.add_child(self)
	return ready_ok

func _ready() -> void:
	for id: String in ["stacy", "lily"]:
		var actor := CastModel.new()
		actor.name = "Harukiya_" + id
		actor.configure(id,"res://assets/characters/%s/%s.gltf" % [id,id],PARTS,
				"at_ease" if id == "stacy" else "weight_on_one_leg")
		add_child(actor)
		if not actor.ready_ok:
			push_error("Harukiya actor refused: " + id)
			for prior: CastModel in actors.values():prior.set_active(false)
			return
		actor.global_position = counter.global_position + (counter.across()*1.10 if id == "stacy" else Vector3(.95,0,.70))
		actor.global_position.y = _floor_y
		actor.rotation.y = 0.0 if id == "stacy" else deg_to_rad(-20.0)
		_ground_rest_shoes(actor)
		actors[id] = actor
	conversations.conversation_started.connect(_on_started)
	conversations.conversation_ended.connect(_on_ended)
	if conversations.dialogue != null:
		conversations.dialogue.node_shown.connect(_on_node_shown)
	ready_ok = _rules.load_table()
	refresh_presence()

func _on_feet(actor: CastModel, draw_name: String) -> bool:
	for part: String in actor.worn_parts():
		if part.ends_with("_feet") and draw_name.begins_with(part + "_"):
			return true
	return false


## What the evening is, for the wardrobe rules: the night that began at six belongs to its own date until four
## in the morning. Friday and Saturday evenings are the act's nights (the schedule's "full room").
static func evening_situation(person: String, date: String, minute: int) -> Dictionary:
	var day := date
	if minute >= 0 and minute < 4 * 60:
		var unix := Time.get_unix_time_from_datetime_string(date + "T12:00:00") - 86400
		day = Time.get_date_string_from_unix_time(unix)
	var weekday := int(Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_string(day + "T12:00:00")).weekday)
	var evening := minute < 0 or minute >= 18 * 60 or minute < 4 * 60
	var activity := "work"
	if person == "lily" and evening and weekday in [5, 6]:
		activity = "performance"
	return {"date": day, "hour": (minute / 60.0) if minute >= 0 else 20.0, "place": "bar", "activity": activity,
		"occasion": Rules.occasion_on(day)}


## Dress both for the evening the rules name. A refused change leaves the person as they were.
func dress_for_evening(date: String, minute: int) -> void:
	for id: String in actors:
		var actor: CastModel = actors[id]
		var situation := evening_situation(id, date, minute)
		var outfit := _rules.choose(id, situation)
		var parts: Array = _rules.parts_for(id, outfit, {}, str(situation.date), situation).parts
		if parts.is_empty() or parts == actor.worn_parts():
			continue
		if actor.wear(parts):
			actor.set_makeup("stage" if outfit == "occasion" else "")
			actor.global_position.y = _floor_y
			_ground_rest_shoes(actor)
		else:
			push_warning("Harukiya %s kept her clothes: %s" % [id, actor.last_refusal])


func _ground_rest_shoes(actor: CastModel) -> void:
	var lowest := INF
	for draw: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if not _on_feet(actor, str(draw.name)):continue
		var bounds := draw.get_aabb()
		for x: float in [bounds.position.x,bounds.end.x]:
			for y: float in [bounds.position.y,bounds.end.y]:
				for z: float in [bounds.position.z,bounds.end.z]:
					lowest = minf(lowest,(draw.global_transform*Vector3(x,y,z)).y)
	if is_finite(lowest):actor.global_position.y += _floor_y-lowest

func _process(delta: float) -> void:
	_accum += delta
	if _accum >= .25:
		_accum = 0.0
		refresh_presence()
		# The shared panel may close between tree nodes without ending the
		# conversation authority. Hidden text must never keep a mouth moving;
		# retain the speaker so a following authored node can speak normally.
		if _speaker != "" and conversations.dialogue != null and not conversations.dialogue.attention_active():
			actors[_speaker].stop_speaking()

func refresh_presence() -> void:
	if not ready_ok:return
	# Lily's chosen bar appearance follows this existing attendance window;
	# this neither creates her a new timetable nor changes Stacy's work hours.
	var present: bool = counter.on_shift()
	# The evening's clothes are chosen as the shift starts and again when the evening changes.
	if present:
		# Keyed by the evening and what Lily is doing in it: at six on a Friday she changes for the set.
		var lily_now := evening_situation("lily", conversations.today(), conversations.minute_now())
		var evening := str(lily_now.date) + "|" + str(lily_now.activity)
		if evening != _dressed_for:
			_dressed_for = evening
			dress_for_evening(conversations.today(), conversations.minute_now())
	if _present == present:return
	_present = present
	for actor: CastModel in actors.values():actor.set_active(present)
	if not present:_speaker = ""

func _on_started(id: String, _entry: String) -> void:
	_speaker = id if actors.has(id) else ""
	if _speaker != "":
		actors[_speaker].express("interest",.5)
		_on_node_shown("")

func _on_ended(id: String) -> void:
	if actors.has(id):
		actors[id].stop_speaking()
		actors[id].express("neutral",0.0)
	if _speaker == id:_speaker = ""

func _on_node_shown(_node: String) -> void:
	if _speaker == "" or not actors.has(_speaker) or conversations.dialogue == null:return
	var line: Dictionary = conversations.dialogue.displayed_line()
	var words := str(line.get("text",""))
	var voice := str(line.get("speaker","")).strip_edges().to_lower()
	var letters := words.strip_edges().replace(".","").replace("…","").replace("—","").strip_edges()
	if voice != _speaker or letters.is_empty():
		actors[_speaker].stop_speaking()
		return
	# Authored text has a restrained jaw fallback until a qualified voice line
	# supplies exact cues through CastModel.speak_cues; no sound/text is generated.
	actors[_speaker].speak_untimed(clampf(float(words.length())/18.0,1.0,12.0))
