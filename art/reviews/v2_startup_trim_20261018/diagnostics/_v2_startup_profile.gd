extends Node
func _ready() -> void:run.call_deferred()
func run() -> void:
	Engine.set_meta("v2_startup_profile",[])
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928,10,15,750)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world=(load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	var probe=load("res://tests/_v2_startup_profile_runtime.gd") as GDScript
	if probe==null or not probe.can_instantiate():
		world.free();get_tree().quit(1);return
	world.set_script(probe)
	add_child(world)
	var events: Array=Engine.get_meta("v2_startup_profile",[])
	var report={"evidence_class":"INERT","startup_failed":world.startup_failed,"startup_ms":world.startup_ms,"events":events}
	var f=FileAccess.open("C:/PleaseRemainOnTheLine/tmp/v2-retirement-20261018/startup1.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "));f.close()
	print("STARTUP PROFILE ","FAIL" if world.startup_failed else "PASS"," events=",events.size()," ms=",world.startup_ms)
	var failed: bool=world.startup_failed
	world.shutdown_for_tests();world.free()
	Engine.remove_meta("v2_startup_profile")
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
