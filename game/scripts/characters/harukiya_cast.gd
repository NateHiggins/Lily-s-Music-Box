extends Node3D
## Harukiya presentations under existing staff/whereabouts and conversation owners.
## The two counter staff remain separate from the death-bounded stage performer.
const CastModel := preload("res://scripts/characters/cast_model_presentation.gd")
const StaffBody := preload("res://scripts/characters/harukiya_staff_body.gd")
const PerformerBody := preload("res://scripts/characters/harukiya_performer_body.gd")
const Rules := preload("res://scripts/characters/wardrobe_rules.gd")
const Show := preload("res://scripts/characters/harukiya_show.gd")
const PARTS: Array[String] = ["work_top", "work_bottom", "work_feet"]
var world: Node3D
var counter: Node3D
var conversations: ResidentConversations
var actors: Dictionary = {}
var performers: Dictionary = {}
var bar_region: OrisonV2BarRegion
var ready_ok := false
var _accum := 0.0
var _speaker := ""
var _line_actor: CastModel
var _floor_y := 0.0
var _rules := Rules.new()
var _dressed_for := ""
var _retired := false
var stage_show: Node3D

func configure(runtime: Node3D, region: Node3D, glass: Node3D, talk: ResidentConversations) -> bool:
	if is_inside_tree() or runtime == null or region == null or glass == null or talk == null:
		return false
	var bar := region as OrisonV2BarRegion
	if bar == null or bar.actors == null:
		return false
	if bar.actors.get_node_or_null("HarukiyaCast") != null:
		return false
	world = runtime
	bar_region = bar
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
	if not _rules.load_table():
		push_error("Harukiya staff profiles or wardrobe rules refused")
		return
	for id: String in ["stacy", "lily"]:
		var actor := StaffBody.new()
		actor.set_active(false)
		actor.name = "Harukiya_" + id
		actor.configure(id,"res://assets/characters/%s/%s.gltf" % [id,id],PARTS,
				"at_ease" if id == "stacy" else "weight_on_one_leg")
		add_child(actor)
		if not actor.ready_ok:
			push_error("Harukiya actor refused: " + id)
			actor.set_active(false)
			for prior: CastModel in actors.values():prior.set_active(false)
			return
		# Native standing-column pilot: keep Stacy at the open service end,
		# clear of backbar shelving, and Lily clear of the raised lounge/seats.
		var station: Vector3 = counter.across() + Vector3(.70,0,0) + bar_region.global_basis.z * .88 if id == "stacy" else Vector3(.75,0,.70)
		actor.global_position = counter.global_position + station
		actor.global_position.y = _floor_y
		actor.rotation.y = 0.0 if id == "stacy" else deg_to_rad(-20.0)
		_ground_rest_shoes(actor)
		if not actor.load_standing_profiles():
			actor.set_active(false)
			for prior: CastModel in actors.values():prior.set_active(false)
			push_error("Harukiya standing profile refused: " + id)
			return
		actors[id] = actor
	if not _setup_performer():
		for actor: CastModel in actors.values():actor.set_active(false)
		return
	conversations.conversation_started.connect(_on_started)
	conversations.conversation_ended.connect(_on_ended)
	if conversations.dialogue != null:
		conversations.dialogue.node_shown.connect(_on_node_shown)
	ready_ok = true
	refresh_presence()
	if world.has_method("resident_whereabouts") and world.get("campaign_clock") != null and performers.has("adela_voss"):
		stage_show = Show.new()
		stage_show.cast_owner = self
		add_child(stage_show)

func _setup_performer() -> bool:
	# Isolated legacy counter fixtures need no invented attendance service.
	if world==null or not world.has_method("resident_whereabouts"):return true
	var destination: Node3D=bar_region.get("destination")
	if destination==null:return false
	var stations: Array=destination.get("spec").get("standing_positions",[])
	var selected: Array=stations.filter(func(row):return str(row.id)=="vocal_performer")
	if selected.size()!=1:return false
	var actor:=PerformerBody.new()
	actor.set_active(false)
	actor.name="Harukiya_adela_voss"
	actor.presence_query=Callable(self,"_adela_is_here")
	actor.interaction_query=func() -> bool: return not stage_busy()
	actor.conversation_owner=conversations
	actor.configure("adela_voss","res://assets/characters/cast/adela_voss/adela_voss.gltf",
		["p_top","p_feet","p_head"],"weight_on_one_leg")
	add_child(actor)
	if not actor.ready_ok:
		actor.free()
		return false
	# The vocal socket meets the kit hardware. The native column probe finds
	# clear stage floor beside the mic, with a further10cm lateral reserve.
	# Keep every collider and the complete measured standing envelope.
	actor.global_position=bar_region.to_global(GameBoot.b2g(selected[0].at)+Vector3(.667,0,.017))
	actor.rotation.y=PI
	_ground_rest_shoes(actor,actor.global_position.y)
	if not actor.set_makeup("stage") or not actor.load_standing_profiles():
		actor.free()
		push_error("Harukiya measured stage presentation refused: Adela")
		return false
	performers["adela_voss"]=actor
	return true

func _adela_is_here() -> bool:
	if _retired or not is_instance_valid(world) or not world.has_method("resident_whereabouts"):return false
	var where: Dictionary=world.call("resident_whereabouts","adela_voss")
	return str(where.get("place",""))=="harukiya_bar"

func lily_is_here() -> bool:
	if _retired or not is_instance_valid(world): return false
	# Counter-only hosts predate the installed resident timetable.
	if not world.has_method("resident_whereabouts"): return counter.on_shift()
	return str(world.resident_whereabouts("lily").get("place", "")) == "harukiya_bar"

