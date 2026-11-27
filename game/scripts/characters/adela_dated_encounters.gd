extends Node3D
## Presents Adela at her authored encounters using the ordinary resident body.
## The schedule owns attendance; the conversation owns all earned facts.
##
## Friday 19 July, the witnessed rescue branches (treatment section 6, WR-05; Lily's ruling
## adela_friday_witnessed_20261126). A lobby choice records only what she agreed to (an intent fact). This owner
## then stages it where the player can go and see it: at the enlarger in Photo Supplies, by the roof parapet, or
## in the shop with Miss Quell and the prints. The key book's attempt flag is granted only by that witness, on
## 19 July before 21:01 (no offscreen act is ever written). The schedule is untouched: these bodies are
## presentation only and retire at 21:01. Mr. Ewald has no body yet (ruling ewald_body_20261126 is open), so the
## prints scene is witnessed with Adela and Nadia.
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const PERSON := "adela_voss"
const LOBBY := "F01_LOBBY"
const CLOCK := "F01_LOBBY_CLOCK_01"
const STANCE_FROM_CLOCK := Vector3(-2.0, 0.0, 0.0)
const ROOF_STANCE := Vector3(8.2, 19.22, 3.0)
const WINDOW := "photo_supplies"
const ENCOUNTERS := {
	"1928-11-10": {"place": WINDOW, "thread": "av_window", "activity": "ritual"},
	"1929-07-11": {"place": "roof", "thread": "av_key11", "activity": "work"},
	"1929-07-19": {"place": "lobby", "thread": "av_nineteen", "activity": "errand"},
}

const FRIDAY := "1929-07-19"
const EVENING_END := 1261  # 21:01, the last recorded minute
const PARAPET := "ROOF_PARAPET_NORTH"
const PARAPET_STANCE_X := 4.0  # along the north parapet, over the north deck and clear of the tank
const PARAPET_INSET := .8
const SHOP := "shop_photo_supplies"
const ENLARGER := "storm_shop_photo_supplies_enl0"
const WITNESS_SECONDS := 1.0
## Each branch: the intent the lobby choice grants, the attempt flag a witness grants, where and from when.
const BRANCHES := [
	{"thread": "av_friday_roof", "intent": "m_o2_roof_company", "attempt": "m_o2_stood_roof", "place": "parapet",
			"from": 1105, "witness_from": 1105, "reach": 2.5},
	{"thread": "av_friday_prints", "intent": "m_o2_monday_sent", "attempt": "m_o2_brought_monday", "place": "prints",
			"from": 1110, "witness_from": 1110, "reach": 4.0, "guests": ["nadia_quell"]},
	{"thread": "av_friday_shop", "intent": "m_o2_shop_agreed", "attempt": "m_o2_kept_shop", "place": "enlarger",
			"from": 1105, "witness_from": 1255, "reach": 4.0},
]
const GUEST_NAMES := {"nadia_quell": "Nadia Quell"}

var world: Node3D
var actor: AnimatedResident
var _current_thread := ""
var _refused_thread := ""
var _poll_due := 0.0
var guests: Array[AnimatedResident] = []
var _witnessed := 0.0
var _stand := {}  # where Adela stands for the staged branch, and the side her guests take


func _physics_process(delta: float) -> void:
	if world.startup_ms <= 0.0:
		return
	_poll_due -= delta
	if _poll_due > 0.0 and not is_instance_valid(actor):
		return
	_poll_due = .2
	var encounter := _scheduled_encounter()
	var thread := str(encounter.get("thread", ""))
	if thread != _current_thread:
		_retire()
	if thread.is_empty():
		_refused_thread = ""
	elif not is_instance_valid(actor) and thread != _refused_thread:
		_mount_resident(encounter)
	if is_instance_valid(actor) and encounter.has("attempt"):
		if guests.size() < encounter.get("guests", []).size():
			_mount_guests(encounter)
		# Sight is continuous: a mounted body is resolved every physics tick, after the schedule has retired
		# anything the clock has closed, and watched with the real delta; any break starts it again.
		_watch(encounter, delta)


