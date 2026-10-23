extends "res://tests/v2_fire_hand_bench.gd"
## Household payload diagnostics. Staged poses are not interaction qualification.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var adapter:=FixtureAdapter.new();adapter.root=Node3D.new();add_child(adapter.root)
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
	var native:=Native.new()
	if not check(native.mount(adapter,{"levels":[{"y":0.}]}),"production cabinet owners mount"):
		print(native.errors);get_tree().quit(1);return
	var actor: Node3D=native.stations.values()[0].get_ref()
	actor.set_process(false)
	var joint: Node3D=actor._nozzle_joint
	# This fixture stages an assembled nozzle; it does not prove assembly input.
	actor.nozzle_coupled=true;joint.restore_legacy(true)
	var legacy: Dictionary=actor.mechanism_snapshot()
	check(legacy.size()==8 and actor.valid_mechanism(legacy),"original eight-field cabinet save is valid")
	var hose:=preload("res://scripts/props/fire_unracked_hose.gd").new();actor.add_child(hose)
	var projection: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_unracked_fire_hose_rig.json"))
	var placement: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_unracked_fire_hose_placement.json"))
	if not check(hose.configure(actor,"res://tests/fixtures/v2_unracked_fire_hose.glb",projection,placement),"native hose prepares for saved-pose reconstruction"):
		print(hose.error);get_tree().quit(1);return
	hose.enable_visual_follow()
	var stored: Dictionary=actor.mechanism_snapshot()
	check(stored.size()==9 and actor.valid_mechanism(stored),"nine-field stored hose snapshot validates")
	# Fixture stages a remote receiver, not a player-input operation.
	hose.extraction=hose.EXTRACTION_M;hose._show_deployment(true);actor.hose_racked=false
	var wanted: Transform3D=actor.global_transform*hose._extracted_receiver
	wanted.origin+=Vector3(-3.,.4,1.)
	hose._visual_receiver(wanted)
	hose.water.restore({"fill":.8,"pressure":.65});actor._wheel_angle=3.
	var saved: Dictionary=actor.mechanism_snapshot()
	check(actor.valid_mechanism(saved),"deployed receiver, intermediate supply and trapped charge validate together")
	var saved_pose: Transform3D=joint.receiver
	wanted.origin+=Vector3(-2.,.2,0.);hose._visual_receiver(wanted)
	var live_pose: Transform3D=joint.receiver
	check(actor.valid_mechanism(saved) and joint.receiver==live_pose,"saved receiver validates without mutating the different live receiver")
	actor.restore_mechanism(saved)
	check(joint.receiver.is_equal_approx(saved_pose) and hose.deployed and hose.model.visible and not actor.hose_racked,"restore reconstructs the saved deployed representation and receiving pose")
	check(hose.water.snapshot()==saved.hose.water and actor._wheel_angle==3.,"restore retains charge and supply angle")
	check(hose.rig.strand.points[0].distance_to(hose.model.to_local(actor.to_global(saved_pose.origin)))<.00001,"resting native skin meets restored receiver")
	check(actor.valid_mechanism(actor.mechanism_snapshot()),"reconstructed cabinet immediately produces a valid snapshot")
	for defect: String in ["basis","reach","wheel","charge","racked","nozzle","extra","nan"]:
		var bad: Dictionary=saved.duplicate(true)
		match defect:
			"basis":bad.hose.receiver.basis[0][0]+=.2
			"reach":bad.hose.receiver.position[0]+=100.
			"wheel":bad.hose.wheel=TAU*2.+1.
			"charge":bad.hose.water.pressure=.95
			"racked":bad.facts.hose_racked=true
			"nozzle":bad.nozzle.position[0]+=.1
			"extra":bad.hose.unowned=true
			"nan":bad.hose.receiver.position[0]=NAN
		var before: Dictionary=actor.mechanism_snapshot()
		check(not actor.valid_mechanism(bad),"reject invalid saved "+defect)
		actor.restore_mechanism(bad)
		check(actor.mechanism_snapshot()==before,"invalid "+defect+" cannot partially mutate household owners")
	actor.restore_mechanism(stored)
	check(not hose.deployed and not hose.model.visible and actor.hose_racked and hose.water.fill==0.,"stored snapshot restores rack, emptiness and hidden extended skin")
	check(actor.valid_mechanism(saved),"deployed save remains valid from the stored receiver")
	actor.restore_mechanism(saved)
	check(actor.valid_mechanism(legacy),"legacy eight-field save validates from deployed state")
	actor.restore_mechanism(legacy)
	check(not hose.deployed and joint.receiver.is_equal_approx(hose._receiver) and hose.water.fill==0.,"legacy restore resets deployed representation and receiver")
	var old_nozzle: Dictionary=legacy.duplicate(true);old_nozzle.nozzle.erase("basis")
	check(actor.valid_mechanism(old_nozzle),"legacy five-field nozzle save remains valid")
	actor.restore_mechanism(old_nozzle)
	check(actor.valid_mechanism(actor.mechanism_snapshot()),"legacy reconstruction emits valid current payload")
	var events: Dictionary={"count":0,"water":{}}
	actor.manipulation_changed.connect(func() -> void:
		events.count+=1;events.water=actor.mechanism_snapshot().hose.water)
	# Exercise the numerical charge clock directly; actual control input is
	# covered separately by the retained windowed water programme.
	hose.extraction=hose.EXTRACTION_M;hose._show_deployment(true);actor.hose_racked=false
	actor.gasket_seated=true;actor.coupling_made_up=true;actor.nozzle_coupled=true
	actor._lever_angle=0.;actor.nozzle_shut=true;actor._wheel_angle=TAU*2.
	for step in 240:hose._physics_process(1./60.)
	check(events.count==1 and events.water.fill==1. and events.water.pressure==1.,"completed charge publishes one household update with final water state")
	check(not hose.is_physics_processing(),"stable charged reconstruction has no resting CPU callback")
	actor.gasket_seated=false
	for step in 300:hose._physics_process(1./60.)
	check(events.count==2 and events.water.fill==0. and events.water.pressure==0.,"completed drain publishes one household update with empty water state")
	check(not hose.is_physics_processing(),"stable empty reconstruction has no resting CPU callback")
	print("V2 HOSE SAVE: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
