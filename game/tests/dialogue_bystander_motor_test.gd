extends Node3D
## Real route motor, floor, player and dialogue owners with short synthetic
## unobstructed lanes. This fixture concerns travel/lock behaviour, not art.
const Route := preload("res://scripts/characters/orison_v2_resident_route.gd")

class Body extends "res://scripts/characters/orison_v2_resident_presentation.gd":
	func _ready() -> void:
		add_to_group("animated_residents"); externally_driven = true
		set_process(false)

class ListenerAttention extends Node:
	var conversing := false
	var ensemble_target: Variant = null

var player: PlayerController
var public_traffic: Node
var actors := {}
var motors := {}
var problems: Array[String] = []
var talk: ResidentConversations
var panel: CaseDialoguePanel

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	print("BACKGROUND CAST: ", message, " = ", ok)
	if not ok: problems.append(message)

func _route(id: String, z: float, endpoint := 4.0) -> void:
	var route := Route.new()
	route.world = self; route.resident = id
	add_child(route)
	var body := Body.new(); body.resident_id = id
	route.add_child(body); route.actor = body; body.position = Vector3(0,0,z)
	route.current_id = route._point("start", body.position)
	route.desired_id = route._point("goal", Vector3(endpoint,0,z))
	route.graph.connect_points(route.current_id,route.desired_id)
	route.destination = "goal"; route.places = {"goal":"goal"}; route._sample = 10000.0
	route._capsule.radius = .28; route._capsule.height = 1.4
	actors[id] = body; motors[id] = route; route.set_physics_process(false)

func _activity_fixture(id: String, at: Vector3) -> Body:
	var body := Body.new(); body.resident_id = id; body.position = at; add_child(body)
	var library := AnimationLibrary.new()
	for clip: String in ["clip_01","clip_03","clip_06"]:
		var animation := Animation.new(); animation.length = 1.0; library.add_animation(clip,animation)
	body._animation_player = AnimationPlayer.new(); body.add_child(body._animation_player)
	body._animation_player.add_animation_library("",library)
	return body

func _frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func _metres(id: String) -> float:
	return float(motors[id].travelled_metres)

func _run() -> void:
	var floor_body := StaticBody3D.new(); var shape := BoxShape3D.new()
	shape.size = Vector3(14,.2,18)
	var coll := CollisionShape3D.new(); coll.shape = shape; floor_body.add_child(coll)
	floor_body.position.y = -.1; add_child(floor_body)
	player = PlayerController.new(); add_child(player); player.set_physics_process(false)
	player.position = Vector3(1.5,.01,2.0)
	panel = CaseDialoguePanel.new(); add_child(panel)
	talk = ResidentConversations.new(); add_child(talk); talk.setup(panel)
	_route("noel_price",-1.5); _route("jonah_price",-.55)
	_route("evelyn_marsh",-4); _route("cal_dwyer",.55); _route("omar_bell",2.0); _route("mina_vale",4)
	var active_worker := _activity_fixture("sacha_reed",Vector3(0,0,-6))
	var seated := _activity_fixture("nadia_quell",Vector3(0,0,-7))
	_check(seated.play_seated(),"fixture seat acquired by actual seated presentation")
	var listener := ListenerAttention.new(); actors.evelyn_marsh.add_child(listener)
	actors.evelyn_marsh.attention = listener; listener.ensemble_target = Vector3.ZERO
	await _frames(2)
	var lines := [{"speaker":"noel_price","text":"Here."},{"speaker":"jonah_price","text":"Yes."}]
	_check(talk.start_performance_sequence("noel_price",lines,player),"real two-person panel opens")
	active_worker.set_loop_activity("work"); seated.set_loop_activity("work")
	_check(active_worker._loop_activity=="work" and active_worker._animation_player.current_animation=="clip_03",
			"standing bystander's authored activity continues under the actual panel")
	_check(seated._loop_seated() and seated._loop_activity.is_empty(),"authored activity cannot displace a seated bystander")
	for route: Node in motors.values(): route.set_physics_process(true)
	await _frames(12)
	_check(_metres("cal_dwyer")>.1 and not actors.cal_dwyer._loop_talking(),"nearby uninvolved body walks while its activity remains eligible")
	_check(_metres("noel_price")==0 and _metres("jonah_price")==0 and _metres("mina_vale")==0,"speaker, listening partner and Mina retain their motor owners")
	_check(is_zero_approx(_metres("evelyn_marsh")), "a historical listener held by the attention owner stays on her mark")
	panel.choose(0)
	await _frames(12)
	_check(not ResidentConversations.permits_background_work(actors.noel_price,player)
			and not ResidentConversations.permits_background_work(actors.jonah_price,player)
			and ResidentConversations.permits_background_work(actors.cal_dwyer,player), "both actual cast ids protected after switching active speaker")
	_check(talk._active_resident=="jonah_price" and not actors.cal_dwyer._loop_talking() and actors.noel_price._loop_talking(), "handoff keeps both actors and releases the bystander")
	_check(_metres("noel_price")==0 and _metres("jonah_price")==0 and _metres("cal_dwyer")>.25, "ordinary motor continues through reply handoff")
	await _frames(105)
	var gap: float = actors.omar_bell.global_position.distance_to(player.global_position)
	_check(gap>=.64 and _metres("omar_bell")>.2 and motors.omar_bell.squeeze.cue_count==0,"bystander approaches but never squeezes through the immobile caller")
	# An independent protected owner can write true over the panel's true.
	player.call_locked = true
	var before := _metres("cal_dwyer")
	await _frames(8)
	_check(is_equal_approx(before,_metres("cal_dwyer")) and actors.cal_dwyer._loop_talking(),"new foreign lock freezes the bystander")
	panel.choose(0)
	_check(player.call_locked and not panel.attention_active(),"closing resident reply preserves newer protected lock")
	player.call_locked = false
	await _frames(8)
	_check(_metres("noel_price")>0 and _metres("jonah_price")>0,"both participants resume after ordinary release")
	var old := _metres("cal_dwyer")
	player.text_input_owner = self
	await _frames(6)
	_check(is_equal_approx(old,_metres("cal_dwyer")),"standalone text input retains its original freeze")
	player.text_input_owner = null
	_check(talk.start_performance("noel_price","Here again.",player),"resident can reopen with fresh input custody")
	panel.present("Telephone","Hold.",[])
	before = _metres("cal_dwyer")
	await _frames(8)
	_check(is_equal_approx(before,_metres("cal_dwyer")) and player.call_locked,"foreign manual prompt on same panel keeps input and blocks bystanders")
	panel.close()
	_check(not player.call_locked,"manual successor releases its own lock")
	var held_pose := _metres("cal_dwyer")
	player.call_locked = true
	_check(talk.start_performance("noel_price","Occupied.",player),"programmatic resident prompt has a foreign lock already held")
	await _frames(6)
	talk.cancel_for_transition()
	_check(player.call_locked and is_equal_approx(held_pose,_metres("cal_dwyer")),"preexisting protected owner survives opening and closing resident panel")
	player.call_locked = false
	print("DIALOGUE BYSTANDER MOTOR: ",problems)
	get_tree().quit(0 if problems.is_empty() else 1)
