extends Node
## SR5 focused proof: the first waking service phrase enters the existing
## organism signal bed and receives an architecture-owned answer without a
## maintenance Dream owner or save fact.

class RouteStub:
	extends Node
	signal route_beat(beat: String)

var failures := 0
var encroachment: ApartmentEncroachment
var ecology: DreamEcologyDirector
var route: RouteStub
var field: LivingField
var radiator_at := Vector3(-10.4, 3.55, 6.1)
var board_at := Vector3(5.2, 1.42, -6.2)
var boiler_at := Vector3(9.05, -2.55, 9.65)


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_build_shared_owners()
	var state_before := JSON.stringify(RealityState.data)
	var children_before := encroachment.get_child_count()

	route.route_beat.emit("diagnosis")
	_check(encroachment.service_answers == 0,
			"a diagnosis label without the physical phrase earns no answer")
	route.route_beat.emit("radiator_evidence")
	route.route_beat.emit("radiator_evidence")
	route.route_beat.emit("lobby_comparison")
	route.route_beat.emit("diagnosis")
	_check(encroachment.service_observations == 2
			and encroachment.service_answers == 0,
			"duplicate or incomplete principles cannot impersonate the phrase")

	route.route_beat.emit("basement_comparison")
	var before_answer := field.census()
	route.route_beat.emit("diagnosis")
	var answered := encroachment.service_response_census()
	var after_answer := field.census()
	_check(int(answered.observations) == 3 and int(answered.answers) == 1,
			"flow, contact and pressure become one recognized service phrase")
	_check((answered.attention_at as Vector3).distance_to(boiler_at) < 0.01
			and ecology.attending.distance_to(boiler_at) < 0.01,
			"the existing rare whole-body attention owner interrupts at the boiler")
	_check((answered.answer_at as Vector3).distance_to(radiator_at) < 0.01
			and int(answered.answer_cells) > 0,
			"architecture secretes its answer into the 2B return destination")
	_check(int(after_answer.vascular_responses)
			== int(before_answer.vascular_responses) + 1
			and int(after_answer.live_voxels) > int(before_answer.live_voxels)
			and int(after_answer.agents) == int(before_answer.agents)
			and int(after_answer.stained_voxels)
			== int(before_answer.stained_voxels),
			"the waiting answer is temporary body pressure, never lineage or stain")
	var signals := ecology.signal_census()
	_check(int(signals.emitted) == 4
			and int(signals.by_function.get("probe", 0)) == 1
			and int(signals.by_function.get("recognize", 0)) == 1
			and int(signals.by_function.get("pulse", 0)) == 1
			and int(signals.by_function.get("secrete", 0)) == 1,
			"all four messages use the one bounded shared signal bed")

	route.route_beat.emit("repair")
	route.route_beat.emit("repair")
	var replied := ecology.signal_census()
	_check(encroachment.service_reply_packets == 1
			and int(replied.emitted) == 5
			and int(replied.by_function.get("recognize", 0)) == 2,
			"the repaired valve returns one recognition packet, idempotently")
	_check(JSON.stringify(RealityState.data) == state_before,
			"the entire exchange adds no RealityState or save fact")
	_check(encroachment.get_child_count() == children_before,
			"the exchange creates no director, entity, hazard or presentation node")

	print("DREAM SERVICE ANSWER TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _build_shared_owners() -> void:
	_anchor("F02_B_RADIATOR_01", radiator_at)
	_anchor("LobbyPorterBoard", board_at)
	_anchor("B1_BOILER_01", boiler_at)
	encroachment = ApartmentEncroachment.new()
	encroachment.name = "ApartmentEncroachment"
	add_child(encroachment)
	encroachment.set_physics_process(false)
	ecology = DreamEcologyDirector.new()
	encroachment.add_child(ecology)
	ecology.setup(5105)
	encroachment.ecology = ecology
	field = LivingField.new()
	field.configure(Vector4(-13.9, -9.9, 13.9, 9.9), 3.2, 5105)
	field.add_source(Vector3(-9.6, 3.55, 5.0), 0)
	encroachment.fields["F02"] = field
	route = RouteStub.new()
	add_child(route)
	encroachment.bind_service_round(route)


func _anchor(label: String, at: Vector3) -> void:
	var node := Node3D.new()
	node.name = label
	node.position = at
	add_child(node)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [answer ok] ", label)
	else:
		failures += 1
		printerr("  [ANSWER FAIL] ", label)
