extends Node
## Synthetic state diagnostic. Actor placement below is NOT motor/native proof.
const Admission := preload("res://scripts/building/bodega_admission.gd")
const INPUTS := ["res://scripts/building/bodega_admission.gd",
	"res://scripts/characters/shared_passage_admission.gd", "res://tests/bodega_admission_test.gd",
	"res://tests/BodegaAdmissionTest.tscn", "res://tests/guide_bell_error_capture.gd"]
class FixtureResolver extends RefCounted:
	var missing := ""
	func resolve_placement(instance: String, identity: String) -> Dictionary:
		var index := Admission.POSITIONS.find(identity)
		if identity == missing or instance != "SHOP_BODEGA" or index < 0: return {}
		return {"instance_id": instance, "placement_id": identity,
			"position": Vector3(index * 2.0, .04, -3.0)}
class FixtureExterior extends Node3D:
	var spatial_resolver := FixtureResolver.new()
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var _completed: Array[String] = []
var _initial: Dictionary = {}
var _started := 0
var _logger

func _ready() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	checks.append({"label": label, "passed": ok})
	if not ok: failures.append(label)
	print("BODEGA ADMISSION: ", label, " = ", ok)

func _body() -> Node3D:
	var body := Node3D.new(); add_child(body); return body

func _fixture() -> Admission:
	var exterior := FixtureExterior.new(); add_child(exterior)
	var owner := Admission.new(); owner.position = Vector3(7, 0, 4); add_child(owner)
	_check("complete resolver configures attached owner", owner.configure(exterior))
	return owner

func _at(body: Node3D, owner: Admission, identity: String) -> void:
	body.global_position = owner.position_marker(identity).global_position
	body.global_position.y = 0.0 # Explicit synthetic supported-height stand-in.

func _run() -> void:
	_started = Time.get_ticks_msec(); _initial = _inputs()
	_logger = preload("res://tests/guide_bell_error_capture.gd").new(); OS.add_logger(_logger)
	_configuration(); _capacity_transfer(); _cancel_and_transit(); _queued_retarget()
	await _lifetime()
	_check("every test group completes", _completed == ["configuration", "capacity", "cancel_transit", "queued_retarget", "lifetime"])
	_check("all source inputs stable", _inputs() == _initial)
	_check("no unexpected engine errors", _logger.errors.is_empty()); OS.remove_logger(_logger)
	_finish()

func _configuration() -> void:
	var exterior := FixtureExterior.new(); add_child(exterior)
	var detached := Admission.new()
	_check("configure refuses detached owner", not detached.configure(exterior)); detached.free()
	exterior.spatial_resolver.missing = "resident_wait_rear"
	var missing := Admission.new(); add_child(missing)
	_check("missing authored marker fails without partial children", not missing.configure(exterior) and missing.get_child_count() == 0)
	exterior.spatial_resolver.missing = ""
	_check("complete retry succeeds once", missing.configure(exterior) and not missing.configure(exterior))
	for identity: String in Admission.POSITIONS:
		var marker := missing.position_marker(identity)
		var expected: Vector3 = exterior.spatial_resolver.resolve_placement("SHOP_BODEGA", identity).position
		_check("exact source world marker " + identity, marker != null and marker.global_position == expected)
	var a := _body(); var wrong := _body()
	_check("same exact binding retries", missing.bind("a", a) and missing.bind("a", a))
	_check("duplicate identity and body alias rejected", not missing.bind("a", wrong) and not missing.bind("alias", a))
	_check("unknown identity has no service", not missing.has_service("unknown", wrong)
		and missing.request_service("unknown", wrong) == null)
	_completed.append("configuration")