func _scheduled_encounter() -> Dictionary:
	var branch := friday_branch()
	if not branch.is_empty():
		return branch
	var encounter: Dictionary = ENCOUNTERS.get(world.conversations.today(), {})
	if encounter.is_empty():
		return {}
	var where: Dictionary = world.resident_whereabouts(PERSON)
	if where.get("place") != encounter.place or where.get("activity") != encounter.activity:
		return {}
	return encounter


## The Friday branch staged now: an intent fact from the lobby, on 19 July, inside its window, before 21:01.
func friday_branch() -> Dictionary:
	if world.conversations.today() != FRIDAY or world.campaign_clock == null:
		return {}
	var minute := int(world.campaign_clock.minute_of_day())
	if minute >= EVENING_END:
		return {}
	for branch: Dictionary in BRANCHES:
		if RealityState.has_knowledge(str(branch.intent)) and minute >= int(branch.from):
			return branch
	return {}


## Where a staged branch keeps Adela or a guest (the runtime's whereabouts hook), or {}. A guest's routed body
## then goes out by the ordinary exterior errand, so only the staged body shows her.
func guest_whereabouts(npc: String) -> Dictionary:
	var branch := friday_branch()
	if branch.is_empty():
		return {}
	if npc == PERSON:
		if str(branch.place) == "parapet":
			return {"place": "roof", "activity": "work", "outfit": "street", "detail": "at the parapet, with the night man beside her"}
		return {"place": "photo_supplies", "activity": "work", "outfit": "street", "detail": "the prints, and the enlarger sulking"}
	if npc not in branch.get("guests", []):
		return {}
	return {"place": "photo_supplies", "activity": "visit", "outfit": "street", "detail": "Adela's prints, three days early"}


## The attempt is the player's own sight of the staged scene: close, in front of the eyes, nothing between,
## for a second.
func _watch(branch: Dictionary, step: float) -> void:
	var attempt := str(branch.attempt)
	if RealityState.has_knowledge(attempt) or int(world.campaign_clock.minute_of_day()) < int(branch.witness_from):
		_witnessed = 0.0
		return
	_witnessed = _witnessed + step if witnessing(branch) else 0.0
	if _witnessed + .0001 >= WITNESS_SECONDS:
		_witnessed = 0.0
		if RealityState.grant_knowledge(attempt):
			RealityState.commit()


## True while the player can see the branch's scene: through the player's own first-person camera, current, with
## the face inside its picture.
func witnessing(branch: Dictionary) -> bool:
	if not is_instance_valid(actor) or not is_instance_valid(world.player):
		return false
	var camera: Camera3D = world.player.camera
	if camera == null or not camera.is_inside_tree() or not camera.current:
		return false
	if str(branch.place) == "parapet" and not str(world.room_at_world(world.player.global_position + Vector3.UP * .8)).begins_with("ROOF_DECK_"):
		return false
	var people: Array = [actor]
	if str(branch.place) == "prints":
		people.append_array(guests)
	var seen := 0
	for person: Variant in people:
		if is_instance_valid(person) and _sees(camera, person as Node3D, float(branch.reach)):
			seen += 1
	return seen >= (2 if str(branch.place) == "prints" else 1)


func _sees(camera: Camera3D, person: Node3D, reach: float) -> bool:
	if not person.is_visible_in_tree():
		return false
	var head := person.global_position + Vector3.UP * 1.55
	var eye := camera.global_position
	if eye.distance_to(head) > reach or not camera.is_position_in_frustum(head):
		return false
	var exclude: Array[RID] = [world.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, head, 1, exclude))
	return hit.is_empty() or (hit.collider is Node and person.is_ancestor_of(hit.collider))


