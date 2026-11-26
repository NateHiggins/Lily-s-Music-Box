extends Node3D
## Presents Adela at her authored encounters using the ordinary resident body.
## The schedule owns attendance; the conversation owns all earned facts.
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

var world: Node3D
var actor: AnimatedResident
var _current_thread := ""
var _refused_thread := ""
var _poll_due := 0.0


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


func _scheduled_encounter() -> Dictionary:
	var encounter: Dictionary = ENCOUNTERS.get(world.conversations.today(), {})
	if encounter.is_empty():
		return {}
	var where: Dictionary = world.resident_whereabouts(PERSON)
	if where.get("place") != encounter.place or where.get("activity") != encounter.activity:
		return {}
	return encounter


func _retire() -> void:
	_current_thread = ""
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
	if placement.is_empty():
		_refuse(thread, "the installed approach marker is missing")
		return
	var origin: Vector3 = placement.origin
	var space := get_world_3d().direct_space_state
	var floor := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,
			origin - Vector3.UP * 3.0, 1, [world.player.get_rid()]))
	if floor.is_empty() or floor.normal.y < .85:
		_refuse(thread, "the marker has no walkable floor")
		return
	var room := str(world.room_at_world(floor.position + Vector3.UP * .8))
	if (placement.has("room") and room != placement.room) or not room.begins_with(str(placement.get("room_prefix", ""))):
		_refuse(thread, "the standing marker is outside its authored room")
		return
	var capsule := CapsuleShape3D.new()
	capsule.radius = .43
	capsule.height = 1.72
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = capsule
	clearance.collision_mask = 1
	clearance.exclude = [world.player.get_rid()]
	clearance.transform.origin = floor.position + Vector3.UP * (capsule.height * .5 + .025)
	if not space.intersect_shape(clearance, 1).is_empty():
		_refuse(thread, "the standing volume is blocked")
		return
	var resident := Presentation.new()
	resident.setup("Adela Voss", PERSON, "", CastBodies.cast_model(PERSON))
	resident.externally_driven = true
	resident.face_interacting_player = true
	resident.use_cast_stand_pose = thread != "av_nineteen"
	resident.installed_topic = thread
	resident.topic_is_present = func() -> bool: return _scheduled_encounter().get("thread") == thread
	resident.position = to_local(floor.position)
	add_child(resident)
	if resident.cast_body == null or not resident.cast_body.ready_ok:
		resident.hide()
		resident.queue_free()
		_refuse(thread, "the existing rebuilt resident body did not load")
		return
	# The rebuilt resident faces model +Z, the same front she turns toward a caller.
	resident.look_at(Vector3(placement.facing.x, resident.global_position.y, placement.facing.z), Vector3.UP, true)
	actor = resident
	_current_thread = thread


func _refuse(thread: String, reason: String) -> void:
	_refused_thread = thread
	push_error("Adela encounter %s: %s" % [thread, reason])
