extends Node3D
class HouseClock extends Node:
	var minute := 180.0
	func _minute_now() -> float: return minute
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print("DETECTOR DRIVE: ",label," = ",ok)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	RealityState.persistence_enabled=false
	var house := HouseClock.new();add_child(house)
	var detector := WatchmanClockProp.new();add_child(detector)
	detector._clock_source=house
	detector.native_manipulation_ready()
	detector.set_process(false)
	var drive: RefCounted=detector._native_drive
	var before: float=detector._paper.rotation.z
	house.minute+=30;detector._process(0)
	check(is_equal_approx(detector._paper.rotation.z,before),"unseated paper stays still")
	check(is_equal_approx(drive.spindle_turn,210.0/1440),"running arbor follows house clock")
	detector.movement_running=false
	var stopped: float=drive.spindle_turn
	var hand: float=detector._hand.rotation.z
	house.minute+=20;detector._process(0)
	check(is_equal_approx(drive.spindle_turn,stopped) and is_equal_approx(detector._hand.rotation.z,hand),"stop freezes arbor and hand")
	detector.dial_seated=true;detector.datum=detector.correct_datum();detector.datum_set=true
	detector.movement_running=true
	drive.invalidate_proof()
	check(not drive.punch(),"one punch cannot prove motion")
	check(not drive.punch() and not detector.marks_prove_movement(),"same-time punches cannot invent separation")
	var first: float=detector.proof_first
	house.minute+=18;detector._process(0)
	check(detector.record_is_honest(),"running paper retains correct datum")
	check(drive.punch(),"separate observations eighteen clock minutes apart prove motion")
	check(is_equal_approx(absf(detector.proof_second-first),18.0/1440),"separation equals measured elapsed time")
	check(not detector.detector_honest,"proof does not bypass publication owner")
	var world_mark: Vector3=detector._paper.transform*detector._proof_b.position
	check(Vector2(world_mark.x,world_mark.y).distance_to(Vector2(detector._punch_head.position.x,detector._punch_head.position.y))<.0001,"fresh hole sits under fixed punch in both axes")
	drive.invalidate_proof()
	check(detector.proof_first<0 and detector.proof_second<0,"adjustment clears previous proof")
	house.minute=1439;drive.restore({"spindle_turn":.8})
	detector.datum=.5
	house.minute=1;detector._process(0)
	check(is_equal_approx(detector.datum,.5+2.0/1440),"midnight advances two minutes")
	detector.movement_running=false
	var snapshot := detector.maintenance_snapshot()
	house.minute=120;detector.restore_maintenance_snapshot(snapshot);detector._process(0)
	check(is_equal_approx(drive.spindle_turn,float(snapshot.native_drive.spindle_turn)),"restore does not wind offline time")
	check(not drive.valid({"spindle_turn":NAN}),"nonfinite spindle rejected")
	print("DETECTOR DRIVE RESULT ",checks," checks ",failures," failures")
	detector.queue_free();house.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
