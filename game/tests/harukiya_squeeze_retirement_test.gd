extends Node3D
## Observer admission controls on declared owner doubles, not gameplay proof.
const Witness = preload("res://tests/harukiya_squeeze_witness.gd")
const Courtesy = preload("res://scripts/characters/character_squeeze_past.gd")
class Visit extends RefCounted:
	func phase() -> String: return ""
class Guide extends RefCounted:
	var visit = Visit.new()
	var _transition := ""
class Owner extends Node3D:
	var actor: Node3D
	var resident := "observer_double"
	var destination := "out"
	var outside := false
	var current_id := 0
	var desired_id := 0
	var graph := AStar3D.new()
	var path := PackedInt64Array()
	var _bar_route = Guide.new()
	var squeeze = Courtesy.new()
	var observed := false
	var leaving := true
	func _observed() -> bool: return observed
	func _leaves_unseen() -> bool: return leaving
var owners: Array[Node3D] = []
var failures: Array[String] = []
var checks: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	checks.append({"ok":ok,"label":label})
	if not ok: failures.append(label)
	print("RETIREMENT OBSERVER: ",label," = ",ok)

func _ready() -> void: run.call_deferred()

func reset_owners() -> void:
	for index: int in 2:
		var route: Node3D = owners[index]
		route.set_physics_process(true)
		route.outside = false; route.observed = false; route.leaving = true
		route.current_id = 0; route.desired_id = 0; route.path.clear()
		route.actor.show(); route.actor.get_node("Visual").show()
		route.actor.position = route.graph.get_point_position(0)
		route.actor.get_node("Interaction").collision_layer = 1
		route.actor.get_node("Body").collision_layer = 0

func open_pair() -> RefCounted:
	reset_owners()
	for tick: int in int(Engine.physics_ticks_per_second * .9):
		await get_tree().physics_frame
		owners[0].squeeze.permits(owners[0].actor,owners[1].actor)
	var witness = Witness.new()
	check(witness.observe_pair("pair",owners[0],owners[0].actor,owners[1],owners[1].actor,true,get_physics_process_delta_time()).ok,"actual timed permission opens a tracked pair")
	return witness

func retire(route: Node3D) -> void:
	route.outside = true; route.actor.hide()
	route.actor.get_node("Interaction").collision_layer = 0

