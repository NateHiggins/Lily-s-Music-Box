extends Node

const FortuneScript := preload("res://scripts/props/fortune_answer_prop.gd")
var failures := 0
var checks := 0
var heard: Array[Dictionary] = []


func _check(ok: bool, label: String) -> void:
	checks += 1
	print("  [%s] %s" % ["fortune ok" if ok else "FORTUNE FAIL", label])
	if not ok: failures += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var machine: Node = FortuneScript.new()
	machine.prop_type = "fortune_answer"
	add_child(machine)
	machine.answer_given.connect(func(record: Dictionary) -> void: heard.append(record))
	var save_before := var_to_bytes(RealityState.data)
	var handle := machine.find_child("OperatingHandle", true, false) as Node3D
	var handle_rest: float = handle.rotation.z
	_check(not machine.work_machine().accepted and machine.balking()
			and absf(handle.rotation.z - handle_rest) > 0.1,
			"REFUSAL: no answer without a coin, and the handle balks visibly")
	var clean: Dictionary = machine.mechanism_snapshot()
	machine.restore_mechanism_snapshot(clean)
	machine.set_powered(false)
	_check(machine.load_coin("YES") and not machine.work_machine().accepted
			and machine.balking() and machine.sequence == 0,
			"REFUSAL: a coin cannot position the striker without current")
	machine.restore_mechanism_snapshot(clean)
	_check(machine.load_coin("YES") and not machine.load_coin("NO"),
			"one penny occupies exactly one visible race")
	var striker := machine.find_child("CommonStriker", true, false) as Node3D
	_check(striker.position.x < -0.04,
			"the YES trough selects one side of the common striker")
	var yes: Dictionary = machine.work_machine()
	_check(yes.accepted and yes.answer == "YES" and heard.size() == 1,
			"the YES race makes exactly one YES answer")
	_check(bool(heard[0].powered),
			"the answer records that selector current was present at actuation")
	_check(is_zero_approx(striker.position.x),
			"working the plunger returns the common striker to neutral")
	_check(heard[0].keys().size() == FortuneScript.ANSWER_FIELDS.size()
			and heard[0].keys().all(func(k: Variant) -> bool:
				return str(k) in FortuneScript.ANSWER_FIELDS),
			"the published fact is closed to mechanism, path and sequence")
	_check(machine.load_coin("NO") and machine.work_machine().answer == "NO"
			and heard.size() == 2, "the NO race makes exactly one NO answer")
	_check(not machine.has_meta("question") and not machine.get_property_list().any(
			func(p: Dictionary) -> bool: return str(p.name).contains("question")),
			"the iron has nowhere to store or understand a question")
	var loaded: Dictionary = machine.mechanism_snapshot()
	var head := machine.find_child("AnsweringHead", true, false) as Node3D
	var loaded_pose: Vector3 = head.rotation
	machine.load_coin("YES")
	machine.work_machine()
	machine.restore_mechanism_snapshot(loaded)
	_check(machine.mechanism_snapshot() == loaded and not machine.balking()
			and head.rotation.is_equal_approx(loaded_pose)
			and is_zero_approx(handle.rotation.z),
			"abort restores every transient mechanism fact")
	_check(var_to_bytes(RealityState.data) == save_before,
			"ordinary answers write no campaign state")
	var source := FileAccess.get_file_as_string(
			"res://scripts/props/fortune_answer_prop.gd")
	_check(not source.contains("WorkOrders") and not source.contains("RealityCases")
			and not source.contains("RealityState") and not source.contains("commit("),
			"the prop owns no job, case, story or persistence seam")
	_check(machine.prop_type == "fortune_answer"
			and not source.contains("ArcadeCabinetProp")
			and not source.contains("ArcadeMachine"),
			"the novelty is not an arcade cabinet or programme host")
	print("FORTUNE ANSWER TEST: %s (%d/%d)" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