func _retire() -> void:
	_current_thread = ""
	_witnessed = 0.0
	for guest: AnimatedResident in guests:
		if is_instance_valid(guest):
			guest.hide()
			guest.queue_free()
	guests.clear()
	_stand = {}
	if not is_instance_valid(actor):
		return
	if world.conversations._active_resident == PERSON:
		world.conversations.cancel_for_transition()
	actor.hide()
	(actor.get_node("Interaction") as Area3D).collision_layer = 0
	actor.queue_free()
	actor = null


## Resolve the three positions against the same installed window, roof and
## clock the player sees. No physical prop, mesh or collision is moved here.
func _stance(place: String) -> Dictionary:
	var building := world.adapter.root as Node3D
	match place:
		WINDOW:
			var window := world.photo_supplies.get("window") as Node3D
			if is_instance_valid(window):
				var origin := window.global_position + window.global_basis.z * 1.55 + window.global_basis.x * .75
				return {"origin": origin, "facing": window.global_position}
		"roof":
			var origin := building.to_global(ROOF_STANCE + Vector3.UP)
			return {"origin": origin, "facing": origin + building.global_basis.z, "room_prefix": "ROOF_DECK_"}
		"parapet":
			var parapet := building.find_child(PARAPET, true, false) as Node3D
			if not is_instance_valid(parapet):
				return {}
			var edge := building.to_local(parapet.global_position).z
			var inward := -signf(edge)
			var local := Vector3(PARAPET_STANCE_X, ROOF_STANCE.y, edge + inward * PARAPET_INSET)
			return {"origin": building.to_global(local + Vector3.UP), "room_prefix": "ROOF_DECK_",
					"facing": building.to_global(Vector3(PARAPET_STANCE_X, ROOF_STANCE.y + 1.0, edge - inward * 2.0))}
		"enlarger", "prints":
			var enlarger: Variant = enlarger_point()
			if enlarger == null:
				return {"retry": true}
			var at: Vector3 = enlarger
			for turn in 8:
				var side := Vector3.FORWARD.rotated(Vector3.UP, TAU * turn / 8.0)
				var origin := at + side * .8
				var floor := _stand_floor(origin)
				if floor.is_empty() or floor.position.y > at.y - .5 or not _clear(floor.position) 						or not world.passage_region.prepared_shop_contains(SHOP, floor.position + Vector3.UP * .8):
					continue
				return {"origin": origin, "facing": at, "beside": side.cross(Vector3.UP)}
			return {}
		"lobby":
			var clocks := world.witness_clocks.get("node") as Node3D
			var clock := clocks.get_node_or_null(CLOCK) as Node3D if is_instance_valid(clocks) else null
			if is_instance_valid(clock):
				var origin := clock.global_position + building.global_basis * STANCE_FROM_CLOCK
				return {"origin": origin, "facing": clock.global_position, "room": LOBBY}
	return {}


func _mount_resident(encounter: Dictionary) -> void:
	var thread := str(encounter.thread)
	var placement := _stance(str(encounter.place))
	if bool(placement.get("retry", false)):
		return # The shop's cell is not loaded yet; it is staged when the player brings it in.
	if placement.is_empty():
		_refuse(thread, "the installed approach marker is missing")
		return
	var floor := _stand_floor(placement.origin)
	if floor.is_empty():
		_refuse(thread, "the marker has no walkable floor")
		return
	var room := str(world.room_at_world(floor.position + Vector3.UP * .8))
	if (placement.has("room") and room != placement.room) or not room.begins_with(str(placement.get("room_prefix", ""))):
		_refuse(thread, "the standing marker is outside its authored room")
		return
	if not _clear(floor.position):
		_refuse(thread, "the standing volume is blocked")
		return
	# A Friday branch is seen, not spoken to: its bodies offer no topic.
	var witnessed := encounter.has("attempt")
	var resident := _present("Adela Voss", PERSON, floor.position, placement.facing,
			"av_friday_witness" if witnessed else thread, thread != "av_nineteen",
			func() -> bool: return not witnessed and _scheduled_encounter().get("thread") == thread)
	if resident == null:
		_refuse(thread, "the existing rebuilt resident body did not load")
		return
	actor = resident
	_current_thread = thread
	_stand = {"at": floor.position, "beside": placement.get("beside", Vector3.RIGHT)}
	_mount_guests(encounter)