func _capacity_transfer() -> void:
	var owner := _fixture()
	var a := _body(); var b := _body(); var c := _body(); var d := _body(); var later := _body(); var wrong := _body()
	_check("five contenders bind", owner.bind("a", a) and owner.bind("b", b) and owner.bind("c", c)
		and owner.bind("d", d) and owner.bind("later", later))
	var front: Node3D = owner.position_marker("resident_wait_front")
	var rear: Node3D = owner.position_marker("resident_wait_rear")
	var overflow: Node3D = owner.position_marker("resident_overflow")
	_check("first request gets stable front", owner.request_service("a", a) == front and owner.request_service("a", a) == front)
	_check("blocked clearance cannot grant service", not owner.try_service("a", a, false) and not owner.has_service("a", a))
	_check("clear head obtains transfer custody", owner.try_service("a", a, true) and owner.has_service("a", a))
	_at(a, owner, "resident_wait_front")
	_check("intent at wait point cannot finish service arrival", not owner.arrive_service("a", a))
	_at(a, owner, "service_stance"); a.global_position.y = .50
	_check("unsupported height cannot finish arrival", not owner.arrive_service("a", a))
	a.global_position.y = 0.0
	_check("physical arrival transfers once", owner.arrive_service("a", a) and owner.arrive_service("a", a))
	var snapshot: Dictionary = owner.debug_snapshot()
	_check("service owner separate from active FIFO slot", snapshot.service_owner.resident == "a" and snapshot.service.active.is_empty())
	_check("three waiters fit beside one service owner", owner.request_service("b", b) == front
		and owner.request_service("c", c) == rear and owner.request_service("d", d) == overflow)
	_check("fifth body has no invented overflow", owner.request_service("later", later) == null)
	_check("physical owner retry does not consume waiting slot", owner.request_service("a", a) == owner.position_marker("service_stance")
		and owner.debug_snapshot().service.queue.size() == 3)
	_check("another owner cannot use occupied service", not owner.try_service("b", b, true))
	_check("wrong body cannot arrive or release", not owner.arrive_service("a", wrong) and not owner.release_service("a", wrong, true))
	_check("clear assertion cannot release feet still at service", not owner.release_service("a", a, true) and owner.has_service("a", a))
	a.global_position += Vector3(0, 0, 2)
	_check("departure still needs measured clearance", not owner.release_service("a", a, false) and owner.has_service("a", a))
	_check("safe release never auto-promotes next", owner.release_service("a", a, true) and not owner.has_service("b", b))
	_check("oldest waiter transfers first", owner.try_service("b", b, true))
	_at(b, owner, "service_stance")
	_check("second actual arrival frees front slot", owner.arrive_service("b", b) and owner.request_service("later", later) == front)
	_check("rear and overflow positions remain stable", owner.request_service("c", c) == rear and owner.request_service("d", d) == overflow)
	b.global_position += Vector3(0, 0, 2)
	_check("next departure clears service", owner.release_service("b", b, true))
	_check("new front-slot body cannot jump older rear waiter", not owner.try_service("later", later, true) and owner.try_service("c", c, true))
	_check("retarget queued body can cancel immediately", owner.cancel("later", later)
		and owner.debug_snapshot().service.queue.size() == 1)
	_completed.append("capacity")

func _cancel_and_transit() -> void:
	var owner := _fixture()
	var a := _body(); var b := _body(); var wrong := _body()
	_check("cancellation fixture binds", owner.bind("a", a) and owner.bind("b", b))
	_check("active transfer begins", owner.request_service("a", a) != null and owner.try_service("a", a, true))
	_at(a, owner, "resident_wait_front")
	_check("remote or unspecified transit slots refused", owner.request_transit("a", a, []) == null
		and owner.request_transit("a", a, [4]) == null)
	_check("actual stance can request independent transit", owner.request_transit("a", a, [1]) == owner.position_marker("resident_wait_front")
		and owner.try_transit("a", a, true) and owner.has_service("a", a))
	_check("wrong body cancellation cannot touch either claim", not owner.cancel("a", wrong, true)
		and owner.has_service("a", a) and owner.has_transit("a", a))
	_check("cancelled active transfer retains both claims until clear", not owner.cancel("a", a)
		and owner.has_service("a", a) and owner.has_transit("a", a))
	_at(a, owner, "service_stance")
	_check("cancelled transfer cannot become service occupant", not owner.arrive_service("a", a)
		and not owner.try_service("a", a, true) and not owner.try_transit("a", a, true))
	_check("false clearance cannot release active transit", not owner.release_transit("a", a, false))
	a.global_position += Vector3(0, 0, 2)
	_check("guide-certified exit clears cancelled claims", owner.cancel("a", a, true)
		and not owner.has_service("a", a) and not owner.has_transit("a", a))
	_check("same body can revisit after cancellation", owner.request_service("a", a) != null and owner.try_service("a", a, true))
	_at(a, owner, "service_stance")
	_check("revisited body becomes actual service owner", owner.arrive_service("a", a))
	_check("physical service owner independently acquires transit", owner.request_transit("a", a, [0]) == owner.position_marker("service_stance")
		and owner.try_transit("a", a, true) and owner.has_service("a", a))
	_check("transit release alone does not release service", owner.release_transit("a", a, true) and owner.has_service("a", a))
	_check("next service wait gets front", owner.request_service("b", b) == owner.position_marker("resident_wait_front"))
	_at(a, owner, "resident_wait_front")
	_check("transit cannot take another body's reserved service wait", owner.request_transit("a", a, [1]) == null)
	_at(b, owner, "resident_overflow_approach"); b.global_position.y = -.10
	_check("overflow approach accepts planar stance and supported height", owner.request_transit("b", b, [4]) == owner.position_marker("resident_overflow_approach"))
	_check("queued transit cancellation independent of service wait", owner.release_transit("b", b)
		and owner.request_service("b", b) == owner.position_marker("resident_wait_front"))
	_completed.append("cancel_transit")

