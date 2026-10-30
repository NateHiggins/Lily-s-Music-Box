extends Node
## Matched production views: circuit off/on, then room plus carried lamp.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Harness := preload("res://tests/shot_harness.gd")
const VIEWS := preload("res://tests/orison_v2_upper_apartment_shot.gd").VIEWS
const ROOMS := ["F05_A_MAIN","F05_B_KITCHEN","F05_C_BED1","F06_A_STUDY","F06_C_MAIN"]
var shots = Harness.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var shadow_pair:=OS.get_environment("V2_LIGHTING_SHADOW_PAIR")=="1"
	var build_started:=Time.get_ticks_msec()
	if not shadow_pair and not shots.setup(self,"V2 UPPER LIGHTING",VIEWS.size()*3):
		get_tree().quit(2)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.configure_date(1928,11,10,20*60)
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	if world.startup_failed:
		world.shutdown_for_tests()
		world.free()
		get_tree().quit(2)
		return
	if shadow_pair:
		# The opt-in paired optical cohort has its own54-second capture bound;
		# the long runner separately bounds and records full-world composition.
		print("V2 SHADOW PAIR composition_ms=",Time.get_ticks_msec()-build_started)
		if not shots.setup(self,"V2 SHADOW PAIR",VIEWS.size()*6):
			world.shutdown_for_tests();world.free();get_tree().quit(2);return
	var player := world.player
	if shadow_pair:
		for driver:CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):driver.set_frozen_for_tests(true)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.camera.make_current()
	var ok := true
	var shadow_before:int=world.light_rig._shadow_budget
	for i in VIEWS.size():
		var view: Array = VIEWS[i]
		player.global_position = world.adapter.root.to_global(view[1])
		player.camera.global_position = player.global_position+Vector3.UP*player.STANDING_EYE
		player.camera.look_at(world.adapter.root.to_global(view[2]))
		var plate: Node = world.adapter.resolve(ROOMS[i]+"_SWITCH")
		for state: String in ["off","on","lamp"]:
			player.set_lamp_enabled(state == "lamp")
			if state != "lamp":plate.call("interact",player)
			# Let the real filament cool before treating a frame as lamp-off.
			if not await shots.settle(3.0 if state == "off" else 1.0,str(view[0])+"_"+state):
				ok = false
				break
			# Cold GPU work can consume wall-clock time without advancing the
			# bounded thermal integrator by the same amount. Wait for its real
			# output, within the unchanged capture deadline; never hide the lamp.
			while state != "lamp" and player.flashlight.visible and shots.remaining_seconds()>14.0:
				await RenderingServer.frame_post_draw
			if state != "lamp" and player.flashlight.visible:
				push_error("Room-only capture still has a visible carried lamp: logical=%s processing=%s optical=%s"%[player.lamp_is_enabled(),player.is_processing(),player.lamp_presentation.output if is_instance_valid(player.lamp_presentation) else {}])
				ok = false
				break
			if shadow_pair:
				# Optical comparison only. Circuit toggles remain the old fixture;
				# these frames do not establish direct-manipulation compliance.
				for budget:int in [32,8]:
					world.light_rig.set_budgets(world.light_rig._active_budget,budget)
					if world.light_rig._shadow_budget!=budget:
						ok=false;push_error("Shadow-pair override refused; clear SHADOW_BUDGET");break
					if not await shots.settle(.3,str(view[0])+"_"+state+"_s"+str(budget)) or not await shots.capture(str(view[0])+"_"+state+"_s"+str(budget)):
						ok=false;break
				world.light_rig.set_budgets(world.light_rig._active_budget,shadow_before)
				if not ok:break
			else:
				if not await shots.capture(str(view[0])+"_"+state):
					ok = false
					break
		if not ok:break
	ok = shots.finish() and ok
	world.shutdown_for_tests()
	world.free()
	get_tree().quit(0 if ok else 1)
