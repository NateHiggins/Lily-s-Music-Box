extends Node3D
## Bounded real-player/native-device input-phase diagnostic; no city or save proof.
class OpticalDriver extends "res://tests/v2_book_lamp_diagnostic.gd":
	func _ready() -> void: pass # Reuse the actual stimulus without constructing a city.

var checks: Array[Dictionary]=[]
var driver: OpticalDriver
var player: PlayerController
var records: Array[Dictionary]=[]

func check(ok: bool,label: String) -> bool:
	checks.append({"ok":ok,"label":label})
	print("LAMP INPUT PHASE CHECK: ",label," = ",ok)
	return ok

func _ready() -> void: _run.call_deferred()

func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	player=PlayerController.new();add_child(player)
	player.set_physics_process(false) # No locomotion in this input-only fixture.
	player.camera.make_current()
	var carrier:=preload("res://scripts/device/companion_world_carrier.gd").new()
	await carrier.setup(player,player.camera,null)
	player.carried_device=carrier
	if not check(carrier.world_ready,"actual native carrier/device binds"): _finish();return
	var thermal:=preload("res://scripts/lamp/carried_lamp_optical_driver.gd").new()
	add_child(thermal)
	if not check(thermal.setup(player),"original thermal presentation owner binds"): _finish();return
	driver=OpticalDriver.new();driver.player=player;add_child(driver)
	if not check(player.is_processing() and not Input.is_action_pressed("lamp_toggle") and not is_instance_valid(player.text_input_owner),"actual player poll and unowned lamp action are available"): _finish();return
	await RenderingServer.frame_post_draw
	var original: bool=player.lamp_is_enabled()
	var before_frame: int=Engine.get_process_frames()
	Input.action_press("lamp_toggle")
	var at_press: Dictionary={"process_frame":before_frame,"pressed":Input.is_action_pressed("lamp_toggle"),"just_pressed":Input.is_action_just_pressed("lamp_toggle"),"logical":player.lamp_is_enabled()}
	for frame in 2:await get_tree().process_frame
	Input.action_release("lamp_toggle")
	await RenderingServer.frame_post_draw
	records.append({"phase":"original_post_draw_stimulus","at_press":at_press,"after_process_frame":Engine.get_process_frames(),"after_logical":player.lamp_is_enabled(),"device_logical":carrier.device.lamp_enabled})
	check(player.lamp_is_enabled()==original and carrier.device.lamp_enabled==original,"original post-draw action reproduces missed player toggle")
	# Actual corrected observer method, actual engine callbacks; no direct player
	# _process, switch setter, physical lever setter or replacement device state.
	check(await driver._optics_lamp_power(not original,"probe_aligned_toggle"),"corrected observer toggles through real player poll")
	check(player.lamp_is_enabled()!=original and carrier.device.lamp_enabled!=original,"logical player and original device both change")
	check(await driver._optics_lamp_power(original,"probe_aligned_restore"),"corrected observer restores through the same input")
	check(player.lamp_is_enabled()==original and carrier.device.lamp_enabled==original,"original logical player/device state restored")
	check(driver.failures.is_empty(),"actual observer retains all input/thermal assertions")
	_finish()

func _finish() -> void:
	var failed:=false
	for row: Dictionary in checks:
		if not row.ok:failed=true
	var output:=OS.get_environment("SHOT_DIR")
	if output.is_empty():get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	var file:=FileAccess.open(output.path_join("input_phase.json"),FileAccess.WRITE)
	if file==null:get_tree().quit(2);return
	file.store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"records":records,"lamp_controls":driver.lamp_controls if driver!=null else [],"failures":driver.failures if driver!=null else [],"scope":"Actual player/native device/thermal owner, engine-polled action timing only. Player locomotion disabled; no installed route, save, readability, performance or artistic acceptance."},"\t"));file.close()
	print("BOOK LAMP INPUT PHASE PROBE: ","FAIL" if failed else "PASS"," checks=",checks.size())
	get_tree().quit(1 if failed else 0)
