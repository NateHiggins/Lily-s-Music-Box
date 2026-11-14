extends Node
## Synthetic state-owner diagnostic only: no geometry, motion or attendance proof.
const Admission := preload("res://scripts/characters/shared_passage_admission.gd")
const INPUTS := ["res://scripts/characters/shared_passage_admission.gd",
	"res://tests/shared_passage_admission_test.gd", "res://tests/SharedPassageAdmissionTest.tscn",
	"res://tests/guide_bell_error_capture.gd"]
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var _initial: Dictionary = {}
var _started := 0
var _completed: Array[String] = []
var _logger

func _ready() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	checks.append({"label": label, "passed": ok})
	if not ok: failures.append(label)
	print("PASSAGE ADMISSION: ", label, " = ", ok)

func _body() -> Node3D:
	var node := Node3D.new()
	add_child(node)
	return node

func _run() -> void:
	_started = Time.get_ticks_msec(); _initial = _inputs()
	_logger = preload("res://tests/guide_bell_error_capture.gd").new(); OS.add_logger(_logger)
	_identity_fifo()
	_retarget_sides()
	_stale_holders()
	await get_tree().process_frame
	_check("all three test groups completed", _completed == ["identity_fifo", "retarget_sides", "stale_holders"])
	_check("all source bindings stable", _inputs() == _initial)
	_check("no unexpected engine errors", _logger.errors.is_empty())
	OS.remove_logger(_logger)
	_finish()

func _identity_fifo() -> void:
	var owner := Admission.new()
	var a := _body(); var b := _body(); var c := _body(); var wrong := _body()
	var poses := [a.transform, c.transform, wrong.transform]
	var holds: Array[Node3D] = [_body(), _body()]
	_check("bind rejects empty identity and missing actor", not owner.bind("", a) and not owner.bind("a", null))
	_check("explicit exact binding is idempotent", owner.bind("a", a) and owner.bind("a", a))
	_check("duplicate identity and body alias refused", not owner.bind("a", wrong) and not owner.bind("alias", a))
	_check("other real bodies bind", owner.bind("b", b) and owner.bind("c", c))
	_check("invalid holding layouts refused", not owner.configure_passage("", holds)
		and not owner.configure_passage("gate", []) and not owner.configure_passage("gate", [holds[0], holds[0]]))
	_check("holding layout configured", owner.configure_passage("gate", holds))
	_check("holding node cannot belong to another passage", not owner.configure_passage("other", [holds[0]]))
	_check("unbound impostor cannot queue", owner.enqueue_passage("gate", "a", wrong) == null
		and owner.enqueue_passage("gate", "missing", wrong) == null)
	_check("first and second get distinct slots", owner.enqueue_passage("gate", "a", a) == holds[0]
		and owner.enqueue_passage("gate", "b", b) == holds[1])
	_check("retry keeps slot and order", owner.enqueue_passage("gate", "a", a) == holds[0])
	_check("full queue refuses overflow", owner.enqueue_passage("gate", "c", c) == null)
	_check("queued passage cannot reconfigure", not owner.configure_passage("gate", holds))
	_check("blocked head and later clear body cannot enter", not owner.try_admit("gate", "a", a, false)
		and not owner.try_admit("gate", "b", b, true))
	_check("only explicit clear head enters", owner.try_admit("gate", "a", a, true))
	_check("admission is idempotent", owner.try_admit("gate", "a", a, true) and owner.has_admission("gate", "a", a))
	_check("active owner retains its slot", owner.enqueue_passage("gate", "a", a) == holds[0]
		and owner.enqueue_passage("gate", "c", c) == null)
	_check("false clearance retains custody", not owner.try_admit("gate", "a", a, false)
		and owner.has_admission("gate", "a", a) and not owner.try_admit("gate", "b", b, true))
	_check("wrong owner cannot release or cancel", not owner.leave_passage("gate", "a", wrong)
		and not owner.cancel("a", wrong) and owner.has_admission("gate", "a", a))
	_check("exact release does not promote follower", owner.leave_passage("gate", "a", a)
		and not owner.has_admission("gate", "b", b) and not owner.leave_passage("gate", "a", a))
	_check("old waiter stays in its slot", owner.enqueue_passage("gate", "b", b) == holds[1])
	_check("new body reuses hole without queue jumping", owner.enqueue_passage("gate", "c", c) == holds[0]
		and not owner.try_admit("gate", "c", c, true))
	_check("next FIFO owner enters", owner.try_admit("gate", "b", b, true))
	b.queue_free()
	_check("queued-for-deletion owner is pruned without auto promotion", not owner.has_admission("gate", "c", c))
	_check("follower explicitly enters after dead owner", owner.try_admit("gate", "c", c, true))
	_check("dead identity can bind its replacement", owner.bind("b", wrong))
	_check("cancel active is idempotent and does not revive it", owner.cancel("c", c) and owner.cancel("c", c)
		and not owner.has_admission("gate", "c", c) and not owner.try_admit("gate", "c", c, true))
	_check("ordinary revisit retains exact binding", owner.enqueue_passage("gate", "c", c) == holds[0]
		and owner.try_admit("gate", "c", c, true))
	_check("policy never moves a body", [a.transform, c.transform, wrong.transform] == poses)
	_completed.append("identity_fifo")