## A guest is staged only once her routed body has gone out, so she is never seen in two places.
func _mount_guests(encounter: Dictionary) -> void:
	var guest_ids: Array = encounter.get("guests", [])
	for i in guest_ids.size():
		var id := str(guest_ids[i])
		if guests.any(func(g: AnimatedResident) -> bool: return is_instance_valid(g) and g.resident_id == id) or routed_visible(id):
			continue
		var beside: Vector3 = _stand.beside
		var spot := _stand_floor(_stand.at + beside * (.9 * (i + 1)) + Vector3.UP * .2)
		if spot.is_empty() or not _clear(spot.position):
			spot = _stand_floor(_stand.at - beside * (.9 * (i + 1)) + Vector3.UP * .2)
		if spot.is_empty() or not _clear(spot.position):
			continue
		var guest := _present(str(GUEST_NAMES.get(id, id)), id, spot.position, _stand.at, "av_friday_witness",
				true, func() -> bool: return false)
		if guest != null:
			guests.append(guest)


## True while any other body of this resident is visible in the world.
func routed_visible(id: String) -> bool:
	for body: Node in get_tree().get_nodes_in_group("animated_residents"):
		if body is Node3D and str(body.get("resident_id")) == id and not guests.has(body) 				and (body as Node3D).is_visible_in_tree():
			return true
	return false


## The mounted enlarger's own drawn body (its dark casting), once the shop is resident; null until then.
func enlarger_point() -> Variant:
	var region: Node = world.get("passage_region")
	if region == null or str(region.residency.state) != "RESIDENT":
		return null
	var fitting := region.shop_fitting(SHOP, "PhotoEnlargers") as Node3D
	if not is_instance_valid(fitting):
		return null
	for draw: MeshInstance3D in fitting.find_children("*", "MeshInstance3D", true, false):
		if draw.mesh != null and draw.is_visible_in_tree() and str(draw.get_meta("photo_enlargers_part", draw.name)) == ENLARGER + "__dark":
			return draw.to_global(draw.mesh.get_aabb().get_center())
	return null


func _stand_floor(origin: Vector3) -> Dictionary:
	var floor := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,
			origin - Vector3.UP * 3.0, 1, [world.player.get_rid()]))
	return {} if floor.is_empty() or floor.normal.y < .85 else floor


func _clear(at: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = .43
	capsule.height = 1.72
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = capsule
	clearance.collision_mask = 1
	clearance.exclude = [world.player.get_rid()]
	clearance.transform.origin = at + Vector3.UP * (capsule.height * .5 + .025)
	return get_world_3d().direct_space_state.intersect_shape(clearance, 1).is_empty()


func _present(display: String, id: String, at: Vector3, facing: Vector3, topic: String, stand_pose: bool,
		present: Callable) -> AnimatedResident:
	var resident := Presentation.new()
	resident.setup(display, id, "", CastBodies.cast_model(id))
	resident.externally_driven = true
	resident.face_interacting_player = true
	resident.use_cast_stand_pose = stand_pose
	resident.installed_topic = topic
	resident.topic_is_present = present
	resident.position = to_local(at)
	add_child(resident)
	if resident.cast_body == null or not resident.cast_body.ready_ok:
		resident.hide()
		resident.queue_free()
		return null
	# The rebuilt resident faces model +Z, the same front she turns toward a caller.
	resident.look_at(Vector3(facing.x, resident.global_position.y, facing.z), Vector3.UP, true)
	return resident


func _refuse(thread: String, reason: String) -> void:
	_refused_thread = thread
	push_error("Adela encounter %s: %s" % [thread, reason])
