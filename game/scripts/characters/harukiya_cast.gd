extends Node3D
## Two Harukiya presentations. The existing staff clock owns attendance and
## the counter glass owns Stacy's conversation. No resident/case/save rows.
const CastModel := preload("res://scripts/characters/cast_model_presentation.gd")
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
	ready_ok = true
	refresh_presence()

func _ground_rest_shoes(actor: CastModel) -> void:
	var lowest := INF
	for draw: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if not str(draw.name).begins_with("work_feet_"):continue
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
