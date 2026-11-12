extends Node3D
## Production player/hand with a scalar owner that interrupts its own setter.
## Target acquisition is explicit fixture setup, not ray-picking qualification.
const ErrorCapture := preload("res://tests/guide_bell_error_capture.gd")
var player: PlayerController
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var modifications: Array[Dictionary] = []
var started := Time.get_ticks_msec()

class ScalarOwner extends Node3D:
	var holder: PlayerController
	var part: Node3D
	var mode := "cancel"
	var value := 0.0
	var held := false
	var begins := 0
	var ends := 0
	var reads := 0
	var stale_reads := 0
	var writes := 0
	var reads_at_write := 0
	var replacement_equal := false
	func descriptor() -> Dictionary:
		return {"kind":"slide", "owner":self, "part":part, "frame":self,
			"hit_position":part.global_position, "axis":Vector3.RIGHT,
			"minimum":0.0, "maximum":1.0, "gesture_travel_px":100.0,
			"gesture_screen_axis":Vector2.RIGHT, "unobstructed_hold":true,
			"begin":begin, "end":end, "owns":owns, "read":read_value, "write":write_value}
	func begin() -> bool:
		begins += 1
		held = true
		return true
	func end() -> void:
		ends += 1
		held = false
	func owns() -> bool: return held
	func read_value() -> float:
		reads += 1
		if not held: stale_reads += 1
		return value
	func write_value(next: float) -> void:
		writes += 1
		reads_at_write = reads
		value = next
		if mode == "retain": return
		var previous: Dictionary = holder._grab.target
		if mode == "notify": holder._grab.release()
		else: holder.cancel_manipulation()
		if mode == "reacquire":
			var replacement := descriptor()
			replacement_equal = previous == replacement and not is_same(previous,replacement)
			holder._grab.acquire(replacement)

func _ready() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"ok":ok, "label":label})
	if not ok: failures.append(label)
	print("SCALAR WRITE RELEASE: ",label," = ",ok)

func exercise(mode: String) -> void:
	var owner := ScalarOwner.new()
	owner.name = "Scalar_" + mode
	owner.holder = player
	add_child(owner)
	owner.part = Node3D.new()
	owner.add_child(owner.part)
	owner.part.global_position = player.camera.global_position + Vector3(0,0,-0.8)
	owner.mode = mode
	var original := owner.descriptor()
	var changes_before := modifications.size()
	check(player._grab.acquire(original),mode+": production hand acquires scalar owner")
	player._grab.profile_records.clear()
	# Use the production player's look-to-held-mechanism path. The test owns
	# neither a dialogue actor nor a replacement copy of ConstrainedGrab.
	player.apply_look(Vector2(20,0))
	check(owner.writes==1 and is_equal_approx(owner.value,0.2),mode+": scalar setter accepts bounded hand motion")
	check(owner.stale_reads==0,mode+": no owner read after custody ends")
	var motion_records: Array = player._grab.profile_records.filter(func(row): return row.stage=="constrained_motion")
	check(motion_records.size()==1 and motion_records[0].owner==str(owner.name),mode+": motion completes profiling with the original owner")
	if mode == "retain":
		check(player._grab.active() and player._grab.changed and owner.held,mode+": ordinary motion remains held and changed")
		player._grab.release()
		check(owner.ends==1 and modifications.size()==changes_before+1,mode+": normal release publishes exactly one accepted change")
	elif mode == "reacquire":
		check(owner.replacement_equal,mode+": replacement descriptor is equal in value but has separate identity")
		check(player._grab.active() and not is_same(player._grab.target,original) and not player._grab.changed,mode+": replacement hand keeps its own unchanged origin")
		check(owner.begins==2 and owner.ends==1 and owner.reads==owner.reads_at_write+2,mode+": only release observation and new acquisition read the owner")
		player._grab.release()
		check(owner.ends==2 and modifications.size()==changes_before,mode+": unchanged replacement release does not publish old motion")
	else:
		check(not player._grab.active() and not player._grab.changed and not owner.held and owner.ends==1,mode+": synchronous release retains cleared hand and ownership state")
		check(modifications.size()==changes_before+(1 if mode=="notify" else 0),mode+": original release notification policy is preserved")
	owner.free()

func _run() -> void:
	var logger := ErrorCapture.new()
	OS.add_logger(logger)
	RealityState.persistence_enabled = false
	player = PlayerController.new()
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.set_lamp_enabled(false)
	player.touch_input = true
	player._grab.profiling = true
	player.world_modified.connect(func(where: Vector3, what: String): modifications.append({"where":where,"what":what}))
	for mode in ["retain", "cancel", "notify", "reacquire"]: exercise(mode)
	player.free()
	check(logger.errors.is_empty(),"no engine/script errors during synchronous scalar writes")
	var result := {"schema_version":2, "evidence_kind":"runtime_contract", "selector":"v2", "production_runtime":false,
		"scope":"Actual PlayerController look path and ConstrainedGrab scalar owner with synchronous cancel, notified release and replacement grab; explicit fixture acquisition, not authored dialogue, ray picking or installed-room qualification",
		"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/tests/constrained_grab_scalar_release_test.gd","test_sha256":get_script().source_code.replace("\r\n","\n").sha256_text()},
		"contracts":{"scalar_write_release":{"executed":true,"status":"PASS" if failures.is_empty() else "FAIL"}},
		"checks":checks,"failures":failures,"engine_errors":logger.errors}
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("scalar_write_release_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SCALAR WRITE RELEASE RESULT: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks.size())
	OS.remove_logger(logger)
	get_tree().quit(0 if failures.is_empty() else 1)