func run() -> void:
	for index: int in 2:
		var route = Owner.new(); add_child(route); route.set_physics_process(true)
		route.resident = "double_" + str(index)
		var point = Vector3(float(index) * .2,0,0)
		route.graph.add_point(0,point); route.graph.add_point(1,point + Vector3.RIGHT)
		route.actor = Node3D.new(); route.add_child(route.actor)
		route.actor.add_to_group("animated_residents")
		var interaction := Area3D.new(); interaction.name = "Interaction"; route.actor.add_child(interaction)
		var body := StaticBody3D.new(); body.name = "Body"; body.collision_layer = 0; route.actor.add_child(body)
		var visual := Node3D.new(); visual.name = "Visual"; route.actor.add_child(visual)
		owners.append(route)
	var valid: RefCounted = await open_pair()
	await get_tree().physics_frame
	retire(owners[1])
	check(valid.observe_retirement("pair",owners[0],owners[0].actor,owners[1],owners[1].actor).ok,"exact endpoint owner retirement is accounted explicitly")
	var completion: Dictionary = valid.snapshot().completed[0]
	check(completion.completion == "owner_retired_unseen" and not completion.physical_separation_proved,"retirement never claims physical separation")
	check(valid.finish_frame().ok and valid.snapshot().active.is_empty(),"explicit validated outcome completes this frame's coverage")
	for retiring: Array in [[0],[0,1]]:
		var witness: RefCounted = await open_pair()
		await get_tree().physics_frame
		for index: int in retiring: retire(owners[index])
		check(witness.observe_retirement("pair",owners[0],owners[0].actor,owners[1],owners[1].actor).ok,"watched-owner and both-owner retirement are accounted: " + str(retiring))
		check(witness.snapshot().completed[0].retired_owners.size() == retiring.size(),"each retired owner retains independent evidence: " + str(retiring))
	for scenario: String in ["outside","interaction","endpoint","off_endpoint","path","observed","leaves","collider","hidden_child","inactive","counterpart","identity","missed_frame","reparented","detached"]:
		var witness: RefCounted = await open_pair()
		await get_tree().physics_frame
		retire(owners[1])
		var first: Node3D = owners[0].actor
		match scenario:
			"outside": owners[1].outside = false
			"interaction": owners[1].actor.get_node("Interaction").collision_layer = 1
			"endpoint": owners[1].desired_id = 1
			"off_endpoint": owners[1].actor.position += Vector3(.1,0,0)
			"path": owners[1].path.append(1)
			"observed": owners[1].observed = true
			"leaves": owners[1].leaving = false
			"collider": owners[1].actor.get_node("Body").collision_layer = 1
			"hidden_child":
				owners[1].outside = false; owners[1].actor.show(); owners[1].actor.get_node("Visual").hide()
			"inactive": owners[1].set_physics_process(false)
			"counterpart": owners[0].actor.hide()
			"identity": first = Node3D.new(); add_child(first)
			"missed_frame": await get_tree().physics_frame
			"reparented": owners[1].actor.reparent(self)
			"detached": remove_child(owners[1])
		check(not witness.observe_retirement("pair",owners[0],first,owners[1],owners[1].actor).ok,"invalid retirement remains refused: " + scenario)
		check(witness.has_pair("pair") and not witness.finish_frame().ok,"refusal retains omission failure: " + scenario)
		if scenario == "identity": first.free()
		if scenario == "reparented": owners[1].actor.reparent(owners[1])
		if scenario == "detached": add_child(owners[1])
	check(not Witness.endpoint_completed(Vector3(NAN,0,0),Vector3.ZERO),"NaN actual feet cannot pass endpoint guard")
	check(not Witness.endpoint_completed(Vector3.ZERO,Vector3(INF,0,0)),"nonfinite authored endpoint cannot pass guard")
	check(not Witness.endpoint_completed(Vector3(3e38,0,0),Vector3(-3e38,0,0)),"finite coordinates with overflowing difference cannot pass guard")
	var separated: RefCounted = await open_pair()
	await get_tree().physics_frame
	check(separated.observe_pair("pair",owners[0],owners[0].actor,owners[1],owners[1].actor,false,get_physics_process_delta_time()).ok,"ordinary visible separation still completes")
	check(separated.snapshot().completed[0].physical_separation_proved,"only separation outcome proves separation")
	var stationary: RefCounted = await open_pair()
	var last_result: Dictionary = {}
	for tick: int in Engine.physics_ticks_per_second * 11:
		await get_tree().physics_frame
		last_result = stationary.observe_pair("pair",owners[0],owners[0].actor,owners[1],owners[1].actor,true,get_physics_process_delta_time())
		if not last_result.ok: break
	check(not last_result.ok and str(last_result.reason).contains("stationary"),"original ten-second stationary overlap remains failure")
	var queued: RefCounted = await open_pair()
	await get_tree().physics_frame
	retire(owners[1]); owners[1].queue_free()
	check(not queued.observe_retirement("pair",owners[0],owners[0].actor,owners[1],owners[1].actor).ok,"queued owner cannot certify retirement")
	check(queued.has_pair("pair") and not queued.finish_frame().ok,"queued owner retains explicit omission failure")
	var output := OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		FileAccess.open(output.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT",
			"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,
			"scope":"Observer admission and negative controls on explicit owner doubles with actual frame-based courtesy timers. No production off-map, physical separation, travel or attendance acceptance."},"\t"))
	get_tree().quit(0 if failures.is_empty() else 1)