func _refresh_performer() -> void:
	if _retired or not ready_ok or not performers.has("adela_voss"):return
	var actor: CastModel=performers.adela_voss
	var present:=_adela_is_here()
	if actor.visible!=present:actor.set_active(present)
	if not present and _speaker=="adela_voss":
		_stop_line()
		actor.stop_speaking()
		_speaker=""


func stage_busy() -> bool:
	return is_instance_valid(stage_show) and stage_show.busy()

func _actor_for(id: String) -> CastModel:
	return actors.get(id,performers.get(id)) as CastModel

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


func _ground_rest_shoes(actor: CastModel, floor_y: float=NAN) -> void:
	var target_y:=_floor_y if is_nan(floor_y) else floor_y
	var lowest := INF
	for draw: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if not _on_feet(actor, str(draw.name)):continue
		var bounds := draw.get_aabb()
		for x: float in [bounds.position.x,bounds.end.x]:
			for y: float in [bounds.position.y,bounds.end.y]:
				for z: float in [bounds.position.z,bounds.end.z]:
					lowest = minf(lowest,(draw.global_transform*Vector3(x,y,z)).y)
	if is_finite(lowest):actor.global_position.y += target_y-lowest

func _process(delta: float) -> void:
	# The existing whereabouts owner handles civil death and earned visits.
	# Check each frame so a clock boundary cannot leave an operable ghost.
	_refresh_performer()
	_accum += delta
	if _accum >= .25:
		_accum = 0.0
		refresh_presence()
		# The shared panel may close between tree nodes without ending the
		# conversation authority. Hidden text must never keep a mouth moving;
		# retain the speaker so a following authored node can speak normally.
		if _speaker != "" and conversations.dialogue != null and not conversations.dialogue.attention_active():
			_stop_line()

func refresh_presence() -> void:
	if _retired or not ready_ok:return
	_refresh_performer()
	var stacy_here: bool = counter.on_shift()
	var lily_here := lily_is_here()
	# The evening's clothes are chosen as the shift starts and again when the evening changes.
	if stacy_here or lily_here:
		# Keyed by the evening and what Lily is doing in it: at six on a Friday she changes for the set.
		var lily_now := evening_situation("lily", conversations.today(), conversations.minute_now())
		var evening := str(lily_now.date) + "|" + str(lily_now.activity)
		if evening != _dressed_for:
			_dressed_for = evening
			dress_for_evening(conversations.today(), conversations.minute_now())
	for actor: CastModel in actors.values():
		var present := stacy_here if actor.person_id == "stacy" else lily_here
		if actor.visible != present:
			actor.set_active(present)
		if not present and (_line_actor == actor or _speaker == actor.person_id):
			_stop_line()
		if not present and _speaker == actor.person_id:
			_speaker = ""

func _on_started(id: String, _entry: String) -> void:
	_stop_line()
	var actor:=_actor_for(id)
	_speaker = id if actor!=null and actor.is_visible_in_tree() else ""
	if _speaker != "":
		actor.express("interest",.5)
		_on_node_shown("")

func _on_ended(id: String) -> void:
	var actor:=_actor_for(id)
	if actor!=null:
		actor.stop_speaking()
		actor.express("neutral",0.0)
	if _speaker == id:
		_stop_line()
		_speaker = ""

func _stop_line() -> void:
	if is_instance_valid(_line_actor):
		_line_actor.stop_speaking()
	_line_actor = null

func _on_node_shown(_node: String) -> void:
	var actor:=_actor_for(_speaker)
	if _speaker == "" or actor==null or conversations.dialogue == null:return
	var line: Dictionary = conversations.dialogue.displayed_line()
	var words := str(line.get("text",""))
	var voice := str(line.get("speaker","")).strip_edges().to_lower()
	var letters := words.strip_edges().replace(".","").replace("â€¦","").replace("â€”","").strip_edges()
	var id := _speaker
	# In The Extra Two Bars the player addresses Adela and witnesses a duet.
	var beat := str(conversations.dialogue.current_node_id)
	if id == "adela_voss" and voice == "lily" and beat.begins_with("av_o") and beat.trim_prefix("av_o").is_valid_int():
		id = "lily"
		actor = _actor_for(id)
	if _line_actor != actor:
		_stop_line()
	if not is_instance_valid(actor) or not actor.is_visible_in_tree():
		_stop_line()
		return
	var own_voice := voice in ["adela", "adela voss"] if id == "adela_voss" else voice == id
	if line.get("delivery", "spoken") == "silent" or not own_voice or letters.is_empty():
		actor.stop_speaking()
		_line_actor = null
		return
	_line_actor = actor
	# Authored text has a restrained jaw fallback until a qualified voice line
	# supplies exact cues through CastModel.speak_cues; no sound/text is generated.
	actor.speak_untimed(clampf(float(words.length())/18.0,1.0,12.0))
	# The face shows how they feel about the line (ruling npc_face_mood_source_20261124). Staff bodies keep their
	# staged show poses, so no stage gesture here.
	var mood: RefCounted = preload("res://scripts/characters/cast_resident_speech.gd").reader()
	if mood != null:
		var reading: Dictionary = mood.read(id, words, int(RealityState.resident_trust(id)), line.get("exchange", {}))
		actor.express(str(reading.expression), float(reading.intensity))

func shutdown() -> void:
	_stop_line()
	_retired=true
	if is_instance_valid(stage_show):
		stage_show.shutdown()
	set_process(false)
	_speaker=""
	for actor: CastModel in actors.values():actor.set_active(false)
	for actor: CastModel in performers.values():actor.set_active(false)