func _retarget_sides() -> void:
	var owner := Admission.new(); var door := Admission.new()
	var a := _body(); var b := _body(); var c := _body()
	var holds: Array[Node3D] = [_body(), _body()]
	var door_hold := _body(); var other_hold := _body()
	_check("side fixture binds", owner.bind("a", a) and owner.bind("b", b) and owner.bind("c", c)
		and owner.configure_passage("gate", holds) and owner.configure_passage("other", [other_hold]))
	_check("matches validates exact ordered markers", owner.matches_passage("gate", holds)
		and not owner.matches_passage("gate", [holds[1], holds[0]]))
	_check("opposite-side head uses only own slot", owner.enqueue_passage("gate", "a", a, [1]) == holds[1])
	_check("retry cannot switch sides or passages", owner.enqueue_passage("gate", "a", a, [0]) == null
		and owner.enqueue_passage("other", "a", a) == null)
	_check("full side cannot spill into free opposite side", owner.enqueue_passage("gate", "b", b, [1]) == null)
	_check("invalid side cannot allocate", owner.enqueue_passage("gate", "c", c, [99]) == null)
	_check("other side queues without overtaking", owner.enqueue_passage("gate", "b", b, [0]) == holds[0]
		and not owner.try_admit("gate", "b", b, true))
	_check("retarget cancels only exact waiter", owner.cancel("a", a) and owner.cancel("a", a)
		and not owner.has_admission("gate", "b", b) and owner.enqueue_passage("gate", "b", b) == holds[0])
	_check("surviving FIFO head explicitly enters", owner.try_admit("gate", "b", b, true))
	_check("same actor can own independent doorway registry", door.bind("b", b)
		and door.configure_passage("door", [door_hold]) and door.enqueue_passage("door", "b", b) == door_hold
		and door.try_admit("door", "b", b, true) and owner.has_admission("gate", "b", b))
	_check("cancel one resource preserves other owner", owner.cancel("b", b) and door.has_admission("door", "b", b))
	_check("retargeted live body may revisit", owner.enqueue_passage("gate", "a", a, [1]) == holds[1]
		and owner.try_admit("gate", "a", a, true))
	_check("second resource needs its own exact release", door.leave_passage("door", "b", b)
		and not door.has_admission("door", "b", b))
	_completed.append("retarget_sides")

func _stale_holders() -> void:
	var owner := Admission.new()
	var a := _body(); var b := _body(); var wrong := _body()
	var first := _body(); var second := _body()
	_check("stale fixture queued", owner.bind("a", a) and owner.bind("b", b)
		and owner.configure_passage("gate", [first, second])
		and owner.enqueue_passage("gate", "a", a) == first and owner.enqueue_passage("gate", "b", b) == second)
	first.free()
	_check("deleted waiting marker retires waiter without promotion", not owner.try_admit("gate", "a", a, true)
		and not owner.has_admission("gate", "b", b))
	_check("next live holder may explicitly enter", owner.try_admit("gate", "b", b, true))
	second.free()
	_check("deleted holding marker never revokes live crossing", owner.has_admission("gate", "b", b)
		and not owner.leave_passage("gate", "b", wrong))
	var replacement := _body()
	_check("active crossing prevents layout replacement", not owner.configure_passage("gate", [replacement]))
	_check("exact owner release permits new layout", owner.leave_passage("gate", "b", b)
		and owner.configure_passage("gate", [replacement]))
	_check("live binding survives marker replacement", owner.enqueue_passage("gate", "a", a) == replacement)
	a.free()
	_check("freed queued owner pruned; no inherited admission", owner.bind("a", wrong)
		and not owner.try_admit("gate", "a", wrong, true))
	_check("replacement must enqueue afresh", owner.enqueue_passage("gate", "a", wrong) == replacement
		and owner.try_admit("gate", "a", wrong, true))
	remove_child(wrong)
	_check("detached owner loses physical-world admission", not owner.has_admission("gate", "a", wrong))
	add_child(wrong)
	_check("reattached body must bind and queue anew", not owner.try_admit("gate", "a", wrong, true) and owner.bind("a", wrong) and owner.enqueue_passage("gate", "a", wrong) == replacement and owner.try_admit("gate", "a", wrong, true))
	_completed.append("stale_holders")

func _inputs() -> Dictionary:
	var result := {}
	for path: String in INPUTS:
		result[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	return result

func _finish() -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("PASSAGE ADMISSION: SHOT_DIR unavailable"); get_tree().quit(2); return
	var result := {"schema_version": 2, "evidence_kind": "diagnostic", "production_runtime": false,
		"status": "PASS" if failures.is_empty() else "FAIL",
		"scope": "loaded FIFO state owner with synthetic bodies/markers; no native geometry, motion, door, schedule, shopping or arrival proof",
		"execution": {"completed": true, "exit_code": 0 if failures.is_empty() else 1,
			"timed_out": false, "elapsed_s": (Time.get_ticks_msec() - _started) / 1000.0},
		"source_hashes": _initial, "completed_groups": _completed, "checks": checks,
		"failures": failures, "engine_errors": _logger.errors.duplicate()}
	var file := FileAccess.open(directory.path_join("passage_admission.json"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush()
	var written := file.get_error() == OK; file.close()
	print("PASSAGE ADMISSION TEST: ", checks.size(), " checks; ", failures.size(), " failures")
	get_tree().quit(0 if written and failures.is_empty() else 1)
