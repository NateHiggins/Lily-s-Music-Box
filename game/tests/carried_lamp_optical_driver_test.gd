extends Node
const Driver := preload("res://scripts/lamp/carried_lamp_optical_driver.gd")
const State := preload("res://scripts/lamp/lamp_optical_state.gd")
const Snapshot := preload("res://scripts/lamp/lamp_optical_snapshot.gd")
var player: PlayerController
var driver: Node
var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _make_player() -> void:
	player = PlayerController.new()
	add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.camera.make_current()
	driver = Driver.new()
	player.add_child(driver)
	_check(driver.setup(player),"driver setup")

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	_check(clock.configure_date(1928,11,10,20*60),"fixed campaign clock")
	_make_player()
	for i in 120: player._advance_lamp(1.0/120.0)
	_check(player.lamp_is_enabled() and player.flashlight.light_energy > 0,"preserved controller warms actual lamp")
	var reference := State.new()
	reference.restore_state(driver.state.save_state())
	for i in 120:
		reference.advance(1.0/120.0)
		player._advance_lamp(1.0/120.0)
	_check(driver.state.save_state() == reference.save_state(),"driver advances exactly the preserved state algorithm")
	var before: Dictionary = driver.state.save_state()
	player.set_lamp_enabled(true)
	_check(driver.state.save_state() == before,"reasserting switch does not reset thermal state")
	player.mechanical_stimulus.emit(Vector3.ZERO,&"impulse",.6,Vector3.UP,.1,&"floor")
	_check(driver.state.mechanical_shock >= .6,"physical impact reaches existing controller")
	player.set_lamp_enabled(false)
	_check(not player.lamp_is_enabled() and not driver.state.switched_on,"logical off is immediate")
	player._advance_lamp(1.0/120.0)
	_check(player.flashlight.light_energy > 0 and not player.lamp_is_enabled(),"thermal tail cannot keep gameplay switch on")
	var expected: Dictionary = driver.state.save_state()
	_check(Snapshot.valid(expected),"current snapshot validates")
	for key in ["switched_on","seed","filament_temperature_k","version"]:
		var invalid := expected.duplicate()
		invalid.erase(key)
		_check(not Snapshot.valid(invalid),"incomplete snapshot refused: "+key)
	var nonfinite := expected.duplicate()
	nonfinite.intensity_rate = NAN
	_check(not Snapshot.valid(nonfinite),"nonfinite state refused")
	var directory := ProjectSettings.globalize_path("user://tests")
	DirAccess.make_dir_recursive_absolute(directory)
	var path := "user://tests/lamp_optical_%s.json"%Crypto.new().generate_random_bytes(8).hex_encode()
	var old_path: String = RealityState.save_path
	RealityState.save_path = path
	_check(RealityState.save_game(),"actual disk snapshot writes")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for key in expected:
		if disk.lamp_optics[key] != expected[key]:
			print("OPTICAL SAVE DIFFERENCE ",key," ",JSON.stringify([expected[key],disk.lamp_optics[key]],"",true,true))
	_check(RealityState.data.lamp_optics == expected,"snapshot hook captures complete live optical state")
	_check(_same_state(disk.lamp_optics,expected),"JSON retains optical state within 1e-12")
	var saved_hash := FileAccess.get_sha256(path)
	player._advance_lamp(.2)
	RealityState.save_write_blocked = true
	_check(not RealityState.save_game() and FileAccess.get_sha256(path) == saved_hash
			and RealityState.data.lamp_optics == expected,
			"protected save neither captures a newer state nor overwrites disk")
	RealityState.save_write_blocked = false
	var invalid_document: Dictionary = RealityState.data.duplicate(true)
	invalid_document.lamp_optics.version = 2
	_check(not RealityState._validate_document(invalid_document).ok,"unsupported optical version refused at disk admission")
	player.free()
	RealityState.load_game()
	_make_player()
	_check(_same_state(driver.state.save_state(),expected) and not player.lamp_is_enabled(),"disk reconstruction restores bounded state and logical switch")
	player.set_lamp_enabled(true)
	for i in 60: player._advance_lamp(1.0/60.0)
	var samples: Array[int] = []
	for i in 240:
		var started := Time.get_ticks_usec()
		player._advance_lamp(1.0/60.0)
		samples.append(Time.get_ticks_usec()-started)
	samples.sort()
	print("OPTICAL DRIVER CPU us median=%d p95=%d max=%d"%[samples[120],samples[227],samples[239]])
	_check(samples[239] < 200,"warm controller stays below 0.20 ms")
	player.free()
	RealityState.save_path = old_path
	for suffix in ["",".bak",".tmp",".txn"]:
		var own := ProjectSettings.globalize_path(path+suffix)
		if own.get_base_dir() == directory and FileAccess.file_exists(own): DirAccess.remove_absolute(own)
	print("CARRIED OPTICAL DRIVER: %d checks; %d failures"%[checks,failures])
	get_tree().quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	print("OPTICAL DRIVER CHECK: ",label," = ",ok)
	if not ok:
		failures += 1
		push_error(label)

func _same_state(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size(): return false
	for key in expected:
		if not actual.has(key): return false
		if typeof(expected[key]) == TYPE_FLOAT:
			if absf(float(actual[key])-float(expected[key])) > 1.0e-12: return false
		elif actual[key] != expected[key]: return false
	return true