func _lifetime() -> void:
	var owner := _fixture()
	var a := _body(); var b := _body(); var replacement := _body()
	_check("lifetime fixture binds and transfers", owner.bind("a", a) and owner.bind("b", b)
		and owner.request_service("a", a) != null and owner.try_service("a", a, true))
	_at(a, owner, "service_stance")
	_check("lifetime fixture at actual service", owner.arrive_service("a", a) and owner.request_service("b", b) != null)
	a.queue_free()
	_check("stale state removal is not physical clearance", not owner.has_service("b", b) and not owner.try_service("b", b, false))
	await get_tree().process_frame
	_check("next owner still needs explicit admission", not owner.has_service("b", b) and owner.try_service("b", b, true))
	_check("replacement identity binds without inheriting service", owner.bind("a", replacement)
		and not owner.has_service("a", replacement))
	remove_child(owner)
	_check("detached owner refuses new work", owner.request_service("a", replacement) == null and not owner.has_service("b", b))
	add_child(owner)
	_check("retired owner remains inert on reattachment", owner.request_service("a", replacement) == null)
	_completed.append("lifetime")

func _inputs() -> Dictionary:
	var out := {}
	for path: String in INPUTS: out[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	return out

func _finish() -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("BODEGA ADMISSION: missing SHOT_DIR"); get_tree().quit(2); return
	var result := {"schema_version": 2, "evidence_kind": "diagnostic", "production_runtime": false,
		"status": "PASS" if failures.is_empty() else "FAIL", "scope": "synthetic FIFO/service state only; placement is explicit fixture setup, no physical clearance or motor/attendance proof",
		"source_hashes": _initial, "completed_groups": _completed, "checks": checks, "failures": failures,
		"engine_errors": _logger.errors.duplicate(), "execution": {"completed": true, "timed_out": false,
			"exit_code": 0 if failures.is_empty() else 1, "elapsed_s": (Time.get_ticks_msec()-_started)/1000.0}}
	var file := FileAccess.open(directory.path_join("bodega_admission.json"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush()
	var written := file.get_error() == OK; file.close()
	print("BODEGA ADMISSION TEST: ", checks.size(), " checks; ", failures.size(), " failures")
	get_tree().quit(0 if written and failures.is_empty() else 1)

func _queued_retarget() -> void:
	# Synthetic state fixture: these placements certify no native route clearance.
	var owner := _fixture()
	var departing := _body(); var rear_body := _body(); var overflow_body := _body(); var newcomer := _body()
	_check("retarget race fixture binds", owner.bind("departing", departing) and owner.bind("rear", rear_body)
		and owner.bind("overflow", overflow_body) and owner.bind("newcomer", newcomer))
	var front: Node3D = owner.position_marker("resident_wait_front")
	_check("retarget race fills authored wait slots", owner.request_service("departing", departing) == front
		and owner.request_service("rear", rear_body) == owner.position_marker("resident_wait_rear")
		and owner.request_service("overflow", overflow_body) == owner.position_marker("resident_overflow"))
	_at(departing, owner, "resident_wait_front")
	_at(rear_body, owner, "resident_wait_rear")
	_at(overflow_body, owner, "resident_overflow")
	_check("departure first reserves exact current transit stance", owner.request_transit("departing", departing, [1]) == front)
	_check("queued service release retains departure holding", owner.release_service("departing", departing)
		and owner.request_transit("departing", departing, [1]) == front)
	_check("new arrival cannot steal vacating slot before crossing", owner.request_service("newcomer", newcomer) == null)
	_check("departure explicitly enters and retains active custody", owner.try_transit("departing", departing, true)
		and not owner.release_transit("departing", departing, false) and owner.has_transit("departing", departing))
	_check("active departure still protects slot from newcomer", owner.request_service("newcomer", newcomer) == null)
	departing.global_position += Vector3(0, 0, 2) # Deliberate synthetic clear endpoint, not a motor trip.
	_check("declared clear endpoint is outside the old stance", departing.global_position.distance_to(front.global_position) > .65)
	_check("only guide-certified clear releases transit", owner.release_transit("departing", departing, true)
		and not owner.has_transit("departing", departing))
	_check("newcomer now reuses exactly the released front hole", owner.request_service("newcomer", newcomer) == front)
	_check("reuse cannot jump the older rear FIFO owner", not owner.try_service("newcomer", newcomer, true)
		and not owner.has_service("rear", rear_body) and owner.try_service("rear", rear_body, true))
	_check("existing overflow request remains stable", owner.request_service("overflow", overflow_body) == owner.position_marker("resident_overflow"))
	_completed.append("queued_retarget")
